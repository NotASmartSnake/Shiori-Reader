//
//  BookCoverImage.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/31/25.
//

import SwiftUI

struct BookCoverImage: View {
    let book: Book
    
    var body: some View {
        Group {
            if book.isLocalCover {
                // Load from local file system
                loadLocalImage(named: book.coverImage)
                    .resizable()
                    .scaledToFit()
            } else {
                // Load from asset catalog
                Image(book.coverImage)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: 200, height: 250)
        .cornerRadius(8)
        .shadow(radius: 4)
    }
    
    private func loadLocalImage(named filename: String) -> Image {
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        
        let coverURL = documentsDirectory
            .appendingPathComponent("BookCovers")
            .appendingPathComponent("\(filename).jpg")
        
        do {
            let imageData = try Data(contentsOf: coverURL)
            if let uiImage = UIImage(data: imageData) {
                return Image(uiImage: uiImage)
            }
        } catch {
            print("DEBUG: Failed to load local cover image: \(error)")
        }
        
        // Fallback to a default image
        return Image("COTECover")
    }
}
