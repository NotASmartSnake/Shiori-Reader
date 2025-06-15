//
//  BookViewModel.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/3/25.
//

import Foundation
import Combine
import SwiftUI
import ReadiumShared
import ReadiumOPDS
import ReadiumStreamer
import ReadiumNavigator
import WebKit

@MainActor
class ReaderViewModel: ObservableObject {
    // Input
    @Published var book: Book

    // Readium core components
    private let publicationOpener: PublicationOpener
    private let assetRetriever: AssetRetriever

    // Published state for UI
    @Published private(set) var publication: Publication?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var initialLocation: Locator?
    @Published var errorMessage: String?
    @Published var preferences = EPUBPreferences() // Using new Preferences API
    @Published private(set) var tableOfContents: [ReadiumShared.Link] = []

    // Other state
    @Published var pendingNavigationLink: ReadiumShared.Link? = nil
    @Published var navigationRequest: Locator? = nil
    
    // Bookmark related properties
    @Published private(set) var bookmarks: [Bookmark] = []
    @Published private(set) var isCurrentLocationBookmarked: Bool = false
    
    // Dictionary related properties
    @Published var showDictionary = false
    @Published var selectedWord = ""
    @Published var fullTextForSelection = ""
    @Published var currentTextOffset = 0  // Track the current text offset
    @Published var clickedTextOffset = 0 // Tracks where in text the user clicked
    
    // Track both current chapter and total book progression
    @Published var currentChapterProgression: Double = 0.0
    @Published var totalBookProgression: Double = 0.0
    @Published var dictionaryMatches: [DictionaryMatch] = []
    @Published var currentSentenceContext: String = ""
    
    // Core Data repositories
    private let bookRepository = BookRepository()
    private let settingsRepository = SettingsRepository()
    private let bookmarkRepository = BookmarkRepository()

    private var cancellables = Set<AnyCancellable>()
    weak var navigatorController: EPUBNavigatorViewController?

