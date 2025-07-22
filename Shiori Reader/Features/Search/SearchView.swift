
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
                    // Search bar (fixed at top)
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
                    
                    // Scrollable content area
                    if viewModel.searchResults.isEmpty || viewModel.isSearching {
                        ScrollView {
                            VStack(spacing: 0) {
                                if viewModel.isSearching {
                                    // Loading indicator
                                    ProgressView()
                                        .padding()
                                    
                                    Spacer(minLength: 400)
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
                                    
                                    Spacer(minLength: 400)
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
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 400)
                                }
                            }
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
                            
                            // Show "Show More" button if there are more results
                            if viewModel.hasMoreResults {
                                VStack(spacing: 12) {
                                    Divider()
                                        .padding(.horizontal)
                                    
                                    Button(action: {
                                        viewModel.showAllResults()
                                    }) {
                                        HStack {
                                            Image(systemName: "chevron.down")
                                                .font(.caption)
                                            Text("Show \(viewModel.remainingResultsCount) more results")
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
                                    
                                    Text("Showing first \(viewModel.searchResults.count) of \(viewModel.totalResultsCount) results")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets())
                            }
                            
                            // Show "Show Less" button if showing all results and there are many
                            if viewModel.showingAllResults && viewModel.totalResultsCount > viewModel.initialResultsLimit {
                                VStack(spacing: 12) {
                                    Divider()
                                        .padding(.horizontal)
                                    
                                    Button(action: {
                                        viewModel.showLessResults()
                                    }) {
                                        HStack {
                                            Image(systemName: "chevron.up")
                                                .font(.caption)
                                            Text("Show fewer results")
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
                                    
                                    Text("Showing all \(viewModel.totalResultsCount) results")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets())
                            }
                            
                            // Add bottom spacer to prevent tab bar overlap
                            Color.clear
                                .frame(height: 80)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
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
