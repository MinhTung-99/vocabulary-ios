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
    /// Best-effort (title, body) for a notification, using a "word" field (plus
    /// "part_of_speech" when present) as the title, falling back to the item's raw
    /// display otherwise.
    var notificationContent: (title: String, body: String) {
        guard case .object(let pairs) = self else {
            return ("Từ vựng", displayString)
        }

        let wordPair = pairs.first { $0.key.lowercased() == "word" }
        var title = wordPair?.value.displayString ?? pairs.first?.value.displayString ?? "Từ vựng"
        if let partOfSpeech = pairs.first(where: { $0.key.lowercased() == "part_of_speech" })?.value.displayString,
           !partOfSpeech.isEmpty {
            title += " - \(partOfSpeech)"
        }

        let excludedKeys: Set<String> = ["word", "part_of_speech"]
        let remaining = pairs.filter { !excludedKeys.contains($0.key.lowercased()) }
        let body = remaining.map { $0.value.displayString }.joined(separator: " · ")
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
