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
    let rules: String?  // Part-of-speech information from database
    var transformed: String? = nil
    var transformationNotes: String? = nil
    let popularity: Double?
    var pitchAccents: PitchAccentData? = nil  // Pitch accent information
    
    static func == (lhs: DictionaryEntry, rhs: DictionaryEntry) -> Bool {
        return lhs.id == rhs.id
    }
    
    /// Returns true if this entry has pitch accent information
    var hasPitchAccent: Bool {
        return pitchAccents?.isEmpty == false
    }
    
    /// Returns the primary pitch accent number, or nil if no pitch accent data
    var primaryPitchAccent: Int? {
        return pitchAccents?.primary?.pitchAccent
    }
    
    /// Returns all pitch accent patterns as a comma-separated string
    var pitchAccentString: String? {
        guard let accents = pitchAccents?.allPatterns, !accents.isEmpty else { return nil }
        return accents.map { "[\($0)]" }.joined(separator: ", ")
    }
}
