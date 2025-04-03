//
//  EntryDetailView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/21/25.
//

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
            ZStack {
                Color("BackgroundColor").ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Word and reading
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
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        // Part of speech / Tags
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
                        
                        // Meanings
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Meanings")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            ForEach(entry.meanings.indices, id: \.self) { index in
                                HStack(alignment: .top) {
                                    Text("\(index + 1).")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    
                                    Text(entry.meanings[index])
                                        .font(.body)
                                }
                                .padding(.leading, 4)
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 30)
                        
                        // Save button
                        Button(action: {
                            // Create a new SavedWord
                            let newSavedWord = SavedWord(
                                word: entry.term,
                                reading: entry.reading,
                                definition: entry.meanings.joined(separator: "; "),
                                sentence: "", // Empty for now, user can add later
                                timeAdded: Date(),
                                sourceBook: "Search" // Indicate this was from search
                            )
                            
                            // Add to saved words
                            savedWordsManager.addWord(newSavedWord)
                            
                            showSavedConfirmation = true
                            
                            // Dismiss after delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                dismiss()
                            }
                        }) {
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
                            .background(Color.indigo)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Word Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay(
                ZStack {
                    // Saved confirmation overlay
                    if showSavedConfirmation {
                        VStack {
                            Text("Saved!")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.green)
                                .cornerRadius(8)
                                .shadow(radius: 3)
                        }
                        .frame(maxWidth: .infinity)
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(), value: showSavedConfirmation)
                    }
                    
                    // Anki success overlay
                    if showAnkiSuccess {
                        VStack {
                            Text("Added to Anki!")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.green)
                                .cornerRadius(8)
                                .shadow(radius: 3)
                        }
                        .frame(maxWidth: .infinity)
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
    }
    
    // Function to handle exporting to Anki
    private func exportToAnki() {
        // Check if Anki is configured
        if !AnkiExportService.shared.isConfigured() {
            // Show the settings sheet
            showingAnkiSettings = true
            return
        }
        
        // Export the word to Anki
        AnkiExportService.shared.addVocabularyCard(
            word: entry.term,
            reading: entry.reading,
            definition: entry.meanings.joined(separator: "; "),
            sentence: "", // No sentence from search results
            completion: { success in
                if success {
                    withAnimation {
                        showAnkiSuccess = true
                    }
                }
            }
        )
    }
}
