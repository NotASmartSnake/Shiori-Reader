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
    @State private var showAnkiSuccess = false
    @State private var showingAnkiSettings = false
    
    var body: some View {
        VStack(alignment: .leading) {
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
            
            if matches.isEmpty {
                Text("No definitions found.")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
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
                                
                                Spacer()
                                
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
                            .padding(.vertical, 4)
                            
                            // Display meaning entries
                            ForEach(entry.meanings.indices, id: \.self) { index in
                                Text(entry.meanings[index])
                                    .font(.body)
                                    .padding(.leading, 8)
                            }
                            
                            Divider()
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(height: UIScreen.main.bounds.height * 0.4)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        .shadow(radius: 5)
        .overlay(
            showAnkiSuccess ?
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
                : nil
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
}



#Preview {
    let isReadingBook = IsReadingBook()
    return BookReaderView(book: Book(
        title: "実力至上主義者の教室",
        coverImage: "COTECover",
        readingProgress: 0.1,
        filePath: "hakomari.epub"
    ))
    .environmentObject(isReadingBook)
}

