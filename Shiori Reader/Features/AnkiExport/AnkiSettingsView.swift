//
//  AnkiSettingsView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/21/25.
//

import SwiftUI

struct AnkiSettingsView: View {
    @AppStorage("ankiNoteType") private var noteType = "Japanese"
    @AppStorage("ankiDeckName") private var deckName = "Shiori-Reader"
    @AppStorage("ankiTags") private var tags = "shiori-reader"
    
    @State private var wordField = UserDefaults.standard.string(forKey: "ankiWordField") ?? "Word"
    @State private var readingField = UserDefaults.standard.string(forKey: "ankiReadingField") ?? "Reading"
    @State private var definitionField = UserDefaults.standard.string(forKey: "ankiDefinitionField") ?? "Definition"
    @State private var sentenceField = UserDefaults.standard.string(forKey: "ankiSentenceField") ?? "Sentence"
    
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        Form {
            Section(header: Text("AnkiMobile Integration")) {
                TextField("Note Type", text: $noteType)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                TextField("Deck Name", text: $deckName)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                TextField("Tags (space separated)", text: $tags)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button(action: {
                    fetchAnkiInfo()
                }) {
                    HStack {
                        Text("Get Decks & Note Types from Anki")
                        Spacer()
                        if isLoading {
                            ProgressView()
                        }
                    }
                }
                .disabled(isLoading)
            }
            
            Section(header: Text("Field Mapping"), footer:  Text("Make sure these field names match your Anki note type exactly")) {
                
                TextField("Word Field Name", text: $wordField)
                    .onChange(of: wordField) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "ankiWordField")
                    }
                
                TextField("Reading Field Name", text: $readingField)
                    .onChange(of: readingField) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "ankiReadingField")
                    }
                
                TextField("Definition Field Name", text: $definitionField)
                    .onChange(of: definitionField) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "ankiDefinitionField")
                    }
                
                TextField("Sentence Field Name", text: $sentenceField)
                    .onChange(of: sentenceField) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "ankiSentenceField")
                    }
            }
            
            Section(footer: Text("Shiori Reader will open AnkiMobile to add your vocabulary cards. Make sure AnkiMobile is installed on your device.")) {
                Button(action: {
                    testAnkiConnection()
                }) {
                    Text("Test AnkiMobile Connection")
                }
            }
        }
        .navigationTitle("Anki Settings")
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func testAnkiConnection() {
        AnkiExportService.shared.testAnkiConnection { success in
            DispatchQueue.main.async {
                if success {
                    alertTitle = "Success"
                    alertMessage = "AnkiMobile is installed and can be opened."
                } else {
                    alertTitle = "Error"
                    alertMessage = "AnkiMobile is not installed or cannot be opened."
                }
                showAlert = true
            }
        }
    }
    
    private func fetchAnkiInfo() {
        isLoading = true
        
        AnkiExportService.shared.fetchAnkiInfo { success, info in
            DispatchQueue.main.async {
                isLoading = false
                
                if success, let info = info {
                    // Process deck and note type info
                    if let decks = info["decks"] as? [String] {
                        // Show deck selection dialog
                        print("Available decks: \(decks)")
                        // You could show a picker here
                    }
                    
                    if let noteTypes = info["noteTypes"] as? [String: [String]] {
                        // Show note type selection dialog
                        print("Available note types: \(noteTypes)")
                        // You could show a picker here
                    }
                } else {
                    alertTitle = "Error"
                    alertMessage = "Failed to fetch information from AnkiMobile."
                    showAlert = true
                }
            }
        }
    }
}

#Preview {
    AnkiSettingsView()
}
