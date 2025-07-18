//
//  YomitanSchemas.swift
//  Shiori Reader
//
//  Created by Claude on 1/10/25.
//

import Foundation

// MARK: - Helper Types

/// A type-erased Codable wrapper for handling mixed type JSON values
struct AnyCodable: Codable {
    let value: Any
    
    init<T>(_ value: T?) {
        self.value = value ?? ()
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Yomitan Dictionary Schema Types

/// Index file structure for Yomitan dictionaries
struct YomitanIndex: Codable {
    let title: String
    let revision: String
    let format: Int?
    let version: Int?
    let sequenced: Bool?
    let author: String?
    let url: String?
    let description: String?
    let attribution: String?
    let sourceLanguage: String?
    let targetLanguage: String?
    let frequencyMode: String?
    let isUpdatable: Bool?
    let indexUrl: String?
    let downloadUrl: String?
    let minimumYomitanVersion: String?
    
    // Legacy tagMeta support
    let tagMeta: [String: TagMeta]?
    
    var actualVersion: Int {
        return version ?? format ?? 1
    }
}

/// Tag metadata from index file
struct TagMeta: Codable {
    let category: String
    let order: Int
    let notes: String
    let score: Int
}

/// Term entry for version 1 format
typealias YomitanTermV1 = [YomitanTermValue]

/// Term entry for version 3 format
typealias YomitanTermV3 = [YomitanTermValue]

/// Generic term value that can be string, number, or array
enum YomitanTermValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case array([String])
    case glossaryArray([YomitanGlossary])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let arrayValue = try? container.decode([String].self) {
            self = .array(arrayValue)
        } else if let glossaryArrayValue = try? container.decode([YomitanGlossary].self) {
            self = .glossaryArray(glossaryArrayValue)
        } else {
            throw DecodingError.typeMismatch(YomitanTermValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Could not decode YomitanTermValue"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .glossaryArray(let value):
            try container.encode(value)
        }
    }
    
    var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .array(let value):
            return value.joined(separator: ",")
        case .glossaryArray:
            return ""
        }
    }
    
    var intValue: Int {
        switch self {
        case .int(let value):
            return value
        case .string(let value):
            return Int(value) ?? 0
        case .double(let value):
            return Int(value)
        default:
            return 0
        }
    }
    
    var arrayValue: [String] {
        switch self {
        case .array(let value):
            return value
        case .string(let value):
            return [value]
        default:
            return []
        }
    }
    
    var glossaryArrayValue: [YomitanGlossary] {
        switch self {
        case .glossaryArray(let value):
            return value
        default:
            return []
        }
    }
}

/// Structured glossary entry
enum YomitanGlossary: Codable {
    case text(String)
    case structured(YomitanStructuredContent)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let stringValue = try? container.decode(String.self) {
            self = .text(stringValue)
        } else if let structuredValue = try? container.decode(YomitanStructuredContent.self) {
            self = .structured(structuredValue)
        } else {
            throw DecodingError.typeMismatch(YomitanGlossary.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Could not decode YomitanGlossary"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .text(let value):
            try container.encode(value)
        case .structured(let value):
            try container.encode(value)
        }
    }
    
    var textValue: String {
        switch self {
        case .text(let value):
            return value
        case .structured(let content):
            return content.flattenToText()
        }
    }
}

/// Structured content for complex glossary entries
struct YomitanStructuredContent: Codable {
    let type: String?
    let content: YomitanStructuredContentData?
    let text: String?
    let tag: String?
    let path: String?
    let collapsed: Bool?
    let collapsible: Bool?
    
    func flattenToText() -> String {
        if let text = text {
            return text
        }
        
        if let content = content {
            return content.flattenToText()
        }
        
        // For image tags, return empty string or alt text
        if tag == "img" {
            return "[Image: \(path ?? "unknown")]"
        }
        
        return ""
    }
}

/// Content data for structured content
enum YomitanStructuredContentData: Codable {
    case string(String)
    case array([YomitanStructuredContentElement])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayValue = try? container.decode([YomitanStructuredContentElement].self) {
            self = .array(arrayValue)
        } else {
            throw DecodingError.typeMismatch(YomitanStructuredContentData.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Could not decode YomitanStructuredContentData"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        }
    }
    
    func flattenToText() -> String {
        switch self {
        case .string(let value):
            return value
        case .array(let values):
            return values.map { $0.flattenToText() }.joined(separator: " ")
        }
    }
}

/// Element in structured content that can be either a string or structured content object
enum YomitanStructuredContentElement: Codable {
    case string(String)
    case structured(YomitanStructuredContent)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let structuredValue = try? container.decode(YomitanStructuredContent.self) {
            self = .structured(structuredValue)
        } else {
            throw DecodingError.typeMismatch(YomitanStructuredContentElement.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Could not decode YomitanStructuredContentElement"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let value):
            try container.encode(value)
        case .structured(let value):
            try container.encode(value)
        }
    }
    
