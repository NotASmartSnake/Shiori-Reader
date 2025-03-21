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
        
        // Escape special characters for URL parameters
        let escapedWord = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let escapedReading = reading.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let escapedDefinition = definition.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let escapedSentence = sentence.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Create query items
        var queryItems = [
            URLQueryItem(name: "type", value: settings.noteType),
            URLQueryItem(name: "deck", value: settings.deckName),
            URLQueryItem(name: "fld\(settings.fields["word"]!)", value: escapedWord),
            URLQueryItem(name: "fld\(settings.fields["reading"]!)", value: escapedReading),
            URLQueryItem(name: "fld\(settings.fields["definition"]!)", value: escapedDefinition),
            URLQueryItem(name: "fld\(settings.fields["sentence"]!)", value: escapedSentence),
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
        let testURL = URL(string: "anki://")!
        if UIApplication.shared.canOpenURL(testURL) {
            UIApplication.shared.open(testURL, options: [:]) { _ in
                completion(true)
            }
        } else {
            completion(false)
        }
    }
    
    // Get deck and note type information from AnkiMobile
    func fetchAnkiInfo(completion: @escaping (Bool, [String: Any]?) -> Void) {
        let infoURL = URL(string: "anki://x-callback-url/infoForAdding?x-success=shiori://anki-info")!
        
        if UIApplication.shared.canOpenURL(infoURL) {
            // Register for clipboard notification
            NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                // Check for clipboard data when app becomes active
                let pasteboard = UIPasteboard.general
                if let data = pasteboard.data(forPasteboardType: "net.ankimobile.json") {
                    // Clear clipboard
                    pasteboard.setData(Data(), forPasteboardType: "net.ankimobile.json")
                    
                    // Decode json data
                    if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        completion(true, json)
                    } else {
                        completion(false, nil)
                    }
                    
                    // Remove observer
                    NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
                } else {
                    completion(false, nil)
                }
            }
            
            UIApplication.shared.open(infoURL, options: [:], completionHandler: nil)
        } else {
            completion(false, nil)
        }
    }
}
