import Foundation

class SettingsRepository {
    private let coreDataManager = CoreDataManager.shared
    
    // MARK: - Custom Themes
    
    // Get all custom themes
    func getAllCustomThemes() -> [CustomTheme] {
        if let entities = coreDataManager.getAllCustomThemes() {
            return entities.map { CustomTheme(entity: $0) }
        } else {
            return []
        }
    }
    
    // Save a custom theme
    func saveCustomTheme(_ theme: CustomTheme) {
        _ = coreDataManager.createOrUpdateCustomTheme(
            id: theme.id,
            name: theme.name,
            textColor: theme.textColor,
            backgroundColor: theme.backgroundColor
        )
    }
    
    // Delete a custom theme
    func deleteCustomTheme(_ theme: CustomTheme) {
        coreDataManager.deleteCustomTheme(with: theme.id)
    }
    
    // MARK: - Default Appearance Settings
    
    // Get or create default appearance settings
    func getDefaultAppearanceSettings() -> DefaultAppearanceSettings {
        if let entity = coreDataManager.getDefaultAppearanceSettings() {
            return DefaultAppearanceSettings(entity: entity)
        } else {
            // Create default settings
            let entity = coreDataManager.createOrUpdateDefaultAppearanceSettings(
                fontSize: 1.0,
                fontFamily: "Default",
                fontWeight: 400.0,
                backgroundColor: "#FFFFFF",
                textColor: "#000000",
                readingDirection: "ltr",
                isVerticalText: false,
                isScrollMode: false,
                theme: "light",
                isDictionaryAnimationEnabled: true,
                dictionaryAnimationSpeed: "normal",
                dictionaryDisplayMode: "card",
                isCharacterPickerSwipeEnabled: true
            )
            return DefaultAppearanceSettings(entity: entity)
        }
    }
    
    // Update default appearance settings
    func saveDefaultAppearanceSettings(_ settings: DefaultAppearanceSettings) {
        _ = coreDataManager.createOrUpdateDefaultAppearanceSettings(
            fontSize: settings.fontSize,
            fontFamily: settings.fontFamily,
            fontWeight: settings.fontWeight,
            backgroundColor: settings.backgroundColor,
            textColor: settings.textColor,
            readingDirection: settings.readingDirection,
            isVerticalText: settings.isVerticalText,
            isScrollMode: settings.isScrollMode,
            theme: settings.theme,
            isDictionaryAnimationEnabled: settings.isDictionaryAnimationEnabled,
            dictionaryAnimationSpeed: settings.dictionaryAnimationSpeed,
            dictionaryDisplayMode: settings.dictionaryDisplayMode,
            isCharacterPickerSwipeEnabled: settings.isCharacterPickerSwipeEnabled
        )
    }
    
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
                pitchAccentField: "Pitch Accent",
                pitchAccentGraphColor: "black",
                pitchAccentTextColor: "black",
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
                wordWithReadingField: settings.wordWithReadingField,
                pitchAccentField: settings.pitchAccentField,
                pitchAccentGraphColor: settings.pitchAccentGraphColor,
                pitchAccentTextColor: settings.pitchAccentTextColor,
                tags: settings.tags
            )
            
            // Add additional fields
            for field in settings.additionalFields {
                _ = coreDataManager.createAdditionalField(
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
        
        _ = coreDataManager.createOrUpdateBookPreference(
            for: bookEntity,
            fontSize: preferences.fontSize,
            fontFamily: preferences.fontFamily,
            fontWeight: preferences.fontWeight,
            backgroundColor: preferences.backgroundColor,
            textColor: preferences.textColor,
            readingDirection: preferences.readingDirection,
            isVerticalText: preferences.isVerticalText,
            isScrollMode: preferences.isScrollMode,
            theme: preferences.theme
        )
    }
}
