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
        let coverImage = try await extractCoverImage(from: url)
        let metadata = try await extractMetadata(from: url)
        
        // Select a random cover image if extraction failed
        let finalCoverImage = coverImage ?? defaultCovers.randomElement() ?? "COTECover"
        
        // Create a Book object
        let book = Book(
            title: metadata.title,
            coverImage: finalCoverImage,
            readingProgress: 0.0,
            filePath: fullPath
        )
        
        return book
    }
    
    private func extractCoverImage(from url: URL) async throws -> String? {
        // This would use the EPUBParser to get the cover and save it
        // For now, we'll return nil and use a default
        return nil
    }
    
    private func extractMetadata(from url: URL) async throws -> EPUBMetadata {
        // Parse the .epub file to try to extract actual metadata
        do {
            // Create a temporary extraction
            let tempDir = try createTempDirectory()
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
