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
    @ObservedObject var isReadingBook: IsReadingBook
    @Binding var lastViewedBookPath: String?
    let sortOption: SortOption
    @EnvironmentObject private var libraryManager: LibraryManager
    
    // Access books directly from libraryManager and sort them
    private var books: [Book] {
        let allBooks = libraryManager.books
        switch sortOption {
        case .recent:
            return allBooks.sorted { book1, book2 in
                // Sort by last opened date, with books that have never been opened at the end
                guard let date1 = book1.lastOpenedDate else { return false }
                guard let date2 = book2.lastOpenedDate else { return true }
                return date1 > date2
            }
        case .title:
            return allBooks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .author:
            return allBooks.sorted { book1, book2 in
                let author1 = book1.author ?? ""
                let author2 = book2.author ?? ""
                if author1.isEmpty && author2.isEmpty {
                    return book1.title.localizedCaseInsensitiveCompare(book2.title) == .orderedAscending
                } else if author1.isEmpty {
                    return false
                } else if author2.isEmpty {
                    return true
                } else {
                    return author1.localizedCaseInsensitiveCompare(author2) == .orderedAscending
                }
            }
        }
    }

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
