//
//  CoreDataManager.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/9/25.
//

import CoreData
import Foundation
import ReadiumShared

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {
        // Ensure database is properly set up on initialization
        // This will create the persistent store if it doesn't exist
        _ = persistentContainer
    }
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ShioriReader")
        
        // Configure options for migration
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Enable automatic lightweight migration
        description?.shouldMigrateStoreAutomatically = true
        description?.shouldInferMappingModelAutomatically = true
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                // Log migration details for debugging
                Logger.debug(category: "CoreData", "Migration failed with error: \(error), \(error.userInfo)")
                
                // In production, you might want to handle this more gracefully
                // For now, we'll still use fatalError but with better logging
                fatalError("Unresolved Core Data error: \(error), \(error.userInfo)")
            } else {
                Logger.debug(category: "CoreData", "Core Data stack loaded successfully")
            }
        }
        
        // Configure automatic merging
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    // MARK: - Context Access
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // MARK: - Saving
    
    func saveContext(_ context: NSManagedObjectContext? = nil) {
        let context = context ?? viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Handle error
                let nserror = error as NSError
                Logger.debug(category: "CoreData", "Error saving context: \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    // MARK: - Book Operations
    
    func createBook(title: String, author: String?, filePath: String, coverImagePath: String?) -> BookEntity {
        let book = BookEntity(context: viewContext)
        book.id = UUID()
        book.title = title
        book.author = author
        book.filePath = filePath
        book.coverImagePath = coverImagePath
        book.addedDate = Date()
        book.readingProgress = 0.0
        saveContext()
        return book
    }
    
    func getAllBooks() -> [BookEntity] {
        let request: NSFetchRequest<BookEntity> = BookEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "lastOpenedDate", ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            Logger.debug(category: "CoreData", "Error fetching books: \(error)")
            return []
        }
    }
    
    func getBook(by id: UUID) -> BookEntity? {
        let request: NSFetchRequest<BookEntity> = BookEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(request)
            return results.first
        } catch {
            Logger.debug(category: "CoreData", "Error fetching book: \(error)")
            return nil
        }
    }
    
    func updateBookProgress(book: BookEntity, progress: Double, locatorData: Data?) {
        book.readingProgress = progress
        book.currentLocatorData = locatorData
        book.lastOpenedDate = Date()
        saveContext()
    }
    
    func updateBookProgress(id: UUID, progress: Double, locatorData: Data?) {
        guard let book = getBook(by: id) else { return }
        book.readingProgress = progress
        book.currentLocatorData = locatorData
        book.lastOpenedDate = Date()
        saveContext()
    }
    
    func deleteBook(_ book: BookEntity) {
        viewContext.delete(book)
        saveContext()
    }
    
    // MARK: - SavedWord Operations
    
    func createSavedWord(word: String, reading: String, definitions: [String],
                         sentence: String, sourceBook: String, pitchAccents: PitchAccentData? = nil, relatedBook: BookEntity? = nil) -> SavedWordEntity {
        let savedWord = SavedWordEntity(context: viewContext)
        savedWord.id = UUID()
        savedWord.word = word
        savedWord.reading = reading
        
        // Store definitions as JSON data
        if let definitionData = try? JSONEncoder().encode(definitions) {
            savedWord.definitionData = definitionData
        }
        // Also store as legacy string for backward compatibility
        savedWord.definition = definitions.joined(separator: "; ")
        
        savedWord.sentence = sentence
        savedWord.sourceBook = sourceBook
        savedWord.timeAdded = Date()
        
        // Serialize pitch accent data if available
        if let pitchAccents = pitchAccents {
            savedWord.pitchAccentData = serializePitchAccentData(pitchAccents)
        }
        
        if let relatedBook = relatedBook {
            // If we have a relationship with a specific book
            savedWord.book = relatedBook
        }
        
        saveContext()
        return savedWord
    }
    
    func getAllSavedWords() -> [SavedWordEntity] {
        let request: NSFetchRequest<SavedWordEntity> = SavedWordEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timeAdded", ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            Logger.debug(category: "CoreData", "Error fetching saved words: \(error)")
            return []
        }
    }
    
    func getSavedWord(by id: UUID) -> SavedWordEntity? {
        let request: NSFetchRequest<SavedWordEntity> = SavedWordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(request)
            return results.first
        } catch {
            Logger.debug(category: "CoreData", "Error fetching saved word: \(error)")
            return nil
        }
    }
    
    func updateSavedWord(_ savedWord: SavedWordEntity) {
        // The context already tracks changes to the object
        // Just save the context
        saveContext()
    }
    
    func deleteSavedWord(_ savedWord: SavedWordEntity) {
        viewContext.delete(savedWord)
        saveContext()
    }
    
    // MARK: - DefaultAppearanceSettings Operations
    
    func getDefaultAppearanceSettings() -> DefaultAppearanceSettingsEntity? {
        let request: NSFetchRequest<DefaultAppearanceSettingsEntity> = DefaultAppearanceSettingsEntity.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(request)
            return results.first
        } catch {
            Logger.debug(category: "CoreData", "Error fetching default appearance settings: \(error)")
            return nil
        }
    }
    
    func createOrUpdateDefaultAppearanceSettings(fontSize: Float,
                                              fontFamily: String,
                                              fontWeight: Float,
                                              backgroundColor: String,
                                              textColor: String,
                                              readingDirection: String,
                                              isVerticalText: Bool,
                                              isScrollMode: Bool,
                                              theme: String,
                                              isDictionaryAnimationEnabled: Bool = true,
                                              dictionaryAnimationSpeed: String = "normal") -> DefaultAppearanceSettingsEntity {
        
        // Check if settings already exist
        if let existingSettings = getDefaultAppearanceSettings() {
            // Update existing settings
            existingSettings.fontSize = fontSize
            existingSettings.fontFamily = fontFamily
            existingSettings.fontWeight = fontWeight
            existingSettings.backgroundColor = backgroundColor
            existingSettings.textColor = textColor
            existingSettings.readingDirection = readingDirection
            existingSettings.isVerticalText = isVerticalText
            existingSettings.isScrollMode = isScrollMode
            existingSettings.theme = theme
            existingSettings.isDictionaryAnimationEnabled = isDictionaryAnimationEnabled
            existingSettings.dictionaryAnimationSpeed = dictionaryAnimationSpeed
            saveContext()
            return existingSettings
        } else {
            // Create new settings
            let settings = DefaultAppearanceSettingsEntity(context: viewContext)
            settings.id = UUID()
            settings.fontSize = fontSize
            settings.fontFamily = fontFamily
            settings.fontWeight = fontWeight
            settings.backgroundColor = backgroundColor
            settings.textColor = textColor
            settings.readingDirection = readingDirection
            settings.isVerticalText = isVerticalText
            settings.isScrollMode = isScrollMode
            settings.theme = theme
            settings.isDictionaryAnimationEnabled = isDictionaryAnimationEnabled
            settings.dictionaryAnimationSpeed = dictionaryAnimationSpeed
            saveContext()
            return settings
        }
    }
    
    // MARK: - BookPreference Operations
    
    func createOrUpdateBookPreference(for book: BookEntity,
                                     fontSize: Float,
                                     fontFamily: String,
                                     fontWeight: Float,
                                     backgroundColor: String,
                                     textColor: String,
                                     readingDirection: String,
                                     isVerticalText: Bool,
                                     isScrollMode: Bool,
                                     theme: String) -> BookPreferenceEntity {
        // Check if a preference already exists
        if let existingPreference = book.preferences {
            // Update existing preference
            existingPreference.fontSize = fontSize
            existingPreference.fontFamily = fontFamily
            existingPreference.fontWeight = fontWeight
            existingPreference.backgroundColor = backgroundColor
            existingPreference.textColor = textColor
            existingPreference.readingDirection = readingDirection
            existingPreference.isVerticalText = isVerticalText
            existingPreference.isScrollMode = isScrollMode
            existingPreference.theme = theme
            saveContext()
            return existingPreference
        } else {
            // Create new preference
            let preference = BookPreferenceEntity(context: viewContext)
            preference.id = UUID()
            preference.fontSize = fontSize
            preference.fontFamily = fontFamily
            preference.fontWeight = fontWeight
            preference.backgroundColor = backgroundColor
            preference.textColor = textColor
            preference.readingDirection = readingDirection
            preference.isVerticalText = isVerticalText
            preference.isScrollMode = isScrollMode
            preference.theme = theme
            preference.book = book
            saveContext()
            return preference
        }
    }
    
    // MARK: - AnkiSettings Operations
    
    func getAnkiSettings() -> AnkiSettingsEntity? {
        let request: NSFetchRequest<AnkiSettingsEntity> = AnkiSettingsEntity.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(request)
            return results.first
        } catch {
            Logger.debug(category: "CoreData", "Error fetching Anki settings: \(error)")
            return nil
        }
    }
    
    func createOrUpdateAnkiSettings(deckName: String, noteType: String, wordField: String,
                                   readingField: String, definitionField: String,
                                   sentenceField: String, wordWithReadingField: String, 
                                   pitchAccentField: String, pitchAccentGraphColor: String,
                                   pitchAccentTextColor: String, tags: String) -> AnkiSettingsEntity {
        
        // Check if settings already exist
        if let existingSettings = getAnkiSettings() {
            // Update existing settings
            existingSettings.deckName = deckName
            existingSettings.noteType = noteType
            existingSettings.wordField = wordField
            existingSettings.readingField = readingField
            existingSettings.definitionField = definitionField
            existingSettings.sentenceField = sentenceField
            existingSettings.wordWithReadingField = wordWithReadingField
            existingSettings.pitchAccentField = pitchAccentField
            existingSettings.pitchAccentGraphColor = pitchAccentGraphColor
            existingSettings.pitchAccentTextColor = pitchAccentTextColor
            existingSettings.tags = tags
            saveContext()
            return existingSettings
        } else {
            // Create new settings
            let settings = AnkiSettingsEntity(context: viewContext)
            settings.id = UUID()
            settings.deckName = deckName
            settings.noteType = noteType
            settings.wordField = wordField
            settings.readingField = readingField
            settings.definitionField = definitionField
            settings.sentenceField = sentenceField
            settings.wordWithReadingField = wordWithReadingField
            settings.pitchAccentField = pitchAccentField
            settings.pitchAccentGraphColor = pitchAccentGraphColor
            settings.pitchAccentTextColor = pitchAccentTextColor
            settings.tags = tags
            saveContext()
            return settings
        }
    }
    
    // MARK: - CustomTheme Operations
    
    func getAllCustomThemes() -> [CustomThemeEntity]? {
        let request: NSFetchRequest<CustomThemeEntity> = CustomThemeEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            Logger.debug(category: "CoreData", "Error fetching custom themes: \(error)")
            return nil
        }
    }
    
    func getCustomTheme(by id: UUID) -> CustomThemeEntity? {
        let request: NSFetchRequest<CustomThemeEntity> = CustomThemeEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(request)
            return results.first
        } catch {
            Logger.debug(category: "CoreData", "Error fetching custom theme: \(error)")
            return nil
        }
    }
    
    func createOrUpdateCustomTheme(id: UUID, name: String, textColor: String, backgroundColor: String) -> CustomThemeEntity {
        // Check if theme already exists
        if let existingTheme = getCustomTheme(by: id) {
            // Update existing theme
            existingTheme.name = name
            existingTheme.textColor = textColor
            existingTheme.backgroundColor = backgroundColor
            saveContext()
            return existingTheme
        } else {
            // Create new theme
            let theme = CustomThemeEntity(context: viewContext)
            theme.id = id
            theme.name = name
            theme.textColor = textColor
            theme.backgroundColor = backgroundColor
            saveContext()
            return theme
        }
    }
    
    func deleteCustomTheme(with id: UUID) {
        guard let theme = getCustomTheme(by: id) else { return }
        viewContext.delete(theme)
        saveContext()
    }
    
    // MARK: - Additional Field Operations
    
    func createAdditionalField(type: String, fieldName: String,
                              for ankiSettings: AnkiSettingsEntity) -> AdditionalFieldEntity {
        let field = AdditionalFieldEntity(context: viewContext)
        field.id = UUID()
        field.type = type
        field.fieldName = fieldName
        field.ankiSettings = ankiSettings
        saveContext()
        return field
    }

    func removeAdditionalField(_ field: AdditionalFieldEntity) {
        viewContext.delete(field)
        saveContext()
    }
    
    // MARK: - Bookmark Operations
    
    func createBookmark(bookId: UUID, locator: Locator, progression: Double?, created: Date = Date()) -> BookmarkEntity {
        let bookmark = BookmarkEntity(context: viewContext)
        bookmark.id = UUID()
        bookmark.bookId = bookId
        bookmark.progression = progression ?? locator.locations.totalProgression ?? 0.0
        bookmark.created = created
        
        // Serialize locator to JSON data
        do {
            let locatorJSON = locator.json
            let locatorData = try JSONSerialization.data(withJSONObject: locatorJSON)
            bookmark.locatorData = locatorData
        } catch {
            Logger.debug(category: "CoreData", "Error serializing locator: \(error)")
        }
        
        // Link to book if available
        if let book = getBook(by: bookId) {
            bookmark.book = book
        }
        
        saveContext()
        return bookmark
    }
    
    func getBookmarks(for bookId: UUID) -> [BookmarkEntity] {
        let request: NSFetchRequest<BookmarkEntity> = BookmarkEntity.fetchRequest()
        request.predicate = NSPredicate(format: "bookId == %@", bookId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "progression", ascending: true)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            Logger.debug(category: "CoreData", "Error fetching bookmarks: \(error)")
            return []
        }
    }
    
    func getBookmark(by id: UUID) -> BookmarkEntity? {
        let request: NSFetchRequest<BookmarkEntity> = BookmarkEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(request)
            return results.first
        } catch {
            Logger.debug(category: "CoreData", "Error fetching bookmark: \(error)")
            return nil
        }
    }
    
    func deleteBookmark(_ bookmark: BookmarkEntity) {
        viewContext.delete(bookmark)
        saveContext()
    }
    
    func isLocationBookmarked(bookId: UUID, locator: Locator) -> Bool {
        let href = locator.href
        let progression = locator.locations.totalProgression ?? 0.0
        let tolerance = 0.01 // Consider locations within 1% to be the same
        
        let request: NSFetchRequest<BookmarkEntity> = BookmarkEntity.fetchRequest()
        
        // Create a complex predicate to check both the href and progression
        let bookIdPredicate = NSPredicate(format: "bookId == %@", bookId as CVarArg)
        
        // We need to extract href from the JSON data
        // This is a simplification - in a real implementation, you'd need to parse the JSON
        // For now, let's fetch all bookmarks for the book and then filter in memory
        
        request.predicate = bookIdPredicate
        
        do {
            let bookmarks = try viewContext.fetch(request)
            
            // Filter bookmarks in memory to check href and progression
            return bookmarks.contains { entity in
                guard let locatorData = entity.locatorData,
                      let json = try? JSONSerialization.jsonObject(with: locatorData) as? [String: Any],
                      let entityHref = json["href"] as? String else {
                    return false
                }
                
                // Need to get href string representation
                let hrefString = href.string
                let hrefMatch = entityHref == hrefString
                let progressionMatch = abs((entity.progression) - progression) < tolerance
                
                return hrefMatch && progressionMatch
            }
        } catch {
            Logger.debug(category: "CoreData", "Error checking if location is bookmarked: \(error)")
            return false
        }
    }
    
    func findBookmarkId(bookId: UUID, locator: Locator) -> UUID? {
        let href = locator.href
        let progression = locator.locations.totalProgression ?? 0.0
        let tolerance = 0.01 // Consider locations within 1% to be the same
        
        let request: NSFetchRequest<BookmarkEntity> = BookmarkEntity.fetchRequest()
        
        // Create a predicate for the book ID
        let bookIdPredicate = NSPredicate(format: "bookId == %@", bookId as CVarArg)
        request.predicate = bookIdPredicate
        
        do {
            let bookmarks = try viewContext.fetch(request)
            
            // Find the bookmark with matching href and progression
            if let matchingBookmark = bookmarks.first(where: { entity in
                guard let locatorData = entity.locatorData,
                      let json = try? JSONSerialization.jsonObject(with: locatorData) as? [String: Any],
                      let entityHref = json["href"] as? String else {
                    return false
                }
                
                // Need to get href string representation
                let hrefString = href.string
                let hrefMatch = entityHref == hrefString
                let progressionMatch = abs((entity.progression) - progression) < tolerance
                
                return hrefMatch && progressionMatch
            }) {
                return matchingBookmark.id
            }
            
            return nil
        } catch {
            Logger.debug(category: "CoreData", "Error finding bookmark ID: \(error)")
            return nil
        }
    }
    
    // MARK: - Pitch Accent Serialization Helper
    
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
            Logger.debug(category: "CoreData", "Failed to serialize pitch accent data: \(error)")
            return nil
        }
    }
}
