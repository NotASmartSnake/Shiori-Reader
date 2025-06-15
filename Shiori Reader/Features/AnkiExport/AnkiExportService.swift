import Foundation
import UIKit
import SwiftUI

class AnkiExportService {
    // Singleton instance
    static let shared = AnkiExportService()
    private let japaneseAnalyzer = JapaneseTextAnalyzer.shared
    private let settingsRepository = SettingsRepository()
    
    private init() {}
    
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
    
    // Create a full vocabulary card in Anki using repository data
    func addVocabularyCard(word: String, reading: String, definition: String, sentence: String,
                         pitchAccents: PitchAccentData? = nil, sourceView: UIViewController? = nil, completion: ((Bool) -> Void)? = nil) {
        // Check if Anki is configured
        if !isConfigured() {
            // Show setup UI if needed
            if let sourceViewController = sourceView {
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
        
        // Add primary fields
        if !settings.wordField.isEmpty {
            queryItems.append(URLQueryItem(name: "fld\(settings.wordField)", value: word))
        }
        if !settings.readingField.isEmpty {
            queryItems.append(URLQueryItem(name: "fld\(settings.readingField)", value: reading))
        }
        if !settings.definitionField.isEmpty {
            queryItems.append(URLQueryItem(name: "fld\(settings.definitionField)", value: definition))
        }
        if !settings.sentenceField.isEmpty {
            queryItems.append(URLQueryItem(name: "fld\(settings.sentenceField)", value: sentence))
        }
        if !settings.wordWithReadingField.isEmpty {
            queryItems.append(URLQueryItem(name: "fld\(settings.wordWithReadingField)", value: wordWithReading))
        }
        if !settings.pitchAccentField.isEmpty && pitchAccentHTML != nil {
            queryItems.append(URLQueryItem(name: "fld\(settings.pitchAccentField)", value: pitchAccentHTML))
        }
        
        // Add additional fields
        for additionalField in settings.additionalFields {
            if let content = contentMap[additionalField.type], !additionalField.fieldName.isEmpty {
                queryItems.append(URLQueryItem(name: "fld\(additionalField.fieldName)", value: content))
            }
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
        let infoURL = URL(string: "anki://x-callback-url/infoForAdding?x-success=shiori://anki-info")!
        
        // Check if URL can be opened
        if UIApplication.shared.canOpenURL(infoURL) {
            
            // Create a timeout mechanism
            let timeoutWorkItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                
                // Check clipboard one last time
                let pasteboard = UIPasteboard.general
                if let data = pasteboard.data(forPasteboardType: "net.ankimobile.json") {
                    self.processAnkiData(data, completion: completion)
                } else {
                    Logger.debug(category: "AnkiExport", "No Anki data found after timeout")
                    completion(false, nil)
                }
                
                // Remove observer
                NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
            }
            
            // Register for becoming active notification
            NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self = self else { return }
                
                timeoutWorkItem.cancel()  // Cancel the timeout since we're back
                
                // Check for clipboard data when app becomes active
                let pasteboard = UIPasteboard.general
                if let data = pasteboard.data(forPasteboardType: "net.ankimobile.json") {
                    // Process the data
                    self.processAnkiData(data, completion: completion)
                } else {
                    completion(false, nil)
                }
                
                // Remove observer
                NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
            }
            
            // Schedule timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeoutWorkItem)
            
            // Open AnkiMobile
            UIApplication.shared.open(infoURL, options: [:]) { success in
                if !success {
                    timeoutWorkItem.cancel()
                    completion(false, nil)
                }
            }
        } else {
            Logger.debug(category: "AnkiExport", "Cannot open Anki info URL")
            completion(false, nil)
        }
    }
    
    // Helper method to process Anki data and update settings in Core Data
    private func processAnkiData(_ data: Data, completion: @escaping (Bool, [String: Any]?) -> Void) {
        // Clear clipboard after reading
        UIPasteboard.general.setData(Data(), forPasteboardType: "net.ankimobile.json")
        
        do {
            // Parse the JSON data
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                // Process the decks data (convert from array of dictionaries to array of strings)
                var processedData: [String: Any] = [:]
                
                if let decksArray = json["decks"] as? [[String: String]] {
                    let deckNames = decksArray.compactMap { $0["name"] }
                    processedData["decks"] = deckNames
                    
                    // Store first deck as default if we don't already have one set
                    let settings = settingsRepository.getAnkiSettings()
                    if settings.deckName.isEmpty && !deckNames.isEmpty {
                        var updatedSettings = settings
                        updatedSettings.deckName = deckNames.first ?? "Default"
                        settingsRepository.updateAnkiSettings(updatedSettings)
                    }
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
                    
                    // Store first note type as default if we don't already have one set
                    let settings = settingsRepository.getAnkiSettings()
                    if settings.noteType.isEmpty && !noteTypesDict.isEmpty {
                        var updatedSettings = settings
                        let firstNoteTypeName = noteTypesDict.keys.sorted().first ?? "Basic"
                        updatedSettings.noteType = firstNoteTypeName
                        
                        // Also set default field mappings if available
                        if let fields = noteTypesDict[firstNoteTypeName], !fields.isEmpty {
                            // Try to find appropriate field names
                            let wordField = fields.first(where: { $0.contains("Word") || $0.contains("Expression") }) ?? fields.first
                            let readingField = fields.first(where: { $0.contains("Reading") || $0.contains("Reading") }) ?? (fields.count > 1 ? fields[1] : nil)
                            let meaningField = fields.first(where: { $0.contains("Meaning") || $0.contains("Definition") }) ?? (fields.count > 2 ? fields[2] : nil)
                            let sentenceField = fields.first(where: { $0.contains("Sentence") || $0.contains("Example") }) ?? (fields.count > 3 ? fields[3] : nil)
                            
                            if let wordField = wordField {
                                updatedSettings.wordField = wordField
                            }
                            if let readingField = readingField {
                                updatedSettings.readingField = readingField
                            }
                            if let meaningField = meaningField {
                                updatedSettings.definitionField = meaningField
                            }
                            if let sentenceField = sentenceField {
                                updatedSettings.sentenceField = sentenceField
                            }
                        }
                        
                        settingsRepository.updateAnkiSettings(updatedSettings)
                    }
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
