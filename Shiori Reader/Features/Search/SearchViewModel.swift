//
//  SearchViewModel.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/21/25.
//

import Foundation
import Combine

class SearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [DictionaryEntry] = []
    @Published var isSearching: Bool = false
    @Published var selectedEntry: DictionaryEntry?
    
    private var searchTask: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Set up a debounce on the search text
        $searchText
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] text in
                self?.performSearch(query: text)
            }
            .store(in: &cancellables)
    }
    
    func performSearch(query: String) {
        // Cancel any existing search task
        searchTask?.cancel()
        
        // Reset search results if query is empty
        guard !query.isEmpty else {
            self.searchResults = []
            self.isSearching = false
            return
        }
        
        // Set searching state
        self.isSearching = true
        
        // Create a new search task
        let task = DispatchWorkItem { [weak self] in
            // Decide which search method to use based on query
            let hasJapaneseCharacters = query.containsJapaneseCharacters()
            
            if hasJapaneseCharacters {
                // Use direct lookup or prefix search for Japanese
                let exactResults = DictionaryManager.shared.lookupWithDeinflection(word: query)
                if !exactResults.isEmpty {
                    DispatchQueue.main.async {
                        self?.searchResults = self?.groupAndMergeEntries(exactResults) ?? []
                        self?.isSearching = false
                    }
                } else {
                    // Try prefix search if exact match fails
                    let prefixResults = DictionaryManager.shared.searchByPrefix(prefix: query, limit: 50)
                    DispatchQueue.main.async {
                        self?.searchResults = self?.groupAndMergeEntries(prefixResults) ?? []
                        self?.isSearching = false
                    }
                }
            } else {
                // Use meaning search for English
                let meaningResults = DictionaryManager.shared.searchByMeaning(text: query, limit: 50)
                DispatchQueue.main.async {
                    self?.searchResults = self?.groupAndMergeEntries(meaningResults) ?? []
                    self?.isSearching = false
                }
            }
        }
        
        searchTask = task
        DispatchQueue.global(qos: .userInitiated).async(execute: task)
    }
    
    func clearSearch() {
        searchText = ""
        searchResults = []
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
                        source: combinedSource
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
    
}

// Helper extension to check for Japanese characters
extension String {
    func containsJapaneseCharacters() -> Bool {
        // Check for Hiragana, Katakana, or Kanji
        let pattern = "[\\p{Hiragana}\\p{Katakana}\\p{Han}]"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex?.firstMatch(in: self, options: [], range: range) != nil
    }
}
