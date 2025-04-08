//
//  BookRepository.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/20/25.
//

import Foundation

class BookRepository {
//    private let epubParser: EPUBParser
//    
//    init(epubParser: EPUBParser = EPUBParser()) {
//        self.epubParser = epubParser
//    }
    
    @MainActor
    func loadEPUB(at path: String) async throws -> (EPUBContent, URL) {
        print("DEBUG: Attempting to load EPUB at path: \(path)")
        
        // First, try to find the file in the app's Documents directory
        let fileManager = FileManager.default
        let documentsDirectory = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        
        let documentsPath = documentsDirectory.appendingPathComponent("Books/\(path)").path
        
        print("DEBUG: File not found: \(path)")
        throw EPUBError.fileNotFound
    }
    
    @MainActor
    func saveProgress(for book: Book, exploredCharCount: Int, totalCharCount: Int) async throws {
        let key = "book_progress_\(book.filePath)"
        
        // Save progress percentage
        UserDefaults.standard.set(book.readingProgress, forKey: key)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "book_progress_timestamp_\(book.filePath)")
        
        // Save character count data
        UserDefaults.standard.set(exploredCharCount, forKey: "book_char_count_\(book.filePath)")
        UserDefaults.standard.set(totalCharCount, forKey: "book_total_char_count_\(book.filePath)")
        
        // Force UserDefaults to save immediately
        UserDefaults.standard.synchronize()
    }
    
    @MainActor
    func getExploredCharCount(for filePath: String) -> Int {
        return UserDefaults.standard.integer(forKey: "book_char_count_\(filePath)")
    }
    
    @MainActor
    func getTotalCharCount(for filePath: String) -> Int {
        return UserDefaults.standard.integer(forKey: "book_total_char_count_\(filePath)")
    }
    
    @MainActor
    func getProgress(for filePath: String) -> Double {
        let key = "book_progress_\(filePath)"
        let progress = UserDefaults.standard.double(forKey: key)
        print("DEBUG: Getting progress with key: \(key), value: \(progress)")
        return progress
    }
    
    @MainActor
    func getLastReadDate(for bookId: UUID) -> Date? {
        let timestamp = UserDefaults.standard.double(forKey: "book_progress_timestamp_\(bookId)")
        if timestamp > 0 {
            return Date(timeIntervalSince1970: timestamp)
        }
        return nil
    }
    
    enum EPUBError: Error {
        case invalidArchive
        case fileNotFound
    }
}
