//
//  RememberedStore.swift
//  vocabulary
//
//  Words the user has marked as learned, kept in Firebase Realtime Database (REST API):
//    /remember_<section title>/<word> = { ...the word's fields... }
//

import Foundation

struct RememberedGroup {
    let title: String
    let items: [JSONValue]
}

enum RememberedStoreError: LocalizedError {
    case http(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .http(let status) where status == 401 || status == 403:
            return "Firebase Realtime Database từ chối truy cập (mã \(status)). Hãy kiểm tra Rules của database."
        case .http(let status):
            return "Realtime Database trả về lỗi (mã \(status))."
        case .invalidResponse:
            return "Dữ liệu từ Realtime Database không hợp lệ."
        }
    }
}

final class RememberedStore {
    static let shared = RememberedStore()
    static let didChange = Notification.Name("RememberedStore.didChange")

    private let baseURL = "https://vocabulary-29514-default-rtdb.firebaseio.com"
    private let nodePrefix = "remember_"

    /// Section groups, in natural title order. Only touched on the main thread.
    private(set) var groups: [RememberedGroup] = []
    private var keysByTitle: [String: Set<String>] = [:]

    private init() {}

    // MARK: - Lookup

    func isRemembered(_ item: JSONValue, title: String) -> Bool {
        keysByTitle[Self.sanitize(title)]?.contains(Self.key(for: item)) ?? false
    }

    // MARK: - Networking

    func refresh(completion: ((Error?) -> Void)? = nil) {
        guard let url = URL(string: baseURL + "/.json") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            let result: Result<[RememberedGroup], Error> = Self.parseGroups(data: data, response: response, error: error, prefix: self?.nodePrefix ?? "")
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let groups):
                    self.apply(groups: groups)
                    completion?(nil)
                case .failure(let error):
                    completion?(error)
                }
            }
        }.resume()
    }

    /// Adds (`remembered == true`) or removes the word. The local state is updated once the server accepts it.
    func setRemembered(_ remembered: Bool, item: JSONValue, title: String, completion: @escaping (Error?) -> Void) {
        guard let url = nodeURL(title: title, key: Self.key(for: item)) else {
            completion(RememberedStoreError.invalidResponse)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = remembered ? "PUT" : "DELETE"
        if remembered {
            request.httpBody = item.jsonString.data(using: .utf8)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            var failure = error
            if failure == nil, let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                failure = RememberedStoreError.http(http.statusCode)
            }
            DispatchQueue.main.async {
                if failure == nil { self?.applyLocal(remembered: remembered, item: item, title: title) }
                completion(failure)
            }
        }.resume()
    }

    // MARK: - Helpers

    /// Realtime Database keys can't contain . $ # [ ] / or control characters.
    private static func sanitize(_ text: String) -> String {
        let forbidden = CharacterSet(charactersIn: ".$#[]/").union(.controlCharacters)
        let cleaned = text.unicodeScalars.map { forbidden.contains($0) ? "_" : String($0) }.joined()
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "_" : trimmed
    }

    private static func key(for item: JSONValue) -> String {
        sanitize(item.wordText)
    }

    private func nodeURL(title: String, key: String) -> URL? {
        func encode(_ text: String) -> String {
            text.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? text
        }
        return URL(string: "\(baseURL)/\(encode(nodePrefix + Self.sanitize(title)))/\(encode(key)).json")
    }

    private static func parseGroups(data: Data?, response: URLResponse?, error: Error?, prefix: String) -> Result<[RememberedGroup], Error> {
        if let error { return .failure(error) }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            return .failure(RememberedStoreError.http(http.statusCode))
        }
        guard let data, let text = String(data: data, encoding: .utf8),
              let root = try? JSONParser.parse(text) else {
            return .failure(RememberedStoreError.invalidResponse)
        }
        guard case .object(let nodes) = root else { return .success([]) }

        let groups: [RememberedGroup] = nodes.compactMap { node in
            guard node.key.hasPrefix(prefix), case .object(let words) = node.value else { return nil }
            let items = words.map { $0.value.withCanonicalFieldOrder }
            return items.isEmpty ? nil : RememberedGroup(title: String(node.key.dropFirst(prefix.count)), items: items)
        }
        return .success(groups)
    }

    private func apply(groups newGroups: [RememberedGroup]) {
        groups = newGroups.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        keysByTitle = Dictionary(uniqueKeysWithValues: groups.map { group in
            (group.title, Set(group.items.map { Self.key(for: $0) }))
        })
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }

    private func applyLocal(remembered: Bool, item: JSONValue, title: String) {
        let key = Self.key(for: item)
        let title = Self.sanitize(title)
        var updated = groups
        let index = updated.firstIndex { $0.title == title }

        if remembered {
            if let index {
                let group = updated[index]
                if !group.items.contains(where: { Self.key(for: $0) == key }) {
                    updated[index] = RememberedGroup(title: title, items: group.items + [item])
                }
            } else {
                updated.append(RememberedGroup(title: title, items: [item]))
            }
        } else if let index {
            let remaining = updated[index].items.filter { Self.key(for: $0) != key }
            if remaining.isEmpty {
                updated.remove(at: index)
            } else {
                updated[index] = RememberedGroup(title: title, items: remaining)
            }
        }
        apply(groups: updated)
    }
}
