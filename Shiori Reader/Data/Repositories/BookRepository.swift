//
//  BookRepository.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/20/25.
//

import Foundation
import CoreData

class BookRepository {
    private let coreDataManager = CoreDataManager.shared
    
    // Get all books
    func getAllBooks() -> [Book] {
        let entities = coreDataManager.getAllBooks()
        return entities.map { Book(entity: $0) }
    }
    
    // Add a new book
    func addBook(title: String, author: String? = nil, filePath: String,
                coverImage: String? = nil, isLocalCover: Bool = false) -> Book {
        let entity = coreDataManager.createBook(
            title: title,
            author: author,
            filePath: filePath,
            coverImagePath: coverImage
        )
        entity.isLocalCover = isLocalCover
        coreDataManager.saveContext()
        return Book(entity: entity)
    }
    
    // Update book progress
    func updateBookProgress(id: UUID, progress: Double, locatorData: Data? = nil) {
        guard let entity = coreDataManager.getBook(by: id) else { return }
        coreDataManager.updateBookProgress(book: entity, progress: progress, locatorData: locatorData)
    }
    
    // Update book title
    func updateBookTitle(id: UUID, newTitle: String) {
        guard let entity = coreDataManager.getBook(by: id) else { return }
        entity.title = newTitle
        coreDataManager.saveContext()
    }
    
    // Delete a book
    func deleteBook(with id: UUID) {
        guard let entity = coreDataManager.getBook(by: id) else { return }
        coreDataManager.deleteBook(entity)
    }
}
