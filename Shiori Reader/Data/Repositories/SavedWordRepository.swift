//
//  SavedWordRepository.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/9/25.
//

import Foundation
import CoreData

class SavedWordRepository {
    private let coreDataManager = CoreDataManager.shared
    
    // Get all saved words
    func getAllSavedWords() -> [SavedWord] {
        let entities = coreDataManager.getAllSavedWords()
        return entities.map { SavedWord(entity: $0) }
    }
    
    // Add a new saved word
    func addSavedWord(word: String, reading: String, definition: String,
                      sentence: String, sourceBook: String) -> SavedWord {
        let entity = coreDataManager.createSavedWord(
            word: word,
            reading: reading,
            definition: definition,
            sentence: sentence,
            sourceBook: sourceBook
        )
        return SavedWord(entity: entity)
    }
    
    // Update an existing saved word
    func updateSavedWord(_ savedWord: SavedWord) {
        guard let entity = coreDataManager.getSavedWord(by: savedWord.id) else { return }
        entity.word = savedWord.word
        entity.reading = savedWord.reading
        entity.definition = savedWord.definition
        entity.sentence = savedWord.sentence
        entity.sourceBook = savedWord.sourceBook
        coreDataManager.saveContext()
    }
    
    // Delete a saved word
    func deleteSavedWord(with id: UUID) {
        guard let entity = coreDataManager.getSavedWord(by: id) else { return }
        coreDataManager.deleteSavedWord(entity)
    }
}
