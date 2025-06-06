//
//  EPUBImportProcessor.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/29/25.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import ReadiumShared
import ReadiumStreamer
import ReadiumNavigator
import ReadiumAdapterGCDWebServer

class EPUBImportProcessor {
    private let coverMaxSize = CGSize(width: 200, height: 300)
    
    private let publicationOpener: PublicationOpener = {
            let httpClient = DefaultHTTPClient()
            // Use the shared server instance
            let assetRetriever = AssetRetriever(httpClient: httpClient)
            let parser = DefaultPublicationParser(
                httpClient: httpClient,
                assetRetriever: assetRetriever,
                pdfFactory: DefaultPDFDocumentFactory()
            )
            return PublicationOpener(
                parser: parser,
                contentProtections: [] // Assuming no DRM
            )
        }()
    
    private let assetRetriever = AssetRetriever(httpClient: DefaultHTTPClient())
    
    private let defaultCovers = [
        "COTECover", "OregairuCover", "3DaysCover", "86Cover", "SlimeCover",
        "OverlordCover", "ReZeroCover", "MushokuCover", "DanmachiCover"
    ]
    
    func processEPUB(at url: URL, fullPath: String) async throws -> Book {
        // Make sure it's an EPUB file
        guard url.pathExtension.lowercased() == "epub" else {
            throw ImportError.invalidFileType
        }

        Logger.debug(category: "EPUBImportProcessor", "Processing EPUB at \(url.path)")

        // Open the Publication using Readium
        guard let anyURL = url.anyURL else {
            Logger.error(category: "EPUBImportProcessor", "Could not create AnyURL from \(url)")
            throw ImportError.metadataExtractionFailed("Invalid URL format")
        }

        let assetResult = await assetRetriever.retrieve(url: anyURL)
        let asset: Asset
        switch assetResult {
        case .success(let retrievedAsset):
            asset = retrievedAsset
            Logger.debug(category: "EPUBImportProcessor", "Asset retrieved successfully. Format: \(asset.format)")

        case .failure(let assetError):
            let errorDescription = assetError.localizedDescription
            Logger.error(category: "EPUBImportProcessor", "Failed to retrieve asset: \(errorDescription)")
            throw ImportError.metadataExtractionFailed("Failed to retrieve EPUB asset: \(errorDescription)")
        }

        let pubResult = await publicationOpener.open(asset: asset, allowUserInteraction: false)
        let publication: Publication
        switch pubResult {
        case .success(let openedPublication):
            publication = openedPublication
            Logger.debug(category: "EPUBImportProcessor", "Publication opened successfully.")

        case .failure(let openError):
            let errorDescription = openError.localizedDescription
            Logger.error(category: "EPUBImportProcessor", "Failed to open publication: \(errorDescription)")
            throw ImportError.metadataExtractionFailed("Failed to open EPUB: \(errorDescription)")
        }

        Logger.debug(category: "EPUBImportProcessor", "Publication opened successfully.")

        // Extract Metadata using Readium
        let metadata = publication.metadata
        let title = metadata.title ?? url.deletingPathExtension().lastPathComponent // Fallback title
        let author = metadata.authors.first?.name // Get first author's name

        Logger.debug(category: "EPUBImportProcessor", "Extracted Metadata - Title: \(title), Author: \(author ?? "N/A")")

        // Extract Cover Image using Readium
        var coverImageFilename: String? = nil
        var isLocalCover = false

        let coverResult: ReadResult<UIImage?> = await publication.coverFitting(maxSize: coverMaxSize)

        switch coverResult {
        case .success(let optionalCoverImage):
            // Result was success, now check if the optional UIImage has a value
            if let coverUIImage = optionalCoverImage {
                Logger.debug(category: "EPUBImportProcessor", "Extracted cover UIImage size: \(coverUIImage.size), scale: \(coverUIImage.scale)")
                do {
                    // Pass the non-optional UIImage to saveCoverImage
                    coverImageFilename = try saveCoverImage(coverUIImage)
                    isLocalCover = true
                    Logger.debug(category: "EPUBImportProcessor", "Saved cover image as \(coverImageFilename ?? "N/A")")
                } catch {
                    Logger.error(category: "EPUBImportProcessor", "Failed to save extracted cover image: \(error). Falling back to default.")
                    // Fallback will be handled after this switch block
                }
            } else {
                // coverResult was .success, but the UIImage? was nil
                Logger.warning(category: "EPUBImportProcessor", "coverFitting succeeded but returned nil image. Falling back.")
            }

        case .failure(let coverError): // Capture the ReadError
            Logger.error(category: "EPUBImportProcessor", "Failed to extract cover using publication.coverFitting: \(coverError.localizedDescription). Falling back.")
            // Fallback will be handled after this switch block
        }

        // Handle fallback to default cover if needed
        if coverImageFilename == nil {
            coverImageFilename = defaultCovers.randomElement() ?? "COTECover" // Use asset name
            isLocalCover = false // Indicate it's an asset
            Logger.debug(category: "EPUBImportProcessor", "Using default asset cover: \(coverImageFilename ?? "N/A")")
        }

        // Create the Book object
        return Book(
            title: title,
            author: author,
            filePath: fullPath,
            coverImagePath: coverImageFilename,
            isLocalCover: isLocalCover,
            addedDate: Date(),
            readingProgress: 0.0
        )
    }
    
    // Helper function to save the cover image and return its relative path
    private func saveCoverImage(_ image: UIImage) throws -> String {
        guard let imageData = image.pngData() else {
            throw ImportError.coverExtractionFailed("Failed to convert UIImage to PNG data")
        }

        let fileManager = FileManager.default

        // Get the Documents directory URL
        let documentsDirectory = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true // Ensure Documents directory exists
        )
        let coversDirectory = documentsDirectory.appendingPathComponent("BookCovers", isDirectory: true)

        // Create the Covers directory if it doesn't exist
        if !fileManager.fileExists(atPath: coversDirectory.path) {
            try fileManager.createDirectory(at: coversDirectory, withIntermediateDirectories: true, attributes: nil)
            Logger.debug(category: "EPUBImportProcessor", "Created BookCovers directory at \(coversDirectory.path)")
        }

        // Generate a unique filename
        let filename = "cover_\(UUID().uuidString).png"
        let coverURL = coversDirectory.appendingPathComponent(filename)

        // Write the image data
        try imageData.write(to: coverURL)
        Logger.debug(category: "EPUBImportProcessor", "Saved cover as PNG: \(coverURL.path)")

        // Return the relative path from Documents directory
        let relativePath = "BookCovers/\(filename)"
        Logger.debug(category: "EPUBImportProcessor", "Returning relative cover path: \(relativePath)")
        return relativePath
    }
    
    enum ImportError: Error {
        case invalidFileType
        case metadataExtractionFailed(String)
        case coverExtractionFailed(String)
        case fileSaveFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidFileType:
                return "Invalid file type. Only EPUB files are supported."
            case .metadataExtractionFailed(let reason):
                return "Failed to extract metadata: \(reason)"
            case .coverExtractionFailed(let reason):
                return "Failed to extract cover image: \(reason)"
            case .fileSaveFailed(let reason):
                return "Failed to save file: \(reason)"
            }
        }
    }
}
