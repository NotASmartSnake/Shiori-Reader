//
//  SavedWordsView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct SavedWordsView: View {
    @EnvironmentObject private var wordsManager: SavedWordsManager
    @State private var searchText = ""
    @State private var showSortOptions = false
    @State private var sortOption = SortOption.dateAdded
    @State private var showDeleteAllConfirmation = false
    @State private var showExportSuccess = false
    @State private var showExportOptions = false
    @State private var exportFilename = ""
    @State private var exportedFileURL: URL?
    
    enum SortOption {
        case dateAdded
        case word
        case book
    }
    
    var filteredWords: [SavedWord] {
        if searchText.isEmpty {
            return sortedWords
        } else {
            return sortedWords.filter { word in
                word.word.localizedCaseInsensitiveContains(searchText) ||
                word.reading.localizedCaseInsensitiveContains(searchText) ||
                word.definition.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var sortedWords: [SavedWord] {
        switch sortOption {
        case .dateAdded:
            return wordsManager.savedWords.sorted(by: { $0.timeAdded > $1.timeAdded })
        case .word:
            return wordsManager.savedWords.sorted(by: { $0.word < $1.word })
        case .book:
            return wordsManager.savedWords.sorted(by: { $0.sourceBook < $1.sourceBook })
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundColor").ignoresSafeArea(edges: .all)
                
                if wordsManager.savedWords.isEmpty {
                    ScrollView {
                        EmptySavedWordsView()
                            .padding(.horizontal)
                            .padding(.vertical, 50)
                    }
                } else {
                    VStack(spacing: 0) {
                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            
                            TextField("Search saved words", text: $searchText)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.top, 5)
                        
                        // Sort menu
                        HStack {
                            Text("Sort by:")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Picker("Sort by", selection: $sortOption) {
                                Text("Date Added").tag(SortOption.dateAdded)
                                Text("Word").tag(SortOption.word)
                                Text("Book").tag(SortOption.book)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.leading, 5)
                        }
                        .padding(.horizontal)
                        .padding(.top, 5)
                        
                        // List of saved words
                        List {
                            ForEach(filteredWords) { word in
                                NavigationLink(destination: SavedWordDetailView(word: word)) {
                                    SavedWordRow(word: word)
                                }
                            }
                            .onDelete { indexSet in
                                let indices = indexSet.map { filteredWords[$0] }
                                indices.forEach { word in
                                    if let index = wordsManager.savedWords.firstIndex(where: { $0.id == word.id }) {
                                        wordsManager.savedWords.remove(at: index)
                                    }
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                        
                        Spacer(minLength: 50)
                    }
                }
            }
            .navigationTitle("Saved Words")
            .onAppear {
                // Refresh from repository when view appears
                wordsManager.refreshWords()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: {
                            exportToCSV()
                        }) {
                            Label("Export to CSV", systemImage: "square.and.arrow.up")
                        }
                        .disabled(wordsManager.savedWords.isEmpty)
                        
                        Button(role: .destructive, action: {
                            showDeleteAllConfirmation = true
                        }) {
                            Label("Delete All", systemImage: "trash")
                        }
                        .disabled(wordsManager.savedWords.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Delete All Words", isPresented: $showDeleteAllConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All", role: .destructive) {
                    wordsManager.deleteAllWords()
                }
            } message: {
                Text("Are you sure you want to delete all saved words? This action cannot be undone.")
            }
            .alert("Export Successful", isPresented: $showExportSuccess) {
                Button("OK", role: .cancel) { }
                Button("Share", role: .none) {
                    showExportOptions = true
                }
            } message: {
                Text("Your vocabulary has been exported to:\n\(exportFilename)")
            }
            .sheet(isPresented: $showExportOptions) {
                if let fileURL = exportedFileURL {
                    ShareSheet(items: [fileURL])
                }
            }
        }
    }
    
    // Function to export words to CSV using the manager
    private func exportToCSV() {
        // Use the manager to export the CSV
        if let (fileURL, filename) = wordsManager.exportToCSV() {
            // Store filename and URL for success message and sharing
            exportFilename = filename
            exportedFileURL = fileURL
            showExportSuccess = true
        }
    }
}

struct SavedWordRow: View {
    let word: SavedWord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(word.word)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if !word.reading.isEmpty && word.reading != word.word {
                    Text("「\(word.reading)」")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(word.sourceBook)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray6))
                    .cornerRadius(4)
            }
            
            Text(word.definition)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

// ShareSheet to handle file sharing
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nothing to update
    }
}

#Preview {
    SavedWordsView()
        .environmentObject(SavedWordsManager())
}