    func flattenToText() -> String {
        switch self {
        case .string(let value):
            return value
        case .structured(let content):
            return content.flattenToText()
        }
    }
}

/// Tag bank entry
typealias YomitanTag = [YomitanTagValue]

enum YomitanTagValue: Codable {
    case string(String)
    case int(Int)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else {
            throw DecodingError.typeMismatch(YomitanTagValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Could not decode YomitanTagValue"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        }
    }
    
    var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        }
    }
    
    var intValue: Int {
        switch self {
        case .int(let value):
            return value
        case .string(let value):
            return Int(value) ?? 0
        }
    }
}

/// Term meta bank entry for frequency and pitch accent data
typealias YomitanTermMeta = [YomitanTermMetaValue]

enum YomitanTermMetaValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case array([String])
    case object([String: AnyCodable])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let arrayValue = try? container.decode([String].self) {
            self = .array(arrayValue)
        } else if let objectValue = try? container.decode([String: AnyCodable].self) {
            self = .object(objectValue)
        } else {
            throw DecodingError.typeMismatch(YomitanTermMetaValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Could not decode YomitanTermMetaValue"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
    
    var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .array(let value):
            return value.joined(separator: ",")
        case .object(let value):
            // Convert object to JSON string for storage
            if let jsonData = try? JSONEncoder().encode(value),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
            return "{}"
        }
    }
    
    var intValue: Int {
        switch self {
        case .int(let value):
            return value
        case .string(let value):
            return Int(value) ?? 0
        case .double(let value):
            return Int(value)
        default:
            return 0
        }
    }
}

// MARK: - Processed Term Structure

/// Processed term structure for easier handling
struct ProcessedYomitanTerm {
    let expression: String
    let reading: String
    let definitionTags: String
    let rules: String
    let score: Int
    let glossary: [String]
    let sequence: Int?
    let termTags: String
    let dictionary: String
    
    /// Create from V1 format: [expression, reading, definitionTags, rules, score, ...glossary]
    static func fromV1(_ values: [YomitanTermValue], dictionary: String) -> ProcessedYomitanTerm? {
        guard values.count >= 6 else { return nil }
        
        let expression = values[0].stringValue
        let reading = values[1].stringValue.isEmpty ? expression : values[1].stringValue
        let definitionTags = values[2].stringValue
        let rules = values[3].stringValue
        let score = values[4].intValue
        
        // Remaining values are glossary
        let glossary = Array(values[5...]).map { $0.stringValue }
        
        return ProcessedYomitanTerm(
            expression: expression,
            reading: reading,
            definitionTags: definitionTags,
            rules: rules,
            score: score,
            glossary: glossary,
            sequence: nil,
            termTags: "",
            dictionary: dictionary
        )
    }
    
    /// Create from V3 format: [expression, reading, definitionTags, rules, score, glossary, sequence, termTags]
    static func fromV3(_ values: [YomitanTermValue], dictionary: String) -> ProcessedYomitanTerm? {
        guard values.count >= 8 else { return nil }
        
        let expression = values[0].stringValue
        let reading = values[1].stringValue.isEmpty ? expression : values[1].stringValue
        let definitionTags = values[2].stringValue
        let rules = values[3].stringValue
        let score = values[4].intValue
        
        // Glossary can be either array of strings or array of glossary objects
        let glossary: [String]
        if !values[5].glossaryArrayValue.isEmpty {
            glossary = values[5].glossaryArrayValue.map { $0.textValue }
        } else {
            glossary = values[5].arrayValue
        }
        
        let sequence = values[6].intValue
        let termTags = values[7].stringValue
        
        return ProcessedYomitanTerm(
            expression: expression,
            reading: reading,
            definitionTags: definitionTags,
            rules: rules,
            score: score,
            glossary: glossary,
            sequence: sequence == 0 ? nil : sequence,
            termTags: termTags,
            dictionary: dictionary
        )
    }
}

/// Processed tag structure
struct ProcessedYomitanTag {
    let name: String
    let category: String
    let order: Int
    let notes: String
    let score: Int
    let dictionary: String
    
    static func fromYomitanTag(_ values: [YomitanTagValue], dictionary: String) -> ProcessedYomitanTag? {
        guard values.count >= 5 else { return nil }
        
        return ProcessedYomitanTag(
            name: values[0].stringValue,
            category: values[1].stringValue,
            order: values[2].intValue,
            notes: values[3].stringValue,
            score: values[4].intValue,
            dictionary: dictionary
        )
    }
}

/// Processed term meta structure for frequency data
struct ProcessedYomitanTermMeta {
    let expression: String
    let mode: String
    let data: String // JSON string representation of the data
    let dictionary: String
    
    static func fromYomitanTermMeta(_ values: [YomitanTermMetaValue], dictionary: String) -> ProcessedYomitanTermMeta? {
        guard values.count >= 3 else { return nil }
        
        let expression = values[0].stringValue
        let mode = values[1].stringValue
        let data = values[2].stringValue
        
        return ProcessedYomitanTermMeta(
            expression: expression,
            mode: mode,
            data: data,
            dictionary: dictionary
        )
    }
}
