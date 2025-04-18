//
//  SearchView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//


import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var wordsManager: SavedWordsManager
    @StateObject private var viewModel = SearchViewModel()
    @State private var showingEntryDetail = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundColor").ignoresSafeArea(edges: .all)
                
                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search Japanese or English", text: $viewModel.searchText)
                            .disableAutocorrection(true)
                            .autocapitalization(.none)
                        
                        if !viewModel.searchText.isEmpty {
                            Button(action: {
                                viewModel.clearSearch()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top, 5)
                    
                    if viewModel.isSearching {
                        // Loading indicator
                        ProgressView()
                            .padding()
                        
                        Spacer()
                    } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
                        // No results message
                        VStack(spacing: 15) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No results found")
                                .font(.headline)
                            Text("Try a different search term or check your spelling")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 50)
                        .frame(maxWidth: .infinity)
                        
                        Spacer()
                    } else if viewModel.searchText.isEmpty {
                        // Initial state
                        VStack(spacing: 20) {
                            Image(systemName: "character.book.closed")
                                .font(.system(size: 70))
                                .foregroundColor(.gray.opacity(0.7))
                                .padding(.top, 50)
                            
                            Text("Search for Japanese words")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Enter Japanese characters or English meanings")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            Spacer()
                        }
                    } else {
                        // Search results list
                        List {
                            ForEach(viewModel.searchResults, id: \.id) { entry in
                                Button(action: {
                                    viewModel.selectedEntry = entry
                                    showingEntryDetail = true
                                }) {
                                    DictionaryEntryRow(entry: entry)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
            .navigationTitle("Dictionary")
            .sheet(isPresented: $showingEntryDetail) {
                if let entry = viewModel.selectedEntry {
                    EntryDetailView(entry: entry)
                        .environmentObject(wordsManager)
                }
            }
        }
    }
}

#Preview {
    SearchView()
        .environmentObject(SavedWordsManager())
}
