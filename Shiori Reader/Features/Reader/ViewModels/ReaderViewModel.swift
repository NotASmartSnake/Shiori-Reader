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

        Logger.debug(category: "ReadiumBookViewModel", "Initialized for book '\(book.title)'")
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
        Logger.debug(category: "loadPublication", "Starting load process...")

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
            Logger.debug(category: "loadPublication", "Creating anyURL...")
            guard let anyURL = url.anyURL else {
                errorMessage = "Invalid URL format for anyURL" // More specific error
                isLoading = false
                Logger.error(category: "loadPublication", "Failed to create anyURL from \(url)")
                return
            }
            Logger.debug(category: "loadPublication", "Created anyURL: \(anyURL)")

            Logger.debug(category: "loadPublication", "Retrieving asset...")
            let assetResult = await assetRetriever.retrieve(url: anyURL)

            // --- Log Asset Retrieval Result ---
            switch assetResult {
            case .success(let asset):
                Logger.debug(category: "loadPublication", "Asset retrieved successfully. Format: \(asset.format)")

                // --- Open Publication ---
                Logger.debug(category: "loadPublication", "Opening publication from asset...")
                let result = await publicationOpener.open(
                    asset: asset,
                    allowUserInteraction: false, // Should be false for background loading
                    sender: nil
                )

                // --- Log Publication Opening Result ---
                switch result {
                case .success(let pub):
                    Logger.debug(category: "loadPublication", "Publication opened successfully!")
                    self.publication = pub
                    // Start TOC loading (keep existing logic)
                    Task {
                        Logger.debug(category: "loadPublication", "Starting TOC load...")
                        let tocResult = await pub.tableOfContents()
                        if case .success(let toc) = tocResult {
                            Logger.debug(category: "loadPublication", "TOC loaded with \(toc.count) items.")
                            self.tableOfContents = toc
                        } else {
                            Logger.error(category: "loadPublication", "Failed to load TOC.")
                            self.tableOfContents = []
                        }
                    }
                    self.errorMessage = nil // Clear error on success
                    Logger.debug(category: "loadPublication", "Publication setup complete.")

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
        Logger.debug(category: "loadPublication", "Load process finished. isLoading: \(isLoading), publication != nil: \(publication != nil), errorMessage: \(errorMessage ?? "None")")
    }

    // MARK: - Preferences
    private func loadPreferences() {
        Logger.debug(category: "ReadiumBookViewModel", "Loading user preferences...")
        
        // First try to load book-specific preferences from Core Data
        if let bookPrefs = settingsRepository.getBookPreferences(bookId: book.id) {
            Logger.debug(category: "ReadiumBookViewModel", "Found book-specific preferences in Core Data")
            
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
                Logger.debug(category: "ReadiumBookViewModel", "Using RTL reading direction from defaults")
            } else {
                preferences.readingProgression = .ltr
                Logger.debug(category: "ReadiumBookViewModel", "Using LTR reading direction from defaults")
            }
        }
    }
    
    // Save preferences to Core Data
    func savePreferences() {
        Logger.debug(category: "ReadiumBookViewModel", "Saving preferences to Core Data")
        
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
        Logger.debug(category: "ReadiumBookViewModel", "Submitted preferences to navigator")
    }

    // MARK: - Location Handling
    private func loadInitialLocation() {
        // Try to load location from Core Data first
        if let locatorData = book.currentLocatorData,
           let jsonString = String(data: locatorData, encoding: .utf8),
           let locator = try? Locator(jsonString: jsonString) {
            self.initialLocation = locator
            Logger.debug(category: "ReadiumBookViewModel", "Loaded initial locator from Core Data: \(locator.locations.progression ?? -1.0)%")
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
        Logger.debug(category: "ReadiumBookViewModel", "Loaded initial locator from UserDefaults: \(locator.locations.progression ?? -1.0)%")
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
            
            Logger.debug(category: "ReadiumBookViewModel", "Saved locator to Core Data successfully.")
            
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
                Logger.debug(category: "ReadiumBookViewModel", "Removed bookmark at \(locator.href)")
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
            Logger.debug(category: "ReadiumBookViewModel", "Added bookmark at \(locator.href)")
            isCurrentLocationBookmarked = true
        }
        
        // Refresh bookmarks list
        await refreshBookmarks()
    }
    
    /// Removes a specific bookmark
    @MainActor
    func removeBookmark(_ bookmark: Bookmark) async {
        _ = await bookmarkRepository.remove(bookmark.id)
        Logger.debug(category: "ReadiumBookViewModel", "Removed bookmark \(bookmark.id)")
        
        // Refresh bookmarks list
        await refreshBookmarks()
    }
    
    /// Navigate to a bookmarked location
    func navigateToBookmark(_ bookmark: Bookmark) {
        Logger.debug(category: "ReadiumBookViewModel", "Navigating to bookmark at \(bookmark.locator.href)")
        requestNavigation(to: bookmark.locator)
    }
    
    // MARK: - Helper Functions
    
    private func getFileURL(for storedPath: String) -> URL? {
        let fileManager = FileManager.default
        Logger.debug(category: "getFileURL", "Resolving path: \(storedPath)")
        
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
                Logger.debug(category: "getFileURL", "Found via relative path")
                return fullURL
            }
        }
        
        // Case 2: Absolute path (legacy format) - try direct access first
        if storedPath.starts(with: "/") {
            Logger.debug(category: "getFileURL", "Trying absolute path: \(storedPath)")
            if fileManager.fileExists(atPath: storedPath) {
                Logger.debug(category: "getFileURL", "Found via absolute path (container unchanged)")
                return URL(fileURLWithPath: storedPath)
            }
            
            // Case 3: Absolute path migration - extract relative path and update database
            Logger.debug(category: "getFileURL", "Absolute path not found, attempting migration")
            if let migratedURL = migrateAbsolutePath(storedPath, documentsDirectory: documentsDirectory) {
                Logger.debug(category: "getFileURL", "Successfully migrated absolute path")
                return migratedURL
            }
        }
        
        // Case 4: Fallback - try bundle resources
        let filename = URL(fileURLWithPath: storedPath).lastPathComponent
        Logger.debug(category: "getFileURL", "Checking Bundle for filename: \(filename)")
        if let bundleURL = Bundle.main.url(forResource: filename, withExtension: nil, subdirectory: "Books") ?? Bundle.main.url(forResource: filename, withExtension: nil) {
            if fileManager.fileExists(atPath: bundleURL.path) {
                Logger.debug(category: "getFileURL", "Found in Bundle")
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
            
            Logger.debug(category: "migrateAbsolutePath", "Extracted relative path: \(relativePath)")
            Logger.debug(category: "migrateAbsolutePath", "Testing new URL: \(newURL.path)")
            
            if fileManager.fileExists(atPath: newURL.path) {
                Logger.debug(category: "migrateAbsolutePath", "File found at migrated path, updating database")
                
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
                Logger.debug(category: "migrateAbsolutePath", "File found via filename search: \(testURL.path)")
                
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
        Logger.debug(category: "updateBookPathInDatabase", "Updating book \(book.id) with relative path: \(relativePath)")
        
        // Update the database through Core Data
        if let entity = CoreDataManager.shared.getBook(by: book.id) {
            entity.filePath = relativePath
            CoreDataManager.shared.saveContext()
            Logger.debug(category: "updateBookPathInDatabase", "Successfully updated database")
            
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
            Logger.debug(category: "updateBookPathInDatabase", "Updated local book object")
        } else {
            Logger.error(category: "updateBookPathInDatabase", "Could not find book entity in database")
        }
    }

    // MARK: - Dictionary Lookups
    
    func handleCharacterSelection(offset: Int) {
        guard !fullTextForSelection.isEmpty else { return }
        
        // Update the current offset
        self.currentTextOffset = offset
        
        print("🔍 handleCharacterSelection - New offset: \(offset)")
        print("🔍 handleCharacterSelection - Full text: \(fullTextForSelection.prefix(20))...")
        
        if offset < 0 || offset >= fullTextForSelection.count {
            print("⚠️ Invalid offset for text selection: \(offset) for text of length \(fullTextForSelection.count)")
            return
        }
        
        // Get the new text to search - slice from offset to end
        let newStartIndex = fullTextForSelection.index(fullTextForSelection.startIndex, offsetBy: offset)
        let newSelectedText = String(fullTextForSelection[newStartIndex...])
        
        // Clean debug log - just show what we're searching
        print("💬 SEARCHING FROM PICKER: \(newSelectedText.prefix(20))...")
        
        // Update selected word
        self.selectedWord = String(fullTextForSelection[newStartIndex])
        
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
        Logger.debug(category: "ReaderViewModel", "Word tapped - \(text) with options: \(options)")
        
        // Check if this is just an initialization message
        if let type = options["type"] as? String, type == "initialization" {
            Logger.debug(category: "ReaderViewModel", "Received initialization message, not showing dictionary")
            return
        }
        
        // Store the full text for selection and character picker
        if let fullText = options["fullText"] as? String {
            self.fullTextForSelection = fullText
            print("📚 RECEIVED - Text: \(text.prefix(10))... from fullText of length \(fullText.count)")
            
            // Get the absoluteOffset if available
            if let offset = options["absoluteOffset"] as? Int {
                self.clickedTextOffset = offset
                self.currentTextOffset = offset
                print("📚 CLICKED - At offset: \(offset) in text")
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
            print("📚 NO FULLTEXT - Using just: \(text)")
        }
        
        // Extract sentence context if available
        var sentenceContext = ""
        if let surroundingText = options["surroundingText"] as? String {
            sentenceContext = surroundingText
            Logger.debug(category: "ReaderViewModel", "Raw sentence context: \(sentenceContext)")
            
            // Clean up the sentence context
            sentenceContext = sentenceContext.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Limit length if necessary (Anki URL has size limits)
            if sentenceContext.count > 250 {
                sentenceContext = String(sentenceContext.prefix(250)) + "..."
            }
            
            Logger.debug(category: "ReaderViewModel", "Processed sentence context: \(sentenceContext)")
        } else if let textFromClickedKanji = options["textFromClickedKanji"] as? String {
            // Try alternative fields if surroundingText is not available
            sentenceContext = textFromClickedKanji
            Logger.debug(category: "ReaderViewModel", "Using textFromClickedKanji as context: \(sentenceContext)")
        } else {
            Logger.debug(category: "ReaderViewModel", "No context text found in options")
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
            
            // Simple log for search
            print("💬 TEXT TAPPED - SEARCHING: \(text)")
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
                    let groupedEntries = Dictionary(grouping: entries) { entry in
                        entry.term
                    }
                    
                    for (baseTerm, termEntries) in groupedEntries {
                        // Only add if we haven't found this base term already
                        if !foundWords.contains(baseTerm) {
                            let match = DictionaryMatch(word: candidateWord, entries: termEntries)
                            matches.append(match)
                            foundWords.insert(baseTerm)
                        }
                    }
                    
                    // Limit to a reasonable number of matches
                    if matches.count >= 5 {
                        break
                    }
                }
            }
            
            // Sort matches to prioritize base forms over conjugated forms
            let sortedMatches = matches.sorted { first, second in
                let firstHasTransform = first.entries.first?.transformed != nil
                let secondHasTransform = second.entries.first?.transformed != nil
                
                // Prefer entries that are transformations (base forms)
                if firstHasTransform != secondHasTransform {
                    return firstHasTransform
                }
                
                // Then by length (longer matches first)
                return first.word.count > second.word.count
            }
            
            // Return all matches found
            DispatchQueue.main.async {
                completion(sortedMatches)
            }
        }
    }
    
    // MARK: - Navigator Interface Methods
    
    func setNavigatorController(_ navigator: EPUBNavigatorViewController) {
        self.navigatorController = navigator
    }
    
    /// Call this to request navigation to a specific locator.
    func requestNavigation(to locator: Locator) {
        // Normalize the locator before publishing the request
        let normalizedLocator = publication?.normalizeLocator(locator) ?? locator
        Logger.debug(category: "ReadiumBookViewModel", "Navigation requested to locator: \(normalizedLocator.href)")
        self.navigationRequest = normalizedLocator
    }

    /// Call this after the navigation attempt has been made by the actual navigator view.
    func clearNavigationRequest() {
        if navigationRequest != nil {
             Logger.debug(category: "ReadiumBookViewModel", "Scheduling navigation request to be cleared.")
             // Schedule the actual modification for the next run loop cycle
             DispatchQueue.main.async {
                 if self.navigationRequest != nil {
                     Logger.debug(category: "ReadiumBookViewModel", "Executing clear navigation request.")
                     self.navigationRequest = nil
                 }
             }
        }
    }

    /// Renamed/Updated method for TOC or similar link navigation
    func requestNavigation(to link: ReadiumShared.Link) {
         Logger.debug(category: "ReadiumBookViewModel", "Navigation requested to link: \(link.href)")
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
         Logger.debug(category: "ReadiumBookViewModel", "Request to navigate to link: \(link.href)")
         // This now becomes a request
         requestNavigation(to: link)
     }
    
    func handleLocationUpdate(_ locator: Locator) {
        Logger.debug(category: "ReadiumBookViewModel", "handleLocationUpdate called with locator progression: \(locator.locations.progression ?? -1.0)")
        
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
            
            Logger.debug(category: "ReadiumBookViewModel", "Updated book total progress to \(totalProgression)")
        } else if let progression = locator.locations.progression {
            // Fallback to using progression as total progression if totalProgression is not available
            Logger.debug(category: "ReadiumBookViewModel", "No totalProgression available, using progression.")
            
            // Update the book's progress in the repository
            bookRepository.updateBookProgress(
                id: book.id,
                progress: progression,
                locatorData: book.currentLocatorData
            )
            
            // Update our local book object as well
            book.readingProgress = progression
            
            Logger.debug(category: "ReadiumBookViewModel", "After assignment, book.readingProgress is now: \(self.book.readingProgress)")
            Logger.debug(category: "ReadiumBookViewModel", "Updated book progress to \(progression)")
        } else {
            Logger.debug(category: "ReadiumBookViewModel", "Locator progression was nil, not updating.")
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
