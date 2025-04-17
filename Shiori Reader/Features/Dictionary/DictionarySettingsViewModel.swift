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
        
        // Initialize with the only dictionary we support for now (JMdict)
        self.availableDictionaries = [
            DictionaryInfo(
                id: "jmdict",
                name: "JMdict (English)",
                description: "Japanese-English dictionary",
                isBuiltIn: true,
                isEnabled: true,
                canDisable: false
            )
        ]
        
        // Now load the saved settings after initializing properties
        if let data = userDefaults.data(forKey: dictionarySettingsKey),
           let savedSettings = try? JSONDecoder().decode(DictionarySettings.self, from: data) {
            self.settings = savedSettings
        }
        
        // Set up publishers to monitor changes
        setupObservers()
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
    let canDisable: Bool
    
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
    
    init(enabledDictionaries: [String] = ["jmdict"]) {
        self.enabledDictionaries = enabledDictionaries
    }
}
