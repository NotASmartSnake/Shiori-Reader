//
//  DictionaryEntry.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/13/25.
//


import Foundation

// Helper class for lazy loading pitch accent data
class PitchAccentLoader {
    private var _pitchAccents: PitchAccentData?
    private var _isLoaded = false
    private let term: String
    private let reading: String
    
    init(term: String, reading: String) {
        self.term = term
        self.reading = reading
    }
    
    func getPitchAccents() -> PitchAccentData? {
        if !_isLoaded {
            _pitchAccents = PitchAccentManager.shared.lookupPitchAccents(for: term, reading: reading)
            _isLoaded = true
        }
        return _pitchAccents
    }
    
    func setPitchAccents(_ data: PitchAccentData?) {
        _pitchAccents = data
        _isLoaded = true
    }
    
    var isLoaded: Bool {
        return _isLoaded
    }
}

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
    
    // Lazy loading helper
    private let pitchAccentLoader: PitchAccentLoader
    
    // Lazy loading for pitch accent data
    var pitchAccents: PitchAccentData? {
        get {
            return pitchAccentLoader.getPitchAccents()
        }
        set {
            pitchAccentLoader.setPitchAccents(newValue)
        }
    }
    
    // Custom initializer to set up lazy loader
    init(id: String, term: String, reading: String, meanings: [String], meaningTags: [String], termTags: [String], score: String?, rules: String?, transformed: String? = nil, transformationNotes: String? = nil, popularity: Double?) {
        self.id = id
        self.term = term
        self.reading = reading
        self.meanings = meanings
        self.meaningTags = meaningTags
        self.termTags = termTags
        self.score = score
        self.rules = rules
        self.transformed = transformed
        self.transformationNotes = transformationNotes
        self.popularity = popularity
        self.pitchAccentLoader = PitchAccentLoader(term: term, reading: reading)
    }
    
    static func == (lhs: DictionaryEntry, rhs: DictionaryEntry) -> Bool {
        return lhs.id == rhs.id &&
               lhs.term == rhs.term &&
               lhs.reading == rhs.reading &&
               lhs.meanings == rhs.meanings &&
               lhs.meaningTags == rhs.meaningTags &&
               lhs.termTags == rhs.termTags &&
               lhs.score == rhs.score &&
               lhs.rules == rhs.rules &&
               lhs.transformed == rhs.transformed &&
               lhs.transformationNotes == rhs.transformationNotes &&
               lhs.popularity == rhs.popularity
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
