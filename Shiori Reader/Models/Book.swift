//
//  Book.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//

import SwiftUI

struct Book: Identifiable, Equatable, Codable {
    let id: UUID
    let title: String
    let coverImage: String
    let filePath: String
    var readingProgress: Double
    
    enum CodingKeys: String, CodingKey {
        case id, title, coverImage, filePath, readingProgress
    }
    
    init(title: String, coverImage: String, readingProgress: Double, filePath: String) {
        self.id = UUID()
        self.title = title
        self.coverImage = coverImage
        self.readingProgress = readingProgress
        self.filePath = filePath
    }
    
    // Custom initializer that preserves an existing ID
    init(id: UUID = UUID(), title: String, coverImage: String, readingProgress: Double, filePath: String) {
        self.id = id
        self.title = title
        self.coverImage = coverImage
        self.readingProgress = readingProgress
        self.filePath = filePath
    }
    
    // Copy with updated title
    func withUpdatedTitle(_ newTitle: String) -> Book {
        return Book(
            id: self.id,
            title: newTitle,
            coverImage: self.coverImage,
            readingProgress: self.readingProgress,
            filePath: self.filePath
        )
    }
    
    // Copy with updated reading progress
    func withUpdatedProgress(_ newProgress: Double) -> Book {
        return Book(
            id: self.id,
            title: self.title,
            coverImage: self.coverImage,
            readingProgress: newProgress,
            filePath: self.filePath
        )
    }
}
