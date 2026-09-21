//
//  OrderedJSON.swift
//  vocabulary
//
//  A minimal JSON value + parser that preserves object key order,
//  since JSONSerialization/JSONDecoder do not guarantee it.
//

import Foundation

indirect enum JSONValue {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([(key: String, value: JSONValue)])

    var displayString: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            if value.truncatingRemainder(dividingBy: 1) == 0, abs(value) < 1e15 {
                return String(Int64(value))
            }
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .null:
            return ""
        case .array(let items):
            return "[" + items.map { $0.displayString }.joined(separator: ", ") + "]"
        case .object(let pairs):
            return "{" + pairs.map { "\($0.key): \($0.value.displayString)" }.joined(separator: ", ") + "}"
        }
    }
}

extension JSONValue {
    /// Text used by search: only the "word" and meaning fields (not IPA, part of speech or example
    /// sentences, which mention other words), one per line so a query can't span two fields.
    /// Falls back to every value when an object has none of those fields.
    var searchableText: String {
        switch self {
        case .object(let pairs):
            let searchKeys: Set<String> = ["word", "mean", "meaning"]
            let focused = pairs.filter { searchKeys.contains($0.key.lowercased()) }
            return (focused.isEmpty ? pairs : focused).map { $0.value.searchableText }.joined(separator: "\n")
        case .array(let items):
            return items.map { $0.searchableText }.joined(separator: "\n")
        default:
            return displayString
        }
    }

    var notificationContent: (title: String, body: String) {
        guard case .object(let pairs) = self else {
            return ("Từ vựng", displayString)
        }

        let partOfSpeech = pairs.first { $0.key.lowercased() == "part_of_speech" }?.value.displayString
        let title = (partOfSpeech?.isEmpty == false) ? partOfSpeech! : "Từ vựng"

        let excludedKeys: Set<String> = ["part_of_speech", "example"]
        let values = pairs.filter { !excludedKeys.contains($0.key.lowercased()) }.map { $0.value.displayString }
        let body: String
        if values.count > 1 {
            body = values[0] + "\n" + values[1...].joined(separator: " - ")
        } else {
            body = values.first ?? ""
        }
        return (title, body.isEmpty ? displayString : body)
    }

    /// Raw [key, value] pairs (as strings) for an object, in source order.
    /// Used to hand structured data to the notification content extension
    /// so it can render each field in its own color.
    var fieldPairs: [[String]] {
        guard case .object(let pairs) = self else { return [] }
        return pairs.map { [$0.key, $0.value.displayString] }
    }
}

enum JSONParseError: Error {
    case unexpectedEnd
    case unexpectedCharacter(Character)
    case invalidNumber(String)
    case invalidEscape
}

struct JSONParser {
    private let characters: [Character]
    private var index = 0

    private init(_ string: String) {
        characters = Array(string)
    }

    static func parse(_ string: String) throws -> JSONValue {
        var parser = JSONParser(string)
        parser.skipWhitespace()
        let value = try parser.parseValue()
        return value
    }

    private func peek() -> Character? {
        index < characters.count ? characters[index] : nil
    }

    private mutating func advance() -> Character? {
        guard index < characters.count else { return nil }
        defer { index += 1 }
        return characters[index]
    }

    private mutating func skipWhitespace() {
        while let c = peek(), c.isWhitespace { index += 1 }
    }

    private mutating func parseValue() throws -> JSONValue {
        skipWhitespace()
        guard let c = peek() else { throw JSONParseError.unexpectedEnd }
        switch c {
        case "{": return try parseObject()
        case "[": return try parseArray()
        case "\"": return .string(try parseString())
        case "t", "f": return try parseBool()
        case "n": return try parseNull()
        default: return try parseNumber()
        }
    }

    private mutating func parseObject() throws -> JSONValue {
        index += 1
        var pairs: [(String, JSONValue)] = []
        skipWhitespace()
        if peek() == "}" { index += 1; return .object(pairs) }

        while true {
            skipWhitespace()
            guard peek() == "\"" else { throw JSONParseError.unexpectedCharacter(peek() ?? " ") }
            let key = try parseString()
            skipWhitespace()
            guard advance() == ":" else { throw JSONParseError.unexpectedCharacter(":") }
            let value = try parseValue()
            pairs.append((key, value))
            skipWhitespace()
            switch advance() {
            case ",": continue
            case "}": return .object(pairs)
            default: throw JSONParseError.unexpectedCharacter("}")
            }
        }
    }

