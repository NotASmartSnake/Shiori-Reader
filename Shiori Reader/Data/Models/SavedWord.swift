//
//  SavedWord.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/21/25.
//
import Foundation

struct SavedWord: Identifiable, Equatable, Hashable {
    // MARK: - Properties
    let id: UUID
    var word: String
    var reading: String
    var definitions: [String] // Changed from definition: String to definitions: [String]
    var sentence: String
    let sourceBook: String
    let timeAdded: Date
    var bookId: UUID?
    var pitchAccents: PitchAccentData? // Pitch accent information
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(),
         word: String,
         reading: String,
         definitions: [String],
         sentence: String,
         sourceBook: String,
         timeAdded: Date = Date(),
         bookId: UUID? = nil,
         pitchAccents: PitchAccentData? = nil) {
        self.id = id
        self.word = word
        self.reading = reading
        self.definitions = definitions
        self.sentence = sentence
        self.sourceBook = sourceBook
        self.timeAdded = timeAdded
        self.bookId = bookId
        self.pitchAccents = pitchAccents
    }
    
    // Convenience initializer for single definition (backward compatibility)
    init(id: UUID = UUID(),
         word: String,
         reading: String,
         definition: String,
         sentence: String,
         sourceBook: String,
         timeAdded: Date = Date(),
         bookId: UUID? = nil,
         pitchAccents: PitchAccentData? = nil) {
        self.init(
            id: id,
            word: word,
            reading: reading,
            definitions: definition.components(separatedBy: "; ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
            sentence: sentence,
            sourceBook: sourceBook,
            timeAdded: timeAdded,
            bookId: bookId,
            pitchAccents: pitchAccents
        )
    }
    
    // Initialize from Core Data entity
    init(entity: SavedWordEntity) {
        self.id = entity.id ?? UUID()
        self.word = entity.word ?? ""
        self.reading = entity.reading ?? ""
        
        // Handle definitions migration - if it's stored as JSON, parse it; otherwise split by semicolon
        if let definitionData = entity.definitionData,
           let decodedDefinitions = try? JSONDecoder().decode([String].self, from: definitionData) {
            self.definitions = decodedDefinitions
        } else if let legacyDefinition = entity.definition, !legacyDefinition.isEmpty {
            // Legacy: split by semicolon and trim whitespace
            self.definitions = legacyDefinition.components(separatedBy: "; ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        } else {
            self.definitions = []
        }
        
        self.sentence = entity.sentence ?? ""
        self.sourceBook = entity.sourceBook ?? ""
        self.timeAdded = entity.timeAdded ?? Date()
        self.bookId = entity.book?.id
        
        // Deserialize pitch accent data if available
        if let pitchAccentData = entity.pitchAccentData {
            self.pitchAccents = deserializePitchAccentData(from: pitchAccentData)
        } else {
            self.pitchAccents = nil
        }
    }
    
    // MARK: - Helper Methods
    
    // Format added date for display
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timeAdded)
    }
    
    // Create a copy with updated definitions
    func withUpdatedDefinitions(_ newDefinitions: [String]) -> SavedWord {
        return SavedWord(
            id: self.id,
            word: self.word,
            reading: self.reading,
            definitions: newDefinitions,
            sentence: self.sentence,
            sourceBook: self.sourceBook,
            timeAdded: self.timeAdded,
            bookId: self.bookId,
            pitchAccents: self.pitchAccents
        )
    }
    
    // Legacy compatibility - get definitions as a single string
    var definition: String {
        return definitions.joined(separator: "; ")
    }
    
    // Create a copy with updated sentence example
    func withUpdatedSentence(_ newSentence: String) -> SavedWord {
        return SavedWord(
            id: self.id,
            word: self.word,
            reading: self.reading,
            definitions: self.definitions,
            sentence: newSentence,
            sourceBook: self.sourceBook,
            timeAdded: self.timeAdded,
            bookId: self.bookId,
            pitchAccents: self.pitchAccents
        )
    }
    
    /// Returns true if this saved word has pitch accent information
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
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Equatable
    
    static func == (lhs: SavedWord, rhs: SavedWord) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Core Data Helpers

    func updateEntity(_ entity: SavedWordEntity, bookEntity: BookEntity? = nil) {
        entity.id = id
        entity.word = word
        entity.reading = reading
        
        // Store definitions as JSON data
        if let definitionData = try? JSONEncoder().encode(definitions) {
            entity.definitionData = definitionData
        }
        // Also keep legacy definition field for backward compatibility
        entity.definition = definitions.joined(separator: "; ")
        
        entity.sentence = sentence
        entity.sourceBook = sourceBook
        entity.timeAdded = timeAdded
        
        // Serialize pitch accent data if available
        if let pitchAccents = self.pitchAccents {
            entity.pitchAccentData = serializePitchAccentData(pitchAccents)
        } else {
            entity.pitchAccentData = nil
        }
        
        // Only update the book relationship if provided
        if let bookEntity = bookEntity {
            entity.book = bookEntity
        }
    }
}

// MARK: - Pitch Accent Serialization Helpers

/// Serialize PitchAccentData to Data for Core Data storage
private func serializePitchAccentData(_ pitchAccents: PitchAccentData) -> Data? {
    let accentsData = pitchAccents.accents.map { accent in
        [
            "term": accent.term,
            "reading": accent.reading,
            "pitchAccent": accent.pitchAccent
        ] as [String: Any]
    }
    
    do {
        return try JSONSerialization.data(withJSONObject: accentsData)
    } catch {
        print("Failed to serialize pitch accent data: \(error)")
        return nil
    }
}

/// Deserialize Data to PitchAccentData from Core Data storage
private func deserializePitchAccentData(from data: Data) -> PitchAccentData? {
    do {
        guard let accentsArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        
        let accents = accentsArray.compactMap { dict -> PitchAccent? in
            guard let term = dict["term"] as? String,
                  let reading = dict["reading"] as? String,
                  let pitchAccent = dict["pitchAccent"] as? Int else {
                return nil
            }
            
            return PitchAccent(term: term, reading: reading, pitchAccent: pitchAccent)
        }
        
        return PitchAccentData(accents: accents)
    } catch {
        print("Failed to deserialize pitch accent data: \(error)")
        return nil
    }
}

