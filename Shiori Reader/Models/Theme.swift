//
//  Theme.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/7/25.
//


import SwiftUI
import Foundation

// Save the selected theme in UserDefaults
extension UserDefaults {
    static let selectedLightThemeNameKey = "selectedLightThemeName"
    static let selectedDarkThemeNameKey = "selectedDarkThemeNameKey"
    
    var selectedLightThemeName: String? {
        get { string(forKey: UserDefaults.selectedLightThemeNameKey) }
        set { set(newValue, forKey: UserDefaults.selectedLightThemeNameKey) }
    }
    
    var selectedDarkThemeName: String? {
        get { string(forKey: UserDefaults.selectedDarkThemeNameKey) }
        set { set(newValue, forKey: UserDefaults.selectedDarkThemeNameKey) }
    }
    
    // Get appropriate theme name based on mode
    func selectedThemeName(forDarkMode isDarkMode: Bool) -> String? {
        return isDarkMode ? selectedDarkThemeName : selectedLightThemeName
    }
    
    // Save theme name for appropriate mode
    func setSelectedThemeName(_ name: String, forDarkMode isDarkMode: Bool) {
        if isDarkMode {
            selectedDarkThemeName = name
        } else {
            selectedLightThemeName = name
        }
    }
}

struct Theme: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let backgroundColor: Color
    let textColor: Color
    
    // CSS color values for WebView
    var backgroundColorCSS: String {
        let uiColor = UIColor(backgroundColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return "rgba(\(Int(red * 255)), \(Int(green * 255)), \(Int(blue * 255)), \(alpha))"
    }
    
    var textColorCSS: String {
        let uiColor = UIColor(textColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return "rgba(\(Int(red * 255)), \(Int(green * 255)), \(Int(blue * 255)), \(alpha))"
    }
    
    // Predefined light themes
    static let original = Theme(
        name: "Original",
        backgroundColor: .white,
        textColor: .black
    )
    
    // Predefined dark themes
    static let darkOriginal = Theme(
        name: "Dark Original",
        backgroundColor: Color(red: 0.1, green: 0.1, blue: 0.1),
        textColor: .white
    )
    
    static let warm = Theme(
        name: "Warm",
        backgroundColor: Color(red: 245/255, green: 230/255, blue: 211/255),
        textColor: .black
    )
    
    static let darkWarm = Theme(
        name: "Dark Warm",
        backgroundColor: Color(red: 48/255, green: 36/255, blue: 24/255),
        textColor: Color(red: 230/255, green: 215/255, blue: 200/255)
    )
    
    static let sepia = Theme(
        name: "Sepia",
        backgroundColor: Color(red: 0.98, green: 0.95, blue: 0.9),
        textColor: .black
    )
    
    static let darkSepia = Theme(
        name: "Dark Sepia",
        backgroundColor: Color(red: 42/255, green: 35/255, blue: 30/255),
        textColor: Color(red: 220/255, green: 208/255, blue: 192/255)
    )
    
    static let soft = Theme(
        name: "Soft",
        backgroundColor: Color(red: 250/255, green: 249/255, blue: 246/255),
        textColor: .black
    )
    
    static let darkSoft = Theme(
        name: "Dark Soft",
        backgroundColor: Color(red: 30/255, green: 30/255, blue: 34/255),
        textColor: Color(red: 210/255, green: 210/255, blue: 215/255)
    )
    
    static let paper = Theme(
        name: "Paper",
        backgroundColor: Color(red: 237/255, green: 237/255, blue: 237/255),
        textColor: .black
    )
    
    static let darkPaper = Theme(
        name: "Dark Paper",
        backgroundColor: Color(red: 38/255, green: 38/255, blue: 42/255),
        textColor: Color(red: 200/255, green: 200/255, blue: 200/255)
    )
    
    static let calm = Theme(
        name: "Calm",
        backgroundColor: Color(red: 227/255, green: 242/255, blue: 253/255),
        textColor: .black
    )
    
    static let darkCalm = Theme(
        name: "Dark Calm",
        backgroundColor: Color(red: 25/255, green: 40/255, blue: 55/255),
        textColor: Color(red: 190/255, green: 210/255, blue: 230/255)
    )
    
    // All available themes
    static let lightThemes = [original, warm, sepia, soft, paper, calm]
    static let darkThemes = [darkOriginal, darkWarm, darkSepia, darkSoft, darkPaper, darkCalm]
    
    // Get all themes based on dark mode setting
    static func getThemes(isDarkMode: Bool) -> [Theme] {
        return isDarkMode ? darkThemes : lightThemes
    }
    
    // All themes for display purposes
    static let allThemes = lightThemes + darkThemes
}
