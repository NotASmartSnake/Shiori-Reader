//
//  CoreDataManager.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/9/25.
//

import CoreData
import Foundation

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
        
        // Configure options
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                fatalError("Unresolved error \(error), \(error.userInfo)")
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
                print("Error saving context: \(nserror), \(nserror.userInfo)")
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
            print("Error fetching books: \(error)")
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
            print("Error fetching book: \(error)")
            return nil
        }
    }
    
    func updateBookProgress(book: BookEntity, progress: Double, locatorData: Data?) {
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
    
    func createSavedWord(word: String, reading: String, definition: String,
                         sentence: String, sourceBook: String, relatedBook: BookEntity? = nil) -> SavedWordEntity {
        let savedWord = SavedWordEntity(context: viewContext)
        savedWord.id = UUID()
        savedWord.word = word
        savedWord.reading = reading
        savedWord.definition = definition
        savedWord.sentence = sentence
        savedWord.sourceBook = sourceBook
        savedWord.timeAdded = Date()
        
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
            print("Error fetching saved words: \(error)")
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
            print("Error fetching saved word: \(error)")
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
            print("Error fetching Anki settings: \(error)")
            return nil
        }
    }
    
    func createOrUpdateAnkiSettings(deckName: String, noteType: String, wordField: String,
                                   readingField: String, definitionField: String,
                                   sentenceField: String, wordWithReadingField: String, tags: String) -> AnkiSettingsEntity {
        
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
            settings.tags = tags
            saveContext()
            return settings
        }
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
}
