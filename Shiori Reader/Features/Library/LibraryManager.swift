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
    private let bookRepository = BookRepository()
    private let settingsRepository = SettingsRepository()
    private let useInitialBooksForTesting = true
    
    init() {
        loadLibrary()
    }
    
    // MARK: - Book Management Functions
    
    func addBook(_ book: Book) {
        bookRepository.addBook(
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
        bookRepository.updateBookTitle(id: book.id, newTitle: newTitle)
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books[index] = books[index].withUpdatedTitle(newTitle)
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
        books = bookRepository.getAllBooks()
    }
    
    // MARK: - Book Preferences
    
    func getBookPreferences(for bookId: UUID) -> BookPreference? {
        return settingsRepository.getBookPreferences(bookId: bookId)
    }
    
    func saveBookPreferences(_ preferences: BookPreference) {
        settingsRepository.saveBookPreferences(preferences)
    }
}
