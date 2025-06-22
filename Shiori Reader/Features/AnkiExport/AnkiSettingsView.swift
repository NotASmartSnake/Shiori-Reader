import SwiftUI

struct AnkiSettingsView: View {
    @StateObject private var viewModel = AnkiSettingsViewModel()
    @State private var showingAddFieldMenu = false
    @State private var fieldTypeToAdd = ""
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Form {
                // MARK: - AnkiMobile Integration Section
                ankiIntegrationSection
                
                // MARK: - Primary Field Mapping Section
                primaryFieldMappingSection
                
                // MARK: - Pitch Accent Customization Section
                pitchAccentCustomizationSection
                
                // MARK: - Additional Fields Section
                if !viewModel.settings.additionalFields.isEmpty {
                    secondaryFieldMappingSection
                }
                
                // MARK: - Add Additional Field Button
                addFieldSection
                
                // MARK: - App Settings Section
                appSettingsSection
                
                // MARK: - Test Connection Section
                testConnectionSection
            }
            .navigationTitle("Anki Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $viewModel.showAlert) {
                Alert(
                    title: Text(viewModel.alertTitle),
                    message: Text(viewModel.alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            
            // Spacer at the bottom for tab bar
            Rectangle()
                .frame(width: 0, height: 40)
                .foregroundStyle(Color.clear)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    viewModel.saveSettings()
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    private var appSettingsSection: some View {
        Section(header: Text("App Settings"), footer: Text("Show a popup to select which definitions to export to Anki. When disabled, all definitions will be exported automatically.")) {
            Toggle("Show Definition Selection Popup", isOn: Binding(
                get: { 
                    // Return true if no value has been set (first time), otherwise return stored value
                    if UserDefaults.standard.object(forKey: "showDefinitionSelectionPopup") == nil {
                        return true // Default to enabled
                    }
                    return UserDefaults.standard.bool(forKey: "showDefinitionSelectionPopup")
                },
                set: { 
                    UserDefaults.standard.set($0, forKey: "showDefinitionSelectionPopup")
                }
            ))
        }
    }
    
    // MARK: - Section Components
    
    private var ankiIntegrationSection: some View {
        Section(header: Text("AnkiMobile Integration"), footer: Text("Deck and note type information is cached locally after the first successful sync. If you get an error fetching new data, close Shiori Reader from the app switcher and try again. AnkiMobile sometimes has issues with rapid successive requests.")) {
            // Note Type Menu
            noteTypeRow
            
            // Deck Name Menu
            deckNameRow
            
            // Tags field
            HStack {
                Text("Tags")
                Spacer()
                TextField("Tags (comma separated)", text: $viewModel.settings.tags)
                    .multilineTextAlignment(.trailing)
            }
            
            // Fetch data from Anki button
            fetchDataButton
        }
    }
    
    private var noteTypeRow: some View {
        HStack {
            Text("Note Type")
            Spacer()
            Menu {
                ForEach(Array(viewModel.availableNoteTypes.keys.sorted()), id: \.self) { type in
                    Button(action: {
                        viewModel.updateNoteType(type)
                    }) {
                        HStack {
                            Text(type)
                            if type == viewModel.settings.noteType {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(viewModel.settings.noteType)
                        .foregroundColor(.blue)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .disabled(viewModel.availableNoteTypes.isEmpty)
        }
    }
    
    private var deckNameRow: some View {
        HStack {
            Text("Deck Name")
            Spacer()
            Menu {
                ForEach(viewModel.availableDecks, id: \.self) { deck in
                    Button(action: {
                        viewModel.updateDeckName(deck)
                    }) {
                        HStack {
                            Text(deck)
                            if deck == viewModel.settings.deckName {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(viewModel.settings.deckName)
                        .foregroundColor(.blue)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .disabled(viewModel.availableDecks.isEmpty)
        }
    }
    
    private var fetchDataButton: some View {
        Button(action: {
            viewModel.fetchAnkiInfo()
        }) {
            HStack {
                Text("Get Decks & Note Types from Anki")
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
        .disabled(viewModel.isLoading)
    }
    
    private var primaryFieldMappingSection: some View {
        Section(header: Text("Primary Field Mapping"), footer: Text("These fields will always receive content in your Anki cards. Choose a blank value if you don't want to use a specific field.")) {
            // Word Field Menu
            fieldPickerRow(
                title: "Word Field",
                binding: Binding(
                    get: { viewModel.settings.wordField },
                    set: { viewModel.updateFieldMapping(fieldType: "word", fieldName: $0) }
                ),
                fields: viewModel.selectedNoteTypeFields
            )
            
            // Reading Field Menu
            fieldPickerRow(
                title: "Reading Field",
                binding: Binding(
                    get: { viewModel.settings.readingField },
                    set: { viewModel.updateFieldMapping(fieldType: "reading", fieldName: $0) }
                ),
                fields: viewModel.selectedNoteTypeFields
            )
            
            // Definition Field Menu
            fieldPickerRow(
                title: "Definition Field",
                binding: Binding(
                    get: { viewModel.settings.definitionField },
                    set: { viewModel.updateFieldMapping(fieldType: "definition", fieldName: $0) }
                ),
                fields: viewModel.selectedNoteTypeFields
            )
            
            // Sentence Field Menu
            fieldPickerRow(
                title: "Sentence Field",
                binding: Binding(
                    get: { viewModel.settings.sentenceField },
                    set: { viewModel.updateFieldMapping(fieldType: "sentence", fieldName: $0) }
                ),
                fields: viewModel.selectedNoteTypeFields
            )
            
            // Word with Reading Field
            fieldPickerRow(
                title: "Word with Reading Field",
                binding: Binding(
                    get: { viewModel.settings.wordWithReadingField },
                    set: { viewModel.updateFieldMapping(fieldType: "wordWithReading", fieldName: $0) }
                ),
                fields: viewModel.selectedNoteTypeFields
            )
            
            // Pitch Accent Field
            fieldPickerRow(
                title: "Pitch Accent Field",
                binding: Binding(
                    get: { viewModel.settings.pitchAccentField },
                    set: { viewModel.updateFieldMapping(fieldType: "pitchAccent", fieldName: $0) }
                ),
                fields: viewModel.selectedNoteTypeFields
            )
        }
    }
    
    private var pitchAccentCustomizationSection: some View {
        Section(header: Text("Pitch Accent Appearance"), footer: Text("Customize how pitch accent graphs appear in your Anki cards.")) {
            // Graph Color Picker
            HStack {
                Text("Graph Color")
                Spacer()
                colorPickerMenu(
                    title: "Graph Color",
                    selectedColor: $viewModel.settings.pitchAccentGraphColor,
                    colors: ["black", "white", "grey", "blue"]
                )
            }
            
            // Text Color Picker
            HStack {
                Text("Text Color")
                Spacer()
                colorPickerMenu(
                    title: "Text Color",
                    selectedColor: $viewModel.settings.pitchAccentTextColor,
                    colors: ["white", "grey", "black", "blue"]
                )
            }
        }
    }
    
    private var secondaryFieldMappingSection: some View {
        Section(header: Text("Secondary Field Mapping"), footer: Text("These additional fields will also receive the same content as their primary counterparts.")) {
            ForEach(viewModel.settings.additionalFields.indices, id: \.self) { index in
                additionalFieldRow(index: index)
            }
        }
    }
    
    private func additionalFieldRow(index: Int) -> some View {
        HStack {
            // Field type label
            Text(viewModel.getFieldTypeDisplayName(viewModel.settings.additionalFields[index].type))
            
            Spacer()
            
            // Field selection menu
            fieldPickerButton(
                binding: Binding(
                    get: { viewModel.settings.additionalFields[index].fieldName },
                    set: { viewModel.updateAdditionalField(at: index, fieldName: $0) }
                ),
                fields: viewModel.selectedNoteTypeFields
            )
            
            // Delete button
            Button(action: {
                viewModel.removeField(at: index)
            }) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }
    
    private var addFieldSection: some View {
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
                    viewModel.addEmptyField(type: "word")
                }
                Button("Reading Field") {
                    viewModel.addEmptyField(type: "reading")
                }
                Button("Definition Field") {
                    viewModel.addEmptyField(type: "definition")
                }
                Button("Sentence Field") {
                    viewModel.addEmptyField(type: "sentence")
                }
                Button("Word with Reading Field") {
                    viewModel.addEmptyField(type: "wordWithReading")
                }
                Button("Pitch Accent Field") {
                    viewModel.addEmptyField(type: "pitchAccent")
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
    
    private var testConnectionSection: some View {
        Section(footer: Text("Shiori Reader will open AnkiMobile to add your vocabulary cards. Make sure AnkiMobile is installed on your device.")) {
            Button(action: {
                viewModel.testAnkiConnection()
            }) {
                Text("Test AnkiMobile Connection")
            }
        }
    }
    
    // MARK: - Helper Functions
    
    // Field picker row with label and button
    private func fieldPickerRow(title: String, binding: Binding<String>, fields: [String]) -> some View {
        HStack {
            Text(title)
            Spacer()
            fieldPickerButton(binding: binding, fields: fields)
        }
    }
    
    // Field picker button for menus
    private func fieldPickerButton(binding: Binding<String>, fields: [String]) -> some View {
        Menu {
            // Empty option - to not send any data for this field
             Button(action: {
                 binding.wrappedValue = ""
             }) {
                 HStack {
                     Text("")
                     if binding.wrappedValue.isEmpty {
                         Spacer()
                         Image(systemName: "checkmark")
                     }
                 }
             }
            
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
    
    // Color picker for pitch accent customization
    private func colorPickerMenu(title: String, selectedColor: Binding<String>, colors: [String]) -> some View {
        Menu {
            ForEach(colors, id: \.self) { color in
                Button(action: {
                    selectedColor.wrappedValue = color
                }) {
                    HStack {
                        Circle()
                            .fill(colorFromString(color))
                            .frame(width: 16, height: 16)
                        Text(color.capitalized)
                        if color == selectedColor.wrappedValue {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Circle()
                    .fill(colorFromString(selectedColor.wrappedValue))
                    .frame(width: 16, height: 16)
                Text(selectedColor.wrappedValue.capitalized)
                    .foregroundColor(.blue)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
    
    // Helper to convert color string to Color
    private func colorFromString(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "black":
            return .black
        case "white":
            return .white
        case "grey", "gray":
            return .gray
        case "blue":
            return .blue
        default:
            return .black
        }
    }
}

struct AnkiSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AnkiSettingsView()
        }
    }
}
