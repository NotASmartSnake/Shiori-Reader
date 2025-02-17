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

// MARK: - EPUB Parser
class EPUBParser {
    private let fileManager = FileManager.default
    
    func parseEPUB(at filePath: String) throws -> (content: EPUBContent, baseURL: URL) {
        // Create temporary directory for extracted files
        let tempDir = try createTempDirectory()
        
        // Executes just before the function exits to ensure tempDir is always cleaned
        // try? returns nil when an error occurs
        defer { try? fileManager.removeItem(at: tempDir) }
        
        // Extract EPUB (ZIP) contents
        let fileURL = URL(fileURLWithPath: filePath)
        let archive: Archive
        
        do {
            archive = try Archive(url: fileURL, accessMode: .read)
            try extractArchive(archive, to: tempDir)
        } catch {
            throw EPUBError.invalidArchive
        }
        
        // Extract images first
        let images = try extractImages(from: archive, to: tempDir)
        
        // Find HTML files and parse them
        let chapters = try findAndParseChapters(in: tempDir, images: images)
         
         // Extract basic metadata
        let metadata = try extractMetadata(from: tempDir)
         
        return (EPUBContent(chapters: chapters, metadata: metadata, images: images), tempDir)
    }
    
    private func createTempDirectory() throws -> URL {
        let tempDir = try fileManager.url(
            for: .itemReplacementDirectory, // type of temp dir used for replacing or moving items without affecting orig ones
            in: .userDomainMask, // directory should be located in the user’s domain (home directory)
            appropriateFor: URL(fileURLWithPath: NSTemporaryDirectory()), // specifies a URL to a directory that is appropriate for the operation
            create: true
        )
        return tempDir
    }
    
    private func extractArchive(_ archive: Archive, to destination: URL) throws {
        for entry in archive {
            // Use underscore to explicitly ignore the return value
            _ = try archive.extract(entry, to: destination.appendingPathComponent(entry.path))
        }
    }
    
    private func extractImages(from archive: Archive, to tempDir: URL) throws -> [String: Data] {
        var images: [String: Data] = [:]
        
        // Potential image directory patterns
        let imageDirectoryPatterns = [
            "images/",           // Direct images directory
            "image/",            // Singular "image" directory
            "items/*/image/",    // Nested directory under "items"
            "OEBPS/images/",     // Common EPUB standard directory
            "*/images/",         // Wildcard match for any parent directory
            "*/image/"           // Wildcard match for any parent directory
        ]
        
        for entry in archive {
            // Check if the entry is an image file
            let fileExtension = (entry.path as NSString).pathExtension.lowercased()
            let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "svg"]
            
            guard imageExtensions.contains(fileExtension) else {
                continue
            }
            
            // Check if the path matches any image directory pattern
            let isImageFile = imageDirectoryPatterns.contains { pattern in
                entry.path.contains(pattern.replacingOccurrences(of: "*", with: "[^/]+"))
            }
            
            guard isImageFile else {
                print("Skipping non-image file in image directories: \(entry.path)")
                continue
            }
            
            do {
                let imageURL = tempDir.appendingPathComponent(entry.path)
                
                // Ensure the directory exists
                try FileManager.default.createDirectory(
                    at: imageURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                
                // Extract image data
                let imageData = try Data(contentsOf: imageURL)
                print("✅ Extracted image: \(entry.path)")
                print("Image size: \(imageData.count) bytes")
                
                images[entry.path] = imageData
            } catch {
                print("❌ Error extracting image \(entry.path): \(error)")
            }
        }
        
        print("🖼️ Total images extracted: \(images.count)")
        print("Extracted image paths: \(images.keys)")
        
        return images
    }
    
    private func findAndParseChapters(in directory: URL, images: [String: Data]) throws -> [Chapter] {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: directory,
                                                includingPropertiesForKeys: [.isRegularFileKey],
                                                options: [.skipsHiddenFiles])
        
        var chapters: [Chapter] = []
        
        while let fileURL = enumerator?.nextObject() as? URL {
            // Only process .html or .xhtml files
            guard fileURL.pathExtension.lowercased() == "html" ||
                  fileURL.pathExtension.lowercased() == "xhtml" else {
                continue
            }
            
            do {
                let htmlContent = try String(contentsOf: fileURL, encoding: .utf8)
                let title = extractTitle(from: htmlContent) ?? "Untitled Chapter"
                
                // Find image references
                let chapterImages = findImageReferences(in: htmlContent)
                
                // Modify image references to be local
                let modifiedContent = updateImageReferences(htmlContent, baseURL: fileURL.deletingLastPathComponent())
                
                chapters.append(Chapter(
                    title: title,
                    content: modifiedContent,
                    images: chapterImages
                ))
            } catch {
                // Log or handle individual file read errors if needed
                print("Error reading file \(fileURL): \(error)")
            }
        }
        
        // Sort chapters by file path to maintain some semblance of order
        chapters.sort { $0.title < $1.title }
        
        return chapters
    }
    
    private func findImageReferences(in htmlContent: String) -> [String] {
        var imageRefs: [String] = []
        
        // Regex for <img> tags
        let imgRegex = try? NSRegularExpression(pattern: "<img[^>]+src=\"([^\"]+)\"", options: [.caseInsensitive])
        
        // Regex for SVG xlink:href
        let svgRegex = try? NSRegularExpression(pattern: "xlink:href=\"([^\"]+)\"", options: [.caseInsensitive])
        
        // Find <img> tag references
        if let imgMatches = imgRegex?.matches(in: htmlContent, range: NSRange(htmlContent.startIndex..., in: htmlContent)) {
            let imgRefs = imgMatches.compactMap { match in
                let range = Range(match.range(at: 1), in: htmlContent)
                return range.map { String(htmlContent[$0]) }
            }
            imageRefs.append(contentsOf: imgRefs)
        }
        
        // Find SVG image references
        if let svgMatches = svgRegex?.matches(in: htmlContent, range: NSRange(htmlContent.startIndex..., in: htmlContent)) {
            let svgRefs = svgMatches.compactMap { match in
                let range = Range(match.range(at: 1), in: htmlContent)
                return range.map { String(htmlContent[$0]) }
            }
            imageRefs.append(contentsOf: svgRefs)
        }
        
        print("Image references found: \(imageRefs)")
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
        // Simple title extraction from <title> tag or first <h1>
        let titleRegex = try? NSRegularExpression(pattern: "<title>(.*?)</title>", options: [.caseInsensitive])
        let h1Regex = try? NSRegularExpression(pattern: "<h1>(.*?)</h1>", options: [.caseInsensitive])
        
        if let titleMatch = titleRegex?.firstMatch(in: htmlContent, range: NSRange(htmlContent.startIndex..., in: htmlContent)) {
            let range = Range(titleMatch.range(at: 1), in: htmlContent)
            return range.map { String(htmlContent[$0]) }
        }
        
        if let h1Match = h1Regex?.firstMatch(in: htmlContent, range: NSRange(htmlContent.startIndex..., in: htmlContent)) {
            let range = Range(h1Match.range(at: 1), in: htmlContent)
            return range.map { String(htmlContent[$0]) }
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

