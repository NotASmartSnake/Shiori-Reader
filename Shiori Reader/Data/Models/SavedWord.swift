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
    var definition: String
    var sentence: String
    let sourceBook: String
    let timeAdded: Date
    var bookId: UUID?
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(),
         word: String,
         reading: String,
         definition: String,
         sentence: String,
         sourceBook: String,
         timeAdded: Date = Date(),
         bookId: UUID? = nil) {
        self.id = id
        self.word = word
        self.reading = reading
        self.definition = definition
        self.sentence = sentence
        self.sourceBook = sourceBook
        self.timeAdded = timeAdded
        self.bookId = bookId
    }
    
    // Initialize from Core Data entity
    init(entity: SavedWordEntity) {
        self.id = entity.id ?? UUID()
        self.word = entity.word ?? ""
        self.reading = entity.reading ?? ""
        self.definition = entity.definition ?? ""
        self.sentence = entity.sentence ?? ""
        self.sourceBook = entity.sourceBook ?? ""
        self.timeAdded = entity.timeAdded ?? Date()
        self.bookId = entity.book?.id
    }
    
    // MARK: - Helper Methods
    
    // Format added date for display
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timeAdded)
    }
    
    // Create a copy with updated definition
    func withUpdatedDefinition(_ newDefinition: String) -> SavedWord {
        return SavedWord(
            id: self.id,
            word: self.word,
            reading: self.reading,
            definition: newDefinition,
            sentence: self.sentence,
            sourceBook: self.sourceBook,
            timeAdded: self.timeAdded,
            bookId: self.bookId
        )
    }
    
    // Create a copy with updated sentence example
    func withUpdatedSentence(_ newSentence: String) -> SavedWord {
        return SavedWord(
            id: self.id,
            word: self.word,
            reading: self.reading,
            definition: self.definition,
            sentence: newSentence,
            sourceBook: self.sourceBook,
            timeAdded: self.timeAdded,
            bookId: self.bookId
        )
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
        entity.definition = definition
        entity.sentence = sentence
        entity.sourceBook = sourceBook
        entity.timeAdded = timeAdded
        
        // Only update the book relationship if provided
        if let bookEntity = bookEntity {
            entity.book = bookEntity
        }
    }
    
}
