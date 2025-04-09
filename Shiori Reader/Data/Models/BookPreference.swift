//
//  BookPreference.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/9/25.
//

import Foundation
import SwiftUI

struct BookPreference: Identifiable, Equatable, Hashable {
    // MARK: - Properties
    let id: UUID
    var fontSize: Float
    var fontFamily: String
    var backgroundColor: String
    var textColor: String
    var readingDirection: String
    var isScrollMode: Bool
    let bookId: UUID
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(),
         fontSize: Float = 1.0,
         fontFamily: String = "Default",
         backgroundColor: String = "#FFFFFF",
         textColor: String = "#000000",
         readingDirection: String = "ltr",
         isScrollMode: Bool = false,
         bookId: UUID) {
        self.id = id
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.readingDirection = readingDirection
        self.isScrollMode = isScrollMode
        self.bookId = bookId
    }
    
    // Initialize from Core Data entity
    init(entity: BookPreferenceEntity) {
        self.id = entity.id ?? UUID()
        self.fontSize = entity.fontSize
        self.fontFamily = entity.fontFamily ?? "Default"
        self.backgroundColor = entity.backgroundColor ?? "#FFFFFF"
        self.textColor = entity.textColor ?? "#000000"
        self.readingDirection = entity.readingDirection ?? "ltr"
        self.isScrollMode = entity.isScrollMode
        self.bookId = entity.book?.id ?? UUID()
    }
    
    // MARK: - Helper Methods
    
    // Convert color string to SwiftUI Color
    func getBackgroundColor() -> Color {
        return Color(hex: backgroundColor) ?? .white
    }
    
    // Convert color string to SwiftUI Color
    func getTextColor() -> Color {
        return Color(hex: textColor) ?? .black
    }
    
    // Check if reading direction is right-to-left
    var isRTL: Bool {
        return readingDirection == "rtl"
    }
    
    // Check if reading direction is vertical (top-to-bottom)
    var isVertical: Bool {
        return readingDirection == "vertical"
    }
    
    // Create a copy with updated font size
    func withUpdatedFontSize(_ newSize: Float) -> BookPreference {
        var copy = self
        copy.fontSize = newSize
        return copy
    }
    
    // Create a copy with updated background and text colors
    func withUpdatedColors(background: String, text: String) -> BookPreference {
        var copy = self
        copy.backgroundColor = background
        copy.textColor = text
        return copy
    }
    
    // Create a copy with updated reading direction
    func withUpdatedReadingDirection(_ direction: String) -> BookPreference {
        var copy = self
        copy.readingDirection = direction
        return copy
    }
    
    // Toggle scroll mode
    func withToggledScrollMode() -> BookPreference {
        var copy = self
        copy.isScrollMode = !isScrollMode
        return copy
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(bookId)
    }
    
    // MARK: - Equatable
    
    static func == (lhs: BookPreference, rhs: BookPreference) -> Bool {
        return lhs.id == rhs.id &&
               lhs.bookId == rhs.bookId &&
               lhs.fontSize == rhs.fontSize &&
               lhs.fontFamily == rhs.fontFamily &&
               lhs.backgroundColor == rhs.backgroundColor &&
               lhs.textColor == rhs.textColor &&
               lhs.readingDirection == rhs.readingDirection &&
               lhs.isScrollMode == rhs.isScrollMode
    }
    
    // MARK: - Core Data Helpers
    
    // Update a Core Data entity with values from this model
    func updateEntity(_ entity: BookPreferenceEntity, bookEntity: BookEntity? = nil) {
        entity.id = id
        entity.fontSize = fontSize
        entity.fontFamily = fontFamily
        entity.backgroundColor = backgroundColor
        entity.textColor = textColor
        entity.readingDirection = readingDirection
        entity.isScrollMode = isScrollMode
        
        // Only update the book relationship if provided
        if let bookEntity = bookEntity {
            entity.book = bookEntity
        }
    }
}

// Helper extension for Color to support hex strings
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
