//
//  ReaderSettingsViewModel.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/10/25.
//


// ReaderSettingsViewModel.swift
import SwiftUI
import Combine
import ReadiumNavigator

class ReaderSettingsViewModel: ObservableObject {
    @Published var preferences: BookPreference
    private let settingsRepository: SettingsRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(bookId: UUID, settingsRepository: SettingsRepository = SettingsRepository()) {
        self.settingsRepository = settingsRepository
        
        // Try to load book preferences, use default appearance settings if none exist
        if let bookPrefs = settingsRepository.getBookPreferences(bookId: bookId) {
            self.preferences = bookPrefs
        } else {
            // Get default appearance settings and convert to book preferences
            let defaultSettings = settingsRepository.getDefaultAppearanceSettings()
            self.preferences = BookPreference(
                fontSize: defaultSettings.fontSize,
                fontFamily: defaultSettings.fontFamily,
                fontWeight: defaultSettings.fontWeight,
                backgroundColor: defaultSettings.backgroundColor,
                textColor: defaultSettings.textColor,
                readingDirection: defaultSettings.readingDirection,
                isVerticalText: defaultSettings.isVerticalText,
                isScrollMode: defaultSettings.isScrollMode,
                theme: defaultSettings.theme,
                bookId: bookId
            )
        }
        
        // Set up publisher to save changes automatically
        $preferences
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] updatedPreferences in
                self?.savePreferences()
            }
            .store(in: &cancellables)
    }
    
    func savePreferences() {
        settingsRepository.saveBookPreferences(preferences)
    }
    
    // Helper functions for updating preferences
    func updateFontSize(_ size: Float) {
        preferences.fontSize = size
    }
    
    func updateFontFamily(_ family: String) {
        preferences.fontFamily = family
    }
    
    func updateFontWeight(_ weight: Float) {
        preferences.fontWeight = weight
    }
    
    func updateReadingDirection(_ direction: String) {
        preferences.readingDirection = direction
    }
    
    func toggleVerticalText() {
        preferences.isVerticalText.toggle()
    }
    
    func toggleScrollMode() {
        preferences.isScrollMode.toggle()
    }
    
    func setTheme(_ theme: String) {
        preferences.theme = theme
        
        // Only update colors automatically if not using custom theme
        if theme != "custom" {
            switch theme {
            case "dark":
                preferences.backgroundColor = "#000000"
                preferences.textColor = "#FEFEFE"
            case "sepia":
                preferences.backgroundColor = "#faf4e8"
                preferences.textColor = "#121212"
            case "light":
                preferences.backgroundColor = "#FFFFFF"
                preferences.textColor = "#121212"
            default:
                break // Don't change colors for custom theme
            }
        }
        
        // Save the preferences
        savePreferences()
    }
    
    // Convert our preferences to EPUBPreferences for Readium
    func toReadiumPreferences() -> EPUBPreferences {
        var prefs = EPUBPreferences()
        
        // Font settings
        prefs.fontSize = Double(preferences.fontSize)
        
        // Font family
        if preferences.fontFamily != "Default" {
            if preferences.fontFamily == "Sans Serif" {
                prefs.fontFamily = .sansSerif
            } else if preferences.fontFamily == "Serif" {
                prefs.fontFamily = FontFamily(rawValue: "serif")
            } else {
                prefs.fontFamily = FontFamily(rawValue: preferences.fontFamily)
            }
        }
        
        // Publisher styles
        prefs.publisherStyles = true
        
        // Reading progression
        if preferences.readingDirection == "rtl" {
            prefs.readingProgression = .rtl
        } else {
            prefs.readingProgression = .ltr
        }
        
        // Vertical text
        prefs.verticalText = preferences.isVerticalText
        
        // Scroll mode
        prefs.scroll = preferences.isScrollMode
        
        // Theme colors
        if preferences.theme == "custom" {
            // For custom theme, set colors directly
            let textColor = ReadiumNavigator.Color(hex: preferences.textColor) ?? ReadiumNavigator.Color(hex: "#000000")!
            let backgroundColor = ReadiumNavigator.Color(hex: preferences.backgroundColor) ?? ReadiumNavigator.Color(hex: "#FFFFFF")!
            
            prefs.textColor = textColor
            prefs.backgroundColor = backgroundColor
        } else {
            // For standard themes, set the theme enum
            switch preferences.theme {
            case "dark":
                prefs.theme = .dark
            case "sepia":
                prefs.theme = .sepia
            default: // light
                prefs.theme = .light
            }
        }
        
        return prefs
    }
    
    // Reset to defaults
    func resetToDefaults() {
        preferences = BookPreference(
            fontSize: 1.0,
            fontFamily: "Default",
            fontWeight: 400.0,
            backgroundColor: "#FFFFFF",
            textColor: "#000000",
            readingDirection: "ltr",
            isVerticalText: false,
            isScrollMode: false,
            theme: "light",
            bookId: preferences.bookId
        )
    }
}
