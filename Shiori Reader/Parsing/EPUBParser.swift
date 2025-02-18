//
//  EPUBParser.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/14/25.
//

import Foundation
import ZIPFoundation

// MARK: - Models
struct EPUBContent: Codable {
    var chapters: [Chapter]
    var metadata: EPUBMetadata
    var images: [String: Data]
}

struct Chapter: Codable {
    var title: String
    var content: String
    var images: [String]
}

struct EPUBMetadata: Codable {
    var title: String
    var author: String
    var language: String
}

//// MARK: - EPUB Parser
class EPUBParser {
    private let fileManager = FileManager.default
    
    func parseEPUB(at filePath: String) throws -> (content: EPUBContent, baseURL: URL) {
        // Get documents directory
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        // Create a unique directory for this book
        let bookName = (filePath as NSString).lastPathComponent
        let bookHash = abs(bookName.hash) // Use absolute value to avoid negative numbers
        let extractionDir = documentsURL.appendingPathComponent("books/\(bookHash)", isDirectory: true)
        
        print("📚 Extraction directory:", extractionDir.path)
        
        // Ensure clean directory
        try? fileManager.removeItem(at: extractionDir)
        try fileManager.createDirectory(
            at: extractionDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Extract EPUB contents
        let fileURL = URL(fileURLWithPath: filePath)
        let archive = try Archive(url: fileURL, accessMode: .read)
        
        // Extract images and other files
        var images: [String: Data] = [:]
        for entry in archive {
            let entryURL = extractionDir.appendingPathComponent(entry.path)
            
            // Create containing directory
            try fileManager.createDirectory(
                at: entryURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            // Extract the file
            try archive.extract(entry, to: entryURL)
            
            // If it's an image, store its data
            let fileExtension = (entry.path as NSString).pathExtension.lowercased()
            let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "svg"]
            
            if imageExtensions.contains(fileExtension) {
                print("🖼️ Found image:", entry.path)
                let imageData = try Data(contentsOf: entryURL)
                images[entry.path] = imageData
                print("✅ Stored image data (\(imageData.count) bytes):", entry.path)
            }
        }
        
        // Find and parse chapters
        let chapters = try findAndParseChapters(in: extractionDir, images: images)
        
        // Extract metadata
        let metadata = try extractMetadata(from: extractionDir)
        
        // Verify files
        var allFilesExist = true
        for (path, _) in images {
            let fullPath = extractionDir.appendingPathComponent(path)
            if fileManager.fileExists(atPath: fullPath.path) {
                print("✅ Verified file exists:", path)
            } else {
                print("❌ File missing:", path)
                allFilesExist = false
            }
        }
        
        if !allFilesExist {
            print("⚠️ Some files are missing, but continuing...")
        }
        
        return (EPUBContent(chapters: chapters, metadata: metadata, images: images), extractionDir)
    }
    
    private func extractImages(from archive: Archive, to directory: URL) throws -> [String: Data] {
        var images: [String: Data] = [:]
        
        for entry in archive {
            let fileExtension = (entry.path as NSString).pathExtension.lowercased()
            let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "svg"]
            
            if imageExtensions.contains(fileExtension) {
                print("🖼️ Found image:", entry.path)
                
                let imageURL = directory.appendingPathComponent(entry.path)
                
                // Create directory if needed
                try fileManager.createDirectory(
                    at: imageURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                
                // Extract and verify the file
                _ = try archive.extract(entry, to: imageURL)
                
                if fileManager.fileExists(atPath: imageURL.path) {
                    let imageData = try Data(contentsOf: imageURL)
                    images[entry.path] = imageData
                    print("✅ Extracted image (\(imageData.count) bytes):", entry.path)
                }
            }
        }
        
        return images
    }
    
    private func findAndParseChapters(in directory: URL, images: [String: Data]) throws -> [Chapter] {
        print("🔍 Finding chapters in:", directory.path)
        var chapters: [Chapter] = []
        
        let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension.lowercased() == "html" ||
                  fileURL.pathExtension.lowercased() == "xhtml" else {
                continue
            }
            
            print("📄 Processing chapter:", fileURL.lastPathComponent)
            
            let htmlContent = try String(contentsOf: fileURL, encoding: .utf8)
            let chapterImgRefs = findImageReferences(in: htmlContent)
            
            chapters.append(Chapter(
                title: extractTitle(from: htmlContent) ?? "Untitled Chapter",
                content: htmlContent,
                images: chapterImgRefs
            ))
            
            print("✅ Processed chapter with \(chapterImgRefs.count) images")
        }
        
        chapters.sort { $0.title < $1.title }
        return chapters
    }
    
