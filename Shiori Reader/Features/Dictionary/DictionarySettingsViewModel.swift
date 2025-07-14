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
                canDisable: true
            ),
            DictionaryInfo(
                id: "obunsha",
                name: "旺文社国語辞典 第十一版",
                description: "Japanese-Japanese monolingual dictionary",
                isBuiltIn: true,
                isEnabled: true,
                canDisable: true
            ),
            DictionaryInfo(
                id: "bccwj",
                name: "BCCWJ Frequency Data",
                description: "Word frequency rankings from Japanese corpus",
                isBuiltIn: true,
                isEnabled: true,
                canDisable: true
            )
        ]
        
        // Now load the saved settings after initializing properties
        loadSettings()
        
        // Load imported dictionaries
        loadImportedDictionaries()
        
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
            
            // Ensure at least one dictionary with definitions is always enabled (JMdict or Obunsha)
            let definitionDictionaries = ["jmdict", "obunsha"]
            let enabledDefinitionDictionaries = availableDictionaries.filter { 
                definitionDictionaries.contains($0.id) && $0.isEnabled 
            }
            
            if enabledDefinitionDictionaries.count <= 1 {
                // If this is the only enabled definition dictionary, it can't be disabled
                if definitionDictionaries.contains(availableDictionaries[index].id) && availableDictionaries[index].isEnabled {
                    availableDictionaries[index].canDisable = false
                } else {
                    availableDictionaries[index].canDisable = true
                }
            } else {
                // Multiple definition dictionaries enabled, all can be disabled
                availableDictionaries[index].canDisable = true
            }
            
            // BCCWJ can always be disabled since it's not a definition dictionary
            if availableDictionaries[index].id == "bccwj" {
                availableDictionaries[index].canDisable = true
            }
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
    
    func toggleDictionary(id: String, isEnabled: Bool) {
        // Find the dictionary in our list
        if let index = availableDictionaries.firstIndex(where: { $0.id == id }) {
            
            // Check if this would leave us with no definition dictionaries
            let definitionDictionaries = ["jmdict", "obunsha"]
            if !isEnabled && definitionDictionaries.contains(id) {
                let remainingDefinitionDictionaries = availableDictionaries.filter { 
                    definitionDictionaries.contains($0.id) && $0.isEnabled && $0.id != id
                }
                
                if remainingDefinitionDictionaries.isEmpty {
                    // Show alert - can't disable the last definition dictionary
                    alertTitle = "Cannot Disable Dictionary"
                    alertMessage = "At least one dictionary with definitions (JMdict or Obunsha) must remain enabled."
                    showAlert = true
                    return
                }
            }
            
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
    
    // MARK: - Imported Dictionary Management
    
    func loadImportedDictionaries() {
        let importedDictionaries = DictionaryImportManager.shared.getImportedDictionaries()
        
        for importedDict in importedDictionaries {
            let dictionaryInfo = DictionaryInfo(
                id: "imported_\(importedDict.id.uuidString)",
                name: importedDict.title,
                description: importedDict.detailText,
                isBuiltIn: false,
                isEnabled: settings.enabledDictionaries.contains("imported_\(importedDict.id.uuidString)"),
                canDisable: true
            )
            
            if !availableDictionaries.contains(dictionaryInfo) {
                availableDictionaries.append(dictionaryInfo)
            }
        }
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
    
    init(enabledDictionaries: [String] = ["jmdict", "obunsha", "bccwj"]) {
        self.enabledDictionaries = enabledDictionaries
    }
}
