import Foundation
import SwiftUI

struct CustomTheme: Identifiable, Equatable, Hashable {
    // MARK: - Properties
    let id: UUID
    var name: String
    var textColor: String
    var backgroundColor: String
    
    // MARK: - Initialization
    init(id: UUID = UUID(),
         name: String,
         textColor: String,
         backgroundColor: String) {
        self.id = id
        self.name = name
        self.textColor = textColor
        self.backgroundColor = backgroundColor
    }
    
    // Initialize from Core Data entity
    init(entity: CustomThemeEntity) {
        self.id = entity.id ?? UUID()
        self.name = entity.name ?? ""
        self.textColor = entity.textColor ?? "#000000"
        self.backgroundColor = entity.backgroundColor ?? "#FFFFFF"
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
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Equatable
    
    static func == (lhs: CustomTheme, rhs: CustomTheme) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.textColor == rhs.textColor &&
               lhs.backgroundColor == rhs.backgroundColor
    }
    
    // MARK: - Core Data Helpers
    
    // Update a Core Data entity with values from this model
    func updateEntity(_ entity: CustomThemeEntity) {
        entity.id = id
        entity.name = name
        entity.textColor = textColor
        entity.backgroundColor = backgroundColor
    }
}
