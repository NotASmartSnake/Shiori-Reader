//
//  AnkiSettingsView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/21/25.
//

import SwiftUI

struct AnkiSettingsView: View {
    // Settings stored in UserDefaults
    @AppStorage("ankiNoteType") private var noteType = "Japanese"
    @AppStorage("ankiDeckName") private var deckName = "Shiori-Reader"
    @AppStorage("ankiTags") private var tags = "shiori-reader"
    
    // Field mappings
    @State private var wordField = UserDefaults.standard.string(forKey: "ankiWordField") ?? "Word"
    @State private var readingField = UserDefaults.standard.string(forKey: "ankiReadingField") ?? "Reading"
    @State private var definitionField = UserDefaults.standard.string(forKey: "ankiDefinitionField") ?? "Definition"
    @State private var sentenceField = UserDefaults.standard.string(forKey: "ankiSentenceField") ?? "Sentence"
    
    // UI state
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    // Anki data state
    @State private var availableDecks: [String] = []
    @State private var availableNoteTypes: [String: [String]] = [:]
    @State private var selectedNoteTypeFields: [String] = []
    
    var body: some View {
        Form {
            Section(header: Text("AnkiMobile Integration")) {
                // Note Type Menu
                HStack {
                    Text("Note Type")
                    Spacer()
                    Menu {
                        ForEach(Array(availableNoteTypes.keys.sorted()), id: \.self) { type in
                            Button(action: {
                                noteType = type
                                selectedNoteTypeFields = availableNoteTypes[type] ?? []
                            }) {
                                HStack {
                                    Text(type)
                                    if type == noteType {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(noteType)
                                .foregroundColor(.blue)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(availableNoteTypes.isEmpty)
                }
                
                // Deck Name Menu
                HStack {
                    Text("Deck Name")
                    Spacer()
                    Menu {
                        ForEach(availableDecks, id: \.self) { deck in
                            Button(action: {
                                deckName = deck
                            }) {
                                HStack {
                                    Text(deck)
                                    if deck == deckName {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(deckName)
                                .foregroundColor(.blue)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(availableDecks.isEmpty)
                }
                
                // Tags field
                HStack {
                    Text("Tags")
                    Spacer()
                    TextField("Tags (comma separated)", text: $tags)
                        .multilineTextAlignment(.trailing)
                }
                
                // Fetch data from Anki button
                Button(action: {
                    isLoading = true
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
            
            Section(header: Text("Field Mapping"), footer: Text("Make sure these field names match your Anki note type exactly")) {
                if !selectedNoteTypeFields.isEmpty {
                    Text("Available fields:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Word Field Menu
                HStack {
                    Text("Word Field")
                    Spacer()
                    Menu {
                        ForEach(selectedNoteTypeFields, id: \.self) { field in
                            Button(action: {
                                wordField = field
                                UserDefaults.standard.set(field, forKey: "ankiWordField")
                            }) {
                                HStack {
                                    Text(field)
                                    if field == wordField {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        
                        // Add custom field option
                        Divider()
                        Button("Custom Field...") {
                            // Prompt for custom field name
                            alertTitle = "Enter Custom Field Name"
                            alertMessage = "Enter the exact name of the field as it appears in your Anki note type"
                            showAlert = true
                        }
                    } label: {
                        HStack {
                            Text(wordField)
                                .foregroundColor(.blue)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(selectedNoteTypeFields.isEmpty)
                }
                
                // Reading Field Menu
                HStack {
                    Text("Reading Field")
                    Spacer()
                    Menu {
                        ForEach(selectedNoteTypeFields, id: \.self) { field in
                            Button(action: {
                                readingField = field
                                UserDefaults.standard.set(field, forKey: "ankiReadingField")
                            }) {
                                HStack {
                                    Text(field)
                                    if field == readingField {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        
                        // Add custom field option
                        Divider()
                        Button("Custom Field...") {
                            // Prompt for custom field name
                            alertTitle = "Enter Custom Field Name"
                            alertMessage = "Enter the exact name of the field as it appears in your Anki note type"
                            showAlert = true
                        }
                    } label: {
                        HStack {
                            Text(readingField)
                                .foregroundColor(.blue)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(selectedNoteTypeFields.isEmpty)
                }
                
                // Definition Field Menu
                HStack {
                    Text("Definition Field")
                    Spacer()
                    Menu {
                        ForEach(selectedNoteTypeFields, id: \.self) { field in
                            Button(action: {
                                definitionField = field
                                UserDefaults.standard.set(field, forKey: "ankiDefinitionField")
                            }) {
                                HStack {
                                    Text(field)
                                    if field == definitionField {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        
                        // Add custom field option
                        Divider()
                        Button("Custom Field...") {
                            // Prompt for custom field name
                            alertTitle = "Enter Custom Field Name"
                            alertMessage = "Enter the exact name of the field as it appears in your Anki note type"
                            showAlert = true
                        }
                    } label: {
                        HStack {
                            Text(definitionField)
                                .foregroundColor(.blue)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(selectedNoteTypeFields.isEmpty)
                }
                
                // Sentence Field Menu
                HStack {
                    Text("Sentence Field")
                    Spacer()
                    Menu {
                        ForEach(selectedNoteTypeFields, id: \.self) { field in
                            Button(action: {
                                sentenceField = field
                                UserDefaults.standard.set(field, forKey: "ankiSentenceField")
                            }) {
                                HStack {
                                    Text(field)
                                    if field == sentenceField {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        
                        // Add custom field option
                        Divider()
                        Button("Custom Field...") {
                            // Prompt for custom field name
                            alertTitle = "Enter Custom Field Name"
                            alertMessage = "Enter the exact name of the field as it appears in your Anki note type"
                            showAlert = true
                        }
                    } label: {
                        HStack {
                            Text(sentenceField)
                                .foregroundColor(.blue)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(selectedNoteTypeFields.isEmpty)
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
            // Handle different alert cases
            if alertTitle == "Enter Custom Field Name" {
                return Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            } else {
                return Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .onAppear {
            // Try to load field list if we already have the note type
            if let currentNoteType = availableNoteTypes[noteType] {
                selectedNoteTypeFields = currentNoteType
            }
        }
    }
    
    private func fetchAnkiInfo() {
        AnkiExportService.shared.fetchAnkiInfo { success, info in
            DispatchQueue.main.async {
                isLoading = false
                
                if success, let info = info {
                    print("DEBUG: Received Anki info successfully")
                    
                    // Process deck information
                    if let decks = info["decks"] as? [String] {
                        self.availableDecks = decks
                        print("DEBUG: Loaded \(decks.count) decks")
                    }
                    
                    // Process note type information
                    if let noteTypes = info["noteTypes"] as? [String: [String]] {
                        self.availableNoteTypes = noteTypes
                        print("DEBUG: Loaded \(noteTypes.count) note types")
                        
                        // Update the selected note type fields
                        if let fields = noteTypes[self.noteType] {
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
}

#Preview {
    NavigationView {
        AnkiSettingsView()
    }
}
