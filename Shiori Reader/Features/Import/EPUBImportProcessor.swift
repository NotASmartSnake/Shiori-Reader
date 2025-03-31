//
//  EPUBImportProcessor.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/29/25.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

class EPUBImportProcessor {
    
    private let defaultCovers = [
        "COTECover", "OregairuCover", "3DaysCover", "86Cover", "SlimeCover",
        "OverlordCover", "ReZeroCover", "MushokuCover", "DanmachiCover"
    ]
    
    func processEPUB(at url: URL, fullPath: String) async throws -> Book {
        // Make sure it's an EPUB file
        guard url.pathExtension.lowercased() == "epub" else {
            throw ImportError.invalidFileType
        }
        
        // Extract metadata and cover image if possible
        let coverImageFilename = try await extractCoverImage(from: url)
        let metadata = try await extractMetadata(from: url)
        
        // Create a Book object
        if let coverImageFilename = coverImageFilename {
            // We successfully extracted a cover image
            return Book(
                title: metadata.title,
                coverImage: coverImageFilename,
                isLocalCover: true,  // This is a local file, not an asset
                readingProgress: 0.0,
                filePath: fullPath
            )
        } else {
            // Use a default cover from assets
            let defaultCover = defaultCovers.randomElement() ?? "COTECover"
            return Book(
                title: metadata.title,
                coverImage: defaultCover,
                isLocalCover: false,  // This is an asset
                readingProgress: 0.0,
                filePath: fullPath
            )
        }
    }
    
    private func extractCoverImage(from url: URL) async throws -> String? {
        do {
            let epubParser = EPUBParser()
            let (content, extractionDir) = try epubParser.parseEPUB(at: url.path)
            
            let fileManager = FileManager.default
            
            // Create a directory for covers if it doesn't exist
            let documentsDirectory = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let coversDirectory = documentsDirectory.appendingPathComponent("BookCovers", isDirectory: true)
            try fileManager.createDirectory(at: coversDirectory, withIntermediateDirectories: true, attributes: nil)
            
            // Generate a unique filename for this book's cover
            let bookId = UUID().uuidString
            let coverFilename = "cover_\(bookId)"
            let coverURL = coversDirectory.appendingPathComponent("\(coverFilename).jpg")
            
            // 1. First try to find covers by name pattern
            let enumerator = fileManager.enumerator(at: extractionDir, includingPropertiesForKeys: nil)
            while let fileURL = enumerator?.nextObject() as? URL {
                // Check if this might be a cover image
                let filename = fileURL.lastPathComponent.lowercased()
                if (filename.contains("cover")) &&
                   (filename.hasSuffix(".jpg") || filename.hasSuffix(".jpeg") || filename.hasSuffix(".png")) {
                    if let imageData = try? Data(contentsOf: fileURL) {
                        try imageData.write(to: coverURL)
                        print("DEBUG: Found and saved cover from filename pattern: \(filename)")
                        return coverFilename
                    }
                }
            }
            
            // 2. Look through the content's images for likely cover candidates
            var largestImageData: Data?
            var largestSize = 0
            
            for (_, imageData) in content.images {
                let size = imageData.count
                if size > largestSize {
                    largestSize = size
                    largestImageData = imageData
                }
            }
            
            if let imageData = largestImageData {
                try imageData.write(to: coverURL)
                print("DEBUG: Saved largest image as cover")
                return coverFilename
            }
            
            print("DEBUG: No suitable cover image found in EPUB")
            return nil
            
        } catch {
            print("DEBUG: Error extracting cover: \(error)")
            return nil
        }
    }
    
    private func extractMetadata(from url: URL) async throws -> EPUBMetadata {
        // Parse the .epub file to try to extract actual metadata
        do {
            let epubParser = EPUBParser()
            let (content, _) = try epubParser.parseEPUB(at: url.path)
            
            // Create a more informative title by adding author name if available
            var displayTitle = content.metadata.title
            
            // If author is not empty or "Unknown", append it to the title
            if !content.metadata.author.isEmpty && content.metadata.author != "Unknown Author" {
                displayTitle += " by \(content.metadata.author)"
            }
            
            return content.metadata
        } catch {
            print("DEBUG: Error extracting metadata: \(error)")
            
            // Fallback to using filename as title if metadata extraction fails
            return EPUBMetadata(
                title: url.deletingPathExtension().lastPathComponent,
                author: "Unknown Author",
                language: "en"
            )
        }
    }
    
    private func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    enum ImportError: Error {
        case invalidFileType
        case metadataExtractionFailed
        case coverExtractionFailed
    }
}
