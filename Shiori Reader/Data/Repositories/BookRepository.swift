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
    func updateBookTitle(id: UUID, newTitle: String) -> Bool {
        guard let entity = coreDataManager.getBook(by: id) else { 
            print("BookRepository: Could not find book with id \(id)")
            return false 
        }
        
        print("BookRepository: Updating book title from '\(entity.title ?? "nil")' to '\(newTitle)'")
        entity.title = newTitle
        
        do {
            try coreDataManager.viewContext.save()
            print("BookRepository: Successfully saved title update")
            return true
        } catch {
            print("BookRepository: Error saving title update: \(error)")
            return false
        }
    }
    
    // Delete a book
    func deleteBook(with id: UUID) {
        guard let entity = coreDataManager.getBook(by: id) else { return }
        coreDataManager.deleteBook(entity)
    }
}
