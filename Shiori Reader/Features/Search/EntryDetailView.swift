import SwiftUI

// Detail view for dictionary entry
struct EntryDetailView: View {
    @EnvironmentObject private var savedWordsManager: SavedWordsManager
    let entry: DictionaryEntry
    @Environment(\.dismiss) private var dismiss
    @State private var showSavedConfirmation = false
    @State private var showAnkiSuccess = false
    @State private var showingAnkiSettings = false
    
    var body: some View {
            NavigationStack {
                mainContent
                    .navigationTitle("Word Details")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                dismiss()
                            }
                        }
                    }
                    .overlay(statusOverlays)
                    .sheet(isPresented: $showingAnkiSettings) {
                        ankiSettingsSheet
                    }
            }
        }
        
        // MARK: - Component Views
        
        private var mainContent: some View {
            ZStack {
                Color("BackgroundColor").ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        wordAndReadingSection
                        tagsSection
                        meaningsSection
                        Spacer(minLength: 30)
                        actionButtons
                    }
                }
            }
        }
        
        private var wordAndReadingSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Word")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Text(entry.term)
                    .font(.title)
                    .padding(.leading, 4)
                
                if !entry.reading.isEmpty && entry.reading != entry.term {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Reading")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text(entry.reading)
                            .font(.title2)
                            .padding(.leading, 4)
                    }
                    .padding(.top, 5)
                }
                
                // Pitch accent section
                if entry.hasPitchAccent, let pitchAccents = entry.pitchAccents {
                    let matchingAccents = pitchAccents.accents.filter { accent in
                        accent.term == entry.term && accent.reading == entry.reading
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
                        .padding(.top, 5)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
        }
        
        private var tagsSection: some View {
            Group {
                if !entry.termTags.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Word Type")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(entry.termTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.7))
                                    .cornerRadius(5)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        
        private var meaningsSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Meanings")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                // Get all entries for this word-reading combination to show dictionary-separated definitions
                let allEntries = getAllEntriesForWord()
                
                if !allEntries.isEmpty {
                    // Show dictionary-separated definitions
                    let entriesBySource = Dictionary(grouping: allEntries) { $0.source }
                    let sourceOrder = getOrderedDictionarySources(availableSources: Array(entriesBySource.keys))
                    
                    ForEach(sourceOrder, id: \.self) { source in
                        if let sourceEntries = entriesBySource[source], !sourceEntries.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                // Dictionary source badge
                                HStack {
                                    getDictionarySourceBadge(for: source)
                                    Spacer()
                                }
                                
                                // Definitions for this source
                                VStack(alignment: .leading, spacing: 4) {
                                    let allMeanings = sourceEntries.flatMap { $0.meanings }
                                    ForEach(allMeanings.indices, id: \.self) { meaningIndex in
                                        Text(allMeanings[meaningIndex])
                                            .font(.body)
                                            .padding(.leading, 8)
                                    }
                                }
                            }
                            .padding(.bottom, 4)
                        }
                    }
                } else {
                    // Fallback: show the current entry's definitions if no lookup results found
                    VStack(alignment: .leading, spacing: 8) {
                        // Dictionary source badge
                        HStack {
                            getDictionarySourceBadge(for: entry.source)
                            Spacer()
                        }
                        
                        // Definitions for this entry
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(entry.meanings.indices, id: \.self) { meaningIndex in
                                Text(entry.meanings[meaningIndex])
                                    .font(.body)
                                    .padding(.leading, 8)
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
            .padding(.horizontal)
        }
        
        private var actionButtons: some View {
            VStack(spacing: 15) {
                // Save button
                Button(action: saveWordAction) {
                    HStack {
                        Image(systemName: "bookmark.fill")
                        Text("Save to Vocabulary List")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Add to Anki button
                Button(action: exportToAnki) {
                    HStack {
                        Image(systemName: "plus.rectangle.on.rectangle")
                        Text("Add to Anki")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        
        private var statusOverlays: some View {
            ZStack {
                // Saved confirmation overlay
                if showSavedConfirmation {
                    statusMessage("Saved!")
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(), value: showSavedConfirmation)
                }
                
                // Anki success overlay
                if showAnkiSuccess {
                    statusMessage("Added to Anki!")
                        .transition(.scale.combined(with: .opacity))
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
        }
        
        private func statusMessage(_ text: String) -> some View {
            VStack {
                Text(text)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .cornerRadius(8)
                    .shadow(radius: 3)
            }
            .frame(maxWidth: .infinity)
        }
        
        private var ankiSettingsSheet: some View {
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
        
        // MARK: - Actions
        
        private func saveWordAction() {
            // Always get all entries for this word-reading combination
            let allEntries = getAllEntriesForWord()
            
            // Group by source and format
            let groupedBySource = Dictionary(grouping: allEntries) { $0.source }
            var sourceSections: [String] = []
            
            // Process in user-configured order
            let sourceOrder = getOrderedDictionarySources(availableSources: Array(groupedBySource.keys))
            
            for source in sourceOrder {
                guard let entries = groupedBySource[source], !entries.isEmpty else { continue }
                let sourceTitle = source == "jmdict" ? "JMdict" : (source.hasPrefix("imported_") ? getImportedDictionaryDisplayName(source: source) : source.capitalized)
                let allMeanings = entries.flatMap { $0.meanings }
                let definitionsText = allMeanings.joined(separator: "\n")
                sourceSections.append("\(sourceTitle)\n\(definitionsText)")
            }
            
            let formattedDefinitions = sourceSections
            
            // Create a new SavedWord
            let newSavedWord = SavedWord(
                word: entry.term,
                reading: entry.reading,
                definitions: formattedDefinitions,
                sentence: "", // Empty for now, user can add later
                sourceBook: "Search", // Indicate this was from search
                timeAdded: Date(),
                pitchAccents: entry.pitchAccents // Include pitch accent data
            )
            
            // Add to saved words
            savedWordsManager.addWord(newSavedWord)
            
            showSavedConfirmation = true
            
            // Dismiss after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                dismiss()
            }
        }
        
        // Function to handle exporting to Anki
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
            
            // Create save callback that calls the same save method as the bookmark button
            let saveCallback = {
                self.saveWordAction()
            }
            
            // Always get all entries for this word-reading combination to use the same flow as popup views
            let allEntries = getAllEntriesForWord()
            
            // Use the export method with all matching entries
            AnkiExportService.shared.exportWordToAnki(
                word: entry.term,
                reading: entry.reading,
                entries: allEntries,
                sentence: "", // No sentence from search results
                pitchAccents: entry.pitchAccents,
                sourceView: topViewController,
                onSaveToVocab: saveCallback,
                completion: { success in
                    if success {
                        withAnimation {
                            showAnkiSuccess = true
                        }
                    }
                }
            )
        }
    
    // MARK: - Helper Functions
    
    private func getOrderedDictionarySources(availableSources: [String]) -> [String] {
        // Get the user's preferred dictionary order from settings
        let orderedSources = DictionaryColorProvider.shared.getOrderedDictionarySources()
        
        // Filter to only include sources that are available in this lookup
        var result: [String] = []
        
        // Add sources in the preferred order if they're available
        for source in orderedSources {
            if availableSources.contains(source) {
                result.append(source)
            }
        }
        
        // Add any remaining sources that weren't in the order (alphabetically)
        let remainingSources = availableSources.filter { !result.contains($0) }.sorted()
        result.append(contentsOf: remainingSources)
        
        return result
    }
    
    private func getAllEntriesForWord() -> [DictionaryEntry] {
        // Use the same lookup method as SearchViewModel to include imported dictionaries
        let allEntries = DictionaryManager.shared.lookupWithDeinflection(word: entry.term)
        return allEntries.filter { $0.term == entry.term && $0.reading == entry.reading }
    }
    
    @ViewBuilder
    private func getDictionarySourceBadge(for source: String) -> some View {
        let color = getDictionaryColor(for: source)
        
        if source == "jmdict" {
            Text("JMdict")
                .font(.caption2)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .cornerRadius(4)
        } else if source.hasPrefix("imported_") {
            let displayName = getImportedDictionaryDisplayName(source: source)
            
            Text(displayName)
                .font(.caption2)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .cornerRadius(4)
        } else {
            // Fallback for any other source types
            Text(source.capitalized)
                .font(.caption2)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .cornerRadius(4)
        }
    }
    
    private func getDictionaryColor(for source: String) -> Color {
        return DictionaryColorProvider.shared.getColor(for: source)
    }
    
    private func getImportedDictionaryDisplayName(source: String) -> String {
        // Extract UUID from source string (format: "imported_UUID")
        let importedId = source.replacingOccurrences(of: "imported_", with: "")
        if let uuid = UUID(uuidString: importedId) {
            let importedDictionaries = DictionaryImportManager.shared.getImportedDictionaries()
            if let dict = importedDictionaries.first(where: { $0.id == uuid }) {
                return dict.title
            }
        }
        return "Imported"
    }
}
