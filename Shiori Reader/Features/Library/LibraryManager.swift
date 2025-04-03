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
    private let useInitialBooksForTesting = true
    
    init() {
        loadLibrary()
    }
    
    let initialBooks: [Book] = [
        Book(title: "COTE", coverImage: "COTECover", readingProgress: 0.4, filePath: "cote.epub"),
        Book(title: "3 Days", coverImage: "3DaysCover", readingProgress: 0.56, filePath: "3Days.epub"),
        Book(title: "Honzuki", coverImage: "AOABCover", readingProgress: 0.3, filePath: "honzuki.epub"),
        Book(title: "Konosuba", coverImage: "KonosubaCover", readingProgress: 0.7, filePath: "konosuba.epub"),
        Book(title: "Hakomari", coverImage: "HakomariCover", readingProgress: 0.6, filePath: "hakomari.epub"),
        Book(title: "Danmachi", coverImage: "DanmachiCover", readingProgress: 0.1, filePath: "cote.epub"),
        Book(title: "86", coverImage: "86Cover", readingProgress: 0.2, filePath: ""),
        Book(title: "Love", coverImage: "LoveCover", readingProgress: 0.8, filePath: ""),
        Book(title: "Mushoku", coverImage: "MushokuCover", readingProgress: 0.9, filePath: ""),
        Book(title: "Oregairu", coverImage: "OregairuCover", readingProgress: 1.0, filePath: ""),
        Book(title: "ReZero", coverImage: "ReZeroCover", readingProgress: 0.0, filePath: ""),
        Book(title: "Slime", coverImage: "SlimeCover", readingProgress: 0.0, filePath: ""),
        Book(title: "Overlord", coverImage: "OverlordCover", readingProgress: 0.0, filePath: ""),
        Book(title: "Death", coverImage: "DeathCover", readingProgress: 0.0, filePath: ""),
        Book(title: "No Game No Life", coverImage: "NoGameCover", readingProgress: 0.0, filePath: "")
    ]
    
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
        // If testing flag is enabled, use initial books
        if useInitialBooksForTesting {
            books = initialBooks
            print("DEBUG: Using initial test books instead of saved books")
            return
        }
        
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
                books = initialBooks
            }
        } else {
            // No saved books, use initial books
            books = initialBooks
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
