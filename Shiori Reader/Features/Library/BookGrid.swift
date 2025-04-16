//
//  BookGrid.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/29/25.
//

import SwiftUI

struct BookGrid: View {
    let books: [Book]
    @ObservedObject var isReadingBook: IsReadingBook
    @Binding var lastViewedBookPath: String?

    // Define layout properties locally
    private let idealCellWidth: CGFloat = 150 // Minimum width for adaptive columns
    private let gridSpacing: CGFloat = 16 // Reduced spacing between grid items

    var body: some View {
        // Get the current device width to calculate column minimum width
        let screenWidth = UIScreen.main.bounds.width
        let calculatedMinWidth = max(idealCellWidth, screenWidth / 4)
        
        let columns: [GridItem] = [
            GridItem(.adaptive(minimum: calculatedMinWidth), spacing: gridSpacing)
        ]

        LazyVGrid(columns: columns, spacing: gridSpacing) {
            ForEach(books) { book in
                BookCell(book: book, isReadingBook: isReadingBook, lastViewedBookPath: $lastViewedBookPath)
                    .frame(maxWidth: .infinity) // Ensure cell fills column width
            }
        }
        .padding(.horizontal, 30) // Padding around the grid
    }
}

#Preview("BookGrid Preview") {
    // Create a custom LibraryManager subclass for preview
    class PreviewLibraryManager: LibraryManager {
        // Override loadLibrary to do nothing in preview
        override func loadLibrary() {
            // Do nothing - keep existing books
        }
    }
    
    // Environment objects
    let isReadingBook = IsReadingBook()
    let libraryManager = PreviewLibraryManager()
    let savedWordsManager = SavedWordsManager()
    
    // Sample books
    let sampleBooks = [
        Book(id: UUID(), title: "Classroom of the Elite Vol. 1", author: "Syougo Kinugasa", filePath: "dummy1.epub", coverImagePath: "COTECover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.25, currentLocatorData: nil),
        Book(id: UUID(), title: "My Teen Romantic Comedy SNAFU Vol. 14", author: "Wataru Watari", filePath: "dummy2.epub", coverImagePath: "OregairuCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.90, currentLocatorData: nil),
        Book(id: UUID(), title: "Overlord Vol. 1", author: "Kugane Maruyama", filePath: "dummy6.epub", coverImagePath: "OverlordCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.70, currentLocatorData: nil),
        Book(id: UUID(), title: "Mushoku Tensei Vol. 7", author: "Rifujin na Magonote", filePath: "dummy7.epub", coverImagePath: "MushokuCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.42, currentLocatorData: nil)
    ]
    
    // Binding for lastViewedBookPath
    struct PreviewWrapper: View {
        @State var lastViewedBookPath: String? = nil
        let books: [Book]
        let isReadingBook: IsReadingBook
        
        var body: some View {
            BookGrid(books: books, isReadingBook: isReadingBook, lastViewedBookPath: $lastViewedBookPath)
        }
    }
    
    return PreviewWrapper(books: sampleBooks, isReadingBook: isReadingBook)
        .environmentObject(libraryManager)
        .environmentObject(savedWordsManager)
}
