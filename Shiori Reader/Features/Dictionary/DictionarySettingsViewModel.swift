//
//  DictionarySettingsViewModel.swift
//  Shiori Reader
//
//  Created by Claude on 4/16/25.
//

import Foundation
import Combine
import SwiftUI

class DictionarySettingsViewModel: ObservableObject {
    // Published properties for UI binding
    @Published var availableDictionaries: [DictionaryInfo] = []
    @Published var settings: DictionarySettings
    @Published var alertMessage = ""
    @Published var showAlert = false
    @Published var alertTitle = ""
    
    private let userDefaults = UserDefaults.standard
    private let dictionarySettingsKey = "dictionarySettings"
    private let migrationKey = "dictionarySettingsMigrated_v2" // Version key for migrations
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        print("📚 [SETTINGS] Initializing DictionarySettingsViewModel")
        
        // Initialize with default settings first
        self.settings = DictionarySettings()
        
        // Initialize with the available dictionaries
        self.availableDictionaries = [
            DictionaryInfo(
                id: "jmdict",
                name: "JMdict",
                description: "English-Japanese bilingual dictionary",
                isBuiltIn: true,
                isEnabled: true,
                canDisable: true,
                tagColor: .blue
            ),
            DictionaryInfo(
                id: "obunsha",
                name: "旺文社国語辞典 第十一版",
                description: "Japanese-Japanese monolingual dictionary",
                isBuiltIn: true,
                isEnabled: true,
                canDisable: true,
                tagColor: .orange
            ),
            DictionaryInfo(
                id: "bccwj",
                name: "BCCWJ Frequency Data",
                description: "Word frequency rankings from Japanese corpus",
                isBuiltIn: true,
                isEnabled: true,
                canDisable: true,
                tagColor: .green
            )
        ]
        
        // Now load the saved settings after initializing properties
        loadSettings()
        
        // Load imported dictionaries
        loadImportedDictionaries()
        
        // Sort dictionaries based on saved order
        sortDictionariesByOrder()
        
        // Sync the dictionary enabled state with settings
        syncDictionaryStatesWithSettings()
        
