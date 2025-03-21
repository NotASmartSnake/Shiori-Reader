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
    
    // State for the deck and note type pickers
    @State private var availableDecks: [String] = []
    @State private var availableNoteTypes: [String: [String]] = [:]
    @State private var selectedNoteTypeFields: [String] = []
    @State private var showingDeckPicker = false
    @State private var showingNoteTypePicker = false
    
    var body: some View {
        Form {
            Section(header: Text("AnkiMobile Integration")) {
                HStack {
                    Text("Note Type")
                    Spacer()
                    Button(noteType) {
                        showingNoteTypePicker = true
                    }
                    .foregroundColor(.blue)
                }
                
                HStack {
                    Text("Deck Name")
                    Spacer()
                    Button(deckName) {
                        showingDeckPicker = true
                    }
                    .foregroundColor(.blue)
                }
                
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
                    Text("Available fields for '\(noteType)':")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(selectedNoteTypeFields, id: \.self) { field in
                        Text(field)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    Divider()
                }
                
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
        .sheet(isPresented: $showingDeckPicker) {
            DeckPickerView(
                selectedDeck: $deckName,
                isPresented: $showingDeckPicker,
                availableDecks: availableDecks
            )
        }
        .sheet(isPresented: $showingNoteTypePicker) {
            NoteTypePickerView(
                selectedNoteType: $noteType,
                isPresented: $showingNoteTypePicker,
                availableNoteTypes: availableNoteTypes,
                onNoteTypeSelected: { type, fields in
                    selectedNoteTypeFields = fields
                }
            )
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
    AnkiSettingsView()
}
