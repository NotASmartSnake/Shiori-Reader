
import SwiftUI

struct SavedWordDetailView: View {
    @EnvironmentObject var wordManager: SavedWordsManager
    @State private var editedWord: SavedWord
    @Environment(\.presentationMode) var presentationMode
    @State private var showDeleteConfirmation = false
    @State private var isEditing = false
    @State private var showAnkiSuccess = false
    @State private var showingAnkiSettings = false
    
    // Create a date formatter for displaying the date added
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    init(word: SavedWord) {
        self._editedWord = State(initialValue: word)
    }
    
    var body: some View {
        ZStack {
            Color("BackgroundColor").ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Source book and date added info
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Source: \(editedWord.sourceBook)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Added: \(dateFormatter.string(from: editedWord.timeAdded))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            isEditing.toggle()
                        }) {
                            Text(isEditing ? "Done" : "Edit")
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // Word and reading
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Word")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        if isEditing {
                            TextField("Word", text: $editedWord.word)
                                .font(.title)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .disableAutocorrection(true)
                        } else {
                            Text(editedWord.word)
                                .font(.title)
                                .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Reading
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Reading")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        if isEditing {
                            TextField("Reading", text: $editedWord.reading)
                                .font(.title2)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .disableAutocorrection(true)
                        } else {
                            Text(editedWord.reading)
                                .font(.title2)
                                .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Pitch accent section
                    if editedWord.hasPitchAccent, let pitchAccents = editedWord.pitchAccents {
                        let matchingAccents = pitchAccents.accents.filter { accent in
                            accent.term == editedWord.word && accent.reading == editedWord.reading
                        }
                        
                        if !matchingAccents.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Pitch Accent")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                // Show pitch accent graphs with pattern numbers
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(matchingAccents.enumerated()), id: \.element.id) { index, accent in
                                        HStack(alignment: .center, spacing: 12) {
                                            // Pitch accent number badge
                                            Text("[\(accent.pitchAccent)]")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(pitchAccentColor(for: accent.pitchAccent))
                                                .cornerRadius(6)
                                            
                                            // Pitch accent graph
                                            PitchAccentGraphView(
                                                word: accent.term,
                                                reading: accent.reading,
                                                pitchValue: accent.pitchAccent
                                            )
                                            
                                            Spacer()
                                        }
                                    }
                                }
                                .padding(.leading, 4)
                            }
                            .padding(.horizontal)
                            .padding(.top, 5)
                        }
                    }
                    
                    // Definition
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Definition")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        if isEditing {
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: Binding(
                                    get: { editedWord.definitions.joined(separator: "\n") },
                                    set: { newValue in
                                        editedWord.definitions = newValue.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                                    }
                                ))
                                    .padding()
                                    .frame(minHeight: 100)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .disableAutocorrection(true)
                                
                                if editedWord.definitions.isEmpty {
                                    Text("Enter definition")
                                        .foregroundColor(.gray)
                                        .padding(25)
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(editedWord.definitions.indices, id: \.self) { index in
                                    let definitionText = editedWord.definitions[index]
                                    let lines = definitionText.components(separatedBy: "\n")
                                    
                                    if lines.count > 1 && isValidDictionarySource(lines[0]) {
                                        // This is a formatted definition with valid dictionary source title
                                        let sourceTitle = lines[0]
                                        let definitions = Array(lines.dropFirst())
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            // Dictionary source badge
                                            HStack {
                                                Text(getDictionaryBadgeText(for: sourceTitle))
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(DictionaryColorProvider.shared.getColor(for: convertSourceTitleToId(sourceTitle)).opacity(0.2))
                                                    .foregroundColor(DictionaryColorProvider.shared.getColor(for: convertSourceTitleToId(sourceTitle)))
                                                    .cornerRadius(4)
                                                
                                                Spacer()
                                            }
                                            
                                            // Definitions
                                            VStack(alignment: .leading, spacing: 4) {
                                                ForEach(definitions.indices, id: \.self) { defIndex in
                                                    Text(definitions[defIndex])
                                                        .font(.body)
                                                        .padding(.leading, 8)
                                                }
                                            }
                                        }
                                    } else {
                                        // Legacy format, single line, or multi-line without dictionary source
                                        // Display as plain text, preserving line breaks
                                        VStack(alignment: .leading, spacing: 4) {
                                            ForEach(lines.indices, id: \.self) { lineIndex in
                                                Text(lines[lineIndex])
                                                    .font(.body)
                                                    .padding(.leading, 4)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Example sentence
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Example Sentence")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        if isEditing {
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $editedWord.sentence)
                                    .padding()
                                    .frame(minHeight: 120)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .disableAutocorrection(true)
                                
                                if editedWord.sentence.isEmpty {
                                    Text("Enter example sentence")
                                        .foregroundColor(.gray)
                                        .padding(25)
                                }
                            }
                        } else {
                            Text(editedWord.sentence)
                                .lineSpacing(4)
                                .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal)
                    
                    if isEditing {
                        // Save button when in edit mode
                        Button(action: {
                            saveChanges()
                            isEditing = false
                        }) {
                            Text("Save Changes")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }
                    
                    // Add to Anki button
                    Button(action: {
                        exportToAnki()
                    }) {
                        HStack {
                            Image(systemName: "plus.rectangle.on.rectangle")
                            Text("Add to Anki")
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.top, isEditing ? 10 : 20)
                    
                    // Delete button
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Word")
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 80) // Increased bottom padding
                    .alert(isPresented: $showDeleteConfirmation) {
                        Alert(
                            title: Text("Delete Word"),
                            message: Text("Are you sure you want to delete this word? This action cannot be undone."),
                            primaryButton: .destructive(Text("Delete")) {
                                deleteWord()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
            }
        }
        .navigationTitle("Edit Word")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .overlay(
            ZStack {
                // Anki success overlay
                if showAnkiSuccess {
                    VStack {
                        Text("Added to Anki!")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                            .padding()
                            .transition(.scale.combined(with: .opacity))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
                    .animation(.spring(), value: showAnkiSuccess)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                showAnkiSuccess = false
                            }
                        }
                    }
                }
            }
        )
        .sheet(isPresented: $showingAnkiSettings) {
            NavigationView {
                AnkiSettingsView()
                    .navigationTitle("Anki Settings")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingAnkiSettings = false
                            }
                        }
                    }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func pitchAccentColor(for pattern: Int) -> Color {
        switch pattern {
        case 0:
            return .green  // Heiban (flat)
        case 1:
            return .orange // Atamadaka (head-high)
        default:
            return .blue   // Nakadaka (middle-high)
        }
    }
    
    /// Get dictionary badge text for display
    private func getDictionaryBadgeText(for sourceTitle: String) -> String {
        switch sourceTitle.lowercased() {
        case "jmdict":
            return "JMdict"
        default:
            return sourceTitle.capitalized
        }
    }
    
    
    /// Check if a line is a valid dictionary source title
    private func isValidDictionarySource(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmedText == "jmdict" || isImportedDictionaryTitle(trimmedText)
    }
    
    /// Check if text is an imported dictionary title
    private func isImportedDictionaryTitle(_ text: String) -> Bool {
        let importedDictionaries = DictionaryImportManager.shared.getImportedDictionaries()
        return importedDictionaries.contains { dict in
            dict.title.lowercased() == text
        }
    }
    
    /// Convert source title back to dictionary ID for color lookup
    private func convertSourceTitleToId(_ sourceTitle: String) -> String {
        switch sourceTitle.lowercased() {
        case "jmdict":
            return "jmdict"
        default:
            // For imported dictionaries, try to find the matching UUID
            let importedDictionaries = DictionaryImportManager.shared.getImportedDictionaries()
            if let dict = importedDictionaries.first(where: { $0.title.lowercased() == sourceTitle.lowercased() }) {
                return "imported_\(dict.id.uuidString)"
            }
            return sourceTitle.lowercased()
        }
    }
    
    // MARK: - Actions
    
    private func saveChanges() {
        wordManager.updateWord(updated: editedWord)
    }
    
    private func deleteWord() {
        wordManager.deleteWord(with: editedWord.id)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func exportToAnki() {
        // Get the root view controller to present from
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        // Get the topmost view controller
        var topViewController = rootViewController
        while let presentedViewController = topViewController.presentedViewController {
            topViewController = presentedViewController
        }
        
        // Reconstruct dictionary entries from saved formatted definitions
        var reconstructedEntries: [DictionaryEntry] = []
        
        for (index, definitionSection) in editedWord.definitions.enumerated() {
            let lines = definitionSection.components(separatedBy: "\n")
            
            if lines.count > 1 && isValidDictionarySource(lines[0]) {
                // This is a formatted definition with valid dictionary source title
                let sourceTitle = lines[0]
                let definitions = Array(lines.dropFirst())
                
                // Convert source title back to source identifier
                let sourceId: String
                switch sourceTitle.lowercased() {
                case "jmdict":
                    sourceId = "jmdict"
                default:
                    // For imported dictionaries, try to find the matching UUID
                    let importedDictionaries = DictionaryImportManager.shared.getImportedDictionaries()
                    if let dict = importedDictionaries.first(where: { $0.title.lowercased() == sourceTitle.lowercased() }) {
                        sourceId = "imported_\(dict.id.uuidString)"
                    } else {
                        sourceId = sourceTitle.lowercased()
                    }
                }
                
                // Create a reconstructed dictionary entry
                var entry = DictionaryEntry(
                    id: "\(editedWord.word)_\(editedWord.reading)_\(sourceId)_\(index)",
                    term: editedWord.word,
                    reading: editedWord.reading,
                    meanings: definitions,
                    meaningTags: [],
                    termTags: [],
                    score: nil,
                    rules: nil,
                    popularity: nil,
                    source: sourceId
                )
                
                // Set pitch accent data if available
                entry.pitchAccents = editedWord.pitchAccents
                
                reconstructedEntries.append(entry)
            }
        }
        
        if !reconstructedEntries.isEmpty {
            // Use reconstructed entries with the same flow as popup views
            AnkiExportService.shared.exportWordToAnki(
                word: editedWord.word,
                reading: editedWord.reading,
                entries: reconstructedEntries,
                sentence: editedWord.sentence,
                pitchAccents: editedWord.pitchAccents,
                sourceView: topViewController,
                onSaveToVocab: nil, // Already saved
                completion: { success in
                    if success {
                        withAnimation {
                            showAnkiSuccess = true
                            
                            // Hide success message after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    showAnkiSuccess = false
                                }
                            }
                        }
                    }
                }
            )
        } else {
            // Fallback - use simple definition format
            let ankiDefinition = editedWord.definitions.joined(separator: "<br>")
            
            AnkiExportService.shared.addVocabularyCard(
                word: editedWord.word,
                reading: editedWord.reading,
                definition: ankiDefinition,
                sentence: editedWord.sentence,
                pitchAccents: editedWord.pitchAccents,
                sourceView: topViewController,
                onSaveToVocab: nil, // Already saved
                completion: { success in
                    if success {
                        withAnimation {
                            showAnkiSuccess = true
                            
                            // Hide success message after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    showAnkiSuccess = false
                                }
                            }
                        }
                    }
                }
            )
        }
    }
}

#Preview {
    NavigationStack {
        SavedWordDetailView(
            word: SavedWord(
                word: "勉強",
                reading: "べんきょう",
                definition: "study",
                sentence: "日本語の勉強は楽しいけど、難しいです。",
                sourceBook: "ReZero",
                timeAdded: Date(),
                pitchAccents: PitchAccentData(accents: [
                    PitchAccent(term: "勉強", reading: "べんきょう", pitchAccent: 0),
                    PitchAccent(term: "勉強", reading: "べんきょう", pitchAccent: 1)
                ])
            )
        )
    }
}
