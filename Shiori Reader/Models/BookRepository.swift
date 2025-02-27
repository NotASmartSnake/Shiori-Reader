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
    func saveProgress(for book: Book) async throws {
        // Implement persistence logic
        // For now, could just use UserDefaults
        UserDefaults.standard.set(book.readingProgress, forKey: "book_progress_\(book.id)")
    }
}
