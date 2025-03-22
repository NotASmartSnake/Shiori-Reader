//
//  BookRepository.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/20/25.
//

import Foundation

class BookRepository {
    private let epubParser: EPUBParser
    
    init(epubParser: EPUBParser = EPUBParser()) {
        self.epubParser = epubParser
    }
    
    @MainActor
    func loadEPUB(at path: String) async throws -> (EPUBContent, URL) {
        print("DEBUG: Attempting to load EPUB at path: \(path)")
        
        // Check if the Books directory exists
        if let booksDirectoryURL = Bundle.main.url(forResource: "Books", withExtension: nil) {
            print("DEBUG: Books directory found at: \(booksDirectoryURL.path)")
        } else {
            print("DEBUG: Books directory NOT found in bundle")
        }
        
        // List contents of the bundle root
        if let bundleURL = Bundle.main.resourceURL {
            print("DEBUG: Bundle resource URL: \(bundleURL.path)")
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil)
                print("DEBUG: Bundle contents: \(contents.map { $0.lastPathComponent })")
            } catch {
                print("DEBUG: Error listing bundle contents: \(error)")
            }
        }
        
        // Try to list all epub files
        if let resourceURLs = Bundle.main.urls(forResourcesWithExtension: "epub", subdirectory: "Books") {
            print("DEBUG: Found EPUB files: \(resourceURLs.map { $0.lastPathComponent })")
        } else {
            print("DEBUG: No EPUB resources found with extension")
        }
        
        guard let epubPath = Bundle.main.path(forResource: path, ofType: nil) else {
            print("DEBUG: File not found: \(path)")
            throw EPUBError.fileNotFound
        }
        
        print("DEBUG: EPUB file found at: \(epubPath)")
        return try epubParser.parseEPUB(at: epubPath)
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
}
