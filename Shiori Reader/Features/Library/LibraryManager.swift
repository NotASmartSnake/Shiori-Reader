//
//  LibraryManager.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/29/25.
//

import Foundation
import SwiftUI

class LibraryManager: ObservableObject {
    @Published var books: [Book] = []
    
    init() {
        loadLibrary()
    }
    
    // MARK: - Book Management Functions
    
    func addBook(_ book: Book) {
        books.append(book)
        saveLibrary()
    }
    
    func removeBook(_ book: Book) {
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books.remove(at: index)
            saveLibrary()
        }
    }
    
    func renameBook(_ book: Book, newTitle: String) {
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            // Use the book's withUpdatedTitle method
            let updatedBook = book.withUpdatedTitle(newTitle)
            
            // Replace the old book with the updated one
            books[index] = updatedBook
            saveLibrary()
        }
    }
    
    func updateBook(_ book: Book) {
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books[index] = book
            saveLibrary()
        }
    }
    
    // MARK: - Persistence Functions
    
    func saveLibrary() {
        do {
            let encoder = JSONEncoder()
            let booksData = try encoder.encode(books)
            UserDefaults.standard.set(booksData, forKey: "savedBooks")
            print("DEBUG: Saved \(books.count) books to UserDefaults")
        } catch {
            print("DEBUG: Failed to save books: \(error)")
        }
    }
    
    func loadLibrary() {
        if let booksData = UserDefaults.standard.data(forKey: "savedBooks") {
            do {
                let decoder = JSONDecoder()
                let savedBooks = try decoder.decode([Book].self, from: booksData)
                books = savedBooks
                print("DEBUG: Loaded \(books.count) books from UserDefaults")
                
                // Load current reading progress for each book
                loadReadingProgress()
            } catch {
                print("DEBUG: Failed to load books: \(error)")
                // Use initial books if we can't load saved books
                loadInitialBooks()
            }
        } else {
            // No saved books, use initial books
            loadInitialBooks()
        }
    }
    
    private func loadInitialBooks() {
        // Default books if no saved library exists
        books = [
            Book(title: "COTE", coverImage: "COTECover", readingProgress: 0.4, filePath: "cote.epub")
        ]
        saveLibrary()
    }
    
    // Load the latest reading progress for all books
    func loadReadingProgress() {
        for index in 0..<books.count {
            if !books[index].filePath.isEmpty {
                let key = "book_progress_\(books[index].filePath)"
                let savedProgress = UserDefaults.standard.double(forKey: key)
                
                if savedProgress > 0 {
                    // Update with the saved progress if it exists
                    // Use the book's withUpdatedProgress method
                    let updatedBook = books[index].withUpdatedProgress(savedProgress)
                    books[index] = updatedBook
                    print("DEBUG: Loaded saved progress for \(books[index].title): \(savedProgress)")
                }
            }
        }
        
        // Save the updated books
        saveLibrary()
    }
}
