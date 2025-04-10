//
//  SavedWordsView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//


import SwiftUI

struct SavedWordsView: View {
    @EnvironmentObject private var wordsManager: SavedWordsManager
    @State private var searchText = ""
    @State private var showSortOptions = false
    @State private var sortOption = SortOption.dateAdded
    
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
                                // Map the filtered indices to the original indices
                                let indices = indexSet.map { filteredWords[$0] }
                                indices.forEach { word in
                                    if let index = wordsManager.savedWords.firstIndex(where: { $0.id == word.id }) {
                                        wordsManager.savedWords.remove(at: index)
                                    }
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                        
                        // Spacer at the bottom for tab bar
                        Rectangle()
                            .frame(width: 0, height: 50)
                            .foregroundStyle(Color.clear)
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
                                // Export action
                            }) {
                                Label("Export to Anki", systemImage: "square.and.arrow.up")
                            }
                            
                            Button(role: .destructive, action: {
                                // Delete all action with confirmation
                                // Add confirmation dialog here
                            }) {
                                Label("Delete All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
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

#Preview {
    SavedWordsView()
        .environmentObject(SavedWordsManager())
}