    // MARK: - Initialization
    init(book: Book) {
        self.book = book

        let httpClient = DefaultHTTPClient()
        self.assetRetriever = AssetRetriever(httpClient: httpClient)
        let parser = DefaultPublicationParser(
            httpClient: httpClient,
            assetRetriever: self.assetRetriever,
            pdfFactory: DefaultPDFDocumentFactory()
        )
        self.publicationOpener = PublicationOpener(
            parser: parser,
            contentProtections: [] // No DRM
        )

        loadPreferences()
        loadInitialLocation()
        
        // Initialize progress properties with existing book progress
        self.totalBookProgression = book.readingProgress
        
        // Load existing bookmarks
        Task {
            await refreshBookmarks()
        }
        
        // Subscribe to bookmark updates
        bookmarkRepository.all(for: book.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] bookmarks in
                    self?.bookmarks = bookmarks
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Loading Publication
    func loadPublication() async {
        guard publication == nil else {
            Logger.debug(category: "loadPublication", "Publication already loaded.")
            return
        }
        guard !isLoading else {
            Logger.debug(category: "loadPublication", "Already loading.")
            return
        }
        isLoading = true
        errorMessage = nil // Clear previous error

        guard let fileURL = getFileURL(for: book.filePath) else {
            // This part is NOT happening based on your logs
            errorMessage = "EPUB file not found or invalid URL: \(book.filePath)"
            isLoading = false
            Logger.error(category: "loadPublication", "EPUB file not found or invalid URL: \(book.filePath)")
            return
        }
        Logger.debug(category: "loadPublication", "Got fileURL: \(fileURL.absoluteString)")

        let url = fileURL.absoluteURL

        do {
            guard let anyURL = url.anyURL else {
                errorMessage = "Invalid URL format for anyURL" // More specific error
                isLoading = false
                Logger.error(category: "loadPublication", "Failed to create anyURL from \(url)")
                return
            }

            let assetResult = await assetRetriever.retrieve(url: anyURL)

            // --- Log Asset Retrieval Result ---
            switch assetResult {
            case .success(let asset):

                // --- Open Publication ---
                let result = await publicationOpener.open(
                    asset: asset,
                    allowUserInteraction: false, // Should be false for background loading
                    sender: nil
                )

                // --- Log Publication Opening Result ---
                switch result {
                case .success(let pub):
                    self.publication = pub
                    // Start TOC loading (keep existing logic)
                    Task {
                        let tocResult = await pub.tableOfContents()
                        if case .success(let toc) = tocResult {
                            self.tableOfContents = toc
                        } else {
                            Logger.error(category: "loadPublication", "Failed to load TOC.")
                            self.tableOfContents = []
                        }
                    }
                    self.errorMessage = nil // Clear error on success

                case .failure(let openError):
                    // Specific error during opening
                    self.errorMessage = "Failed to open EPUB: \(openError.localizedDescription)" // Set specific error
                    self.publication = nil
                    self.tableOfContents = []
                    Logger.error(category: "loadPublication", "publicationOpener.open failed: \(openError)")
                }
                // --- End Publication Opening ---

            case .failure(let assetError):
                // Specific error during asset retrieval
                self.errorMessage = "Failed to retrieve asset: \(assetError.localizedDescription)" // Set specific error
                self.publication = nil // Ensure publication is nil on asset error
                Logger.error(category: "loadPublication", "assetRetriever.retrieve failed: \(assetError)")
            }
            // --- End Asset Retrieval ---

        }

        // Ensure isLoading is set to false regardless of success or failure path within do-catch
        isLoading = false
    }

    // MARK: - Preferences
    private func loadPreferences() {
        
        // First try to load book-specific preferences from Core Data
        if let bookPrefs = settingsRepository.getBookPreferences(bookId: book.id) {
            
            // FIXED: Properly map BookPreference to EPUBPreferences
            let fontSize = Double(bookPrefs.fontSize)
            
            // Create a new preferences object with safely unwrapped values
            preferences = EPUBPreferences()
            
            // Set font family - convert String to FontFamily enum
            if bookPrefs.fontFamily != "Default" {
                // Create a FontFamily from the string value
                preferences.fontFamily = FontFamily(rawValue: bookPrefs.fontFamily)
            }
            
            // Set font size
            preferences.fontSize = fontSize
            
            // Set publisher styles flag
            preferences.publisherStyles = true
            
            // Set scroll mode
            preferences.scroll = bookPrefs.isScrollMode
            
            // Set vertical text flag
            preferences.verticalText = bookPrefs.isVertical
            
            // Set reading direction/progression
            if bookPrefs.isRTL {
                // Use the correct enum value for right-to-left
                preferences.readingProgression = .rtl
            } else {
                // Left-to-right is the default
                preferences.readingProgression = .ltr
            }
            
            // Always use single column layout
            preferences.columnCount = .one
        } else {
            // If no book-specific preferences, use global defaults
            Logger.debug(category: "ReadiumBookViewModel", "No book preferences found, using defaults")
            
            // Set default preferences if none saved
            preferences = EPUBPreferences()
            preferences.fontFamily = nil  // use publisher font
            preferences.fontSize = 1.0    // default scale
            preferences.publisherStyles = true
            preferences.scroll = false    // paginated by default
            preferences.verticalText = false
            preferences.columnCount = .one   // always use single column layout
            
            // Check for default reading direction
            let savedDirection = UserDefaults.standard.string(forKey: "preferred_reading_direction")
            if savedDirection == "rtl" {
                preferences.readingProgression = .rtl
            } else {
                preferences.readingProgression = .ltr
            }
        }
    }
    
    // Save preferences to Core Data
    func savePreferences() {
        
        // Determine reading direction string representation
        let readingDirection: String
        if preferences.readingProgression == .rtl {
            readingDirection = "rtl"
        } else if preferences.verticalText == true {
            readingDirection = "vertical"
        } else {
            readingDirection = "ltr"
        }
        
        // Create or update BookPreference
        let bookPrefs = BookPreference(
            fontSize: Float(preferences.fontSize ?? 1.0),
            fontFamily: preferences.fontFamily?.rawValue ?? "Default",
            backgroundColor: "#FFFFFF", // Default white background
            textColor: "#000000",       // Default black text
            readingDirection: readingDirection,
            isScrollMode: preferences.scroll ?? false,
            bookId: book.id
        )
        
        // Save to repository
        settingsRepository.saveBookPreferences(bookPrefs)
    }
    
    // Submit preferences to navigator (to be called from SwiftUI view when navigator is available)
    func submitPreferencesToNavigator(_ navigator: EPUBNavigatorViewController) {
        navigator.submitPreferences(preferences)
    }

    // MARK: - Location Handling
    private func loadInitialLocation() {
        // Try to load location from Core Data first
        if let locatorData = book.currentLocatorData,
           let jsonString = String(data: locatorData, encoding: .utf8),
           let locator = try? Locator(jsonString: jsonString) {
            self.initialLocation = locator
            return
        }
        
        // Fall back to legacy UserDefaults approach if needed
        let key = "readium_locator_\(book.id.uuidString)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let jsonString = String(data: data, encoding: .utf8),
              let locator = try? Locator(jsonString: jsonString) else {
            Logger.debug(category: "ReadiumBookViewModel", "No saved locator found for book \(book.id)")
            initialLocation = nil
            return
        }

        self.initialLocation = locator
    }
    
    func saveLocation(_ locator: Locator) {
        do {
            // Get the JSON dictionary representation from the Locator
            let jsonDictionary = locator.json
            
            // Serialize the dictionary into Data using JSONSerialization
            let jsonData = try JSONSerialization.data(withJSONObject: jsonDictionary, options: [])
            
            // Save to Core Data via repository
            bookRepository.updateBookProgress(
                id: book.id,
                progress: locator.locations.progression ?? book.readingProgress,
                locatorData: jsonData
            )
            
            // Also update our local book object
            book.readingProgress = locator.locations.progression ?? book.readingProgress
            book.currentLocatorData = jsonData
                        
            // Legacy: Also save to UserDefaults for backward compatibility
            let key = "readium_locator_\(book.id.uuidString)"
            UserDefaults.standard.set(jsonData, forKey: key)
        } catch {
            Logger.error(category: "ReadiumBookViewModel", "Failed to serialize or save locator: \(error)")
        }
    }
    
    // MARK: - Bookmark Management
    
    /// Refreshes the bookmarks list from the repository
    @MainActor
    func refreshBookmarks() async {
        // We don't need async/await with the new implementation
        bookmarkRepository.refreshBookmarks(for: book.id)
    }
    
    /// Toggles a bookmark at the current location
    @MainActor
    func toggleBookmark() async {
        guard let navigator = navigatorController, let locator = navigator.currentLocation else {
            Logger.error(category: "ReadiumBookViewModel", "Cannot toggle bookmark - no current location")
            return
        }
        
        if isCurrentLocationBookmarked {
            // Find the bookmark ID to remove
            if let bookmarkId = bookmarkRepository.findBookmarkId(bookId: book.id, locator: locator) {
                _ = await bookmarkRepository.remove(bookmarkId)
                isCurrentLocationBookmarked = false
            }
        } else {
            // Create new bookmark
            let bookmark = Bookmark(
                bookId: book.id,
                locator: locator,
                created: Date()
            )
            
            _ = await bookmarkRepository.add(bookmark)
            isCurrentLocationBookmarked = true
        }
        
        // Refresh bookmarks list
        await refreshBookmarks()
    }
    
    /// Removes a specific bookmark
    @MainActor
    func removeBookmark(_ bookmark: Bookmark) async {
        _ = await bookmarkRepository.remove(bookmark.id)
        
        // Refresh bookmarks list
        await refreshBookmarks()
    }
    
    /// Navigate to a bookmarked location
    func navigateToBookmark(_ bookmark: Bookmark) {
        requestNavigation(to: bookmark.locator)
    }
    
    // MARK: - Helper Functions
    
    private func getFileURL(for storedPath: String) -> URL? {
        let fileManager = FileManager.default
        
        // Get current Documents directory
        guard let documentsDirectory = try? fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
            Logger.error(category: "getFileURL", "Could not access Documents directory")
            return nil
        }
        
        // Case 1: Relative path (new format) - try direct resolution
        if !storedPath.starts(with: "/") {
            let fullURL = documentsDirectory.appendingPathComponent(storedPath)
            Logger.debug(category: "getFileURL", "Trying relative path: \(fullURL.path)")
            if fileManager.fileExists(atPath: fullURL.path) {
                return fullURL
            }
        }
        
        // Case 2: Absolute path (legacy format) - try direct access first
        if storedPath.starts(with: "/") {
            if fileManager.fileExists(atPath: storedPath) {
                return URL(fileURLWithPath: storedPath)
            }
            
            // Case 3: Absolute path migration - extract relative path and update database
            if let migratedURL = migrateAbsolutePath(storedPath, documentsDirectory: documentsDirectory) {
                Logger.debug(category: "getFileURL", "Successfully migrated absolute path")
                return migratedURL
            }
        }
        
        // Case 4: Fallback - try bundle resources
        let filename = URL(fileURLWithPath: storedPath).lastPathComponent
        if let bundleURL = Bundle.main.url(forResource: filename, withExtension: nil, subdirectory: "Books") ?? Bundle.main.url(forResource: filename, withExtension: nil) {
            if fileManager.fileExists(atPath: bundleURL.path) {
                return bundleURL
            }
        }
        
        Logger.error(category: "getFileURL", "File not found for path: \(storedPath)")
        return nil
    }
    
