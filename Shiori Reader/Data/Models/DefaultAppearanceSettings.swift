//
//  DefaultAppearanceSettings.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/16/25.
//

import Foundation
import SwiftUI

struct DefaultAppearanceSettings: Identifiable, Equatable, Hashable {
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
    var isDictionaryAnimationEnabled: Bool
    var dictionaryAnimationSpeed: String // "slow", "normal", "fast"
    
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
         isDictionaryAnimationEnabled: Bool = true,
         dictionaryAnimationSpeed: String = "normal") {
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
        self.isDictionaryAnimationEnabled = isDictionaryAnimationEnabled
        self.dictionaryAnimationSpeed = dictionaryAnimationSpeed
    }
    
    // Initialize from Core Data entity
    init(entity: DefaultAppearanceSettingsEntity) {
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
        self.isDictionaryAnimationEnabled = entity.isDictionaryAnimationEnabled
        self.dictionaryAnimationSpeed = entity.dictionaryAnimationSpeed ?? "normal"
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
    
    // Get animation duration based on speed setting
    var animationDuration: Double {
        guard isDictionaryAnimationEnabled else { return 0 }
        
        switch dictionaryAnimationSpeed {
        case "slow":
            return 0.5
        case "fast":
            return 0.15
        default: // "normal"
            return 0.3
        }
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Equatable
    
    static func == (lhs: DefaultAppearanceSettings, rhs: DefaultAppearanceSettings) -> Bool {
        return lhs.id == rhs.id &&
            lhs.fontSize == rhs.fontSize &&
            lhs.fontFamily == rhs.fontFamily &&
            lhs.fontWeight == rhs.fontWeight &&
            lhs.backgroundColor == rhs.backgroundColor &&
            lhs.textColor == rhs.textColor &&
            lhs.readingDirection == rhs.readingDirection &&
            lhs.isScrollMode == rhs.isScrollMode &&
            lhs.isVertical == rhs.isVertical &&
            lhs.theme == rhs.theme &&
            lhs.isDictionaryAnimationEnabled == rhs.isDictionaryAnimationEnabled &&
            lhs.dictionaryAnimationSpeed == rhs.dictionaryAnimationSpeed
    }
    
    // MARK: - Core Data Helpers
    
    // Update a Core Data entity with values from this model
    func updateEntity(_ entity: DefaultAppearanceSettingsEntity) {
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
        entity.isDictionaryAnimationEnabled = isDictionaryAnimationEnabled
        entity.dictionaryAnimationSpeed = dictionaryAnimationSpeed
    }
}
