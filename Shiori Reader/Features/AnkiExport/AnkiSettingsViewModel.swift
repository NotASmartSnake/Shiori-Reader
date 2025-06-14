//
//  AnkiSettingsViewModel.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/9/25.
//


import Foundation
import Combine

class AnkiSettingsViewModel: ObservableObject {
    // Published properties for UI binding
    @Published var settings: AnkiSettings
    @Published var availableDecks: [String] = []
    @Published var availableNoteTypes: [String: [String]] = [:]
    @Published var selectedNoteTypeFields: [String] = []
    @Published var isLoading = false
    @Published var alertMessage = ""
    @Published var showAlert = false
    @Published var alertTitle = ""
    
    private let settingsRepository: SettingsRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(settingsRepository: SettingsRepository = SettingsRepository()) {
        self.settingsRepository = settingsRepository
        self.settings = settingsRepository.getAnkiSettings()
        
        // If we have a note type, load its fields
        if !settings.noteType.isEmpty, 
           let fields = availableNoteTypes[settings.noteType] {
            selectedNoteTypeFields = fields
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
    
    // MARK: - Public Methods
    
    func saveSettings() {
        settingsRepository.updateAnkiSettings(settings)
    }
    
    func fetchAnkiInfo() {
        isLoading = true
        
        AnkiExportService.shared.fetchAnkiInfo { [weak self] success, info in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success, let info = info {
                    // Process decks
                    if let decks = info["decks"] as? [String] {
                        self.availableDecks = decks
                    }
                    
                    // Process note types
                    if let noteTypes = info["noteTypes"] as? [String: [String]] {
                        self.availableNoteTypes = noteTypes
                        
                        // Update fields for the current note type
                        if let fields = noteTypes[self.settings.noteType] {
                            self.selectedNoteTypeFields = fields
                        }
                    }
                    
                    self.alertTitle = "Success"
                    self.alertMessage = "Successfully retrieved Anki information. You can now select deck and note type."
                    self.showAlert = true
                } else {
                    self.alertTitle = "Error"
                    self.alertMessage = "Failed to fetch information from AnkiMobile."
                    self.showAlert = true
                }
            }
        }
    }
    
    func testAnkiConnection() {
        AnkiExportService.shared.testAnkiConnection { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if success {
                    self.alertTitle = "Success"
                    self.alertMessage = "AnkiMobile is installed and can be opened."
                } else {
                    self.alertTitle = "Error"
                    self.alertMessage = "AnkiMobile is not installed or cannot be opened."
                }
                self.showAlert = true
            }
        }
    }
    
    func addEmptyField(type: String) {
        // Default to first available field if any
        let defaultField = selectedNoteTypeFields.first ?? "Field"
        let newField = AdditionalField(type: type, fieldName: defaultField)
        
        // Update settings with the new field
        var updatedSettings = settings
        updatedSettings.additionalFields.append(newField)
        settings = updatedSettings
        
        // Save updated settings
        saveSettings()
    }
    
    func removeField(at index: Int) {
        guard index >= 0 && index < settings.additionalFields.count else { return }
        
        var updatedSettings = settings
        updatedSettings.additionalFields.remove(at: index)
        settings = updatedSettings
        
        saveSettings()
    }
    
    func updateDeckName(_ newName: String) {
        var updatedSettings = settings
        updatedSettings.deckName = newName
        settings = updatedSettings
    }
    
    func updateNoteType(_ newType: String) {
        var updatedSettings = settings
        updatedSettings.noteType = newType
        settings = updatedSettings
        
        // Update available fields for this note type
        if let fields = availableNoteTypes[newType] {
            selectedNoteTypeFields = fields
        }
    }
    
    func updateFieldMapping(fieldType: String, fieldName: String) {
        var updatedSettings = settings
        
        switch fieldType {
        case "word":
            updatedSettings.wordField = fieldName
        case "reading":
            updatedSettings.readingField = fieldName
        case "definition":
            updatedSettings.definitionField = fieldName
        case "sentence":
            updatedSettings.sentenceField = fieldName
        case "wordWithReading":
            updatedSettings.wordWithReadingField = fieldName
        case "pitchAccent":
            updatedSettings.pitchAccentField = fieldName
        default:
            break
        }
        
        settings = updatedSettings
    }
    
    func updateAdditionalField(at index: Int, fieldName: String) {
        guard index >= 0 && index < settings.additionalFields.count else { return }
        
        var updatedSettings = settings
        updatedSettings.additionalFields[index].fieldName = fieldName
        settings = updatedSettings
    }
    
    // Helper to get display name for field type
    func getFieldTypeDisplayName(_ type: String) -> String {
        switch type {
        case "word": return "Word Field"
        case "reading": return "Reading Field"
        case "definition": return "Definition Field"
        case "sentence": return "Sentence Field"
        case "wordWithReading": return "Word with Reading Field"
        case "pitchAccent": return "Pitch Accent Field"
        default: return "Field"
        }
    }
}