    /// Attempts to migrate an absolute path to the current container
    private func migrateAbsolutePath(_ absolutePath: String, documentsDirectory: URL) -> URL? {
        let fileManager = FileManager.default
        
        // Extract the relative path from the old absolute path
        // Look for "/Documents/" in the path and extract everything after it
        if let documentsRange = absolutePath.range(of: "/Documents/") {
            let relativePath = String(absolutePath[documentsRange.upperBound...])
            let newURL = documentsDirectory.appendingPathComponent(relativePath)
            
            if fileManager.fileExists(atPath: newURL.path) {
                
                // Update the database with the relative path
                Task { @MainActor in
                    self.updateBookPathInDatabase(relativePath: relativePath)
                }
                
                return newURL
            }
        }
        
        // If that doesn't work, try looking for just the filename in common locations
        let filename = URL(fileURLWithPath: absolutePath).lastPathComponent
        let possiblePaths = [
            "Books/\(filename)",
            "BookCovers/\(filename)",
            filename
        ]
        
        for relativePath in possiblePaths {
            let testURL = documentsDirectory.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: testURL.path) {
                
                // Update the database with the relative path
                Task { @MainActor in
                    self.updateBookPathInDatabase(relativePath: relativePath)
                }
                
                return testURL
            }
        }
        
