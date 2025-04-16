//
//  BookCoverImage.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/31/25.
//

import SwiftUI
import Combine

struct BookCoverImage: View {
    let book: Book
    @State private var loadedUIImage: UIImage? = nil
    @State private var isLoading = true
    @Environment(\.colorScheme) private var colorScheme
    
    // Standard book cover aspect ratio (height:width) is typically around 1.5:1
    private static let coverAspectRatio: CGFloat = 0.66 // This is width:height (1/1.5)
    private let topGradientColor = Color(red: 214/255, green: 1/255, blue: 58/255)
    private let bottomGradientColor = Color(red: 179/255, green: 33/255, blue: 34/255)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                // Shadow layer
                RoundedRectangle(cornerRadius: 50)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.5))
                    .blur(radius: 10)
                    .offset(x: 0, y: 12)
                    .opacity(isLoading ? 0 : 0.3)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Content layer
                Group {
                    if let uiImage = loadedUIImage {
                        // Display the successfully loaded image
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    } else if !isLoading {
                        // Show default cover ONLY if not loading and no image loaded
                        defaultCoverView
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
                .cornerRadius(5)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(Self.coverAspectRatio, contentMode: .fit)
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
                .appendingPathComponent("\(filenameStem).png")

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
    // Create a sample book for preview
    let sampleBook = Book(
        id: UUID(), 
        title: "Classroom of the Elite Vol. 1", 
        author: "Syougo Kinugasa", 
        filePath: "dummy1.epub", 
        coverImagePath: "COTECover", 
        isLocalCover: false, 
        addedDate: Date(), 
        lastOpenedDate: Date(), 
        readingProgress: 0.25, 
        currentLocatorData: nil
    )
    
    // Simple preview that just shows the book cover image directly
    return BookCoverImage(book: sampleBook)
}
