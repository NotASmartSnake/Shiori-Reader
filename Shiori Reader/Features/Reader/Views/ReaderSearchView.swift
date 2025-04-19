//
//  EnhancedSearchView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/4/25.
//

import SwiftUI

struct ReaderSearchView: View {
    @ObservedObject var viewModel: ReaderSearchViewModel
    @Binding var isShowing: Bool
    @State private var viewVisible: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search bar and done button
            HStack {
                SearchBar(
                    text: Binding(
                        get: { viewModel.query },
                        set: { viewModel.search(with: $0) }
                    ),
                    onSearchButtonClicked: {
                        if !viewModel.query.isEmpty {
                            viewModel.search(with: viewModel.query)
                        }
                    }
                )
                
                Button(action: {
                    isShowing = false
                }) {
                    Text("Done")
                        .foregroundColor(.blue)
                }
                .padding(.trailing)
            }
            .padding(.top)
            
            // Search mode selection for Japanese text
            if JapaneseSearchHelper.shared.containsJapanese(viewModel.query) {
                Picker("Search Mode", selection: Binding(
                    get: { viewModel.searchMode },
                    set: { viewModel.setSearchMode($0) }
                )) {
                    Text("Standard").tag(ReaderSearchViewModel.SearchMode.normal)
                    Text("Deinflect").tag(ReaderSearchViewModel.SearchMode.deinflect)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 8)
                
                Text("Deinflect mode searches for dictionary forms of words")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }
            
            Divider()
                .padding(.top, 8)
            
            // Results section
            if viewModel.isSearching {
                ProgressView()
                    .padding()
                Spacer()
            } else if viewModel.results.isEmpty && !viewModel.query.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                        .padding()
                    Text("No results found")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    List(viewModel.results.indices, id: \.self) { index in
                        let locator = viewModel.results[index]

                        // Use the extracted SearchResultRow
                        SearchResultRow(
                            locator: locator,
                            index: index,
                            isSelected: viewModel.selectedIndex == index,
                            colorScheme: colorScheme,
                            action: {
                                // Define the action to take on tap
                                viewModel.selectSearchResultCell(locator: locator, index: index)
                                isShowing = false // Close search sheet after selection
                            }
                        )
                        .onAppear { // Keep onAppear here for pagination
                            if index == viewModel.results.count - 5 && viewModel.hasMoreResults {
                                viewModel.loadNextPage()
                            }
                        }
                        .id(index)
                    }
                    .listStyle(PlainListStyle())
                    .onChange(of: viewVisible) { oldValue, newValue in
                        if newValue, let lastSelectedIndex = viewModel.selectedIndex {
                            proxy.scrollTo(lastSelectedIndex, anchor: .top)
                        }
                    }
                }
            }
        }
        .onAppear {
            viewVisible = true
        }
        .onDisappear {
            viewVisible = false
        }
    }
}
