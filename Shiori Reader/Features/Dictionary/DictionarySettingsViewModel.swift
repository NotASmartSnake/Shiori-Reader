//
//  DictionarySettingsViewModel.swift
//  Shiori Reader
//
//  Created by Claude on 4/16/25.
//

import Foundation
import Combine

class DictionarySettingsViewModel: ObservableObject {
    // Published properties for UI binding
    @Published var availableDictionaries: [DictionaryInfo] = []
    @Published var settings: DictionarySettings
    @Published var alertMessage = ""
    @Published var showAlert = false
    @Published var alertTitle = ""
    
    private let userDefaults = UserDefaults.standard
    private let dictionarySettingsKey = "dictionarySettings"
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Initialize with default settings first
        self.settings = DictionarySettings()
        
        // Initialize with the available dictionaries
        self.availableDictionaries = [
            DictionaryInfo(
                id: "jmdict",
                name: "JMdict (English)",
                description: "Japanese-English dictionary",
                isBuiltIn: true,
                isEnabled: true,
                canDisable: true
            ),
            DictionaryInfo(
                id: "obunsha",
                name: "旺文社国語辞典 第十一版",
                description: "Japanese monolingual dictionary",
                isBuiltIn: true,
                isEnabled: true,
                canDisable: true
            )
        ]
        
        // Now load the saved settings after initializing properties
        if let data = userDefaults.data(forKey: dictionarySettingsKey),
           let savedSettings = try? JSONDecoder().decode(DictionarySettings.self, from: data) {
            self.settings = savedSettings
            
            // Migration: Add obunsha to existing settings if it's not there
            if !savedSettings.enabledDictionaries.contains("obunsha") {
                print("📚 [SETTINGS] Migrating settings to include Obunsha dictionary")
                self.settings.enabledDictionaries.append("obunsha")
                saveSettings()
            }
        } else {
            // No saved settings, use defaults
            print("📚 [SETTINGS] No saved settings found, using defaults")
        }
        
        // Sync the dictionary enabled state with settings
        syncDictionaryStatesWithSettings()
        
        // Set up publishers to monitor changes
        setupObservers()
    }
    
    private func syncDictionaryStatesWithSettings() {
        for index in availableDictionaries.indices {
            let dictionaryId = availableDictionaries[index].id
            let isEnabled = settings.enabledDictionaries.contains(dictionaryId)
            availableDictionaries[index].isEnabled = isEnabled
            
            // Ensure at least one dictionary can't be disabled if it's the only one enabled
            let enabledCount = availableDictionaries.filter { $0.isEnabled }.count
            if enabledCount <= 1 {
                // If this is the only enabled dictionary, it can't be disabled
                if availableDictionaries[index].isEnabled {
                    availableDictionaries[index].canDisable = false
                }
            } else {
                availableDictionaries[index].canDisable = true
            }
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
}

// Model for dictionary information
struct DictionaryInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let isBuiltIn: Bool
    var isEnabled: Bool
    var canDisable: Bool
    
    static func == (lhs: DictionaryInfo, rhs: DictionaryInfo) -> Bool {
        return lhs.id == rhs.id
    }
}

// Settings structure for dictionaries
struct DictionarySettings: Equatable, Codable {
    var enabledDictionaries: [String]
    
    static func == (lhs: DictionarySettings, rhs: DictionarySettings) -> Bool {
        return lhs.enabledDictionaries == rhs.enabledDictionaries
    }
    
    init(enabledDictionaries: [String] = ["jmdict", "obunsha"]) {
        self.enabledDictionaries = enabledDictionaries
    }
}