        // Set up publishers to monitor changes
        setupObservers()
    }
    
    private func syncDictionaryStatesWithSettings() {
        // This will trigger UI updates since availableDictionaries is @Published
        for index in availableDictionaries.indices {
            let dictionaryId = availableDictionaries[index].id
            let isEnabled = settings.enabledDictionaries.contains(dictionaryId)
            availableDictionaries[index].isEnabled = isEnabled
            
            // Update color from settings if available
            if let savedColor = settings.dictionaryColors[dictionaryId] {
                availableDictionaries[index].tagColor = savedColor
            }
            
            // All dictionaries can be disabled - no restrictions
            availableDictionaries[index].canDisable = true
        }
        
        // Force UI update
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    private func setupObservers() {
        // Monitor settings changes to save
        $settings
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] settings in
                self?.saveSettings()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        let hasMigrated = userDefaults.bool(forKey: migrationKey)
        print("📚 [SETTINGS] Loading settings (hasMigrated: \(hasMigrated))")
        
        if let data = userDefaults.data(forKey: dictionarySettingsKey),
           let savedSettings = try? JSONDecoder().decode(DictionarySettings.self, from: data) {
            self.settings = savedSettings
            print("📚 [SETTINGS] Loaded settings: \(savedSettings.enabledDictionaries)")
            
            // Migration: Only run once per device/app install
            if !hasMigrated {
                var needsMigration = false
                if !savedSettings.enabledDictionaries.contains("obunsha") {
                    print("📚 [SETTINGS] Migrating settings to include Obunsha dictionary")
                    self.settings.enabledDictionaries.append("obunsha")
                    needsMigration = true
                }
                if !savedSettings.enabledDictionaries.contains("bccwj") {
                    print("📚 [SETTINGS] Migrating settings to include BCCWJ frequency data")
                    self.settings.enabledDictionaries.append("bccwj")
                    needsMigration = true
                }
                // Set initial dictionary order if it doesn't exist (first run only)
                if savedSettings.dictionaryOrder.isEmpty {
                    print("📚 [SETTINGS] Setting initial dictionary order")
                    // Set initial order based on available dictionaries in default sequence
                    self.settings.dictionaryOrder = availableDictionaries.map { $0.id }
                    needsMigration = true
                }
                if needsMigration {
                    saveSettings()
                    print("📚 [SETTINGS] Migration completed")
                }
                userDefaults.set(true, forKey: migrationKey)
            }
        } else {
            // No saved settings, use defaults
            print("📚 [SETTINGS] No saved settings found, using defaults")
            self.settings = DictionarySettings()
            userDefaults.set(true, forKey: migrationKey) // Mark as migrated since we're using defaults
        }
    }
    
    func refreshSettings() {
        let hasMigrated = userDefaults.bool(forKey: migrationKey)
        print("📚 [SETTINGS] Refreshing settings (hasMigrated: \(hasMigrated))")
        
        // Simple reload without migration logic
        if let data = userDefaults.data(forKey: dictionarySettingsKey),
           let savedSettings = try? JSONDecoder().decode(DictionarySettings.self, from: data) {
            self.settings = savedSettings
            print("📚 [SETTINGS] Refreshed settings: \(savedSettings.enabledDictionaries)")
        } else {
            // If no saved settings, use defaults
            self.settings = DictionarySettings()
            print("📚 [SETTINGS] No saved settings during refresh, using defaults")
        }
        
        // Re-sync the dictionary states with the refreshed settings
        sortDictionariesByOrder()
        syncDictionaryStatesWithSettings()
    }
    
    private func getDictionarySettings() -> DictionarySettings {
        if let data = userDefaults.data(forKey: dictionarySettingsKey),
           let settings = try? JSONDecoder().decode(DictionarySettings.self, from: data) {
            return settings
        }
        return DictionarySettings()
    }
    
    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: dictionarySettingsKey)
        }
    }
    
    // MARK: - Dictionary Management
    
    func reorderDictionaries(from source: IndexSet, to destination: Int) {
        availableDictionaries.move(fromOffsets: source, toOffset: destination)
        
        // Update the dictionary order in settings
        let newOrder = availableDictionaries.map { $0.id }
        settings.dictionaryOrder = newOrder
        saveSettings()
    }
    
    func sortDictionariesByOrder() {
        let order = settings.dictionaryOrder
        availableDictionaries.sort { first, second in
            let firstIndex = order.firstIndex(of: first.id) ?? Int.max
            let secondIndex = order.firstIndex(of: second.id) ?? Int.max
            return firstIndex < secondIndex
        }
    }
    
    func getOrderedDictionarySources() -> [String] {
        // Return the current dictionary order from settings
        // Include any imported dictionaries that aren't in the order yet
        var orderedSources = settings.dictionaryOrder
        let importedDictionaries = availableDictionaries.filter { $0.id.hasPrefix("imported_") && !orderedSources.contains($0.id) }
        orderedSources.append(contentsOf: importedDictionaries.map { $0.id })
        return orderedSources
    }
    
    func toggleDictionary(id: String, isEnabled: Bool) {
        // Find the dictionary in our list
        if let index = availableDictionaries.firstIndex(where: { $0.id == id }) {
            // Update the entry
            availableDictionaries[index].isEnabled = isEnabled
            
            // Update the settings
            var updatedSettings = settings
            if isEnabled {
                // Add to enabled dictionaries if not already there
                if !updatedSettings.enabledDictionaries.contains(id) {
                    updatedSettings.enabledDictionaries.append(id)
                }
            } else {
                // Remove from enabled dictionaries
                updatedSettings.enabledDictionaries.removeAll(where: { $0 == id })
            }
            
            settings = updatedSettings
            saveSettings()
            
            // Update canDisable states for all dictionaries
            syncDictionaryStatesWithSettings()
        }
    }
    
    func updateDictionaryColor(id: String, color: DictionaryTagColor) {
        // Find the dictionary in our list
        if let index = availableDictionaries.firstIndex(where: { $0.id == id }) {
            // Update the entry
            availableDictionaries[index].tagColor = color
            
            // Update the settings
            var updatedSettings = settings
            updatedSettings.dictionaryColors[id] = color
            settings = updatedSettings
            saveSettings()
        }
    }
    
    /// Get an unused color for a new dictionary, or random if all are used
    private func getUnusedColor() -> DictionaryTagColor {
        let usedColors = Set(settings.dictionaryColors.values)
        let availableColors = DictionaryTagColor.allCases.filter { !usedColors.contains($0) }
        
        if !availableColors.isEmpty {
            // Return first unused color
            return availableColors.first!
        } else {
            // All colors are used, return a random color
            return DictionaryTagColor.allCases.randomElement() ?? .gray
        }
    }
    
    // MARK: - Imported Dictionary Management
    
    func loadImportedDictionaries() {
        let importedDictionaries = DictionaryImportManager.shared.getImportedDictionaries()
        
        for importedDict in importedDictionaries {
            let importedId = "imported_\(importedDict.id.uuidString)"
            
            // Get color for this dictionary, assigning unique color if not set
            let assignedColor: DictionaryTagColor
            if let existingColor = settings.dictionaryColors[importedId] {
                assignedColor = existingColor
            } else {
                assignedColor = getUnusedColor()
                // Update settings with the new color
                var updatedSettings = settings
                updatedSettings.dictionaryColors[importedId] = assignedColor
                settings = updatedSettings
                saveSettings()
            }
            
            let dictionaryInfo = DictionaryInfo(
                id: importedId,
                name: importedDict.title,
                description: importedDict.detailText,
                isBuiltIn: false,
                isEnabled: settings.enabledDictionaries.contains(importedId),
                canDisable: true,
                tagColor: assignedColor
            )
            
            if !availableDictionaries.contains(dictionaryInfo) {
                availableDictionaries.append(dictionaryInfo)
                
                // Add new dictionary to end of order list if not already there
                if !settings.dictionaryOrder.contains(importedId) {
                    var updatedSettings = settings
                    updatedSettings.dictionaryOrder.append(importedId)
                    settings = updatedSettings
                    saveSettings()
                }
            }
        }
        
        // Re-sort dictionaries after loading imported ones
        sortDictionariesByOrder()
    }
    
    func deleteImportedDictionary(_ info: ImportedDictionaryInfo) {
        Task {
            do {
                try await DictionaryImportManager.shared.deleteImportedDictionary(info)
                
                DispatchQueue.main.async { [weak self] in
                    self?.removeFromAvailableDictionaries(id: "imported_\(info.id.uuidString)")
                    self?.settings.enabledDictionaries.removeAll(where: { $0 == "imported_\(info.id.uuidString)" })
                    self?.saveSettings()
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.alertTitle = "Delete Error"
                    self?.alertMessage = "Failed to delete dictionary: \(error.localizedDescription)"
                    self?.showAlert = true
                }
            }
        }
    }
    
    private func removeFromAvailableDictionaries(id: String) {
        availableDictionaries.removeAll { $0.id == id }
    }
    
    // MARK: - Testing Helper
    
    func resetMigrationForTesting() {
        userDefaults.removeObject(forKey: migrationKey)
        print("📚 [SETTINGS] Migration flag reset for testing")
    }
}

