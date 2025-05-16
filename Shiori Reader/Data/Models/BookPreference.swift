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
    var fontWeight: Float
    var backgroundColor: String
    var textColor: String
    var readingDirection: String // "ltr", "rtl"
    var isVerticalText: Bool
    var isScrollMode: Bool
    var theme: String // "light", "dark", "sepia"
    let bookId: UUID
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(),
         fontSize: Float = 1.0,
         fontFamily: String = "Default",
         fontWeight: Float = 400.0,
         backgroundColor: String = "#FFFFFF",
         textColor: String = "#000000",
         readingDirection: String = "ltr",
         isVerticalText: Bool = false,
         isScrollMode: Bool = false,
         theme: String = "light",
         bookId: UUID) {
        self.id = id
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.fontWeight = fontWeight
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.readingDirection = readingDirection
        self.isVerticalText = isVerticalText
        self.isScrollMode = isScrollMode
        self.theme = theme
        self.bookId = bookId
    }
    
    // Initialize from Core Data entity
    init(entity: BookPreferenceEntity) {
        self.id = entity.id ?? UUID()
        self.fontSize = entity.fontSize
        self.fontFamily = entity.fontFamily ?? "Default"
        self.fontWeight = entity.fontWeight
        self.backgroundColor = entity.backgroundColor ?? "#FFFFFF"
        self.textColor = entity.textColor ?? "#000000"
        self.readingDirection = entity.readingDirection ?? "ltr"
        self.isVerticalText = entity.isVerticalText
        self.isScrollMode = entity.isScrollMode
        self.theme = entity.theme ?? "light"
        self.bookId = entity.book?.id ?? UUID()
    }
    
    // MARK: - Helper Methods
    
    // Convert color string to SwiftUI Color
    func getBackgroundColor() -> Color {
        switch theme {
        case "dark":
            return Color(hex: "#222222") ?? .black
        case "sepia":
            return Color(hex: "#F8F1E3") ?? Color(red: 0.98, green: 0.94, blue: 0.89)
        default:
            return Color(hex: backgroundColor) ?? .white
        }
    }
    
    // Convert color string to SwiftUI Color
    func getTextColor() -> Color {
        switch theme {
        case "dark":
            return Color(hex: "#EEEEEE") ?? .white
        case "sepia":
            return Color(hex: "#5F4B32") ?? Color(red: 0.37, green: 0.29, blue: 0.2)
        default:
            return Color(hex: textColor) ?? .black
        }
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
            lhs.fontWeight == rhs.fontWeight &&
            lhs.backgroundColor == rhs.backgroundColor &&
            lhs.textColor == rhs.textColor &&
            lhs.readingDirection == rhs.readingDirection &&
            lhs.isScrollMode == rhs.isScrollMode &&
            lhs.isVertical == rhs.isVertical &&
            lhs.theme == rhs.theme
    }
    
    // MARK: - Core Data Helpers
    
    // Update a Core Data entity with values from this model
    func updateEntity(_ entity: BookPreferenceEntity, bookEntity: BookEntity? = nil) {
        entity.id = id
        entity.fontSize = fontSize
        entity.fontWeight = fontWeight
        entity.fontFamily = fontFamily
        entity.backgroundColor = backgroundColor
        entity.textColor = textColor
        entity.readingDirection = readingDirection
        entity.isScrollMode = isScrollMode
        entity.isVerticalText = isVertical
        entity.theme = theme
        
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
        let success = Scanner(string: hex).scanHexInt64(&int)
        
        // Return nil if scan fails or if string is empty
        if !success || hex.isEmpty {
            return nil
        }
        
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
        
        // Make sure values are within valid range
        let red = Double(min(r, 255)) / 255.0
        let green = Double(min(g, 255)) / 255.0
        let blue = Double(min(b, 255)) / 255.0
        let alpha = Double(min(a, 255)) / 255.0
        
        self.init(
            .sRGB,
            red: red,
            green: green,
            blue: blue,
            opacity: alpha
        )
    }
    
    func toHex() -> String? {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // Clamp values between 0 and 1 to ensure valid hex output
        r = max(0, min(1, r))
        g = max(0, min(1, g))
        b = max(0, min(1, b))
        
        let hex = String(
            format: "#%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255)
        )
        
        return hex
    }
}
