//
//  LibraryManager.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/29/25.
//

import Foundation
import SwiftUI
import Combine

class LibraryManager: ObservableObject {
    @Published var books: [Book] = []
    @Published var refreshTrigger = UUID() // Add this to force UI refresh
    private let bookRepository = BookRepository()
    private let settingsRepository = SettingsRepository()
    
    init() {
        loadLibrary()
        // Perform migration for existing books with absolute paths
        migrateAbsolutePaths()
    }
    
    // MARK: - Book Management Functions
    
    func addBook(_ book: Book) {
        _ = bookRepository.addBook(
            title: book.title,
            author: book.author,
            filePath: book.filePath,
            coverImage: book.coverImagePath,
            isLocalCover: book.isLocalCover
        )
        loadLibrary() // Reload to ensure we have the updated list
    }
    
    func removeBook(_ book: Book) {
        bookRepository.deleteBook(with: book.id)
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books.remove(at: index)
        }
    }
    
    func renameBook(_ book: Book, newTitle: String) {
        print("LibraryManager: Attempting to rename book '\(book.title)' to '\(newTitle)'")
        let success = bookRepository.updateBookTitle(id: book.id, newTitle: newTitle)
        
        if success {
            print("LibraryManager: Title update successful, reloading library")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let newBooks = self.bookRepository.getAllBooks()
                print("LibraryManager: Reloaded \(newBooks.count) books after rename")
                self.books = newBooks
                self.refreshTrigger = UUID() // Force UI refresh
            }
        } else {
            print("LibraryManager: Title update failed")
        }
    }
    
    func updateBook(_ book: Book) {
        bookRepository.updateBookProgress(
            id: book.id,
            progress: book.readingProgress,
            locatorData: book.currentLocatorData
        )
        
        // Update the book in the array
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books[index] = book
        }
    }
    
    // Load all books from repository
    func loadLibrary() {
        print("LibraryManager: Loading library...")
        let loadedBooks = bookRepository.getAllBooks()
        print("LibraryManager: Loaded \(loadedBooks.count) books")
        
        // Print book titles for debugging
        for book in loadedBooks {
            print("LibraryManager: Book - ID: \(book.id), Title: '\(book.title)'")
        }
        
        books = loadedBooks
        print("LibraryManager: Library updated with \(books.count) books")
    }
    
    // MARK: - Book Preferences
    
    func getBookPreferences(for bookId: UUID) -> BookPreference? {
        return settingsRepository.getBookPreferences(bookId: bookId)
    }
    
    func saveBookPreferences(_ preferences: BookPreference) {
        settingsRepository.saveBookPreferences(preferences)
    }
    
    // MARK: - Migration Functions
    
    /// Migrates existing books with absolute paths to relative paths
    private func migrateAbsolutePaths() {
        Logger.info(category: "LibraryManager", "Starting migration of absolute paths...")
        
        let fileManager = FileManager.default
        guard let documentsDirectory = try? fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            Logger.error(category: "LibraryManager", "Could not access Documents directory for migration")
            return
        }
        
        var migrationCount = 0
        var coverMigrationCount = 0
        
        for book in books {
            var needsUpdate = false
            var updatedFilePath = book.filePath
            var updatedCoverPath = book.coverImagePath
            
            // Migrate book file path if it's absolute
            if book.filePath.starts(with: "/") {
                if let migratedPath = migrateAbsoluteBookPath(book.filePath, documentsDirectory: documentsDirectory) {
                    updatedFilePath = migratedPath
                    needsUpdate = true
                    migrationCount += 1
                    Logger.info(category: "LibraryManager", "Migrated book '\(book.title)' from '\(book.filePath)' to '\(migratedPath)'")
                }
            }
            
            // Migrate cover path if it exists, is local, and appears to be absolute
            if let coverPath = book.coverImagePath,
               book.isLocalCover,
               coverPath.starts(with: "/") {
                if let migratedCoverPath = migrateAbsoluteCoverPath(coverPath, documentsDirectory: documentsDirectory) {
                    updatedCoverPath = migratedCoverPath
                    needsUpdate = true
                    coverMigrationCount += 1
                    Logger.info(category: "LibraryManager", "Migrated cover for '\(book.title)' from '\(coverPath)' to '\(migratedCoverPath)'")
                }
            }
            
            // Update the database if any paths were migrated
            if needsUpdate {
                if let entity = CoreDataManager.shared.getBook(by: book.id) {
                    entity.filePath = updatedFilePath
                    entity.coverImagePath = updatedCoverPath
                    CoreDataManager.shared.saveContext()
                }
            }
        }
        
        if migrationCount > 0 || coverMigrationCount > 0 {
            Logger.info(category: "LibraryManager", "Migration completed. Migrated \(migrationCount) book paths and \(coverMigrationCount) cover paths.")
            // Reload library to reflect changes
            loadLibrary()
        } else {
            Logger.info(category: "LibraryManager", "No migration needed.")
        }
    }
    
    /// Migrates an absolute book file path to a relative path
    private func migrateAbsoluteBookPath(_ absolutePath: String, documentsDirectory: URL) -> String? {
        let fileManager = FileManager.default
        
        // Extract relative path from "/Documents/" onwards
        if let documentsRange = absolutePath.range(of: "/Documents/") {
            let relativePath = String(absolutePath[documentsRange.upperBound...])
            let testURL = documentsDirectory.appendingPathComponent(relativePath)
            
            if fileManager.fileExists(atPath: testURL.path) {
                return relativePath
            }
        }
        
        // Try common book locations
        let filename = URL(fileURLWithPath: absolutePath).lastPathComponent
        let possiblePaths = [
            "Books/\(filename)",
            filename
        ]
        
        for relativePath in possiblePaths {
            let testURL = documentsDirectory.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: testURL.path) {
                return relativePath
            }
        }
        
        return nil
    }
    
    /// Migrates an absolute cover path to a relative path
    private func migrateAbsoluteCoverPath(_ absolutePath: String, documentsDirectory: URL) -> String? {
        let fileManager = FileManager.default
        
        // Extract relative path from "/Documents/" onwards
        if let documentsRange = absolutePath.range(of: "/Documents/") {
            let relativePath = String(absolutePath[documentsRange.upperBound...])
            let testURL = documentsDirectory.appendingPathComponent(relativePath)
            
            if fileManager.fileExists(atPath: testURL.path) {
                return relativePath
            }
        }
        
        // Try common cover locations
        let filename = URL(fileURLWithPath: absolutePath).lastPathComponent
        let possiblePaths = [
            "BookCovers/\(filename)",
            filename
        ]
        
        for relativePath in possiblePaths {
            let testURL = documentsDirectory.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: testURL.path) {
                return relativePath
            }
        }
        
        return nil
    }
}