// Model for dictionary information
struct DictionaryInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let isBuiltIn: Bool
    var isEnabled: Bool
    var canDisable: Bool
    var tagColor: DictionaryTagColor
    
    static func == (lhs: DictionaryInfo, rhs: DictionaryInfo) -> Bool {
        return lhs.id == rhs.id
    }
}

// Available colors for dictionary tags
enum DictionaryTagColor: String, CaseIterable, Codable {
    case blue = "blue"
    case orange = "orange"
    case green = "green"
    case red = "red"
    case purple = "purple"
    case yellow = "yellow"
    case pink = "pink"
    case gray = "gray"
    
    var displayName: String {
        switch self {
        case .blue: return "Blue"
        case .orange: return "Orange"
        case .green: return "Green"
        case .red: return "Red"
        case .purple: return "Purple"
        case .yellow: return "Yellow"
        case .pink: return "Pink"
        case .gray: return "Gray"
        }
    }
    
    var swiftUIColor: Color {
        switch self {
        case .blue: return .blue
        case .orange: return .orange
        case .green: return .green
        case .red: return .red
        case .purple: return .purple
        case .yellow: return .yellow
        case .pink: return .pink
        case .gray: return .gray
        }
    }
}

// Settings structure for dictionaries
struct DictionarySettings: Equatable, Codable {
    var enabledDictionaries: [String]
    var dictionaryOrder: [String]
    var dictionaryColors: [String: DictionaryTagColor]
    
    static func == (lhs: DictionarySettings, rhs: DictionarySettings) -> Bool {
        return lhs.enabledDictionaries == rhs.enabledDictionaries && 
               lhs.dictionaryOrder == rhs.dictionaryOrder &&
               lhs.dictionaryColors == rhs.dictionaryColors
    }
    
    init(enabledDictionaries: [String] = ["jmdict", "obunsha", "bccwj"], 
         dictionaryOrder: [String] = [],
         dictionaryColors: [String: DictionaryTagColor] = [:]) {
        self.enabledDictionaries = enabledDictionaries
        self.dictionaryOrder = dictionaryOrder
        // Set default colors if not provided
        if dictionaryColors.isEmpty {
            self.dictionaryColors = [
                "jmdict": .blue,
                "obunsha": .orange,
                "bccwj": .green
            ]
        } else {
            self.dictionaryColors = dictionaryColors
        }
    }
}
