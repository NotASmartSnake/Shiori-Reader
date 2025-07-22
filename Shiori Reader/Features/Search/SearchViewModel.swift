import Foundation
import Combine

class SearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [DictionaryEntry] = []
    @Published var isSearching: Bool = false
    @Published var selectedEntry: DictionaryEntry?
    @Published var showingAllResults: Bool = false
    
    private var allSearchResults: [DictionaryEntry] = [] // Store all results
    let initialResultsLimit = 30
    
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
            self.allSearchResults = []
            self.isSearching = false
            self.showingAllResults = false
            return
        }
        
        // Set searching state
        self.isSearching = true
        self.showingAllResults = false
        
        // Create a new search task
        let task = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // Decide which search method to use based on query
            let hasJapaneseCharacters = query.containsJapaneseCharacters()
            
            var results: [DictionaryEntry] = []
            
            if hasJapaneseCharacters {
                // Use the same lookup method as ReaderView for consistency
                let exactResults = DictionaryManager.shared.lookupWithDeinflection(word: query)
                if !exactResults.isEmpty {
                    results = exactResults
                } else {
                    // Try prefix search if exact match fails - include both built-in and imported dictionaries
                    let builtInResults = DictionaryManager.shared.searchByPrefix(prefix: query, limit: 50)
                    let importedResults = DictionaryManager.shared.searchImportedDictionariesByPrefix(prefix: query, limit: 50)
                    results = builtInResults + importedResults
                }
                
                results = Array(results.prefix(100)) // Limit total results
            } else {
                // Use meaning search for English - only built-in dictionaries support meaning search
                results = DictionaryManager.shared.searchByMeaning(text: query, limit: 100)
            }
            
            let groupedResults = self.groupAndMergeEntries(results)
            
            DispatchQueue.main.async {
                self.allSearchResults = groupedResults
                self.updateDisplayedResults()
                self.isSearching = false
            }
        }
        
        searchTask = task
        DispatchQueue.global(qos: .userInitiated).async(execute: task)
    }
    
    func showAllResults() {
        showingAllResults = true
        updateDisplayedResults()
    }
    
    func showLessResults() {
        showingAllResults = false
        updateDisplayedResults()
    }
    
    private func updateDisplayedResults() {
        if showingAllResults {
            searchResults = allSearchResults
        } else {
            searchResults = Array(allSearchResults.prefix(initialResultsLimit))
        }
    }
    
    var hasMoreResults: Bool {
        return allSearchResults.count > initialResultsLimit && !showingAllResults
    }
    
    var remainingResultsCount: Int {
        return max(0, allSearchResults.count - initialResultsLimit)
    }
    
    var totalResultsCount: Int {
        return allSearchResults.count
    }
    
    func clearSearch() {
        searchText = ""
        searchResults = []
        allSearchResults = []
        showingAllResults = false
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
                    
                    // Mark as combined if we have multiple different sources
                    let uniqueSources = Array(Set(allSources))
                    let combinedSource = uniqueSources.count > 1 ? "combined" : entry.source
                    
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
