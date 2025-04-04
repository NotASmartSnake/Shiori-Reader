//
//  ReadiumBookViewModel.swift
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

@MainActor
class ReadiumBookViewModel: ObservableObject {
    // --- Input ---
    @Published var book: Book

    // --- Readium Core Components ---
    private let publicationOpener: PublicationOpener
    private let assetRetriever: AssetRetriever

    // --- Published State for UI ---
    @Published private(set) var publication: Publication?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var initialLocation: Locator?
    @Published var errorMessage: String?
    @Published var preferences = EPUBPreferences() // Using new Preferences API
    @Published private(set) var tableOfContents: [ReadiumShared.Link] = []

    // --- Other State ---
    @Published var showDictionary = false
    @Published var selectedWord = ""
    @Published var currentSentenceContext: String = ""
    @Published var state = BookState() // Temporary bridge to your existing state model
    @Published var pendingNavigationLink: ReadiumShared.Link? = nil
    @Published var navigationRequest: Locator? = nil

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
    }

    // MARK: - Loading Publication
    func loadPublication() async {
        guard publication == nil else { return }
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        guard let fileURL = getFileURL(for: book.filePath) else {
            errorMessage = "EPUB file not found or invalid URL: \(book.filePath)"
            isLoading = false
            return
        }

        let url = fileURL.absoluteURL
        
        do {
            guard let anyURL = url.anyURL else {
                errorMessage = "Invalid URL format"
                isLoading = false
                return
            }
            
            let assetResult = await assetRetriever.retrieve(url: anyURL)
            guard case .success(let asset) = assetResult else {
                errorMessage = "Failed to retrieve asset"
                isLoading = false
                return
            }
            
            // Open a Publication from the Asset
            let result = await publicationOpener.open(
                asset: asset,
                allowUserInteraction: false,
                sender: nil
            )
            
            switch result {
                case .success(let pub):
                    self.publication = pub
                    Task {
                        let tocResult = await pub.tableOfContents()
                        if case .success(let toc) = tocResult {
                            self.tableOfContents = toc
                        } else {
                            self.tableOfContents = []
                        }
                    }
                    self.errorMessage = nil
                    
                    // Determine base URL
                    self.state.epubBaseURL = fileURL.deletingLastPathComponent()
                    
                    print("DEBUG [ReadiumBookViewModel]: Publication loaded successfully")
                    
                case .failure(let error):
                    self.errorMessage = "Failed to load EPUB: \(error.localizedDescription)"
                    self.publication = nil
                    self.tableOfContents = []
            }
        }
        
        isLoading = false
    }

    // MARK: - Preferences
    private func loadPreferences() {
        print("DEBUG [ReadiumBookViewModel]: Loading user preferences...")
        
        // Load from UserDefaults if available
        if let data = UserDefaults.standard.data(forKey: "epub_preferences"),
           let savedPreferences = try? JSONDecoder().decode(EPUBPreferences.self, from: data) {
            preferences = savedPreferences
            print("DEBUG [ReadiumBookViewModel]: Loaded saved preferences")
        } else {
            // Set default preferences if none saved
            preferences = EPUBPreferences(
                fontFamily: nil,  // use publisher font
                fontSize: 1.0,  // default scale
                publisherStyles: true,  // allow publisher styles
                scroll: false    // paginated by default
            )
            print("DEBUG [ReadiumBookViewModel]: Using default preferences")
        }
        
        // Load reading direction
        let savedDirection = UserDefaults.standard.string(forKey: "preferred_reading_direction")
        if savedDirection == "vertical" {
            preferences.readingProgression = .rtl
            print("DEBUG [ReadiumBookViewModel]: Loaded reading direction: Vertical (RTL)")
        } else {
            preferences.readingProgression = .ltr
            print("DEBUG [ReadiumBookViewModel]: Loaded reading direction: Horizontal (LTR)")
        }
    }
    
    // Submit preferences to navigator (to be called from SwiftUI view when navigator is available)
    func submitPreferencesToNavigator(_ navigator: EPUBNavigatorViewController) {
        navigator.submitPreferences(preferences)
        print("DEBUG [ReadiumBookViewModel]: Submitted preferences to navigator")
    }

    // MARK: - Location Handling
    private func loadInitialLocation() {
        let key = "readium_locator_\(book.id.uuidString)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let jsonString = String(data: data, encoding: .utf8),
              let locator = try? Locator(jsonString: jsonString) else {
            print("DEBUG [ReadiumBookViewModel]: No saved locator found for book \(book.id)")
            initialLocation = nil
            return
        }

        self.initialLocation = locator
        print("DEBUG [ReadiumBookViewModel]: Loaded initial locator: \(locator.locations.progression ?? -1.0)%")
    }
    
    func saveLocation(_ locator: Locator) {
        do {
            // Get the JSON dictionary representation from the Locator
            let jsonDictionary = locator.json // This is a [String: Any], not a String

            // Serialize the dictionary into Data using JSONSerialization
            let jsonData = try JSONSerialization.data(withJSONObject: jsonDictionary, options: [])

            // Save the Data to UserDefaults
            let key = "readium_locator_\(book.id.uuidString)"
            UserDefaults.standard.set(jsonData, forKey: key)
            print("DEBUG [ReadiumBookViewModel]: Saved locator successfully.")

        } catch {
            // Handle potential errors during JSON serialization or other issues
            print("ERROR [ReadiumBookViewModel]: Failed to serialize or save locator: \(error)")
        }
    }
    
    // MARK: - Helper Functions
    private func getFileURL(for storedPath: String) -> URL? {
        let fileManager = FileManager.default
        if storedPath.starts(with: "/") && fileManager.fileExists(atPath: storedPath) {
            return URL(fileURLWithPath: storedPath)
        }
        do {
            let documentsDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let booksDirectory = documentsDirectory.appendingPathComponent("Books")
            let fileURLInBooks = booksDirectory.appendingPathComponent(storedPath)
            if fileManager.fileExists(atPath: fileURLInBooks.path) {
                return fileURLInBooks
            }
        } catch { print("ERROR: Couldn't access Documents directory: \(error)") }

        let filename = URL(fileURLWithPath: storedPath).lastPathComponent
        if let bundleURL = Bundle.main.url(forResource: filename, withExtension: nil, subdirectory: "Books") ?? Bundle.main.url(forResource: filename, withExtension: nil) {
             if fileManager.fileExists(atPath: bundleURL.path) {
                 return bundleURL
             }
        }
        print("WARN: File not found for path: \(storedPath)")
        return nil
    }

    // MARK: - Dictionary Lookups
    
    // Dictionary lookup methods can be kept from your original implementation
    // as they're specific to your application's features
    
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
    
//    func navigateToLink(_ link: ReadiumShared.Link) {
//        Task {
//            await MainActor.run {
//                self.pendingNavigationLink = link
//                print("DEBUG: Set pending navigation to link: \(link.href)")
//            }
//        }
//    }
    
    func handleLocationUpdate(_ locator: Locator) {
        print("DEBUG [ReadiumBookViewModel]: handleLocationUpdate called with locator progression: \(locator.locations.progression ?? -1.0)") // Added
        saveLocation(locator)

        if let progression = locator.locations.progression {
            print("DEBUG [ReadiumBookViewModel]: Attempting to update progress to: \(progression)") // Added
            book.readingProgress = progression
            // ADD THIS LINE:
            print("DEBUG [ReadiumBookViewModel]: After assignment, book.readingProgress is now: \(self.book.readingProgress)")
            print("DEBUG [ReadiumBookViewModel]: Updated book progress to \(progression)") // Your existing line
            // TODO: Update in database if needed
        } else {
            print("DEBUG [ReadiumBookViewModel]: Locator progression was nil, not updating.") // Added
        }
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
