import SwiftUI

struct AnkiSettingsView: View {
    // Settings stored in UserDefaults
    @AppStorage("ankiNoteType") private var noteType = "Japanese"
    @AppStorage("ankiDeckName") private var deckName = "Shiori-Reader"
    @AppStorage("ankiTags") private var tags = "shiori-reader"
    
    // Primary field mappings
    @AppStorage("ankiWordField") private var wordField = "Word"
    @AppStorage("ankiReadingField") private var readingField = "Reading"
    @AppStorage("ankiDefinitionField") private var definitionField = "Definition"
    @AppStorage("ankiSentenceField") private var sentenceField = "Sentence"
    
    // Additional field mappings as arrays
    @State private var additionalFields: [AdditionalField] = []
    
    // UI state
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var showingAddFieldMenu = false
    @State private var fieldTypeToAdd = ""
    
    // Anki data state
    @State private var availableDecks: [String] = []
    @State private var availableNoteTypes: [String: [String]] = [:]
    @State private var selectedNoteTypeFields: [String] = []
    
    var body: some View {
        VStack {
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
                                    loadAdditionalFields()
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
                
                Section(header: Text("Primary Field Mapping"), footer: Text("These fields will always receive content in your Anki cards.")) {
                    // Word Field Menu
                    HStack {
                        Text("Word Field")
                        Spacer()
                        fieldPickerButton(for: $wordField, fields: selectedNoteTypeFields)
                    }
                    
                    // Reading Field Menu
                    HStack {
                        Text("Reading Field")
                        Spacer()
                        fieldPickerButton(for: $readingField, fields: selectedNoteTypeFields)
                    }
                    
                    // Definition Field Menu
                    HStack {
                        Text("Definition Field")
                        Spacer()
                        fieldPickerButton(for: $definitionField, fields: selectedNoteTypeFields)
                    }
                    
                    // Sentence Field Menu
                    HStack {
                        Text("Sentence Field")
                        Spacer()
                        fieldPickerButton(for: $sentenceField, fields: selectedNoteTypeFields)
                    }
                }
                
                // Additional Fields Section
                if !additionalFields.isEmpty {
                    Section(header: Text("Secondary Field Mapping"), footer: Text("These additional fields will also receive the same content as their primary counterparts.")) {
                        ForEach(additionalFields.indices, id: \.self) { index in
                            HStack {
                                // Field type label
                                Text(getFieldTypeDisplayName(additionalFields[index].type))
                                
                                Spacer()
                                
                                // Field selection menu
                                fieldPickerButton(
                                    for: Binding(
                                        get: { additionalFields[index].fieldName },
                                        set: {
                                            additionalFields[index].fieldName = $0
                                            saveAdditionalFields()
                                        }
                                    ),
                                    fields: selectedNoteTypeFields
                                )
                                
                                // Delete button
                                Button(action: {
                                    additionalFields.remove(at: index)
                                    saveAdditionalFields()
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
                
                // Add additional field button
                Section {
                    Button(action: {
                        showingAddFieldMenu = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add Secondary Field Mapping")
                        }
                    }
                    .confirmationDialog("Add Field Type", isPresented: $showingAddFieldMenu, titleVisibility: .visible) {
                        Button("Word Field") {
                            addEmptyField(type: "word")
                        }
                        Button("Reading Field") {
                            addEmptyField(type: "reading")
                        }
                        Button("Definition Field") {
                            addEmptyField(type: "definition")
                        }
                        Button("Sentence Field") {
                            addEmptyField(type: "sentence")
                        }
                        Button("Cancel", role: .cancel) { }
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
            .onAppear {
                // Try to load field list if we already have the note type
                if let currentNoteType = availableNoteTypes[noteType] {
                    selectedNoteTypeFields = currentNoteType
                }
                
                // Load existing additional fields
                loadAdditionalFields()
            }
            
            // Spacer at the bottom for tab bar
            Rectangle()
                .frame(width: 0, height: 40)
                .foregroundStyle(Color.clear)
        }
    }
    
    // Field picker button for menus
    private func fieldPickerButton(for binding: Binding<String>, fields: [String]) -> some View {
        Menu {
            ForEach(fields, id: \.self) { field in
                Button(action: {
                    binding.wrappedValue = field
                }) {
                    HStack {
                        Text(field)
                        if field == binding.wrappedValue {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            
            // Custom field option
            if !fields.isEmpty {
                Divider()
            }
            Button("Custom Field...") {
                promptForCustomField(for: binding)
            }
        } label: {
            HStack {
                Text(binding.wrappedValue)
                    .foregroundColor(.blue)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
    
    // Custom field prompt
    private func promptForCustomField(for binding: Binding<String>) {
        alertTitle = "Enter Custom Field Name"
        alertMessage = "Enter the exact name of the field as it appears in your Anki note type"
        
        // In a real app, you'd use a TextAlert or other custom solution here
        // For simplicity, we're just showing a placeholder alert
        showAlert = true
        
        // This would actually set the binding value with the user input
    }
    
    // Helper to get display name for field type
    private func getFieldTypeDisplayName(_ type: String) -> String {
        switch type {
        case "word": return "Word Field"
        case "reading": return "Reading Field"
        case "definition": return "Definition Field"
        case "sentence": return "Sentence Field"
        default: return "Field"
        }
    }
    
    // Add a new empty field
    private func addEmptyField(type: String) {
        // Default to first available field if any
        let defaultField = selectedNoteTypeFields.first ?? "Field"
        let newField = AdditionalField(type: type, fieldName: defaultField)
        additionalFields.append(newField)
        saveAdditionalFields()
    }
    
    // Save additional fields to UserDefaults
    private func saveAdditionalFields() {
        let encodedData = try? JSONEncoder().encode(additionalFields)
        UserDefaults.standard.set(encodedData, forKey: "ankiAdditionalFields")
    }
    
    // Load additional fields from UserDefaults
    private func loadAdditionalFields() {
        if let data = UserDefaults.standard.data(forKey: "ankiAdditionalFields"),
           let decoded = try? JSONDecoder().decode([AdditionalField].self, from: data) {
            additionalFields = decoded
        } else {
            additionalFields = []
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