    private func findImageReferences(in htmlContent: String) -> [String] {
        var imageRefs: [String] = []
        
        // Find standard image tags
        let imgRegex = try? NSRegularExpression(pattern: "src=\"([^\"]+)\"", options: [.caseInsensitive])
        if let matches = imgRegex?.matches(in: htmlContent, range: NSRange(htmlContent.startIndex..., in: htmlContent)) {
            for match in matches {
                if let range = Range(match.range(at: 1), in: htmlContent) {
                    let imagePath = String(htmlContent[range])
                    let cleanPath = imagePath.replacingOccurrences(of: "../", with: "")
                    imageRefs.append(cleanPath)
                }
            }
        }
        
        // Find SVG image references
        let svgRegex = try? NSRegularExpression(pattern: "xlink:href=\"([^\"]+)\"", options: [.caseInsensitive])
        if let matches = svgRegex?.matches(in: htmlContent, range: NSRange(htmlContent.startIndex..., in: htmlContent)) {
            for match in matches {
                if let range = Range(match.range(at: 1), in: htmlContent) {
                    let imagePath = String(htmlContent[range])
                    let cleanPath = imagePath.replacingOccurrences(of: "../", with: "")
                    imageRefs.append(cleanPath)
                }
            }
        }
        
        return imageRefs
    }
    
    private func updateImageReferences(_ htmlContent: String, baseURL: URL) -> String {
        var modifiedContent = htmlContent
        
        let imageRegexPatterns = [
            "<img[^>]+src=\"([^\"]+)\"",
            "xlink:href=\"([^\"]+)\""
        ]
        
        imageRegexPatterns.forEach { pattern in
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            
            let matches = regex?.matches(in: modifiedContent, range: NSRange(modifiedContent.startIndex..., in: modifiedContent))
            
            matches?.reversed().forEach { match in
                guard let range = Range(match.range(at: 1), in: modifiedContent) else { return }
                
                let originalSrc = String(modifiedContent[range])
                
                print("🖼️ Original image source in chapter: \(originalSrc)")
                
                // Simply replace the path, keeping the relative structure
                // We'll rely on BookReaderView to do the final resolution
                let cleanPath = originalSrc
                    .replacingOccurrences(of: "file://", with: "")
                    .replacingOccurrences(of: "../", with: "")
                
                let replacementTag: String
                if pattern.contains("img") {
                    replacementTag = "<img src=\"\(cleanPath)\" />"
                } else {
                    replacementTag = "xlink:href=\"\(cleanPath)\""
                }
                
                // Replace the entire tag
                if let fullMatchRange = modifiedContent.range(of: "\(pattern.replacingOccurrences(of: "([^\"]+)", with: "\(originalSrc)"))", options: .regularExpression) {
                    modifiedContent.replaceSubrange(fullMatchRange, with: replacementTag)
                }
            }
        }
        
        return modifiedContent
    }
    
    private func extractTitle(from htmlContent: String) -> String? {
        // Try to find title in various places
        let patterns = [
            "<title>(.*?)</title>",
            "<h1>(.*?)</h1>"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: htmlContent, range: NSRange(htmlContent.startIndex..., in: htmlContent)),
               let range = Range(match.range(at: 1), in: htmlContent) {
                return String(htmlContent[range])
            }
        }
        
        return nil
    }
    
    private func extractMetadata(from directory: URL) throws -> EPUBMetadata {
        return EPUBMetadata(
            title: "Unknown Title",
            author: "Unknown Author",
            language: "en"
        )
    }
    
}

// MARK: - Errors
enum EPUBError: Error {
    case invalidArchive
    case fileNotFound
}

