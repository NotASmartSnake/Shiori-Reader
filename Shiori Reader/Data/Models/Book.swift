//
//  Book.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//

import Foundation

struct Book: Identifiable, Equatable, Hashable {
    // MARK: - Properties
    let id: UUID
    let title: String
    let author: String?
    let filePath: String
    let coverImagePath: String?
    let isLocalCover: Bool
    let addedDate: Date
    var lastOpenedDate: Date?
    var readingProgress: Double
    var currentLocatorData: Data?
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(),
         title: String,
         author: String? = nil,
         filePath: String,
         coverImagePath: String? = nil,
         isLocalCover: Bool = false,
         addedDate: Date = Date(),
         lastOpenedDate: Date? = nil,
         readingProgress: Double = 0.0,
         currentLocatorData: Data? = nil) {
        self.id = id
        self.title = title
        self.author = author
        self.filePath = filePath
        self.coverImagePath = coverImagePath
        self.isLocalCover = isLocalCover
        self.addedDate = addedDate
        self.lastOpenedDate = lastOpenedDate
        self.readingProgress = readingProgress
        self.currentLocatorData = currentLocatorData
    }
    
    // Initialize from Core Data entity
    init(entity: BookEntity) {
        self.id = entity.id ?? UUID()
        self.title = entity.title ?? ""
        self.author = entity.author
        self.filePath = entity.filePath ?? ""
        self.coverImagePath = entity.coverImagePath
        self.isLocalCover = entity.isLocalCover
        self.addedDate = entity.addedDate ?? Date()
        self.lastOpenedDate = entity.lastOpenedDate
        self.readingProgress = entity.readingProgress
        self.currentLocatorData = entity.currentLocatorData
    }
    
    // MARK: - Helper Methods
    
    // Format reading progress for display
    func formattedProgress() -> String {
        return String(format: "%.1f%%", readingProgress * 100)
    }
    
    // Create a copy with updated progress
    func withUpdatedProgress(_ newProgress: Double) -> Book {
        return Book(
            id: self.id,
            title: self.title,
            author: self.author,
            filePath: self.filePath,
            coverImagePath: self.coverImagePath,
            isLocalCover: self.isLocalCover,
            addedDate: self.addedDate,
            lastOpenedDate: Date(),
            readingProgress: newProgress,
            currentLocatorData: self.currentLocatorData
        )
    }
    
    // Return a copy with updated title
    func withUpdatedTitle(_ newTitle: String) -> Book {
        return Book(
            id: self.id,
            title: newTitle,
            author: self.author,
            filePath: self.filePath,
            coverImagePath: self.coverImagePath,
            isLocalCover: self.isLocalCover,
            addedDate: self.addedDate,
            lastOpenedDate: self.lastOpenedDate,
            readingProgress: self.readingProgress,
            currentLocatorData: self.currentLocatorData
        )
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Equatable
    
    static func == (lhs: Book, rhs: Book) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Core Data Helpers
    
    // Update a Core Data entity with values from this model
    func updateEntity(_ entity: BookEntity) {
        entity.id = id
        entity.title = title
        entity.author = author
        entity.filePath = filePath
        entity.coverImagePath = coverImagePath
        entity.isLocalCover = isLocalCover
        entity.lastOpenedDate = lastOpenedDate
        entity.readingProgress = readingProgress
        entity.currentLocatorData = currentLocatorData
        // Note: We don't update addedDate since that should remain fixed
    }
}