        Logger.warning(category: "migrateAbsolutePath", "Could not migrate path: \(absolutePath)")
        return nil
    }
    
    /// Updates the book's file path in the database with a relative path
    @MainActor
    private func updateBookPathInDatabase(relativePath: String) {
        
        // Update the database through Core Data
        if let entity = CoreDataManager.shared.getBook(by: book.id) {
            entity.filePath = relativePath
            CoreDataManager.shared.saveContext()
            
            // Create a new Book object with the updated path
            let updatedBook = Book(
                id: book.id,
                title: book.title,
                author: book.author,
                filePath: relativePath,
                coverImagePath: book.coverImagePath,
                isLocalCover: book.isLocalCover,
                addedDate: book.addedDate,
                lastOpenedDate: book.lastOpenedDate,
                readingProgress: book.readingProgress,
                currentLocatorData: book.currentLocatorData
            )
            
            // Update our local book reference
            book = updatedBook
        } else {
            Logger.error(category: "updateBookPathInDatabase", "Could not find book entity in database")
        }
    }

    // MARK: - Dictionary Lookups
    
    func handleCharacterSelection(offset: Int) {
        guard !fullTextForSelection.isEmpty else { return }
        
        // Ensure offset is within bounds
        let safeOffset = max(0, min(offset, fullTextForSelection.count - 1))
        
        // Update the current offset
        self.currentTextOffset = safeOffset
        
        // Get the new text to search - slice from safe offset to end
        let newStartIndex = fullTextForSelection.index(fullTextForSelection.startIndex, offsetBy: safeOffset)
        let newSelectedText = String(fullTextForSelection[newStartIndex...])
        
        // Update selected word (single character at the new position)
        if safeOffset < fullTextForSelection.count {
            let charIndex = fullTextForSelection.index(fullTextForSelection.startIndex, offsetBy: safeOffset)
            self.selectedWord = String(fullTextForSelection[charIndex])
        }
        
        // Lookup with the new text
        getDictionaryMatches(text: newSelectedText) { matches in
            DispatchQueue.main.async {
                self.dictionaryMatches = matches
                // Always show the dictionary even if no matches found
                self.showDictionary = true
            }
        }
    }
    
    func handleWordSelection(text: String, options: [String: Any]) {
        // Check if this is just an initialization message
        if let type = options["type"] as? String, type == "initialization" {
            return
        }
        
        // Store the full text for selection and character picker
        if let fullText = options["fullText"] as? String {
            self.fullTextForSelection = fullText
            
            // Get the absoluteOffset if available
            if let offset = options["absoluteOffset"] as? Int {
                // Ensure offset is within bounds of the full text
                let safeOffset = max(0, min(offset, fullText.count - 1))
                self.clickedTextOffset = safeOffset
                self.currentTextOffset = safeOffset
            } else {
                // Default to start of text
                self.clickedTextOffset = 0
                self.currentTextOffset = 0
            }
        } else {
            // If fullText is not available, use a larger context or just the current word
            self.fullTextForSelection = text
            self.clickedTextOffset = 0
            self.currentTextOffset = 0
        }
        
        // Extract sentence context if available
        var sentenceContext = ""
        if let surroundingText = options["surroundingText"] as? String {
            sentenceContext = surroundingText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Limit length if necessary (Anki URL has size limits)
            if sentenceContext.count > 250 {
                sentenceContext = String(sentenceContext.prefix(250)) + "..."
            }
        } else if let textFromClickedKanji = options["textFromClickedKanji"] as? String {
            sentenceContext = textFromClickedKanji
        }
        
        // Set the selected word for display
        self.selectedWord = text
        
        // Lookup words in the dictionary
        getDictionaryMatches(text: text) { matches in
            withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                self.dictionaryMatches = matches
                self.currentSentenceContext = sentenceContext.trimmingCharacters(in: .whitespacesAndNewlines)
                // Always show the dictionary even if no matches found
                self.showDictionary = true
            }
        }
    }
    
    func getDictionaryMatches(text: String, completion: @escaping ([DictionaryMatch]) -> Void) {
        let lookupQueue = DispatchQueue(label: "com.shiori.dictionaryLookup", qos: .userInitiated)
        
        lookupQueue.async {
            // Maximum word length to consider (adjust as needed)
            let maxLength = min(27, text.count)
            
            // Store all valid matches
            var matches: [DictionaryMatch] = []
            var foundWords: Set<String> = [] // Track words we've already found
            
            // Debug logging for specific problematic words only (remove or modify as needed)
            let shouldDebug = false // Set to true only for specific debugging
            let isDebugWord = shouldDebug && text.hasPrefix("よって")
            
            // Try words of decreasing length, starting from the longest
            for length in stride(from: maxLength, through: 1, by: -1) {
                // Make sure we don't exceed the text length
                guard length <= text.count else { continue }
                
                // Extract the substring of current length
                let endIndex = text.index(text.startIndex, offsetBy: length)
                let candidateWord = String(text[..<endIndex])
                
                // Look up this word in the dictionary with improved deinflection
                let entries = DictionaryManager.shared.lookupWithDeinflection(word: candidateWord)
                
                // If we found matches, add this as a valid match
                if !entries.isEmpty {
                    // Group entries by their base term to avoid duplicates
                    // Use order-preserving approach instead of Dictionary(grouping:)
                    var seenBaseTerms: Set<String> = []
                    var orderedGroups: [(String, [DictionaryEntry])] = []
                    
                    for entry in entries {
                        if !seenBaseTerms.contains(entry.term) {
                            seenBaseTerms.insert(entry.term)
                            let termEntries = entries.filter { $0.term == entry.term }
                            orderedGroups.append((entry.term, termEntries))
                        }
                    }
                    
                    var addedFromThisLength = 0
                    for (baseTerm, termEntries) in orderedGroups {
                        // Only add if we haven't found this base term already
                        if !foundWords.contains(baseTerm) {
                            let match = DictionaryMatch(word: candidateWord, entries: termEntries)
                            matches.append(match)
                            foundWords.insert(baseTerm)
                            addedFromThisLength += 1
                            
                        }
                    }
                    // No match limit - try all possible lengths
                }
            }
            
            // Sort matches using multi-criteria comparison (based on _sortDefinitionsForTermSearch)
            let sortedMatches = matches.sorted { first, second in
                // Multi-criteria comparators in order of priority
                let comparators: [(DictionaryMatch, DictionaryMatch) -> ComparisonResult] = [
                    // 1. Max transformed text length (longer matches first)
                    { match1, match2 in
                        let firstLength = match1.word.count
                        let secondLength = match2.word.count
                        return firstLength.compare(to: secondLength)
                    },
                    
                    // 2. Source term exact match count (higher is better)
                    { match1, match2 in
                        let firstExactCount = self.getExactMatchCount(match: match1)
                        let secondExactCount = self.getExactMatchCount(match: match2)
                        return firstExactCount.compare(to: secondExactCount)
                    },
                    
                    // 3. Popularity (higher is better)
                    { match1, match2 in
                        let firstPop = match1.entries.first?.popularity ?? 0.0
                        let secondPop = match2.entries.first?.popularity ?? 0.0
                        return firstPop.compare(to: secondPop)
                    },
                    
                    // 4. Has popular tag (entries with popular tags first)
                    { match1, match2 in
                        let firstHasPopularTag = self.hasPopularTag(entry: match1.entries.first!)
                        let secondHasPopularTag = self.hasPopularTag(entry: match2.entries.first!)
                        return firstHasPopularTag.compare(to: secondHasPopularTag)
                    },
                    
                    // 5. Fewer transformation rules (direct matches preferred)
                    { match1, match2 in
                        let firstRulesCount = match1.entries.first?.transformed != nil ? 1 : 0
                        let secondRulesCount = match2.entries.first?.transformed != nil ? 1 : 0
                        return (-firstRulesCount).compare(to: -secondRulesCount)
                    },
                    
                    // 6. Alphabetical by expression/term
                    { match1, match2 in
                        let firstTerm = match1.entries.first?.term ?? ""
                        let secondTerm = match2.entries.first?.term ?? ""
                        return firstTerm < secondTerm ? .orderedAscending : (firstTerm > secondTerm ? .orderedDescending : .orderedSame)
                    }
                ]
                
                // Apply comparators in order until we find a non-equal result
                for comparator in comparators {
                    let result = comparator(first, second)
                    if result != .orderedSame {
                        // Reverse the result to match Dart's .reversed.toList() behavior
                        return result == .orderedDescending
                    }
                }
                
                return false // Equal
            }
            
            // Return all matches found
            DispatchQueue.main.async {
                completion(sortedMatches)
            }
        }
    }
    
    // MARK: - Helper Methods for Dictionary Sorting
    
    private func getExactMatchCount(match: DictionaryMatch) -> Int {
        let candidateWord = match.word
        var count = 0
        
        // Count exact term matches
        if match.entries.contains(where: { $0.term == candidateWord }) {
            count += 1
        }
        
        // Count exact reading matches
        if match.entries.contains(where: { $0.reading == candidateWord }) {
            count += 1
        }
        
        return count
    }
    
    private func hasPopularTag(entry: DictionaryEntry) -> Bool {
        // Check if the entry has popular indicators
        // This could be based on popularity score, frequency tags, etc.
        // For now, we'll use a popularity threshold
        if let popularity = entry.popularity, popularity > 0.5 {
            return true
        }
        
        // You might also check for specific tags if your DictionaryEntry has a tags field
        // For example: return entry.tags?.contains("P") ?? false
        
        return false
    }
    
    func setNavigatorController(_ navigator: EPUBNavigatorViewController) {
        self.navigatorController = navigator
    }
    
    /// Call this to request navigation to a specific locator.
    func requestNavigation(to locator: Locator) {
        // Normalize the locator before publishing the request
        let normalizedLocator = publication?.normalizeLocator(locator) ?? locator
        self.navigationRequest = normalizedLocator
    }

    /// Call this after the navigation attempt has been made by the actual navigator view.
    func clearNavigationRequest() {
        if navigationRequest != nil {
             // Schedule the actual modification for the next run loop cycle
             DispatchQueue.main.async {
                 if self.navigationRequest != nil {
                     self.navigationRequest = nil
                 }
             }
        }
    }

    /// Renamed/Updated method for TOC or similar link navigation
    func requestNavigation(to link: ReadiumShared.Link) {
         // Resolve the Link to a Locator before requesting navigation
         Task {
             if let locator = await publication?.locate(link) {
                 self.requestNavigation(to: locator)
             } else {
                 Logger.warning(category: "ReadiumBookViewModel", "Could not create locator for link: \(link.href)")
             }
         }
     }

    // Keep your existing navigateToLink if used elsewhere, or rename it like above
    func navigateToLink(_ link: ReadiumShared.Link) {
         // This now becomes a request
         requestNavigation(to: link)
     }
    
    func handleLocationUpdate(_ locator: Locator) {
        // Save location to Core Data
        saveLocation(locator)

        // Update progression properties (chapter and total)
        self.currentChapterProgression = locator.locations.progression ?? 0.0
        
        // Use totalProgression if available, otherwise fall back to progression for compatibility
        if let totalProgression = locator.locations.totalProgression {
            self.totalBookProgression = totalProgression
            
            // Update the book's progress in the repository and local model
            bookRepository.updateBookProgress(
                id: book.id,
                progress: totalProgression,
                locatorData: book.currentLocatorData
            )
            
            // Update our local book object as well
            book.readingProgress = totalProgression
        } else if let progression = locator.locations.progression {
            // Update the book's progress in the repository
            bookRepository.updateBookProgress(
                id: book.id,
                progress: progression,
                locatorData: book.currentLocatorData
            )
            
            // Update our local book object as well
            book.readingProgress = progression
        }
        
        // Check if current location is bookmarked
        isCurrentLocationBookmarked = bookmarkRepository.isBookmarked(bookId: book.id, locator: locator)
    }
}

// Extension to help with anyURL expected by assetRetriever
extension URL {
    var anyURL: AbsoluteURL? {
        if self.isFileURL {
            return FileURL(url: self)
        } else {
            return HTTPURL(string: self.absoluteString)
        }
    }
}

// Extensions for numeric comparison
extension Int {
    func compare(to other: Int) -> ComparisonResult {
        if self < other { return .orderedAscending }
        if self > other { return .orderedDescending }
        return .orderedSame
    }
}

extension Double {
    func compare(to other: Double) -> ComparisonResult {
        if self < other { return .orderedAscending }
        if self > other { return .orderedDescending }
        return .orderedSame
    }
}

extension Bool {
    func compare(to other: Bool) -> ComparisonResult {
        if self == other { return .orderedSame }
        return self ? .orderedDescending : .orderedAscending
    }
}
