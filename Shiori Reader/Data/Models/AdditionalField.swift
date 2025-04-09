//
//  AdditionalField.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/26/25.
//

import Foundation

// Model for additional fields
struct AdditionalField: Identifiable, Equatable, Hashable, Codable {
    var id = UUID()
    var type: String  // "word", "reading", "definition", "sentence"
    var fieldName: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AdditionalField, rhs: AdditionalField) -> Bool {
        return lhs.id == rhs.id &&
               lhs.type == rhs.type &&
               lhs.fieldName == rhs.fieldName
    }
}
