//
//  DictionaryPopupCardView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 6/22/25.
//

import SwiftUI

struct DictionaryPopupCardView: View {
    let matches: [DictionaryMatch]
    let onDismiss: () -> Void
    let sentenceContext: String
    let bookTitle: String
    let fullText: String
    let currentOffset: Int
    let onCharacterSelected: (Int) -> Void
    
    @State private var showAnkiSuccess = false
    @State private var showSaveSuccess = false
    @State private var showingAnkiSettings = false
    @State private var showDuplicateAlert = false
    @State private var pendingEntryToSave: DictionaryEntry? = nil
    @State private var expandedDefinitions: Set<String> = [] // Track which definitions are expanded
    @State private var showingAllEntries = false // Track if showing all entries or just the first few
    @State private var collapsedSources: Set<String> = [] // Track which dictionary sources are collapsed
    @EnvironmentObject private var wordsManager: SavedWordsManager
    
    private let initialEntriesLimit = 20 // Show first 20 entries initially
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Dictionary")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Button(action: {
                    onDismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            // Character picker view
            if !fullText.isEmpty {
                CharacterPickerView(
                    currentText: fullText,
                    selectedOffset: currentOffset,
                    onCharacterSelected: { _, offset in
                        onCharacterSelected(offset)
                    }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading) {
                    if matches.isEmpty {
                        Text("No definitions found.")
                            .foregroundColor(.secondary)
                            .padding(.top, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        // Group entries by term-reading combination and merge definitions from different sources
                        let mergedEntries = groupAndMergeEntries(matches.flatMap { $0.entries })
                        let displayedEntries = showingAllEntries ? mergedEntries : Array(mergedEntries.prefix(initialEntriesLimit))
                        
                        // Display merged entries
                        ForEach(displayedEntries, id: \.id) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .center) {
                                    // Term with furigana reading above it
                                    VStack(alignment: .leading, spacing: 0) {
                                        if !entry.reading.isEmpty && entry.reading != entry.term {
                                            // Furigana reading
                                            Text(entry.reading)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .padding(.bottom, 1)
                                        }
                                        
                                        // Main term (without dictionary badge)
                                        Text(entry.term)
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    // Pitch accent graphs in horizontal scroll view
                                    if entry.hasPitchAccent, let pitchAccents = entry.pitchAccents {
                                        
                                        // Filter to only show graphs that match both term AND reading
                                        let matchingAccents = pitchAccents.accents.filter { accent in
                                            accent.term == entry.term && accent.reading == entry.reading
                                        }
                                        
                                        if !matchingAccents.isEmpty {
                                            // Scrollable container for pitch accent graphs
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(alignment: .top, spacing: 8) {
                                                    ForEach(Array(matchingAccents), id: \.id) { accent in
                                                        SimplePitchAccentGraphView(
                                                            word: accent.term,
                                                            reading: accent.reading,
                                                            pitchValue: accent.pitchAccent
                                                        )
                                                    }
                                                }
                                                .padding(.horizontal, 4)
                                            }
                                            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 400 : 200) // Wider on iPad
                                            .padding(.leading, 12) // Small gap from the word
                                            .layoutPriority(0) // Lower priority than term
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Action buttons
                                    HStack(spacing: 10) {
                                        // Save to Vocabulary button
                                        Button(action: {
                                            handleSaveWordToVocabulary(entry)
                                        }) {
                                            // Show filled bookmark if word AND reading are already saved
                                            let isWordSaved = wordsManager.isWordSaved(entry.term, reading: entry.reading)
                                            Image(systemName: isWordSaved ? "bookmark.fill" : "bookmark")
                                                .foregroundColor(.blue)
                                                .padding(8)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(8)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        // Add to Anki button
                                        Button(action: {
                                            exportToAnki(entry)
                                        }) {
                                            Image(systemName: "plus.rectangle.on.rectangle")
                                                .foregroundColor(.blue)
                                                .padding(8)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(8)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.vertical, 4)
                                
                                // Display frequency data if available
                                if let frequencyRank = entry.frequencyRankString {
                                    HStack {
                                        Text(frequencyRank)
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.green.opacity(0.2))
                                            .foregroundColor(.green)
                                            .cornerRadius(4)
                                        Spacer()
                                    }
                                    .padding(.bottom, 4)
                                }
                                
                                // Display meanings grouped by source
                                let entriesBySource = Dictionary(grouping: getAllEntriesForTerm(entry.term, reading: entry.reading, from: matches)) { $0.source }
                                let sourceOrder = getOrderedDictionarySources(availableSources: Array(entriesBySource.keys))
                                
                                ForEach(sourceOrder, id: \.self) { source in
                                    if let sourceEntries = entriesBySource[source], !sourceEntries.isEmpty {
                                        let sourceId = "\(entry.term)_\(entry.reading)_\(source)"
                                        let isSourceCollapsed = collapsedSources.contains(sourceId)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            // Dictionary source badge
                                            HStack {
                                                getDictionarySourceBadge(for: source)
                                                Spacer()
                                            }
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                                impact.impactOccurred()
                                                
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    if isSourceCollapsed {
                                                        collapsedSources.remove(sourceId)
                                                    } else {
                                                        collapsedSources.insert(sourceId)
                                                    }
                                                }
                                            }
                                            
                                            if !isSourceCollapsed {
                                                // All dictionaries treated identically - no special obunsha logic
                                                ForEach(sourceEntries.flatMap { $0.meanings }.indices, id: \.self) { meaningIndex in
                                                    let meaning = sourceEntries.flatMap { $0.meanings }[meaningIndex]
                                                    let definitionId = "\(entry.id)_\(source)_\(meaningIndex)"
                                                    let isExpanded = expandedDefinitions.contains(definitionId)
                                                    
                                                    Text(meaning)
                                                        .font(.body)
                                                        .lineLimit(isExpanded ? nil : 1)
                                                        .padding(.leading, 8)
                                                        .contentShape(Rectangle())
                                                        .onTapGesture {
                                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                                if isExpanded {
                                                                    expandedDefinitions.remove(definitionId)
                                                                } else {
                                                                    expandedDefinitions.insert(definitionId)
                                                                }
                                                            }
                                                        }
                                                }
                                            }
                                        }
                                        .padding(.bottom, 4)
                                    }
                                }
                                
                                Divider()
                                    .padding(.vertical, 4)
                            }
                            .contentShape(Rectangle())
                            .onLongPressGesture {
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                                
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    toggleAllSourcesForTerm(entry.term, reading: entry.reading)
                                }
                            }
                        }
                        
                        // Show "Show More" button if there are more entries
                        if !showingAllEntries && mergedEntries.count > initialEntriesLimit {
                            VStack(spacing: 8) {
                                Divider()
                                    .padding(.horizontal)
                                
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showingAllEntries = true
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "chevron.down")
                                            .font(.caption)
                                        Text("Show \(mergedEntries.count - initialEntriesLimit) more entries")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color.blue.opacity(0.1))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Text("Showing first \(min(initialEntriesLimit, mergedEntries.count)) of \(mergedEntries.count) entries")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        
                        // Show "Show Less" button if showing all entries and there are many
                        if showingAllEntries && mergedEntries.count > initialEntriesLimit {
                            VStack(spacing: 8) {
                                Divider()
                                    .padding(.horizontal)
                                
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showingAllEntries = false
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "chevron.up")
                                            .font(.caption)
                                        Text("Show fewer entries")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.gray)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color.gray.opacity(0.1))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Text("Showing all \(mergedEntries.count) entries")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: UIScreen.main.bounds.height * 0.4) // 40% of screen height
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding(.horizontal, 24) // Reduced from 32 to make it wider
        .overlay(
            ZStack {
                // Existing Anki success overlay
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
                
                // New Save success overlay
                if showSaveSuccess {
                    VStack {
                        Text("Saved to Vocabulary!")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                            .padding()
                            .transition(.scale.combined(with: .opacity))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(.spring(), value: showSaveSuccess)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                showSaveSuccess = false
                            }
                        }
                    }
                }
            }
        )
        .alert("Word Already Saved", isPresented: $showDuplicateAlert) {
            Button("Save Anyway") {
                if let entry = pendingEntryToSave {
                    saveWordToVocabulary(entry)
                }
                pendingEntryToSave = nil
            }
            Button("Delete", role: .destructive) {
                if let entry = pendingEntryToSave,
                   let existingWord = wordsManager.getSavedWord(for: entry.term, reading: entry.reading) {
                    wordsManager.deleteWord(with: existingWord.id)
                }
                pendingEntryToSave = nil
            }
            Button("Cancel", role: .cancel) {
                pendingEntryToSave = nil
            }
        } message: {
            Text("This word is already in your Saved Words. What would you like to do?")
        }
        .sheet(isPresented: $showingAnkiSettings) {
            NavigationView {
                AnkiSettingsView()
                    .navigationTitle("Anki Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(trailing: 
                        Button("Done") {
                            showingAnkiSettings = false
                        }
                    )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    // Simple center positioning
    // The popup will be centered on screen by the parent view
    
    // MARK: - Helper Functions
    
    
    private func toggleAllSourcesForTerm(_ term: String, reading: String) {
        // Get all available sources for this term-reading combination
        let entriesBySource = Dictionary(grouping: getAllEntriesForTerm(term, reading: reading, from: matches)) { $0.source }
        let sourceIds = entriesBySource.keys.map { "\(term)_\(reading)_\($0)" }
        
        // Check if any sources are currently expanded (not collapsed)
        let hasExpandedSources = sourceIds.contains { !collapsedSources.contains($0) }
        
        if hasExpandedSources {
            // If any are expanded, collapse all
            sourceIds.forEach { collapsedSources.insert($0) }
        } else {
            // If all are collapsed, expand all
            sourceIds.forEach { collapsedSources.remove($0) }
        }
    }
    
    private func groupAndMergeEntries(_ entries: [DictionaryEntry]) -> [DictionaryEntry] {
        // Group entries by term-reading combination, keeping one representative per group
        let groupedEntries = Dictionary(grouping: entries) { entry in
            "\(entry.term)-\(entry.reading)"
        }
        
        var processedKeys = Set<String>()
        var mergedEntries: [DictionaryEntry] = []
        
        for entry in entries {
            let groupKey = "\(entry.term)-\(entry.reading)"
            
            if !processedKeys.contains(groupKey) {
                processedKeys.insert(groupKey)
                
                // Use the first entry as representative, but the actual meanings will be displayed grouped by source
                mergedEntries.append(entry)
            }
        }
        
        // Now apply post-grouping sorting to fix just the JMnedict and no-reading issues
        return mergedEntries.sorted { first, second in
            // 1. Prioritize entries with readings over no reading
            let firstHasReading = !first.reading.isEmpty && first.reading != first.term
            let secondHasReading = !second.reading.isEmpty && second.reading != second.term
            if firstHasReading != secondHasReading {
                return firstHasReading
            }
            
            // 2. Among entries with readings, prioritize non-JMnedict entries
            if firstHasReading && secondHasReading {
                let firstIsJMnedict = isJMnedictEntry(first)
                let secondIsJMnedict = isJMnedictEntry(second)
                if firstIsJMnedict != secondIsJMnedict {
                    return !firstIsJMnedict
                }
            }
            
            // 3. Preserve original order for everything else
            return false
        }
    }
    
    private func isJMnedictEntry(_ entry: DictionaryEntry) -> Bool {
        // Check if this term-reading combination ONLY has JMnedict definitions
        let allEntries = getAllEntriesForTerm(entry.term, reading: entry.reading, from: matches)
        let entriesBySource = Dictionary(grouping: allEntries) { $0.source }
        
        // Check if we have any non-JMnedict sources
        for (source, _) in entriesBySource {
            if source == "jmdict" || source == "obunsha" {
                // Built-in dictionary sources - not JMnedict-only
                return false
            } else if source.hasPrefix("imported_") {
                let importedId = source.replacingOccurrences(of: "imported_", with: "")
                if let uuid = UUID(uuidString: importedId) {
                    let importedDictionaries = DictionaryImportManager.shared.getImportedDictionaries()
                    if let dict = importedDictionaries.first(where: { $0.id == uuid }) {
                        if !dict.title.lowercased().contains("jmnedict") {
                            // Non-JMnedict imported dictionary - not JMnedict-only
                            return false
                        }
                    }
                }
            }
        }
        
        // If we get here, all sources are JMnedict
        return true
    }
    
    private func exportToAnki(_ entry: DictionaryEntry) {
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
        
        // Find all entries for this word/reading combination from matches
        let wordEntries = matches.flatMap { match in
            match.entries.filter { $0.term == entry.term && $0.reading == entry.reading }
        }
        
        // Use the new exportWordToAnki method
        AnkiExportService.shared.exportWordToAnki(
            word: entry.term,
            reading: entry.reading,
            entries: wordEntries,
            sentence: sentenceContext,
            pitchAccents: entry.pitchAccents,
            sourceView: topViewController,
            completion: { success in
                if success {
                    withAnimation {
                        showAnkiSuccess = true
                        
                        // Hide success message after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            withAnimation {
                                showAnkiSuccess = false
                            }
                        }
                    }
                }
            }
        )
    }
    
    private func handleSaveWordToVocabulary(_ entry: DictionaryEntry) {
        // Check if the word with this specific reading is already saved
        if wordsManager.isWordSaved(entry.term, reading: entry.reading) {
            // Show confirmation alert
            pendingEntryToSave = entry
            showDuplicateAlert = true
        } else {
            // Word with this reading is not saved yet, save it directly
            saveWordToVocabulary(entry)
        }
    }
    
    private func saveWordToVocabulary(_ entry: DictionaryEntry) {
        // Create a new SavedWord
        let newWord = SavedWord(
            word: entry.term,
            reading: entry.reading,
            definitions: entry.meanings,
            sentence: sentenceContext,
            sourceBook: bookTitle,
            timeAdded: Date(),
            pitchAccents: entry.pitchAccents // Include pitch accent data
        )
        
        // Add to saved words manager
        wordsManager.addWord(newWord)
        
        // Show success message
        withAnimation {
            showSaveSuccess = true
            
            // Hide success message after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showSaveSuccess = false
                }
            }
        }
    }
    
    // MARK: - Imported Dictionary Helpers
    
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
    
    private func getImportedDictionaryColor(source: String) -> Color {
        // Assign colors based on stable hash of the source string for consistency
        let availableColors: [Color] = [.purple, .pink, .indigo, .teal, .cyan, .mint, .brown]
        
        // Use a simple stable hash based on string content
        let hash = source.unicodeScalars.reduce(0) { result, scalar in
            return result &+ Int(scalar.value)
        }
        
        return availableColors[abs(hash) % availableColors.count]
    }
    
    // MARK: - Source Display Helpers
    
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
    
    private func getAllEntriesForTerm(_ term: String, reading: String, from matches: [DictionaryMatch]) -> [DictionaryEntry] {
        return matches.flatMap { $0.entries }.filter { $0.term == term && $0.reading == reading }
    }
    
    @ViewBuilder
    private func getDictionarySourceBadge(for source: String) -> some View {
        let color = getDictionaryColor(for: source)
        
        if source == "obunsha" {
            Text("旺文社")
                .font(.caption2)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .cornerRadius(4)
        } else if source == "jmdict" {
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
        }
    }
    
    private func getDictionaryColor(for source: String) -> Color {
        return DictionaryColorProvider.shared.getColor(for: source)
    }
    
}
