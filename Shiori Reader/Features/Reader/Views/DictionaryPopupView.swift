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
    @EnvironmentObject private var wordsManager: SavedWordsManager
    
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
                        // Flatten all entries from all matches into a single list
                        ForEach(matches.flatMap { $0.entries }, id: \.id) { entry in
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
                                        
                                        // Main term
                                        Text(entry.term)
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    // Pitch accent graphs right after the word/reading (left-aligned)
                                    if entry.hasPitchAccent, let pitchAccents = entry.pitchAccents {
                                        let _ = print("🗓️ [POPUP DEBUG] Entry: \(entry.term) (\(entry.reading))")
                                        let _ = print("🗓️ [POPUP DEBUG] All pitch accents: \(pitchAccents.accents.map { "\($0.term) (\($0.reading)) - [\($0.pitchAccent)]" })")
                                        
                                        // Filter to only show graphs that match both term AND reading
                                        let matchingAccents = pitchAccents.accents.filter { accent in
                                            accent.term == entry.term && accent.reading == entry.reading
                                        }
                                        
                                        let _ = print("🗓️ [POPUP DEBUG] Matching accents: \(matchingAccents.map { "\($0.term) (\($0.reading)) - [\($0.pitchAccent)]" })")
                                        
                                        if !matchingAccents.isEmpty {
                                            // Show matching graphs side by side
                                            HStack(alignment: .top, spacing: 8) {
                                                ForEach(Array(matchingAccents.prefix(3)), id: \.id) { accent in
                                                    SimplePitchAccentGraphView(
                                                        word: accent.term,
                                                        reading: accent.reading,
                                                        pitchValue: accent.pitchAccent
                                                    )
                                                }
                                            }
                                            .padding(.leading, 12) // Small gap from the word
                                        } else {
                                            let _ = print("⚠️ [POPUP DEBUG] No matching accents found after filtering!")
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
                                
                                // Display meaning entries with expandable functionality
                                ForEach(entry.meanings.indices, id: \.self) { index in
                                    let definitionId = "\(entry.id)_\(index)" // Unique ID for each definition
                                    let isExpanded = expandedDefinitions.contains(definitionId)
                                    
                                    Text(entry.meanings[index])
                                        .font(.body)
                                        .lineLimit(isExpanded ? nil : 1) // Show 1 line when collapsed, unlimited when expanded
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
    
    private func exportToAnki(_ entry: DictionaryEntry) {
        // Check if Anki is configured
        if !AnkiExportService.shared.isConfigured() {
            // Show the settings sheet
            showingAnkiSettings = true
            return
        }
        
        AnkiExportService.shared.addVocabularyCard(
            word: entry.term,
            reading: entry.reading,
            definition: entry.meanings.joined(separator: "; "),
            sentence: sentenceContext,
            pitchAccents: entry.pitchAccents,
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
            definition: entry.meanings.joined(separator: "; "),
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
