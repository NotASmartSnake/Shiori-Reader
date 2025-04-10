//
// BookmarkRepository.swift
// Shiori Reader
//
// Created by Russell Graviet on 4/10/25.
//

import Foundation
import Combine
import ReadiumShared

class BookmarkRepository {
    private let coreDataManager = CoreDataManager.shared
    
    // Publisher for bookmarks
    private let bookmarksSubject = PassthroughSubject<[Bookmark], Error>()
    
    // MARK: - Public Methods
    
    func all(for bookId: UUID) -> AnyPublisher<[Bookmark], Error> {
        // Return a publisher for the bookmarks
        refreshBookmarks(for: bookId)
        return bookmarksSubject.eraseToAnyPublisher()
    }
    
    func refreshBookmarks(for bookId: UUID) {
        // Get bookmarks from Core Data
        let bookmarkEntities = coreDataManager.getBookmarks(for: bookId)
        
        // Convert to model objects
        let bookmarks = bookmarkEntities.compactMap { Bookmark(entity: $0) }
        
        // Publish the results
        bookmarksSubject.send(bookmarks)
    }
    
    @discardableResult
    func add(_ bookmark: Bookmark) async -> Bool {
        // Create a bookmark entity
        let entity = coreDataManager.createBookmark(
            bookId: bookmark.bookId,
            locator: bookmark.locator,
            progression: bookmark.progression,
            created: bookmark.created
        )
        
        // Refresh bookmarks
        refreshBookmarks(for: bookmark.bookId)
        
        return entity.id != nil
    }
    
    func remove(_ id: UUID) async -> Bool {
        // Find the bookmark entity
        guard let entity = coreDataManager.getBookmark(by: id) else {
            return false
        }
        
        // Get the book ID to refresh later
        let bookId = entity.bookId
        
        // Delete the entity
        coreDataManager.deleteBookmark(entity)
        
        // Refresh bookmarks
        if let bookId = bookId {
            refreshBookmarks(for: bookId)
        }
        
        return true
    }
    
    func isBookmarked(bookId: UUID, locator: Locator) -> Bool {
        return coreDataManager.isLocationBookmarked(bookId: bookId, locator: locator)
    }
    
    func findBookmarkId(bookId: UUID, locator: Locator) -> UUID? {
        return coreDataManager.findBookmarkId(bookId: bookId, locator: locator)
    }
}