    private mutating func parseArray() throws -> JSONValue {
        index += 1
        var items: [JSONValue] = []
        skipWhitespace()
        if peek() == "]" { index += 1; return .array(items) }

        while true {
            let value = try parseValue()
            items.append(value)
            skipWhitespace()
            switch advance() {
            case ",": continue
            case "]": return .array(items)
            default: throw JSONParseError.unexpectedCharacter("]")
            }
        }
    }

    private mutating func parseString() throws -> String {
        index += 1
        var result = ""
        while let c = advance() {
            if c == "\"" { return result }
            if c == "\\" {
                guard let escaped = advance() else { throw JSONParseError.invalidEscape }
                switch escaped {
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                case "/": result.append("/")
                case "n": result.append("\n")
                case "t": result.append("\t")
                case "r": result.append("\r")
                case "b": result.append("\u{08}")
                case "f": result.append("\u{0C}")
                case "u":
                    let hexChars = (0..<4).compactMap { _ in advance() }
                    guard hexChars.count == 4,
                          let code = UInt32(String(hexChars), radix: 16),
                          let scalar = Unicode.Scalar(code) else {
                        throw JSONParseError.invalidEscape
                    }
                    result.append(Character(scalar))
                default:
                    throw JSONParseError.invalidEscape
                }
            } else {
                result.append(c)
            }
        }
        throw JSONParseError.unexpectedEnd
    }

    private mutating func parseBool() throws -> JSONValue {
        if matchLiteral("true") { return .bool(true) }
        if matchLiteral("false") { return .bool(false) }
        throw JSONParseError.unexpectedCharacter(peek() ?? " ")
    }

    private mutating func parseNull() throws -> JSONValue {
        if matchLiteral("null") { return .null }
        throw JSONParseError.unexpectedCharacter(peek() ?? " ")
    }

    private mutating func matchLiteral(_ literal: String) -> Bool {
        let literalChars = Array(literal)
        guard index + literalChars.count <= characters.count else { return false }
        guard Array(characters[index..<(index + literalChars.count)]) == literalChars else { return false }
        index += literalChars.count
        return true
    }

    private mutating func parseNumber() throws -> JSONValue {
        var text = ""
        while let c = peek(), "-+.eE0123456789".contains(c) {
            text.append(c)
            index += 1
        }
        guard let value = Double(text) else { throw JSONParseError.invalidNumber(text) }
        return .number(value)
    }
}

extension JSONValue {
    /// Compact JSON text that keeps object key order.
    var jsonString: String {
        switch self {
        case .string(let value):
            return Self.quoted(value)
        case .number, .bool:
            return displayString
        case .null:
            return "null"
        case .array(let items):
            return "[" + items.map { $0.jsonString }.joined(separator: ",") + "]"
        case .object(let pairs):
            return "{" + pairs.map { Self.quoted($0.key) + ":" + $0.value.jsonString }.joined(separator: ",") + "}"
        }
    }

    private static func quoted(_ string: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: string, options: .fragmentsAllowed),
              let text = String(data: data, encoding: .utf8) else { return "\"\"" }
        return text
    }

    /// The vocabulary word this item is keyed by: its "word" field, else its first field.
    var wordText: String {
        guard case .object(let pairs) = self, !pairs.isEmpty else { return displayString }
        return (pairs.first { $0.key.lowercased() == "word" } ?? pairs[0]).value.displayString
    }

    /// Fields in the usual reading order (word, part of speech, IPA, meaning, example, then the rest).
    /// Realtime Database returns object keys alphabetically, so stored words are put back in this order.
    var withCanonicalFieldOrder: JSONValue {
        guard case .object(let pairs) = self else { return self }
        let order = ["word", "part_of_speech", "ipa", "mean", "meaning", "example"]
        func rank(_ key: String) -> Int { order.firstIndex(of: key.lowercased()) ?? order.count }
        let sorted = pairs.enumerated()
            .sorted { (rank($0.element.key), $0.offset) < (rank($1.element.key), $1.offset) }
            .map { $0.element }
        return .object(sorted)
    }
}
