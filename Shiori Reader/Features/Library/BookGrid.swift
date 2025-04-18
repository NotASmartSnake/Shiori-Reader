//
//  BookGrid.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/29/25.
//

import SwiftUI

// Extension to detect device type
extension UIDevice {
    enum DeviceType {
        case iPhone, iPad, unknown
    }
    
    var deviceType: DeviceType {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .iPhone
        } else if UIDevice.current.userInterfaceIdiom == .pad {
            return .iPad
        } else {
            return .unknown
        }
    }
}

struct BookGrid: View {
    let books: [Book]
    @ObservedObject var isReadingBook: IsReadingBook
    @Binding var lastViewedBookPath: String?

    // Define layout properties locally
    private let iPhoneIdealCellWidth: CGFloat = 150 // Minimum width for iPhone (2 columns)
    private let iPadIdealCellWidth: CGFloat = 120 // Smaller width for iPad (4 columns)
    private let gridSpacing: CGFloat = 16
    
    private var deviceType: UIDevice.DeviceType {
        return UIDevice.current.deviceType
    }

    // Calculate the grid columns based on device type
    private var columns: [GridItem] {
        // Get the current device width to calculate column minimum width
        let screenWidth = UIScreen.main.bounds.width
        
        if deviceType == .iPad {
            // Calculate column width for exactly 4 columns on iPad
            // Account for grid spacing and horizontal padding
            let horizontalPadding: CGFloat = 24 * 2 // Left and right padding
            let availableWidth = screenWidth - horizontalPadding - (gridSpacing * 3) // Space for 4 columns with 3 spacers
            let columnWidth = availableWidth / 4
            
            // Create 4 fixed columns
            return Array(
                repeating: GridItem(.fixed(columnWidth), spacing: gridSpacing),
                count: 4
            )
        } else {
            // Calculate column width for exactly 2 columns on iPhone
            let horizontalPadding: CGFloat = 30 * 2 // Left and right padding
            let availableWidth = screenWidth - horizontalPadding - gridSpacing // Space for 2 columns with 1 spacer
            let columnWidth = availableWidth / 2
            
            // Create 2 fixed columns
            return Array(
                repeating: GridItem(.fixed(columnWidth), spacing: gridSpacing),
                count: 2
            )
        }
    }
    
    var body: some View {

        LazyVGrid(columns: columns, spacing: gridSpacing) {
            ForEach(books) { book in
                BookCell(book: book, isReadingBook: isReadingBook, lastViewedBookPath: $lastViewedBookPath)
                    .frame(maxWidth: .infinity) // Ensure cell fills column width
            }
        }
        .padding(.horizontal, deviceType == .iPad ? 24 : 30) // Reduced padding on iPad to fit more columns
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
        Book(id: UUID(), title: "Mushoku Tensei Vol. 7", author: "Rifujin na Magonote", filePath: "dummy7.epub", coverImagePath: "MushokuCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.42, currentLocatorData: nil),
        // Additional books using your assets
        Book(id: UUID(), title: "Re:Zero Vol. 3", author: "Tappei Nagatsuki", filePath: "dummy8.epub", coverImagePath: "ReZeroCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.15, currentLocatorData: nil),
        Book(id: UUID(), title: "Konosuba Vol. 2", author: "Natsume Akatsuki", filePath: "dummy9.epub", coverImagePath: "KonosubaCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.67, currentLocatorData: nil),
        Book(id: UUID(), title: "No Game No Life Vol. 1", author: "Yuu Kamiya", filePath: "dummy10.epub", coverImagePath: "NoGameCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.33, currentLocatorData: nil),
        Book(id: UUID(), title: "86 -Eighty Six- Vol. 4", author: "Asato Asato", filePath: "dummy11.epub", coverImagePath: "86Cover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.55, currentLocatorData: nil),
        Book(id: UUID(), title: "DanMachi Vol. 12", author: "Fujino Omori", filePath: "dummy12.epub", coverImagePath: "DanmachiCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.81, currentLocatorData: nil),
        Book(id: UUID(), title: "The Empty Box and Zeroth Maria Vol. 1", author: "Eiji Mikage", filePath: "dummy13.epub", coverImagePath: "HakomariCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.05, currentLocatorData: nil),
        Book(id: UUID(), title: "That Time I Got Reincarnated as a Slime Vol. 3", author: "Fuse", filePath: "dummy14.epub", coverImagePath: "SlimeCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.47, currentLocatorData: nil),
        Book(id: UUID(), title: "3 Days of Happiness", author: "Sugaru Miaki", filePath: "dummy15.epub", coverImagePath: "3DaysCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.99, currentLocatorData: nil),
        Book(id: UUID(), title: "I Want to Eat Your Pancreas", author: "Yoru Sumino", filePath: "dummy16.epub", coverImagePath: "DeathCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.22, currentLocatorData: nil),
        Book(id: UUID(), title: "I Had That Same Dream Again", author: "Yoru Sumino", filePath: "dummy17.epub", coverImagePath: "LoveCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.13, currentLocatorData: nil),
        Book(id: UUID(), title: "Alchemist Who Survived Now Dreams of a Quiet City Life", author: "Usata Nonohara", filePath: "dummy18.epub", coverImagePath: "AOABCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.78, currentLocatorData: nil)
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
