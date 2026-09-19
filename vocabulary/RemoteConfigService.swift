//
//  RemoteConfigService.swift
//  vocabulary
//

import FirebaseCore
import FirebaseRemoteConfig

struct VocabularySection {
    let key: String
    let items: [JSONValue]

    var dayNumber: Int? {
        key.split(separator: "_").last.flatMap { Int($0) }
    }

    var title: String {
        key
    }
}

struct GrammarTopic {
    let title: String
    let html: String
}

enum RemoteConfigServiceError: Error {
    case emptyValue
    case decodingFailed(Error)
}

final class RemoteConfigService {
    static let shared = RemoteConfigService()

    private let vocabulariesKey = "vocabularies"
    private let grammarKey = "grammar"
    private let remoteConfig: RemoteConfig

    private init() {
        remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        remoteConfig.configSettings = settings
    }

    func fetchVocabularies(completion: @escaping (Result<[VocabularySection], Error>) -> Void) {
        fetchJSON(key: vocabulariesKey) { result in
            completion(result.map(Self.makeSections))
        }
    }

    func fetchGrammar(completion: @escaping (Result<[GrammarTopic], Error>) -> Void) {
        fetchJSON(key: grammarKey) { result in
            completion(result.map(Self.makeGrammarTopics))
        }
    }

    private func fetchJSON(key: String, completion: @escaping (Result<JSONValue, Error>) -> Void) {
        remoteConfig.fetchAndActivate { [weak self] _, error in
            guard let self else { return }

            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            let jsonString = self.remoteConfig[key].stringValue
            guard !jsonString.isEmpty else {
                DispatchQueue.main.async { completion(.failure(RemoteConfigServiceError.emptyValue)) }
                return
            }

            do {
                let root = try JSONParser.parse(jsonString)
                DispatchQueue.main.async { completion(.success(root)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(RemoteConfigServiceError.decodingFailed(error))) }
            }
        }
    }

    private static func makeSections(from root: JSONValue) -> [VocabularySection] {
        switch root {
        case .object(let pairs):
            return pairs
                .map { VocabularySection(key: $0.key, items: itemsArray(from: $0.value)) }
                .sorted { ($0.dayNumber ?? .max, $0.key) < ($1.dayNumber ?? .max, $1.key) }
        case .array(let items):
            return [VocabularySection(key: "all", items: items)]
        default:
            return [VocabularySection(key: "value", items: [root])]
        }
    }

    private static func itemsArray(from value: JSONValue) -> [JSONValue] {
        if case .array(let items) = value { return items }
        return [value]
    }

    private static func makeGrammarTopics(from root: JSONValue) -> [GrammarTopic] {
        switch root {
        case .array(let items):
            // [{ "title": "...", "grammar": "<html>" }, ...]
            return items.compactMap { item -> GrammarTopic? in
                guard case .object(let fields) = item else { return nil }
                guard case .string(let title)? = fields.first(where: { $0.key.lowercased() == "title" })?.value,
                      case .string(let html)? = fields.first(where: { $0.key.lowercased() == "grammar" })?.value else {
                    return nil
                }
                return GrammarTopic(title: title, html: html)
            }

        case .object(let pairs):
            // { "Title": { "grammar": "<html>" }, ... }
            return pairs.compactMap { pair -> GrammarTopic? in
                guard case .object(let fields) = pair.value,
                      case .string(let html)? = fields.first(where: { $0.key.lowercased() == "grammar" })?.value else {
                    return nil
                }
                return GrammarTopic(title: pair.key, html: html)
            }

        default:
            return []
        }
    }
}
