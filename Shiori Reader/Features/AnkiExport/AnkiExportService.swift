import Foundation
import UIKit
import SwiftUI

class AnkiExportService {
    // Singleton instance
    static let shared = AnkiExportService()
    private let japaneseAnalyzer = JapaneseTextAnalyzer.shared
    private let settingsRepository = SettingsRepository()
    
    // State management for fetchAnkiInfo
    private var isFetchingAnkiInfo = false
    private var currentTimeoutWorkItem: DispatchWorkItem?
    
    private init() {}
    
    // MARK: - Dictionary Ordering Helper
    
    /// Sort dictionary sources based on user-defined order from Dictionary Settings
    private func sortSourcesByUserOrder(_ sources: [String]) -> [String] {
        let userOrder = DictionaryColorProvider.shared.getOrderedDictionarySources()
        
        return sources.sorted { first, second in
            let firstIndex = userOrder.firstIndex(of: first) ?? Int.max
            let secondIndex = userOrder.firstIndex(of: second) ?? Int.max
            
            if firstIndex == secondIndex {
                // If both are not in user order (or same position), sort alphabetically
                return first < second
            }
            
            return firstIndex < secondIndex
        }
    }
    
    // Check if AnkiMobile is installed
    func isAnkiInstalled() -> Bool {
        let ankiURL = URL(string: "anki://")!
        return UIApplication.shared.canOpenURL(ankiURL)
    }
    
    func isConfigured() -> Bool {
        // Get settings from repository instead of UserDefaults
        let settings = settingsRepository.getAnkiSettings()
        return !settings.noteType.isEmpty && !settings.deckName.isEmpty
    }
    
    // MARK: - Public Export Methods
    
    /// Export word to Anki with automatic definition selection logic
    /// - If popup setting is enabled, shows selection popup
    /// - If popup setting is disabled, exports all definitions directly
    func exportWordToAnki(word: String, reading: String, entries: [DictionaryEntry], sentence: String = "",
                         pitchAccents: PitchAccentData? = nil, sourceView: UIViewController? = nil, 
                         onSaveToVocab: (() -> Void)? = nil, completion: ((Bool) -> Void)? = nil) {
        
        // Check if Anki is configured
        if !isConfigured() {
            showAnkiSetupAlert(sourceView: sourceView)
            completion?(false)
            return
        }
        
        // Get the current settings
        let settings = settingsRepository.getAnkiSettings()
        
        // Group definitions by dictionary source
        let definitionsBySource = getDefinitionsBySource(from: entries)
        
        // If no definitions found, fail
        if definitionsBySource.isEmpty {
            completion?(false)
            return
        }
        
        // Check if popup should be shown based on user preference
        let shouldShowPopup: Bool
        if UserDefaults.standard.object(forKey: "showDefinitionSelectionPopup") == nil {
            shouldShowPopup = true // Default to enabled
        } else {
            shouldShowPopup = UserDefaults.standard.bool(forKey: "showDefinitionSelectionPopup")
        }
        
        if shouldShowPopup {
            // Show selection popup
            showDefinitionSelectionPopup(
                word: word,
                reading: reading,
                definitionsBySource: definitionsBySource,
                sentence: sentence,
                pitchAccents: pitchAccents,
                sourceView: sourceView,
                onSaveToVocab: onSaveToVocab,
                completion: completion
            )
        } else {
            // Export all definitions directly without popup
            exportAllDefinitionsDirectly(
                word: word,
                reading: reading,
                definitionsBySource: definitionsBySource,
                sentence: sentence,
                pitchAccents: pitchAccents,
                sourceView: sourceView,
                onSaveToVocab: onSaveToVocab,
                completion: completion
            )
        }
    }
    
