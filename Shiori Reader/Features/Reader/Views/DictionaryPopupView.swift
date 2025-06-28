//
//  DictionaryPopupView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/13/25.
//


import SwiftUI

struct DictionaryPopupView: View {
    let matches: [DictionaryMatch]
    let onDismiss: () -> Void
    let sentenceContext: String
    let bookTitle: String
    let fullText: String
    let currentOffset: Int // Track current offset
    let onCharacterSelected: (Int) -> Void
    
    @State private var showAnkiSuccess = false
    @State private var showSaveSuccess = false
    @State private var showingAnkiSettings = false
    @State private var showDuplicateAlert = false
    @State private var pendingEntryToSave: DictionaryEntry? = nil
    @State private var expandedDefinitions: Set<String> = [] // Track which definitions are expanded
    @State private var showingAllEntries = false // Track if showing all entries or just the first few
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
            .padding(0)
            
            // Character picker view
            if !fullText.isEmpty {
                CharacterPickerView(
                    currentText: fullText,
                    selectedOffset: currentOffset,
                    onCharacterSelected: { _, offset in
                        onCharacterSelected(offset)
                    }
                )
                .padding(.top, 8)
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
                                    // Term with furigana reading above it - gets layout priority
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
                                    .layoutPriority(1) // Give term highest priority
                                    .fixedSize(horizontal: false, vertical: true)
                                    
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
                                            .frame(maxWidth: 200) // Limit width so term gets priority
                                            .padding(.leading, 12) // Small gap from the word
                                            .layoutPriority(0) // Lower priority than term
                                        } else {
                                            let _ = print("⚠️ [POPUP DEBUG] No matching accents found after filtering!")
                                        }
                                    }
                                    
                                    Spacer(minLength: 8)
                                    
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
                                    .layoutPriority(1) // Also give buttons high priority
                                }
                                .padding(.vertical, 4)
                                
                                // Dictionary source badges and frequency data on their own line
                                HStack(spacing: 4) {
                                    // Frequency data first (if available)
                                    if let frequencyRank = entry.frequencyRankString {
                                        Text(frequencyRank)
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.green.opacity(0.2))
                                            .foregroundColor(.green)
                                            .cornerRadius(4)
                                    }
                                    
                                    if entry.source == "obunsha" {
                                        Text("旺文社")
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.orange.opacity(0.2))
                                            .foregroundColor(.orange)
                                            .cornerRadius(4)
                                    } else if entry.source == "jmdict" {
                                        Text("JMdict")
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.blue.opacity(0.2))
                                            .foregroundColor(.blue)
                                            .cornerRadius(4)
                                    } else if entry.source == "combined" {
                                        HStack(spacing: 4) {
                                            Text("JMdict")
                                                .font(.caption2)
                                                .padding(.horizontal, 3)
                                                .padding(.vertical, 1)
                                                .background(Color.blue.opacity(0.2))
                                                .foregroundColor(.blue)
                                                .cornerRadius(3)
                                            Text("旺文社")
                                                .font(.caption2)
                                                .padding(.horizontal, 3)
                                                .padding(.vertical, 1)
                                                .background(Color.orange.opacity(0.2))
                                                .foregroundColor(.orange)
                                                .cornerRadius(3)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.bottom, 4)
                                
                                // Display meaning entries with expandable functionality
                                ForEach(entry.meanings.indices, id: \.self) { index in
                                    let definitionId = "\(entry.id)_\(index)" // Unique ID for each definition
                                    let isExpanded = expandedDefinitions.contains(definitionId)
                                    
                                    // For Obunsha entries or combined entries, show only 2 lines initially; for JMdict, show 1 line
                                    let lineLimit = if entry.source == "obunsha" || entry.source == "combined" {
                                        isExpanded ? nil : 2
                                    } else {
                                        isExpanded ? nil : 1
                                    }
                                    
                                    Text(entry.meanings[index])
                                        .font(.body)
                                        .lineLimit(lineLimit)
                                        .padding(.leading, 8)
                                        .contentShape(Rectangle()) // Make entire area tappable
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
                                
                                Divider()
                                    .padding(.vertical, 4)
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
                .padding(.top, 8)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(height: UIScreen.main.bounds.height * 0.4)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        .shadow(radius: 5)
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
    
    // MARK: - Helper Functions
    
    private func groupAndMergeEntries(_ entries: [DictionaryEntry]) -> [DictionaryEntry] {
        let groupedEntries = Dictionary(grouping: entries) { entry in
            "\(entry.term)-\(entry.reading)"
        }
        
        var processedKeys = Set<String>()
        var mergedEntries: [DictionaryEntry] = []
        
        for entry in entries {
            let groupKey = "\(entry.term)-\(entry.reading)"
            
            if !processedKeys.contains(groupKey) {
                processedKeys.insert(groupKey)
                
                if let groupEntries = groupedEntries[groupKey], groupEntries.count > 1 {
                    // Multiple entries with same term/reading - merge their meanings
                    let allMeanings = groupEntries.flatMap { $0.meanings }
                    let allSources = groupEntries.map { $0.source }
                    let combinedSource = allSources.contains("jmdict") && allSources.contains("obunsha") ? "combined" : entry.source
                    
                    let mergedEntry = DictionaryEntry(
                        id: "merged_\(groupKey)",
                        term: entry.term,
                        reading: entry.reading,
                        meanings: allMeanings,
                        meaningTags: entry.meaningTags,
                        termTags: entry.termTags,
                        score: entry.score,
                        rules: entry.rules,
                        transformed: entry.transformed,
                        transformationNotes: entry.transformationNotes,
                        popularity: entry.popularity,
                        source: combinedSource,
                        frequencyData: entry.frequencyData
                    )
                    mergedEntries.append(mergedEntry)
                } else {
                    // Single entry - use as is
                    mergedEntries.append(entry)
                }
            }
        }
        
        return mergedEntries
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
        
        // Create save callback that calls the same save method as the bookmark button
        let saveCallback = {
            self.saveWordToVocabulary(entry)
        }
        
        // Use the new exportWordToAnki method with save callback
        AnkiExportService.shared.exportWordToAnki(
            word: entry.term,
            reading: entry.reading,
            entries: wordEntries,
            sentence: sentenceContext,
            pitchAccents: entry.pitchAccents,
            sourceView: topViewController,
            onSaveToVocab: saveCallback,
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
        // Format definitions with source title and proper newlines
        let formattedDefinitions: [String]
        
        if entry.source == "combined" {
            // For combined entries, we need to get the original separate entries to properly format
            let wordEntries = matches.flatMap { match in
                match.entries.filter { $0.term == entry.term && $0.reading == entry.reading }
            }
            
            // Group by source and format
            let groupedBySource = Dictionary(grouping: wordEntries) { $0.source }
            var sourceSections: [String] = []
            
            // Process in preferred order: jmdict first, then obunsha, then others
            let sourceOrder = ["jmdict", "obunsha"] + groupedBySource.keys.filter { !["jmdict", "obunsha"].contains($0) }.sorted()
            
            for source in sourceOrder {
                guard let entries = groupedBySource[source], !entries.isEmpty else { continue }
                let sourceTitle = source == "jmdict" ? "JMdict" : (source == "obunsha" ? "旺文社" : source.capitalized)
                let allMeanings = entries.flatMap { $0.meanings }
                let definitionsText = allMeanings.joined(separator: "\n")
                sourceSections.append("\(sourceTitle)\n\(definitionsText)")
            }
            
            formattedDefinitions = sourceSections
        } else {
            // Single source entry
            let sourceTitle = entry.source == "jmdict" ? "JMdict" : (entry.source == "obunsha" ? "旺文社" : entry.source.capitalized)
            let definitionsText = entry.meanings.joined(separator: "\n")
            formattedDefinitions = ["\(sourceTitle)\n\(definitionsText)"]
        }
        
        // Create a new SavedWord
        let newWord = SavedWord(
            word: entry.term,
            reading: entry.reading,
            definitions: formattedDefinitions,
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
}
