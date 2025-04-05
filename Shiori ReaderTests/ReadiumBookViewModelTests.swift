//
//  ReadiumBookViewModelTests.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/3/25.
//

import XCTest
@testable import Shiori_Reader // Replace YourAppName with your actual app module name
import ReadiumShared // For Locator

@MainActor // Ensure tests run on the main actor if needed
final class ReadiumBookViewModelTests: XCTestCase {

    var userDefaults: UserDefaults!
    let testSuiteName = "TestDefaults"
    var testBook: Book!
    var testEpubURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        userDefaults = UserDefaults(suiteName: testSuiteName)
        userDefaults.removePersistentDomain(forName: testSuiteName)

        // --- Find the EPUB in the Test Bundle ---
        let testBundle = Bundle(for: type(of: self)) // Get the bundle for this test class
        guard let url = testBundle.url(forResource: "honzuki", withExtension: "epub") else {
            // Important: Fail the test if the EPUB isn't found in the test bundle!
            XCTFail("Test EPUB 'hakomari.epub' not found in the test bundle. Check Target Membership.")
            return
        }
        self.testEpubURL = url // Store the found URL
        // --- End Finding EPUB ---

        // --- Create the Book instance using the found path ---
        self.testBook = Book(
            title: "Hakomari Test", // Or use actual title if desired
            coverImage: "",         // Provide dummy or actual if needed
            readingProgress: 0.0,
            filePath: self.testEpubURL.path // <-- Use the path from the found URL
        )
        // --- End Creating Book ---
    }

    override func tearDownWithError() throws {
        userDefaults.removePersistentDomain(forName: testSuiteName)
        userDefaults = nil
        testBook = nil
        testEpubURL = nil
        try super.tearDownWithError()
    }

    // --- Test Cases ---

    func testInitialization_Defaults() throws {
        let viewModel = ReaderViewModel(book: testBook)
        // Inject or override UserDefaults for testing if needed, or rely on setup clearing
        // UserDefaults.standard = userDefaults // Be careful with overriding standard directly

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.publication)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.initialLocation) // Assumes no saved location
        // Add asserts for default preferences
        XCTAssertEqual(viewModel.preferences.readingProgression, .ltr) // Assuming default
    }

    func testLoadPublication_Success() async throws {
        let viewModel = ReaderViewModel(book: testBook)

        // Optional: Use Combine publishers to observe changes if needed for more complex checks
        // let pubExpectation = expectation(description: "Publication loaded")
        // let cancellable = viewModel.$publication.sink { pub in if pub != nil { pubExpectation.fulfill() }}

        await viewModel.loadPublication()

        // await fulfillment(of: [pubExpectation], timeout: 10.0) // If using expectations
        // cancellable.cancel()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.publication)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.tableOfContents.isEmpty) // Assuming test epub has TOC
        XCTAssertNotNil(viewModel.state.epubBaseURL)
    }

    func testLoadPublication_FileNotFound() async throws {
        let badBook = Book(title: "Bad Path", coverImage: "", readingProgress: 0, filePath: "/non/existent/file.epub")
        let viewModel = ReaderViewModel(book: badBook)

        await viewModel.loadPublication()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.publication)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("file not found") ?? false, "Error message should indicate file not found")
    }

    func testSaveAndLoadLocation() throws {
         // 1. Create ViewModel and save location
        let viewModel1 = ReaderViewModel(book: testBook)
        guard let testHref = RelativeURL(string: "/page1.xhtml"),
              let testMediaType = MediaType("application/xhtml+xml") else {
            XCTFail("Failed to create URL or MediaType for testLocator")
            return
        }
        let testLocator = Locator(
            href: testHref,                 // Use RelativeURL
            mediaType: testMediaType,       // Use MediaType and correct label
            locations: .init(progression: 0.25)
        )
        viewModel1.saveLocation(testLocator) // This uses UserDefaults.standard by default

        // 2. Create a *new* ViewModel instance for the *same* book ID
        // Ensure the book ID is the same for loading to work
        let viewModel2 = ReaderViewModel(book: testBook)

        // 3. Assert the location was loaded
        XCTAssertNotNil(viewModel2.initialLocation)
        XCTAssertEqual(viewModel2.initialLocation?.href, testLocator.href)
        XCTAssertEqual(viewModel2.initialLocation?.locations.progression, testLocator.locations.progression)
    }

    func testHandleLocationUpdate() throws {
        let viewModel = ReaderViewModel(book: testBook)
        guard let newHref = RelativeURL(string: "/page2.xhtml"),
              let newMediaType = MediaType("application/xhtml+xml") else {
             XCTFail("Failed to create URL or MediaType for newLocator")
             return
        }
        let newLocator = Locator(
            href: newHref,                  // Use RelativeURL
            mediaType: newMediaType,        // Use MediaType and correct label
            locations: .init(progression: 0.75)
        )

        viewModel.handleLocationUpdate(newLocator)

        // Assert book progress property was updated
        XCTAssertEqual(viewModel.book.readingProgress, 0.75, accuracy: 0.001)

        // Optionally: Verify it was saved to UserDefaults by loading it again
        let key = "readium_locator_\(testBook.id.uuidString)"
        guard let savedData = UserDefaults.standard.data(forKey: key), // Use standard if not overriding
              let json = try? JSONSerialization.jsonObject(with: savedData) as? [String: Any],
              let loadedLocator = try? Locator(json: json) else {
            XCTFail("Failed to load or decode locator from UserDefaults")
            return
        }
        XCTAssertEqual(loadedLocator.locations.progression, 0.75)
    }
}
