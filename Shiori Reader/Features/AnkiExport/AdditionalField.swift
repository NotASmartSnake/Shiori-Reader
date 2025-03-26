//
//  AdditionalField.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/26/25.
//

import Foundation

// Model for additional fields
struct AdditionalField: Codable, Identifiable {
    var id = UUID()
    var type: String  // "word", "reading", "definition", "sentence"
    var fieldName: String
    
    enum CodingKeys: String, CodingKey {
        case id, type, fieldName
    }
}
