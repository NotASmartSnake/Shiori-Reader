//
//  DefaultAppearanceSettingsViewModel.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/16/25.
//

import SwiftUI
import Combine
import ReadiumNavigator

class DefaultAppearanceSettingsViewModel: ObservableObject {
    @Published var preferences: DefaultAppearanceSettings
    private let settingsRepository: SettingsRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(settingsRepository: SettingsRepository = SettingsRepository()) {
        self.settingsRepository = settingsRepository
        
        // Load default appearance settings
        self.preferences = settingsRepository.getDefaultAppearanceSettings()
        
        // Set up publisher to save changes automatically
        $preferences
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] updatedPreferences in
                self?.savePreferences()
            }
            .store(in: &cancellables)
    }
    
    func savePreferences() {
        settingsRepository.saveDefaultAppearanceSettings(preferences)
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
    
    // Reset to defaults
    func resetToDefaults() {
        preferences = DefaultAppearanceSettings(
            fontSize: 1.0,
            fontFamily: "Default",
            fontWeight: 400.0,
            backgroundColor: "#FFFFFF",
            textColor: "#000000",
            readingDirection: "ltr",
            isVerticalText: false,
            isScrollMode: false,
            theme: "light"
        )
    }
    
    // Convert our default preferences to a BookPreference
    // This can be used when creating new BookPreference instances for new books
    func toBookPreference(bookId: UUID) -> BookPreference {
        return BookPreference(
            fontSize: preferences.fontSize,
            fontFamily: preferences.fontFamily,
            fontWeight: preferences.fontWeight,
            backgroundColor: preferences.backgroundColor,
            textColor: preferences.textColor,
            readingDirection: preferences.readingDirection,
            isVerticalText: preferences.isVerticalText,
            isScrollMode: preferences.isScrollMode,
            theme: preferences.theme,
            bookId: bookId
        )
    }
}
