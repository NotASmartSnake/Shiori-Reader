import SwiftUI
import Combine
import ReadiumNavigator

class DefaultAppearanceSettingsViewModel: ObservableObject {
    @Published var preferences: DefaultAppearanceSettings
    @Published var customThemes: [CustomTheme] = []
    @Published var selectedCustomThemeId: UUID? = nil
    private let settingsRepository: SettingsRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(settingsRepository: SettingsRepository = SettingsRepository()) {
        self.settingsRepository = settingsRepository
        
        // Load default appearance settings
        self.preferences = settingsRepository.getDefaultAppearanceSettings()
        print("[DEBUG] Loaded preferences: isDictionaryAnimationEnabled=\(preferences.isDictionaryAnimationEnabled), speed=\(preferences.dictionaryAnimationSpeed), displayMode=\(preferences.dictionaryDisplayMode)")
        
        // Load custom themes
        self.customThemes = settingsRepository.getAllCustomThemes()
        
        // Set up publisher to save changes automatically
        $preferences
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] updatedPreferences in
                self?.savePreferences()
            }
            .store(in: &cancellables)
    }
    
    func savePreferences() {
        print("[DEBUG] Saving preferences: isDictionaryAnimationEnabled=\(preferences.isDictionaryAnimationEnabled), speed=\(preferences.dictionaryAnimationSpeed), displayMode=\(preferences.dictionaryDisplayMode)")
        settingsRepository.saveDefaultAppearanceSettings(preferences)
        print("[DEBUG] Preferences saved successfully")
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
    
    func toggleDictionaryAnimation() {
        preferences.isDictionaryAnimationEnabled.toggle()
    }
    
    func updateDictionaryAnimationSpeed(_ speed: String) {
        preferences.dictionaryAnimationSpeed = speed
    }
    
    func updateDictionaryDisplayMode(_ mode: String) {
        print("[DEBUG] Updating dictionary display mode from \(preferences.dictionaryDisplayMode) to \(mode)")
        preferences.dictionaryDisplayMode = mode
        // Explicitly save to ensure persistence
        savePreferences()
    }
    
    func toggleCharacterPickerSwipe() {
        preferences.isCharacterPickerSwipeEnabled.toggle()
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
            
            // Reset selected custom theme when choosing a predefined theme
            selectedCustomThemeId = nil
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
            theme: "light",
            isDictionaryAnimationEnabled: true,
            dictionaryAnimationSpeed: "normal",
            dictionaryDisplayMode: "card",
            isCharacterPickerSwipeEnabled: true
        )
        
        // Reset selected custom theme
        selectedCustomThemeId = nil
    }
    
    // Save current theme as a custom theme
    func saveCurrentThemeAs(name: String) {
        let theme = CustomTheme(
            name: name,
            textColor: preferences.textColor,
            backgroundColor: preferences.backgroundColor
        )
        
        settingsRepository.saveCustomTheme(theme)
        customThemes = settingsRepository.getAllCustomThemes()
        selectedCustomThemeId = theme.id
    }
    
    // Apply a custom theme
    func applyCustomTheme(_ theme: CustomTheme) {
        preferences.textColor = theme.textColor
        preferences.backgroundColor = theme.backgroundColor
        preferences.theme = "custom" // Set to custom theme mode
        selectedCustomThemeId = theme.id
        savePreferences()
    }
    
    // Delete a custom theme
    func deleteCustomTheme(_ theme: CustomTheme) {
        settingsRepository.deleteCustomTheme(theme)
        customThemes = settingsRepository.getAllCustomThemes()
        
        // Reset selected theme if it's the one that was deleted
        if selectedCustomThemeId == theme.id {
            selectedCustomThemeId = nil
        }
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
