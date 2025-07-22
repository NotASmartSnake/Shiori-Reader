import Foundation
import CoreData

struct AnkiSettings: Identifiable, Equatable, Hashable {
    // MARK: - Properties
    let id: UUID
    var deckName: String
    var noteType: String
    var wordField: String
    var readingField: String
    var definitionField: String
    var sentenceField: String
    var wordWithReadingField: String
    var pitchAccentField: String
    var pitchAccentGraphColor: String
    var pitchAccentTextColor: String
    var tags: String
    var additionalFields: [AdditionalField]
    
    // Cached Anki data
    var cachedDecks: [String]
    var cachedNoteTypes: [String: [String]]
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(),
         deckName: String = "Shiori-Reader",
         noteType: String = "Japanese",
         wordField: String = "Word",
         readingField: String = "Reading",
         definitionField: String = "Definition",
         sentenceField: String = "Sentence",
         wordWithReadingField: String = "Word with Reading",
         pitchAccentField: String = "Pitch Accent",
         pitchAccentGraphColor: String = "black",
         pitchAccentTextColor: String = "black",
         tags: String = "shiori-reader",
         additionalFields: [AdditionalField] = [],
         cachedDecks: [String] = [],
         cachedNoteTypes: [String: [String]] = [:]) {
        self.id = id
        self.deckName = deckName
        self.noteType = noteType
        self.wordField = wordField
        self.readingField = readingField
        self.definitionField = definitionField
        self.sentenceField = sentenceField
        self.wordWithReadingField = wordWithReadingField
        self.pitchAccentField = pitchAccentField
        self.pitchAccentGraphColor = pitchAccentGraphColor
        self.pitchAccentTextColor = pitchAccentTextColor
        self.tags = tags
        self.additionalFields = additionalFields
        self.cachedDecks = cachedDecks
        self.cachedNoteTypes = cachedNoteTypes
    }
    
    // Initialize from Core Data entity
    init(entity: AnkiSettingsEntity) {
        self.id = entity.id ?? UUID()
        self.deckName = entity.deckName ?? "Shiori-Reader"
        self.noteType = entity.noteType ?? "Japanese"
        self.wordField = entity.wordField ?? "Word"
        self.readingField = entity.readingField ?? "Reading"
        self.definitionField = entity.definitionField ?? "Definition"
        self.sentenceField = entity.sentenceField ?? "Sentence"
        self.wordWithReadingField = entity.wordWithReadingField ?? "Word with Reading"
        self.pitchAccentField = entity.pitchAccentField ?? "Pitch Accent"
        self.pitchAccentGraphColor = entity.pitchAccentGraphColor ?? "black"
        self.pitchAccentTextColor = entity.pitchAccentTextColor ?? "black"
        self.tags = entity.tags ?? "shiori-reader"
        
        // Convert related AdditionalFieldEntity objects to AdditionalField structs
        if let fields = entity.additionalFields as? Set<AdditionalFieldEntity> {
            self.additionalFields = fields.compactMap { field in
                guard let type = field.type, let fieldName = field.fieldName else {
                    return nil
                }
                return AdditionalField(id: field.id ?? UUID(),
                                      type: type,
                                      fieldName: fieldName)
            }
        } else {
            self.additionalFields = []
        }
        
        // Load cached data
        if let decksData = entity.cachedDecksData,
           let decks = try? JSONDecoder().decode([String].self, from: decksData) {
            self.cachedDecks = decks
        } else {
            self.cachedDecks = []
        }
        
        if let noteTypesData = entity.cachedNoteTypesData,
           let noteTypes = try? JSONDecoder().decode([String: [String]].self, from: noteTypesData) {
            self.cachedNoteTypes = noteTypes
        } else {
            self.cachedNoteTypes = [:]
        }
    }
    
    // MARK: - Helper Methods
    
    // Get all fields as a dictionary for quick lookups
    func getFieldsMap() -> [String: String] {
        return [
            "word": wordField,
            "reading": readingField,
            "definition": definitionField,
            "sentence": sentenceField,
            "wordWithReading": wordWithReadingField,
            "pitchAccent": pitchAccentField,
            "pitchAccentGraphColor": pitchAccentGraphColor,
            "pitchAccentTextColor": pitchAccentTextColor
        ]
    }
    
    // Get all tags as an array
    func getTagsArray() -> [String] {
        return tags.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
    }
    
    // Add an additional field
    func withAddedField(_ field: AdditionalField) -> AnkiSettings {
        var copy = self
        copy.additionalFields.append(field)
        return copy
    }
    
    // Create a copy with updated deck name
    func withUpdatedDeckName(_ newName: String) -> AnkiSettings {
        var copy = self
        copy.deckName = newName
        return copy
    }
    
    // Create a copy with updated cached data
    func withCachedData(decks: [String]?, noteTypes: [String: [String]]?) -> AnkiSettings {
        var copy = self
        if let decks = decks {
            copy.cachedDecks = decks
        }
        if let noteTypes = noteTypes {
            copy.cachedNoteTypes = noteTypes
        }
        return copy
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Equatable
    
    static func == (lhs: AnkiSettings, rhs: AnkiSettings) -> Bool {
        return lhs.id == rhs.id &&
            lhs.deckName == rhs.deckName &&
            lhs.noteType == rhs.noteType &&
            lhs.wordField == rhs.wordField &&
            lhs.readingField == rhs.readingField &&
            lhs.definitionField == rhs.definitionField &&
            lhs.sentenceField == rhs.sentenceField &&
            lhs.wordWithReadingField == rhs.wordWithReadingField &&
            lhs.pitchAccentField == rhs.pitchAccentField &&
            lhs.pitchAccentGraphColor == rhs.pitchAccentGraphColor &&
            lhs.pitchAccentTextColor == rhs.pitchAccentTextColor &&
            lhs.tags == rhs.tags &&
            lhs.additionalFields == rhs.additionalFields &&
            lhs.cachedDecks == rhs.cachedDecks &&
            lhs.cachedNoteTypes == rhs.cachedNoteTypes
    }
    
    // MARK: - Core Data Helpers
    
    func updateEntity(_ entity: AnkiSettingsEntity, in context: NSManagedObjectContext) {
        entity.id = id
        entity.deckName = deckName
        entity.noteType = noteType
        entity.wordField = wordField
        entity.readingField = readingField
        entity.definitionField = definitionField
        entity.sentenceField = sentenceField
        entity.wordWithReadingField = wordWithReadingField
        entity.pitchAccentField = pitchAccentField
        entity.pitchAccentGraphColor = pitchAccentGraphColor
        entity.pitchAccentTextColor = pitchAccentTextColor
        entity.tags = tags
        
        // Handle additional fields
        // First, remove old fields that aren't in the model anymore
        if let existingFields = entity.additionalFields as? Set<AdditionalFieldEntity> {
            for existingField in existingFields {
                if !additionalFields.contains(where: { $0.id == existingField.id }) {
                    context.delete(existingField)
                }
            }
        }
        
        // Then update existing fields and add new ones
        for field in additionalFields {
            let existingField: AdditionalFieldEntity
            
            // Find existing field or create new one
            if let foundField = (entity.additionalFields as? Set<AdditionalFieldEntity>)?.first(where: { $0.id == field.id }) {
                existingField = foundField
            } else {
                existingField = AdditionalFieldEntity(context: context)
                existingField.id = field.id
                existingField.ankiSettings = entity
            }
            
            // Update field properties
            existingField.type = field.type
            existingField.fieldName = field.fieldName
        }
        
        // Save cached data
        if let decksData = try? JSONEncoder().encode(cachedDecks) {
            entity.cachedDecksData = decksData
        }
        
        if let noteTypesData = try? JSONEncoder().encode(cachedNoteTypes) {
            entity.cachedNoteTypesData = noteTypesData
        }
    }
}
