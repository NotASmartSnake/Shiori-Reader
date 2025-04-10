//
//  BookCoverImage.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/31/25.
//

import SwiftUI

struct BookCoverImage: View {
    let book: Book
    @State private var loadedUIImage: UIImage? = nil
    @State private var isLoading = true
    
    private let coverWidth: CGFloat = UIScreen.main.bounds.width * 0.4
    private var coverHeight: CGFloat { coverWidth * 1.5 }
    private let topGradientColor = Color(red: 214/255, green: 1/255, blue: 58/255)
    private let bottomGradientColor = Color(red: 179/255, green: 33/255, blue: 34/255)
    
    var body: some View {
        ZStack {
            // Shadow layer
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.black.opacity(0.8))
                .frame(width: coverWidth, height: coverHeight)
                .blur(radius: 8)
                .offset(x: 0, y: 10)
                .opacity(isLoading ? 0 : 0.6)
            
            // Content layer
            Group {
                if let uiImage = loadedUIImage {
                    // Display the successfully loaded image
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill) // Fill the frame
                } else if !isLoading {
                    // Show default cover ONLY if not loading and no image loaded
                    defaultCoverView
                }
            }
            .frame(width: coverWidth, height: coverHeight)
            .cornerRadius(3)
            .clipped()
        }
        .onAppear(perform: loadImage)
        .onChange(of: book.coverImagePath) { _, _ in loadImage() }
        .onChange(of: book.isLocalCover) { _, _ in loadImage() }
    }
    
    
    private var defaultCoverView: some View {
        LinearGradient(
            gradient: Gradient(colors: [topGradientColor, bottomGradientColor]),
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            Text(book.title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .padding()
        )
    }
    
    private func loadImage() {
        isLoading = true
        loadedUIImage = nil // Reset before loading

        // Determine the source and attempt loading
        guard let coverPath = book.coverImagePath, !coverPath.isEmpty else {
             print("DEBUG [BookCoverImage]: No cover path for \(book.title). Using default.")
             isLoading = false // No path, stop loading, default will show
             return
        }

        if book.isLocalCover {
            // Load from local file system async
            DispatchQueue.global(qos: .userInitiated).async {
                let image = loadLocalUIImage(filenameStem: coverPath)
                DispatchQueue.main.async {
                    self.loadedUIImage = image
                    self.isLoading = false
                    if image == nil {
                         print("DEBUG [BookCoverImage]: Failed to load local cover '\(coverPath)'. Using default.")
                    } else {
                         print("DEBUG [BookCoverImage]: Successfully loaded local cover '\(coverPath)'.")
                    }
                }
            }
        } else {
            // Load from asset catalog (synchronous)
            let image = UIImage(named: coverPath) // Assumes coverPath is the asset name
            self.loadedUIImage = image
            self.isLoading = false
            if image == nil {
                 print("DEBUG [BookCoverImage]: Failed to load asset cover '\(coverPath)'. Using default.")
            } else {
                 print("DEBUG [BookCoverImage]: Successfully loaded asset cover '\(coverPath)'.")
            }
        }
    }

    // Updated function to return UIImage?
    private func loadLocalUIImage(filenameStem: String) -> UIImage? {
        let fileManager = FileManager.default
        do {
            let documentsDirectory = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            let coverURL = documentsDirectory
                .appendingPathComponent("BookCovers")
                .appendingPathComponent("\(filenameStem).jpg")

            if fileManager.fileExists(atPath: coverURL.path) {
                let imageData = try Data(contentsOf: coverURL)
                return UIImage(data: imageData) // Return UIImage directly
            } else {
                print("WARN [BookCoverImage]: Local cover file not found at \(coverURL.path)")
                return nil
            }
        } catch {
            print("ERROR [BookCoverImage]: Failed to get documents directory or load image data: \(error)")
            return nil
        }
    }
}

