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
    @Published var state = BookState() // Temporary bridge to your existing state model
    @Published var pendingNavigationLink: ReadiumShared.Link? = nil
    @Published var navigationRequest: Locator? = nil
    
    // Bookmark related properties
    @Published private(set) var bookmarks: [Bookmark] = []
    @Published private(set) var isCurrentLocationBookmarked: Bool = false
    
    // Dictionary related properties
    @Published var showDictionary = false
    @Published var selectedWord = ""
    
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

        print("DEBUG [ReadiumBookViewModel]: Initialized for book '\(book.title)'")
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
            print("DEBUG [loadPublication]: Publication already loaded.") // Added
            return
        }
        guard !isLoading else {
            print("DEBUG [loadPublication]: Already loading.") // Added
            return
        }
        isLoading = true
        errorMessage = nil // Clear previous error
        print("DEBUG [loadPublication]: Starting load process...") // Added

        guard let fileURL = getFileURL(for: book.filePath) else {
            // This part is NOT happening based on your logs
            errorMessage = "EPUB file not found or invalid URL: \(book.filePath)"
            isLoading = false
            print("ERROR [loadPublication]: getFileURL failed.") // Added
            return
        }
        print("DEBUG [loadPublication]: Got fileURL: \(fileURL.absoluteString)") // Added

        let url = fileURL.absoluteURL

        do {
            print("DEBUG [loadPublication]: Creating anyURL...") // Added
            guard let anyURL = url.anyURL else {
                errorMessage = "Invalid URL format for anyURL" // More specific error
                isLoading = false
                print("ERROR [loadPublication]: Failed to create anyURL from \(url)") // Added
                return
            }
            print("DEBUG [loadPublication]: Created anyURL: \(anyURL)") // Added

            print("DEBUG [loadPublication]: Retrieving asset...") // Added
            let assetResult = await assetRetriever.retrieve(url: anyURL)

            // --- Log Asset Retrieval Result ---
            switch assetResult {
            case .success(let asset):
                print("DEBUG [loadPublication]: Asset retrieved successfully. Format: \(asset.format)") // Added

                // --- Open Publication ---
                print("DEBUG [loadPublication]: Opening publication from asset...") // Added
                let result = await publicationOpener.open(
                    asset: asset,
                    allowUserInteraction: false, // Should be false for background loading
                    sender: nil
                )

                // --- Log Publication Opening Result ---
                switch result {
                case .success(let pub):
                    print("DEBUG [loadPublication]: Publication opened successfully!") // Added
                    self.publication = pub
                    // Start TOC loading (keep existing logic)
                    Task {
                        print("DEBUG [loadPublication]: Starting TOC load...") // Added
                        let tocResult = await pub.tableOfContents()
                        if case .success(let toc) = tocResult {
                            print("DEBUG [loadPublication]: TOC loaded with \(toc.count) items.") // Added
                            self.tableOfContents = toc
                        } else {
                            print("ERROR [loadPublication]: Failed to load TOC.") // Added
                            self.tableOfContents = []
                        }
                    }
                    self.errorMessage = nil // Clear error on success
                    self.state.epubBaseURL = fileURL.deletingLastPathComponent()
                    print("DEBUG [loadPublication]: Publication setup complete.") // Added

                case .failure(let openError):
                    // Specific error during opening
                    self.errorMessage = "Failed to open EPUB: \(openError.localizedDescription)" // Set specific error
                    self.publication = nil
                    self.tableOfContents = []
                    print("ERROR [loadPublication]: publicationOpener.open failed: \(openError)") // Log specific error
                }
                // --- End Publication Opening ---

            case .failure(let assetError):
                // Specific error during asset retrieval
                self.errorMessage = "Failed to retrieve asset: \(assetError.localizedDescription)" // Set specific error
                self.publication = nil // Ensure publication is nil on asset error
                print("ERROR [loadPublication]: assetRetriever.retrieve failed: \(assetError)") // Log specific error
            }
            // --- End Asset Retrieval ---

        }

        // Ensure isLoading is set to false regardless of success or failure path within do-catch
        isLoading = false
        print("DEBUG [loadPublication]: Load process finished. isLoading: \(isLoading), publication != nil: \(publication != nil), errorMessage: \(errorMessage ?? "None")") // Added final state log
    }

    // MARK: - Preferences
    private func loadPreferences() {
        print("DEBUG [ReadiumBookViewModel]: Loading user preferences...")
        
        // First try to load book-specific preferences from Core Data
        if let bookPrefs = settingsRepository.getBookPreferences(bookId: book.id) {
            print("DEBUG [ReadiumBookViewModel]: Found book-specific preferences in Core Data")
            
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
        } else {
            // If no book-specific preferences, use global defaults
            print("DEBUG [ReadiumBookViewModel]: No book preferences found, using defaults")
            
            // Set default preferences if none saved
            preferences = EPUBPreferences()
            preferences.fontFamily = nil  // use publisher font
            preferences.fontSize = 1.0    // default scale
            preferences.publisherStyles = true
            preferences.scroll = false    // paginated by default
            preferences.verticalText = false
            
            // Check for default reading direction
            let savedDirection = UserDefaults.standard.string(forKey: "preferred_reading_direction")
            if savedDirection == "rtl" {
                preferences.readingProgression = .rtl
                print("DEBUG [ReadiumBookViewModel]: Using RTL reading direction from defaults")
            } else {
                preferences.readingProgression = .ltr
                print("DEBUG [ReadiumBookViewModel]: Using LTR reading direction from defaults")
            }
        }
    }
    
    // Save preferences to Core Data
    func savePreferences() {
        print("DEBUG [ReadiumBookViewModel]: Saving preferences to Core Data")
        
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
        print("DEBUG [ReadiumBookViewModel]: Submitted preferences to navigator")
    }

    // MARK: - Location Handling
    private func loadInitialLocation() {
        // Try to load location from Core Data first
        if let locatorData = book.currentLocatorData,
           let jsonString = String(data: locatorData, encoding: .utf8),
           let locator = try? Locator(jsonString: jsonString) {
            self.initialLocation = locator
            print("DEBUG [ReadiumBookViewModel]: Loaded initial locator from Core Data: \(locator.locations.progression ?? -1.0)%")
            return
        }
        
        // Fall back to legacy UserDefaults approach if needed
        let key = "readium_locator_\(book.id.uuidString)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let jsonString = String(data: data, encoding: .utf8),
              let locator = try? Locator(jsonString: jsonString) else {
            print("DEBUG [ReadiumBookViewModel]: No saved locator found for book \(book.id)")
            initialLocation = nil
            return
        }

        self.initialLocation = locator
        print("DEBUG [ReadiumBookViewModel]: Loaded initial locator from UserDefaults: \(locator.locations.progression ?? -1.0)%")
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
            
            print("DEBUG [ReadiumBookViewModel]: Saved locator to Core Data successfully.")
            
            // Legacy: Also save to UserDefaults for backward compatibility
            let key = "readium_locator_\(book.id.uuidString)"
            UserDefaults.standard.set(jsonData, forKey: key)
        } catch {
            print("ERROR [ReadiumBookViewModel]: Failed to serialize or save locator: \(error)")
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
            print("ERROR [ReadiumBookViewModel]: Cannot toggle bookmark - no current location")
            return
        }
        
        if isCurrentLocationBookmarked {
            // Find the bookmark ID to remove
            if let bookmarkId = bookmarkRepository.findBookmarkId(bookId: book.id, locator: locator) {
                _ = await bookmarkRepository.remove(bookmarkId)
                print("DEBUG [ReadiumBookViewModel]: Removed bookmark at \(locator.href)")
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
            print("DEBUG [ReadiumBookViewModel]: Added bookmark at \(locator.href)")
            isCurrentLocationBookmarked = true
        }
        
        // Refresh bookmarks list
        await refreshBookmarks()
    }
    
    /// Removes a specific bookmark
    @MainActor
    func removeBookmark(_ bookmark: Bookmark) async {
        _ = await bookmarkRepository.remove(bookmark.id)
        print("DEBUG [ReadiumBookViewModel]: Removed bookmark \(bookmark.id)")
        
        // Refresh bookmarks list
        await refreshBookmarks()
    }
    
    /// Navigate to a bookmarked location
    func navigateToBookmark(_ bookmark: Bookmark) {
        print("DEBUG [ReadiumBookViewModel]: Navigating to bookmark at \(bookmark.locator.href)")
        requestNavigation(to: bookmark.locator)
    }
    
    // MARK: - Helper Functions
    
    private func getFileURL(for storedPath: String) -> URL? {
        let fileManager = FileManager.default
        print("DEBUG [getFileURL] Checking path: \(storedPath)")

        if storedPath.starts(with: "/") && fileManager.fileExists(atPath: storedPath) {
            print("DEBUG [getFileURL] Found as absolute path.")
            return URL(fileURLWithPath: storedPath)
        }
        do {
            let documentsDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let booksDirectory = documentsDirectory.appendingPathComponent("Books")
            let fileURLInBooks = booksDirectory.appendingPathComponent(storedPath)
            print("DEBUG [getFileURL] Checking Documents/Books path: \(fileURLInBooks.path)")
            if fileManager.fileExists(atPath: fileURLInBooks.path) {
                print("DEBUG [getFileURL] Found in Documents/Books.")
                return fileURLInBooks
            }
        } catch { print("ERROR [getFileURL]: Couldn't access Documents directory: \(error)") }

        let filename = URL(fileURLWithPath: storedPath).lastPathComponent
        print("DEBUG [getFileURL] Checking Bundle for filename: \(filename)")
        if let bundleURL = Bundle.main.url(forResource: filename, withExtension: nil, subdirectory: "Books") ?? Bundle.main.url(forResource: filename, withExtension: nil) {
             print("DEBUG [getFileURL] Found potential bundle URL: \(bundleURL.path)")
             if fileManager.fileExists(atPath: bundleURL.path) {
                 print("DEBUG [getFileURL] Found in Bundle.")
                 return bundleURL
             } else {
                  print("DEBUG [getFileURL] Bundle URL exists but file not present at path.")
             }
        }
        print("WARN [getFileURL]: File not found for path: \(storedPath)")
        return nil
    }

    // MARK: - Dictionary Lookups
    
    func handleWordSelection(text: String, options: [String: Any]) {
        print("DEBUG [ReaderViewModel]: Word tapped - \(text) with options: \(options)")
        
        // Check if this is just an initialization message
        if let type = options["type"] as? String, type == "initialization" {
            print("DEBUG [ReaderViewModel]: Received initialization message, not showing dictionary")
            return
        }
        
        // Extract sentence context if available
        var sentenceContext = ""
        if let surroundingText = options["surroundingText"] as? String {
            sentenceContext = surroundingText
            print("DEBUG [ReaderViewModel]: Raw sentence context: \(sentenceContext)")
            
            // Clean up the sentence context
            sentenceContext = sentenceContext.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Limit length if necessary (Anki URL has size limits)
            if sentenceContext.count > 250 {
                sentenceContext = String(sentenceContext.prefix(250)) + "..."
            }
            
            print("DEBUG [ReaderViewModel]: Processed sentence context: \(sentenceContext)")
        } else if let textFromClickedKanji = options["textFromClickedKanji"] as? String {
            // Try alternative fields if surroundingText is not available
            sentenceContext = textFromClickedKanji
            print("DEBUG [ReaderViewModel]: Using textFromClickedKanji as context: \(sentenceContext)")
        } else {
            print("DEBUG [ReaderViewModel]: No context text found in options")
        }
        
        // Set the selected word for display
        self.selectedWord = text
        
        // Lookup words in the dictionary
        getDictionaryMatches(text: text) { matches in
            if !matches.isEmpty {
                self.dictionaryMatches = matches
                self.currentSentenceContext = sentenceContext.trimmingCharacters(in: .whitespacesAndNewlines)
                self.showDictionary = true
            } else {
                print("DEBUG [ReaderViewModel]: No dictionary matches found for \(text)")
            }
        }
    }
    
    private func getDictionaryMatches(text: String, completion: @escaping ([DictionaryMatch]) -> Void) {
        let lookupQueue = DispatchQueue(label: "com.shiori.dictionaryLookup", qos: .userInitiated)
        
        lookupQueue.async {
            // Maximum word length to consider (adjust as needed)
            let maxLength = min(27, text.count)
            
            // Store all valid matches
            var matches: [DictionaryMatch] = []
            
            // Try words of decreasing length, starting from the longest
            for length in stride(from: maxLength, through: 1, by: -1) {
                // Make sure we don't exceed the text length
                guard length <= text.count else { continue }
                
                // Extract the substring of current length
                let endIndex = text.index(text.startIndex, offsetBy: length)
                let candidateWord = String(text[..<endIndex])
                
                // Look up this word in the dictionary
                let entries = DictionaryManager.shared.lookupWithDeinflection(word: candidateWord)
                
                // If we found matches, add this as a valid match
                if !entries.isEmpty {
                    let match = DictionaryMatch(word: candidateWord, entries: entries)
                    matches.append(match)
                    
                    // Limit to a reasonable number of matches
                    if matches.count >= 5 {
                        break
                    }
                }
            }
            
            // Return all matches found, ordered by length (longest first)
            DispatchQueue.main.async {
                completion(matches)
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
        print("DEBUG [ReadiumBookViewModel]: Navigation requested to locator: \(normalizedLocator.href)")
        self.navigationRequest = normalizedLocator
    }

    /// Call this after the navigation attempt has been made by the actual navigator view.
    func clearNavigationRequest() {
        if navigationRequest != nil {
             print("DEBUG [ReadiumBookViewModel]: Scheduling navigation request to be cleared.")
             // Schedule the actual modification for the next run loop cycle
             DispatchQueue.main.async {
                 if self.navigationRequest != nil {
                     print("DEBUG [ReadiumBookViewModel]: Executing clear navigation request.")
                     self.navigationRequest = nil
                 }
             }
        }
    }

    /// Renamed/Updated method for TOC or similar link navigation
    func requestNavigation(to link: ReadiumShared.Link) {
         print("DEBUG [ReadiumBookViewModel]: Navigation requested to link: \(link.href)")
         // Resolve the Link to a Locator before requesting navigation
         Task {
             if let locator = await publication?.locate(link) {
                 self.requestNavigation(to: locator)
             } else {
                 print("WARN [ReadiumBookViewModel]: Could not create locator for link: \(link.href)")
             }
         }
     }

    // Keep your existing navigateToLink if used elsewhere, or rename it like above
    func navigateToLink(_ link: ReadiumShared.Link) {
         print("DEBUG [ReadiumBookViewModel]: Request to navigate to link: \(link.href)")
         // This now becomes a request
         requestNavigation(to: link)
     }
    
    func handleLocationUpdate(_ locator: Locator) {
        print("DEBUG [ReadiumBookViewModel]: handleLocationUpdate called with locator progression: \(locator.locations.progression ?? -1.0)")
        
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
            
            print("DEBUG [ReadiumBookViewModel]: Updated book total progress to \(totalProgression)")
        } else if let progression = locator.locations.progression {
            // Fallback to using progression as total progression if totalProgression is not available
            print("DEBUG [ReadiumBookViewModel]: No totalProgression available, using progression.")
            
            // Update the book's progress in the repository
            bookRepository.updateBookProgress(
                id: book.id,
                progress: progression,
                locatorData: book.currentLocatorData
            )
            
            // Update our local book object as well
            book.readingProgress = progression
            
            print("DEBUG [ReadiumBookViewModel]: After assignment, book.readingProgress is now: \(self.book.readingProgress)")
            print("DEBUG [ReadiumBookViewModel]: Updated book progress to \(progression)")
        } else {
            print("DEBUG [ReadiumBookViewModel]: Locator progression was nil, not updating.")
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
