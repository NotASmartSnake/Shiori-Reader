//
//  DictionaryEntry.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/13/25.
//


import Foundation

struct DictionaryEntry: Identifiable, Equatable {
    var id: String
    let term: String
    let reading: String
    var meanings: [String]
    let meaningTags: [String]
    let termTags: [String]
    let score: String?
    var transformed: String? = nil
    var transformationNotes: String? = nil
    let popularity: Double?
    
    static func == (lhs: DictionaryEntry, rhs: DictionaryEntry) -> Bool {
        return lhs.id == rhs.id
    }
}