#Preview("BookCoverImage Preview") {
    // Define a wrapper struct specifically for the preview
    struct LibraryView_PreviewWrapper: View {
    // Create StateObjects for the required environment objects
    @StateObject var isReadingBook = IsReadingBook()
    @StateObject var libraryManager = LibraryManager()
    @StateObject var savedWordsManager = SavedWordsManager()

    // Define the dummy book data
    let dummyBooks: [Book] = [
        Book(id: UUID(), title: "Classroom of the Elite Vol. 1", author: "Syougo Kinugasa", filePath: "dummy1.epub", coverImagePath: "COTECover", isLocalCover: false, addedDate: Date().addingTimeInterval(-86400 * 5), lastOpenedDate: Date().addingTimeInterval(-3600), readingProgress: 0.25, currentLocatorData: nil),
        Book(id: UUID(), title: "My Teen Romantic Comedy SNAFU Vol. 14", author: "Wataru Watari", filePath: "dummy2.epub", coverImagePath: "OregairuCover", isLocalCover: false, addedDate: Date().addingTimeInterval(-86400 * 2), lastOpenedDate: Date().addingTimeInterval(-7200), readingProgress: 0.90, currentLocatorData: nil),
        Book(id: UUID(), title: "Three Days of Happiness", author: "Sugaru Miaki", filePath: "dummy3.epub", coverImagePath: "cover_local_dummy_1", isLocalCover: true, addedDate: Date().addingTimeInterval(-86400 * 10), lastOpenedDate: Date().addingTimeInterval(-10800), readingProgress: 0.05, currentLocatorData: nil), // Example local cover (will likely default in preview)
        Book(id: UUID(), title: "86 - Eighty Six - Ep. 1", author: "Asato Asato", filePath: "dummy4.epub", coverImagePath: nil, isLocalCover: false, addedDate: Date().addingTimeInterval(-86400 * 1), lastOpenedDate: nil, readingProgress: 0.0, currentLocatorData: nil), // No cover path -> Default gradient
        Book(id: UUID(), title: "That Time I Got Reincarnated as a Slime Vol. 10", author: "Fuse", filePath: "dummy5.epub", coverImagePath: "", isLocalCover: false, addedDate: Date().addingTimeInterval(-86400 * 3), lastOpenedDate: Date().addingTimeInterval(-14400), readingProgress: 0.15, currentLocatorData: nil), // Empty cover path -> Default gradient
        Book(id: UUID(), title: "Overlord Vol. 1", author: "Kugane Maruyama", filePath: "dummy6.epub", coverImagePath: "OverlordCover", isLocalCover: false, addedDate: Date().addingTimeInterval(-86400 * 7), lastOpenedDate: Date().addingTimeInterval(-18000), readingProgress: 0.70, currentLocatorData: nil),
        Book(id: UUID(), title: "Mushoku Tensei Vol. 7", author: "Rifujin na Magonote", filePath: "dummy7.epub", coverImagePath: "MushokuCover", isLocalCover: false, addedDate: Date().addingTimeInterval(-86400 * 4), lastOpenedDate: Date().addingTimeInterval(-21600), readingProgress: 0.42, currentLocatorData: nil),
        Book(id: UUID(), title: "Is It Wrong to Try to Pick Up Girls in a Dungeon? Vol. 17", author: "Fujino Ōmori", filePath: "dummy8.epub", coverImagePath: "invalid_local_path", isLocalCover: true, addedDate: Date().addingTimeInterval(-86400 * 6), lastOpenedDate: Date().addingTimeInterval(-25200), readingProgress: 0.88, currentLocatorData: nil) // Invalid local path -> Default gradient
    ]

    var body: some View {
        // Embed LibraryView within a NavigationView or NavigationStack if needed for title/toolbar testing
        NavigationStack {
            LibraryView() // The actual view we want to preview
                .environmentObject(isReadingBook)
                .environmentObject(libraryManager)
                .environmentObject(savedWordsManager)
                .onAppear {
                    // Load the dummy data into the manager when the preview appears
                    // Sort books by last opened date descending for a realistic look
                     libraryManager.books = dummyBooks.sorted {
                         ($0.lastOpenedDate ?? Date.distantPast) > ($1.lastOpenedDate ?? Date.distantPast)
                     }
                }
        }
    }
    }

    // Return an instance of the wrapper for the preview
    return LibraryView_PreviewWrapper()
}
