//
//  EnhancedSearchViewModel.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/4/25.
//

import Foundation
import ReadiumShared

@MainActor
class ReaderSearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [Locator] = []
    @Published var isSearching: Bool = false // True during initial search OR loading next page
    @Published var selectedIndex: Int? = nil
    @Published var searchMode: SearchMode = .normal
    @Published private(set) var hasMoreResults: Bool = false // Initially false until a search succeeds

    private let publication: Publication
    private weak var readiumViewModel: ReaderViewModel?

    // Task for the initial search call
    private var initialSearchTask: Task<Void, Never>? {
        didSet { oldValue?.cancel() }
    }
    // Task for loading the next page
    private var loadNextPageTask: Task<Void, Never>? {
        didSet { oldValue?.cancel() }
    }
    // Store the iterator to fetch subsequent pages
    private var currentIterator: SearchIterator?

    enum SearchMode {
        case normal
        case deinflect
        case fuzzy
    }

    init(publication: Publication, readiumViewModel: ReaderViewModel?) {
        self.publication = publication
        self.readiumViewModel = readiumViewModel
    }

    // --- Public Methods ---

    func search(with query: String) {
        self.query = query
        resetSearch() // Reset state before starting

        if query.isEmpty {
            return // Don't search empty query
        }

        isSearching = true // Indicate initial search activity

        initialSearchTask = Task {
            // Determine the actual query based on mode
            let effectiveQuery = getEffectiveQuery(query)

            // Perform the initial search call to get the iterator
            let result = await publication.search(query: effectiveQuery) // No options needed here for initial call? Check API.

            // Check for cancellation before updating state
            guard !Task.isCancelled else {
                print("Search cancelled for query: \(query)")
                return
            }

            switch result {
            case .success(let iterator):
                self.currentIterator = iterator
                self.hasMoreResults = true // Assume there might be results
                self.isSearching = false // Initial search done, ready to load pages
                loadNextPage() // Load the *first* page of results

            case .failure(let error):
                print("Initial search failed: \(error)")
                handleSearchError(error)
            }
        }
    }

    func loadNextPage() {
        // Only load if we have an iterator, more results are expected, and not already loading a page
        guard let iterator = currentIterator, hasMoreResults, loadNextPageTask == nil else {
            // If already loading, or no iterator/more results, do nothing
            return
        }

        isSearching = true // Indicate loading next page activity

        loadNextPageTask = Task {
            let result = await iterator.next() // Fetch the next chunk

            // Check for cancellation before updating state
            guard !Task.isCancelled else {
                print("Load next page cancelled.")
                // Reset state partially? Or let resetSearch handle it?
                self.isSearching = false // Ensure searching stops
                self.loadNextPageTask = nil
                return
            }

            switch result {
            case .success(let collection):
                if let locators = collection?.locators, !locators.isEmpty {
                    self.results.append(contentsOf: locators)
                    // Assuming the iterator internally knows if there's more.
                    // If `collection` was nil or empty, we've reached the end.
                    self.hasMoreResults = true // We got results, maybe more? API might need refinement here.
                } else {
                    // No more results from the iterator
                    self.hasMoreResults = false
                }
                self.isSearching = false // Done loading this page
                self.loadNextPageTask = nil // Allow next load

            case .failure(let error):
                print("Error loading next search page: \(error)")
                handleSearchError(error) // Handle error state
                self.loadNextPageTask = nil // Allow potential retry?
            }
        }
    }

    func selectSearchResultCell(locator: Locator, index: Int) {
        selectedIndex = index
        // Request navigation via the ReadiumBookViewModel
        readiumViewModel?.requestNavigation(to: locator)
    }

    func setSearchMode(_ mode: SearchMode) {
        guard self.searchMode != mode else { return } // No change needed
        self.searchMode = mode
        if !query.isEmpty {
            search(with: query) // Restart search with the new mode
        }
    }

    func cancelSearch() {
        resetSearch()
    }

    // --- Private Helper Methods ---

    private func resetSearch() {
        initialSearchTask?.cancel()
        loadNextPageTask?.cancel()
        initialSearchTask = nil
        loadNextPageTask = nil
        currentIterator = nil
        results = []
        selectedIndex = nil
        isSearching = false
        hasMoreResults = false // Reset until a successful search starts
        // query is kept as is
    }

    private func handleSearchError(_ error: SearchError) {
        // You might want specific error handling/messaging here
        isSearching = false
        hasMoreResults = false
        // Optionally set an error message property to display in the UI
        // @Published var searchError: String? = nil
        // self.searchError = error.localizedDescription
    }

    /// Determines the actual query string based on the search mode.
    private func getEffectiveQuery(_ query: String) -> String {
        if JapaneseSearchHelper.shared.containsJapanese(query) && searchMode == .deinflect {
            // Try to get the primary dictionary form (lemma) of the main word
            if let primaryForm = JapaneseSearchHelper.shared.getPrimaryDictionaryForm(query), primaryForm != query {
                 // Use the specific lemma if it was found and is different from the input
                 print("DEBUG [ReaderSearchViewModel]: Using deinflected primary form for search: '\(primaryForm)' (from query '\(query)')")
                 return primaryForm
            } else {
                 // Fallback: If no useful primary form found, or if input was already base form,
                 // search using the original user query.
                 print("DEBUG [ReaderSearchViewModel]: No different primary form found, using original query for search: '\(query)'")
                 return query
            }
        } else {
            // Standard search mode, use the query as is
            return query
        }
    }
}
