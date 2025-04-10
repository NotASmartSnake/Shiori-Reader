//
// Bookmark.swift
// Shiori Reader
//
// Created by Russell Graviet on 4/10/25.
//

import Foundation
import ReadiumShared

struct Bookmark: Identifiable, Equatable, Hashable {
    // MARK: - Properties
    let id: UUID
    let bookId: UUID
    let locator: Locator
    let progression: Double?
    let created: Date
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(),
         bookId: UUID,
         locator: Locator,
         progression: Double? = nil,
         created: Date = Date()) {
        self.id = id
        self.bookId = bookId
        self.locator = locator
        self.progression = progression ?? locator.locations.totalProgression
        self.created = created
    }
    
    // Initialize from Core Data entity
    init?(entity: BookmarkEntity) {
        guard let id = entity.id,
              let bookId = entity.bookId,
              let created = entity.created,
              let locatorData = entity.locatorData else {
            return nil
        }
        
        self.id = id
        self.bookId = bookId
        self.created = created
        self.progression = entity.progression
        
        // Deserialize locator from JSON
        do {
            guard let locatorJSON = try JSONSerialization.jsonObject(with: locatorData) as? [String: Any] else {
                return nil
            }
            
            guard let locator = try? Locator(json: locatorJSON) else {
                print("Invalid locator JSON")
                return nil
            }
            self.locator = locator
        } catch {
            print("Error deserializing locator: \(error)")
            return nil
        }
    }
    
    // MARK: - CoreData Helpers
    
    // Update a Core Data entity with values from this model
    func updateEntity(_ entity: BookmarkEntity) {
        entity.id = id
        entity.bookId = bookId
        entity.progression = progression ?? 0.0
        entity.created = created
        
        // Serialize locator to JSON data
        do {
            let locatorJSON = locator.json
            let locatorData = try JSONSerialization.data(withJSONObject: locatorJSON)
            entity.locatorData = locatorData
        } catch {
            print("Error serializing locator: \(error)")
        }
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(bookId)
        hasher.combine(locator.href)
    }
    
    // MARK: - Equatable
    
    static func == (lhs: Bookmark, rhs: Bookmark) -> Bool {
        return lhs.id == rhs.id
    }
}