    // Create a full vocabulary card in Anki using repository data
    func addVocabularyCard(word: String, reading: String, definition: String, sentence: String,
                         pitchAccents: PitchAccentData? = nil, sourceView: UIViewController? = nil, 
                         sourceBook: String = "Anki Export", onSaveToVocab: (() -> Void)? = nil, completion: ((Bool) -> Void)? = nil) {
        // Check if Anki is configured
        if !isConfigured() {
            showAnkiSetupAlert(sourceView: sourceView)
            completion?(false)
            return
        }
        
        // Get Anki settings from repository
        let settings = settingsRepository.getAnkiSettings()
        
        // Create URL asynchronously on main actor
        Task { @MainActor in
            guard let url = await createAnkiExportURL(
                word: word,
                reading: reading,
                definition: definition,
                sentence: sentence,
                pitchAccents: pitchAccents,
                settings: settings
            ) else {
                completion?(false)
                return
            }
            
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { success in
                    if success {
                        // Check if auto-save to vocab list is enabled
                        let autoSaveEnabled = UserDefaults.standard.bool(forKey: "autoSaveToVocabOnAnkiExport")
                        
                        if autoSaveEnabled, let saveCallback = onSaveToVocab {
                            // Use the callback to trigger the same save action as the bookmark button
                            saveCallback()
                        }
                    }
                    completion?(success)
                }
            } else {
                Logger.debug(category: "AnkiExport", "Cannot open Anki URL: \(url)")
                completion?(false)
            }
        }
    }
    
    // Get all field mappings including additional fields
    private func getAllFieldMappings() -> [String: [String]] {
        // Primary fields
        let fieldMappings: [String: [String]] = [
            "word": [UserDefaults.standard.string(forKey: "ankiWordField") ?? "Word"],
            "reading": [UserDefaults.standard.string(forKey: "ankiReadingField") ?? "Reading"],
            "definition": [UserDefaults.standard.string(forKey: "ankiDefinitionField") ?? "Definition"],
            "sentence": [UserDefaults.standard.string(forKey: "ankiSentenceField") ?? "Sentence"],
            "wordWithReading": [UserDefaults.standard.string(forKey: "ankiWordWithReadingField") ?? "Word with Reading"]
        ]
        
        // Get secondary fields
        var result = fieldMappings
        
        if let data = UserDefaults.standard.data(forKey: "ankiAdditionalFields"),
           let additionalFields = try? JSONDecoder().decode([AdditionalField].self, from: data) {
            
            // Group additional fields by type
            for field in additionalFields {
                result[field.type, default: []].append(field.fieldName)
            }
        }
        
        return result
    }
    
    // Create the URL for AnkiMobile with all field mappings
    @MainActor
    private func createAnkiExportURL(word: String, reading: String, definition: String,
                                   sentence: String, pitchAccents: PitchAccentData? = nil, settings: AnkiSettings) async -> URL? {
        var components = URLComponents(string: "anki://x-callback-url/addnote")
        
        let wordWithReading = japaneseAnalyzer.formatWordWithReading(word: word, reading: reading)
        
        // Generate pitch accent HTML if available
        let pitchAccentHTML = generatePitchAccentHTML(word: word, reading: reading, pitchAccents: pitchAccents, settings: settings)
        
        // Create base query items
        var queryItems = [
            URLQueryItem(name: "type", value: settings.noteType),
            URLQueryItem(name: "deck", value: settings.deckName),
            URLQueryItem(name: "tags", value: settings.tags)
        ]
        
        // Map of content types to their values
        let contentMap = [
            "word": word,
            "reading": reading,
            "definition": definition,
            "sentence": sentence,
            "wordWithReading": wordWithReading,
            "pitchAccent": pitchAccentHTML ?? ""
        ]
        
        // Dictionary to collect all field values, allowing concatenation for duplicate field names
        var fieldValues: [String: [String]] = [:]
        
        // Helper function to add field value to the collection
        func addFieldValue(fieldName: String, value: String) {
            guard !fieldName.isEmpty && !value.isEmpty else { return }
            fieldValues[fieldName, default: []].append(value)
        }
        
        // Add primary fields
        addFieldValue(fieldName: settings.wordField, value: word)
        addFieldValue(fieldName: settings.readingField, value: reading)
        addFieldValue(fieldName: settings.definitionField, value: definition)
        addFieldValue(fieldName: settings.sentenceField, value: sentence)
        addFieldValue(fieldName: settings.wordWithReadingField, value: wordWithReading)
        if let pitchHTML = pitchAccentHTML {
            addFieldValue(fieldName: settings.pitchAccentField, value: pitchHTML)
        }
        
        // Add additional fields
        for additionalField in settings.additionalFields {
            if let content = contentMap[additionalField.type] {
                addFieldValue(fieldName: additionalField.fieldName, value: content)
            }
        }
        
        // Convert the collected field values to URLQueryItems, concatenating duplicate fields with HTML line breaks
        for (fieldName, values) in fieldValues {
            let concatenatedValue = values.joined(separator: "<br>")
            queryItems.append(URLQueryItem(name: "fld\(fieldName)", value: concatenatedValue))
        }
        
        // Add x-success callback to return to Shiori after adding
        let appURLScheme = "shiori://"
        queryItems.append(URLQueryItem(name: "x-success", value: appURLScheme))
        
        components?.queryItems = queryItems
        return components?.url
    }
    
    // Generate HTML for pitch accent graphs
    @MainActor
    private func generatePitchAccentHTML(word: String, reading: String, pitchAccents: PitchAccentData?, settings: AnkiSettings) -> String? {
        guard let pitchAccents = pitchAccents, !pitchAccents.isEmpty else {
            return nil
        }
        
        // Filter to only show graphs that match both term AND reading
        let matchingAccents = pitchAccents.accents.filter { accent in
            accent.term == word && accent.reading == reading
        }
        
        guard !matchingAccents.isEmpty else {
            return nil
        }
        
        var htmlParts: [String] = []
        
        // Generate images for each pitch accent pattern
        for accent in matchingAccents.prefix(3) { // Limit to 3 patterns to avoid URL length issues
            if let image = ViewImageRenderer.renderPitchAccentGraph(
                word: accent.term,
                reading: accent.reading,
                pitchValue: accent.pitchAccent,
                graphColor: settings.pitchAccentGraphColor,
                textColor: settings.pitchAccentTextColor
            ) {
                // Create HTML with just the image (no badge)
                if let imageHTML = ViewImageRenderer.imageToHTMLTag(
                    image: image,
                    format: .png,
                    altText: "Pitch accent pattern \(accent.pitchAccent)"
                ) {
                    htmlParts.append(imageHTML) // No div wrapper, just the image
                }
            }
        }
        
        if htmlParts.isEmpty {
            return nil
        }
        
        // Wrap in a centered horizontal container div
        return "<div style='display: flex; align-items: center; justify-content: center; gap: 3px; line-height: 1; margin: 0; padding: 0;'>\(htmlParts.joined())</div>"
    }
    
    // MARK: - Helper Methods
    
    /// Group dictionary entries by source and extract their definitions
    private func getDefinitionsBySource(from entries: [DictionaryEntry]) -> [String: [String]] {
        var definitionsBySource: [String: [String]] = [:]
        
        for entry in entries {
            if definitionsBySource[entry.source] == nil {
                definitionsBySource[entry.source] = []
            }
            
            definitionsBySource[entry.source]?.append(contentsOf: entry.meanings)
        }
        
        return definitionsBySource
    }
    
    /// Get display name for dictionary source
    private func getDictionaryDisplayName(for source: String) -> String {
        if source == "jmdict" {
            return "JMdict"
        } else if source == "obunsha" {
            return "旺文社"
        } else if source.hasPrefix("imported_") {
            // Extract UUID from source string (format: "imported_UUID")
            let importedId = source.replacingOccurrences(of: "imported_", with: "")
            if let uuid = UUID(uuidString: importedId) {
                let importedDictionaries = DictionaryImportManager.shared.getImportedDictionaries()
                if let dict = importedDictionaries.first(where: { $0.id == uuid }) {
                    return dict.title
                }
            }
            return "Imported"
        } else {
            return source // fallback to original source name
        }
    }
    
    /// Export all definitions from all sources directly without showing popup
    private func exportAllDefinitionsDirectly(
        word: String,
        reading: String,
        definitionsBySource: [String: [String]],
        sentence: String,
        pitchAccents: PitchAccentData?,
        sourceView: UIViewController?,
        onSaveToVocab: (() -> Void)?,
        completion: ((Bool) -> Void)?
    ) {
        // Sort based on user-defined dictionary order
        let sortedSources = sortSourcesByUserOrder(Array(definitionsBySource.keys))
        
        let formattedDefinitions = sortedSources.compactMap { source -> String? in
            guard let definitions = definitionsBySource[source], !definitions.isEmpty else { return nil }
            let sourceLabel = self.getDictionaryDisplayName(for: source)
            let combinedDefs = definitions.joined(separator: "<br>")
            return "<b>\(sourceLabel):</b><br>\(combinedDefs)"
        }.joined(separator: "<br><br>")
        
        // Export with all definitions
        addVocabularyCard(
            word: word,
            reading: reading,
            definition: formattedDefinitions,
            sentence: sentence,
            pitchAccents: pitchAccents,
            sourceView: sourceView,
            sourceBook: "Dictionary Search",
            onSaveToVocab: onSaveToVocab,
            completion: completion
        )
    }
    
    /// Show the definition selection popup
    private func showDefinitionSelectionPopup(
        word: String,
        reading: String,
        definitionsBySource: [String: [String]],
        sentence: String,
        pitchAccents: PitchAccentData?,
        sourceView: UIViewController?,
        onSaveToVocab: (() -> Void)?,
        completion: ((Bool) -> Void)?
    ) {
        guard let sourceViewController = sourceView else {
            completion?(false)
            return
        }
        
        // Convert to the format expected by the popup and sort by user-defined order
        let sortedSources = sortSourcesByUserOrder(Array(definitionsBySource.keys))
        let availableDefinitions = sortedSources.compactMap { source -> DictionarySourceDefinition? in
            guard let definitions = definitionsBySource[source], !definitions.isEmpty else { return nil }
            return DictionarySourceDefinition(source: source, definitions: definitions)
        }
        
        let popupView = DefinitionSelectionPopupView(
            word: word,
            reading: reading,
            availableDefinitions: availableDefinitions,
            onDefinitionsSelected: { selectedDefinitions in
                // Combine selected definitions with source labels for clarity
                // Sort based on user-defined dictionary order
                let sortedSources = self.sortSourcesByUserOrder(Array(selectedDefinitions.keys))
                
                let formattedDefinitions = sortedSources.compactMap { source -> String? in
                    guard let definitions = selectedDefinitions[source], !definitions.isEmpty else { return nil }
                    let sourceLabel = self.getDictionaryDisplayName(for: source)
                    let combinedDefs = definitions.joined(separator: "<br>")
                    return "<b>\(sourceLabel):</b><br>\(combinedDefs)"
                }.joined(separator: "<br><br>")
                
                // Dismiss the popup
                sourceViewController.dismiss(animated: true) {
                    // Export with selected definitions
                    self.addVocabularyCard(
                        word: word,
                        reading: reading,
                        definition: formattedDefinitions,
                        sentence: sentence,
                        pitchAccents: pitchAccents,
                        sourceView: sourceView,
                        sourceBook: "Dictionary Popup",
                        onSaveToVocab: onSaveToVocab,
                        completion: completion
                    )
                }
            },
            onCancel: {
                sourceViewController.dismiss(animated: true)
                completion?(false)
            }
        )
        
        let hostingController = UIHostingController(rootView: popupView)
        hostingController.modalPresentationStyle = .overFullScreen
        hostingController.modalTransitionStyle = .crossDissolve
        hostingController.view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        
        sourceViewController.present(hostingController, animated: true)
    }
    
    /// Show Anki setup alert
    private func showAnkiSetupAlert(sourceView: UIViewController?) {
        guard let sourceViewController = sourceView else { return }
        
        let alert = UIAlertController(
            title: "Anki Setup Required",
            message: "You need to configure Anki integration before adding cards. Would you like to do that now?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Configure", style: .default) { _ in
            // Present the Anki settings view
            let settingsView = UIHostingController(rootView:
                NavigationView {
                    AnkiSettingsView()
                }
            )
            sourceViewController.present(settingsView, animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        sourceViewController.present(alert, animated: true)
    }
    
    // Test connection to AnkiMobile
    func testAnkiConnection(completion: @escaping (Bool) -> Void) {
        let testURL = URL(string: "anki://")!
        
        // Check if we're running in the simulator
        let isSimulator = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
        
        if isSimulator {
            // For simulator testing, provide a mock result
            // You can toggle this to test both success and failure paths
            let mockSuccess = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion(mockSuccess)
            }
            return
        }
        
        // For real device testing
        if UIApplication.shared.canOpenURL(testURL) {
            UIApplication.shared.open(testURL, options: [:]) { success in
                completion(success)
            }
        } else {
            Logger.debug(category: "AnkiExport", "URL scheme 'anki://' is not supported on this device")
            completion(false)
        }
    }
    
    // Get deck and note type information from AnkiMobile
    func fetchAnkiInfo(completion: @escaping (Bool, [String: Any]?) -> Void) {
        // Prevent multiple concurrent calls
        guard !isFetchingAnkiInfo else {
            Logger.debug(category: "AnkiExport", "Already fetching Anki info, ignoring subsequent call")
            completion(false, nil)
            return
        }
        
        let infoURL = URL(string: "anki://x-callback-url/infoForAdding?x-success=shiori://anki-info")!
        
        // Check if URL can be opened
        guard UIApplication.shared.canOpenURL(infoURL) else {
            Logger.debug(category: "AnkiExport", "Cannot open Anki info URL")
            completion(false, nil)
            return
        }
        
        // Set fetching state
        isFetchingAnkiInfo = true
        
        // Cancel any existing timeout
        currentTimeoutWorkItem?.cancel()
        
        // Remove any existing observers to prevent duplicates
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        
        // Create a timeout mechanism
        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            Logger.debug(category: "AnkiExport", "Timeout reached, checking clipboard one last time")
            
            // Check clipboard one last time
            let pasteboard = UIPasteboard.general
            if let data = pasteboard.data(forPasteboardType: "net.ankimobile.json"), !data.isEmpty {
                self.processAnkiData(data, completion: completion)
            } else {
                Logger.debug(category: "AnkiExport", "No valid Anki data found after timeout")
                self.cleanupFetch()
                completion(false, nil)
            }
        }
        
        // Store the current timeout work item
        currentTimeoutWorkItem = timeoutWorkItem
        
        // Register for becoming active notification
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            
            Logger.debug(category: "AnkiExport", "App became active, checking for Anki data")
            
            // Cancel the timeout since we're back
            self.currentTimeoutWorkItem?.cancel()
            
            // Small delay to ensure clipboard is populated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Check for clipboard data when app becomes active
                let pasteboard = UIPasteboard.general
                if let data = pasteboard.data(forPasteboardType: "net.ankimobile.json"), !data.isEmpty {
                    Logger.debug(category: "AnkiExport", "Found Anki data in clipboard (\(data.count) bytes)")
                    // Process the data
                    self.processAnkiData(data, completion: completion)
                } else {
                    Logger.debug(category: "AnkiExport", "No valid Anki data found in clipboard")
                    self.cleanupFetch()
                    completion(false, nil)
                }
            }
        }
        
        // Schedule timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeoutWorkItem)
        
        // Open AnkiMobile
        UIApplication.shared.open(infoURL, options: [:]) { [weak self] success in
            if !success {
                Logger.debug(category: "AnkiExport", "Failed to open Anki URL")
                self?.currentTimeoutWorkItem?.cancel()
                self?.cleanupFetch()
                completion(false, nil)
            }
        }
    }
    
    // Clean up fetch state and observers
    private func cleanupFetch() {
        isFetchingAnkiInfo = false
        currentTimeoutWorkItem?.cancel()
        currentTimeoutWorkItem = nil
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    // Helper method to process Anki data and update settings in Core Data
    private func processAnkiData(_ data: Data, completion: @escaping (Bool, [String: Any]?) -> Void) {
        // Clean up fetch state first
        cleanupFetch()
        
        // Clear clipboard after reading by completely removing the item
        if UIPasteboard.general.contains(pasteboardTypes: ["net.ankimobile.json"]) {
            // Create a new pasteboard item without the Anki data
            let items = UIPasteboard.general.items.compactMap { item -> [String: Any]? in
                var newItem = item
                newItem.removeValue(forKey: "net.ankimobile.json")
                return newItem.isEmpty ? nil : newItem
            }
            UIPasteboard.general.items = items
        }
        
        do {
            // Parse the JSON data
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                Logger.debug(category: "AnkiExport", "Successfully parsed JSON with keys: \(json.keys.joined(separator: ", "))")
                
                // Process the decks data (convert from array of dictionaries to array of strings)
                var processedData: [String: Any] = [:]
                
                if let decksArray = json["decks"] as? [[String: String]] {
                    let deckNames = decksArray.compactMap { $0["name"] }
                    processedData["decks"] = deckNames
                    
                    // Cache the decks data
                    var settings = settingsRepository.getAnkiSettings()
                    settings.cachedDecks = deckNames
                    
                    // Store first deck as default if we don't already have one set
                    if settings.deckName.isEmpty && !deckNames.isEmpty {
                        settings.deckName = deckNames.first ?? "Default"
                    }
                    
                    settingsRepository.updateAnkiSettings(settings)
                }
                
                // Process the notetypes data (convert from array of dictionaries to dictionary of arrays)
                if let notesArray = json["notetypes"] as? [[String: Any]] {
                    var noteTypesDict: [String: [String]] = [:]
                    
                    for noteType in notesArray {
                        if let name = noteType["name"] as? String,
                           let fields = noteType["fields"] as? [[String: String]] {
                            let fieldNames = fields.compactMap { $0["name"] }
                            noteTypesDict[name] = fieldNames
                        }
                    }
                    
                    processedData["noteTypes"] = noteTypesDict
                    
                    // Cache the note types data
                    var settings = settingsRepository.getAnkiSettings()
                    settings.cachedNoteTypes = noteTypesDict
                    
                    // Store first note type as default if we don't already have one set
                    if settings.noteType.isEmpty && !noteTypesDict.isEmpty {
                        let firstNoteTypeName = noteTypesDict.keys.sorted().first ?? "Basic"
                        settings.noteType = firstNoteTypeName
                        
                        // Also set default field mappings if available
                        if let fields = noteTypesDict[firstNoteTypeName], !fields.isEmpty {
                            // Try to find appropriate field names
                            let wordField = fields.first(where: { $0.contains("Word") || $0.contains("Expression") }) ?? fields.first
                            let readingField = fields.first(where: { $0.contains("Reading") || $0.contains("Reading") }) ?? (fields.count > 1 ? fields[1] : nil)
                            let meaningField = fields.first(where: { $0.contains("Meaning") || $0.contains("Definition") }) ?? (fields.count > 2 ? fields[2] : nil)
                            let sentenceField = fields.first(where: { $0.contains("Sentence") || $0.contains("Example") }) ?? (fields.count > 3 ? fields[3] : nil)
                            
                            if let wordField = wordField {
                                settings.wordField = wordField
                            }
                            if let readingField = readingField {
                                settings.readingField = readingField
                            }
                            if let meaningField = meaningField {
                                settings.definitionField = meaningField
                            }
                            if let sentenceField = sentenceField {
                                settings.sentenceField = sentenceField
                            }
                        }
                    }
                    
                    settingsRepository.updateAnkiSettings(settings)
                }
                
                // Return the processed data
                completion(true, processedData)
            } else {
                Logger.debug(category: "AnkiExport", "JSON is not a dictionary")
                completion(false, nil)
            }
        } catch {
            Logger.debug(category: "AnkiExport", "JSON parsing error: \(error)")
            completion(false, nil)
        }
    }
}
