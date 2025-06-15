//
//  BookCoverImage.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/31/25.
//

import SwiftUI
import Combine

struct BookCoverImage: View {
    // Access the device type using the UIDevice extension
    private var deviceType: UIDevice.DeviceType {
        return UIDevice.current.deviceType
    }
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
                    if let uiImage = loadedUIImage {
                        // Display the successfully loaded image
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .cornerRadius(3)
                    } else if !isLoading {
                        // Show default cover ONLY if not loading and no image loaded
                        defaultCoverView
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .cornerRadius(3)
                    }

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
                .font(deviceType == .iPad ? .body : .title2) // Smaller font on iPad for 4 column layout
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.4) // Allow slightly smaller scaling on iPad
                .padding(deviceType == .iPad ? 8 : 12) // Less padding on iPad
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
                }
            }
        } else {
            // Load from asset catalog (synchronous)
            let image = UIImage(named: coverPath) // Assumes coverPath is the asset name
            self.loadedUIImage = image
            self.isLoading = false
        }
    }

    // Updated function to handle both relative paths and legacy filename stems
    private func loadLocalUIImage(filenameStem: String) -> UIImage? {
        let fileManager = FileManager.default
        
        guard let documentsDirectory = try? fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            print("ERROR [BookCoverImage]: Could not access Documents directory")
            return nil
        }
        
        // Try loading as relative path first (new format)
        if filenameStem.contains("/") {
            let coverURL = documentsDirectory.appendingPathComponent(filenameStem)
            
            if fileManager.fileExists(atPath: coverURL.path) {
                do {
                    let imageData = try Data(contentsOf: coverURL)
                    return UIImage(data: imageData)
                } catch {
                    print("ERROR [BookCoverImage]: Failed to load image data from \(coverURL.path): \(error)")
                }
            }
        }
        
        // Fallback: try legacy format (filename stem in BookCovers directory)
        let legacyCoverURL = documentsDirectory
            .appendingPathComponent("BookCovers")
            .appendingPathComponent("\(filenameStem).png")
                
        if fileManager.fileExists(atPath: legacyCoverURL.path) {
            do {
                let imageData = try Data(contentsOf: legacyCoverURL)
                return UIImage(data: imageData)
            } catch {
                print("ERROR [BookCoverImage]: Failed to load image data from \(legacyCoverURL.path): \(error)")
            }
        }
        
        print("WARN [BookCoverImage]: Local cover file not found for: \(filenameStem)")
        return nil
    }
}

