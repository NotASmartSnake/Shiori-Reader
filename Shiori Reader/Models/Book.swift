//
//  Book.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//

import SwiftUI

class Book: ObservableObject, Identifiable {
    let id = UUID() // Unique identifier
    let title: String
    let coverImage: String
    @Published var readingProgress: Double
    let filePath: String
    @Published var epubContent: EPUBContent?
    @Published var epubBaseURL: URL?
    
    // Convenience initializer
    init(title: String, coverImage: String, readingProgress: Double, filePath: String) {
        self.title = title
        self.coverImage = coverImage
        self.readingProgress = readingProgress
        self.filePath = filePath
        self.epubContent = nil
        self.epubBaseURL = nil
    }
    
    func loadEPUBContent() async throws {
        guard epubContent == nil else { return }
        
        guard let epubPath = Bundle.main.path(forResource: filePath, ofType: nil) else {
            throw EPUBError.fileNotFound
        }
        
        let parser = EPUBParser()
        let (content, baseURL) = try parser.parseEPUB(at: epubPath)
        
        await MainActor.run {
            self.epubContent = content
            self.epubBaseURL = baseURL
        }
    }
    
    // Implement Hashable manually since EPUBContent might not conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(coverImage)
        hasher.combine(readingProgress)
        hasher.combine(filePath)
    }
    
    // Implement Equatable
    static func == (lhs: Book, rhs: Book) -> Bool {
        return lhs.id == rhs.id
    }
}
