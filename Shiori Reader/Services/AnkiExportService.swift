//
//  AnkiExportService.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/21/25.
//


// AnkiExportService.swift
import Foundation
import UIKit
import SwiftUI

class AnkiExportService {
    // Singleton instance
    static let shared = AnkiExportService()
    
    private init() {}
    
    // Check if AnkiMobile is installed
    func isAnkiInstalled() -> Bool {
        let ankiURL = URL(string: "anki://")!
        return UIApplication.shared.canOpenURL(ankiURL)
    }
    
    func isConfigured() -> Bool {
        // Check if basic settings exist
        if UserDefaults.standard.string(forKey: "ankiNoteType") != nil &&
           UserDefaults.standard.string(forKey: "ankiDeckName") != nil {
            return true
        }
        return false
    }
    
    // Create a full vocabulary card in Anki
    func addVocabularyCard(word: String, reading: String, definition: String, sentence: String, sourceView: UIViewController? = nil, completion: ((Bool) -> Void)? = nil) {
        // Check if Anki is configured
        if !isConfigured() {
            // If we have a source view, show a setup prompt
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
        
        guard let url = createAnkiExportURL(word: word, reading: reading, definition: definition, sentence: sentence) else {
            completion?(false)
            return
        }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
                completion?(success)
            }
        } else {
            print("Cannot open Anki URL: \(url)")
            completion?(false)
        }
    }
    
    // Get user settings
    private func getUserSettings() -> (noteType: String, deckName: String, tags: String, fields: [String: String]) {
        let noteType = UserDefaults.standard.string(forKey: "ankiNoteType") ?? "Japanese"
        let deckName = UserDefaults.standard.string(forKey: "ankiDeckName") ?? "Shiori-Reader"
        let tags = UserDefaults.standard.string(forKey: "ankiTags") ?? "shiori-reader"
        
        // Get field names
        let fields = [
            "word": UserDefaults.standard.string(forKey: "ankiWordField") ?? "Word",
            "reading": UserDefaults.standard.string(forKey: "ankiReadingField") ?? "Reading",
            "definition": UserDefaults.standard.string(forKey: "ankiDefinitionField") ?? "Definition",
            "sentence": UserDefaults.standard.string(forKey: "ankiSentenceField") ?? "Sentence"
        ]
        
        return (noteType, deckName, tags, fields)
    }
    
    // Create the URL for AnkiMobile
    private func createAnkiExportURL(word: String, reading: String, definition: String, sentence: String) -> URL? {
        var components = URLComponents(string: "anki://x-callback-url/addnote")
        
        let settings = getUserSettings()
        
        // Create query items
        var queryItems = [
            URLQueryItem(name: "type", value: settings.noteType),
            URLQueryItem(name: "deck", value: settings.deckName),
            URLQueryItem(name: "fld\(settings.fields["word"]!)", value: word),
            URLQueryItem(name: "fld\(settings.fields["reading"]!)", value: reading),
            URLQueryItem(name: "fld\(settings.fields["definition"]!)", value: definition),
            URLQueryItem(name: "fld\(settings.fields["sentence"]!)", value: sentence),
            URLQueryItem(name: "tags", value: settings.tags)
        ]
        
        // Add x-success callback to return to Shiori after adding
        let appURLScheme = "shiori://"
        queryItems.append(URLQueryItem(name: "x-success", value: appURLScheme))
        
        components?.queryItems = queryItems
        
        return components?.url
    }
    
    // Test connection to AnkiMobile
    func testAnkiConnection(completion: @escaping (Bool) -> Void) {
        print("DEBUG: Testing Anki connection")
        let testURL = URL(string: "anki://")!
        
        // Check if we're running in the simulator
        let isSimulator = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
        print("DEBUG: Running in simulator: \(isSimulator)")
        
        if isSimulator {
            print("DEBUG: In simulator - AnkiMobile likely not installed")
            // For simulator testing, provide a mock result
            // You can toggle this to test both success and failure paths
            let mockSuccess = true
            
            print("DEBUG: Using mock success: \(mockSuccess)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion(mockSuccess)
            }
            return
        }
        
        // For real device testing
        print("DEBUG: Checking if URL '\(testURL)' can be opened")
        if UIApplication.shared.canOpenURL(testURL) {
            print("DEBUG: URL can be opened, attempting to open AnkiMobile")
            UIApplication.shared.open(testURL, options: [:]) { success in
                print("DEBUG: Open URL result: \(success)")
                completion(success)
            }
        } else {
            print("DEBUG: URL scheme 'anki://' is not supported on this device")
            completion(false)
        }
    }
    
    // Get deck and note type information from AnkiMobile
    func fetchAnkiInfo(completion: @escaping (Bool, [String: Any]?) -> Void) {
        print("DEBUG: Attempting to fetch Anki info")
        let infoURL = URL(string: "anki://x-callback-url/infoForAdding?x-success=shiori://anki-info")!
        
        // Check if URL can be opened
        if UIApplication.shared.canOpenURL(infoURL) {
            print("DEBUG: Can open Anki info URL")
            
            // Create a timeout mechanism
            let timeoutWorkItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                print("DEBUG: Timeout reached while waiting for Anki data")
                
                // Check clipboard one last time
                let pasteboard = UIPasteboard.general
                if let data = pasteboard.data(forPasteboardType: "net.ankimobile.json") {
                    self.processAnkiData(data, completion: completion)
                } else {
                    print("DEBUG: No Anki data found after timeout")
                    completion(false, nil)
                }
                
                // Remove observer
                NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
            }
            
            // Register for becoming active notification
            NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self = self else { return }
                
                print("DEBUG: App became active, checking clipboard")
                timeoutWorkItem.cancel()  // Cancel the timeout since we're back
                
                // Check for clipboard data when app becomes active
                let pasteboard = UIPasteboard.general
                if let data = pasteboard.data(forPasteboardType: "net.ankimobile.json") {
                    // Process the data
                    self.processAnkiData(data, completion: completion)
                } else {
                    print("DEBUG: No Anki data found in clipboard after return")
                    completion(false, nil)
                }
                
                // Remove observer
                NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
            }
            
            // Schedule timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeoutWorkItem)
            
            // Open AnkiMobile
            UIApplication.shared.open(infoURL, options: [:]) { success in
                print("DEBUG: Open URL result: \(success)")
                if !success {
                    timeoutWorkItem.cancel()
                    completion(false, nil)
                }
            }
        } else {
            print("DEBUG: Cannot open Anki info URL")
            completion(false, nil)
        }
    }
    
    // Helper method to process Anki data
    private func processAnkiData(_ data: Data, completion: @escaping (Bool, [String: Any]?) -> Void) {
        // Clear clipboard after reading
        UIPasteboard.general.setData(Data(), forPasteboardType: "net.ankimobile.json")
        
        do {
            // Parse the JSON data
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("DEBUG: Successfully parsed Anki JSON data")
                
                // Process the decks data (convert from array of dictionaries to array of strings)
                var processedData: [String: Any] = [:]
                
                if let decksArray = json["decks"] as? [[String: String]] {
                    let deckNames = decksArray.compactMap { $0["name"] }
                    processedData["decks"] = deckNames
                    print("DEBUG: Processed \(deckNames.count) decks")
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
                    print("DEBUG: Processed \(noteTypesDict.count) note types")
                }
                
                // Return the processed data
                completion(true, processedData)
            } else {
                print("DEBUG: JSON is not a dictionary")
                completion(false, nil)
            }
        } catch {
            print("DEBUG: JSON parsing error: \(error)")
            completion(false, nil)
        }
    }
}
