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
        guard let epubPath = Bundle.main.path(forResource: path, ofType: nil) else {
            throw EPUBError.fileNotFound
        }
        return try epubParser.parseEPUB(at: epubPath)
    }
    
    @MainActor
    func saveProgress(for book: Book) async throws {
        // Implement persistence logic
        // For now, could just use UserDefaults
        UserDefaults.standard.set(book.readingProgress, forKey: "book_progress_\(book.id)")
    }
}
