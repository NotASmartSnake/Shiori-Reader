//
//  SettingsRepository.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/9/25.
//

import Foundation

class SettingsRepository {
    private let coreDataManager = CoreDataManager.shared
    
    // Get or create Anki settings
    func getAnkiSettings() -> AnkiSettings {
        if let entity = coreDataManager.getAnkiSettings() {
            return AnkiSettings(entity: entity)
        } else {
            // Create default settings
            let entity = coreDataManager.createOrUpdateAnkiSettings(
                deckName: "Shiori-Reader",
                noteType: "Japanese",
                wordField: "Word",
                readingField: "Reading",
                definitionField: "Definition",
                sentenceField: "Sentence",
                wordWithReadingField: "Word with Reading",
                tags: "shiori-reader"
            )
            return AnkiSettings(entity: entity)
        }
    }
    
    // Update Anki settings
    func updateAnkiSettings(_ settings: AnkiSettings) {
        if let entity = coreDataManager.getAnkiSettings() {
            settings.updateEntity(entity, in: coreDataManager.viewContext)
            coreDataManager.saveContext()
        } else {
            // Create new settings
            let entity = coreDataManager.createOrUpdateAnkiSettings(
                deckName: settings.deckName,
                noteType: settings.noteType,
                wordField: settings.wordField,
                readingField: settings.readingField,
                definitionField: settings.definitionField,
                sentenceField: settings.sentenceField,
                wordWithReadingField: settings.wordWithReadingField, // Added this field
                tags: settings.tags
            )
            
            // Add additional fields
            for field in settings.additionalFields {
                coreDataManager.createAdditionalField(
                    type: field.type,
                    fieldName: field.fieldName,
                    for: entity
                )
            }
        }
    }
    
    // Get book preferences
    func getBookPreferences(bookId: UUID) -> BookPreference? {
        guard let bookEntity = coreDataManager.getBook(by: bookId),
              let prefEntity = bookEntity.preferences else {
            return nil
        }
        
        return BookPreference(entity: prefEntity)
    }
    
    // Create or update book preferences
    func saveBookPreferences(_ preferences: BookPreference) {
        guard let bookEntity = coreDataManager.getBook(by: preferences.bookId) else {
            return
        }
        
        coreDataManager.createOrUpdateBookPreference(
            for: bookEntity,
            fontSize: preferences.fontSize,
            fontFamily: preferences.fontFamily,
            backgroundColor: preferences.backgroundColor,
            textColor: preferences.textColor,
            readingDirection: preferences.readingDirection,
            isScrollMode: preferences.isScrollMode
        )
    }
}
