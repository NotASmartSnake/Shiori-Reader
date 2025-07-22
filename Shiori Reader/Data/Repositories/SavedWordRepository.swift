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
    func addSavedWord(word: String, reading: String, definitions: [String],
                      sentence: String, sourceBook: String, pitchAccents: PitchAccentData? = nil) -> SavedWord {
        let entity = coreDataManager.createSavedWord(
            word: word,
            reading: reading,
            definitions: definitions,
            sentence: sentence,
            sourceBook: sourceBook,
            pitchAccents: pitchAccents
        )
        return SavedWord(entity: entity)
    }
    
    // Add a new saved word (legacy compatibility - single definition string)
    func addSavedWord(word: String, reading: String, definition: String,
                      sentence: String, sourceBook: String, pitchAccents: PitchAccentData? = nil) -> SavedWord {
        let definitions = definition.components(separatedBy: "; ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return addSavedWord(word: word, reading: reading, definitions: definitions, sentence: sentence, sourceBook: sourceBook, pitchAccents: pitchAccents)
    }
    
    // Update an existing saved word
    func updateSavedWord(_ savedWord: SavedWord) {
        guard let entity = coreDataManager.getSavedWord(by: savedWord.id) else { return }
        savedWord.updateEntity(entity)
        coreDataManager.saveContext()
    }
    
    // Delete a saved word
    func deleteSavedWord(with id: UUID) {
        guard let entity = coreDataManager.getSavedWord(by: id) else { return }
        coreDataManager.deleteSavedWord(entity)
    }
}
