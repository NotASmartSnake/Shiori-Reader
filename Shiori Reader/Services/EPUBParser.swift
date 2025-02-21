//
//  EPUBParser.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/14/25.
//

import Foundation
import ZIPFoundation

// MARK: - Models
struct Chapter: Codable {
    var title: String
    var content: String
    var images: [String]
    var filePath: String
}

struct EPUBMetadata: Codable {
    let title: String
    let author: String
    let language: String
    var publisher: String?
    var publicationDate: String?
    var rights: String?
    var identifier: String?
    
    init(title: String, author: String, language: String,
         publisher: String? = nil, publicationDate: String? = nil,
         rights: String? = nil, identifier: String? = nil) {
        self.title = title
        self.author = author
        self.language = language
        self.publisher = publisher
        self.publicationDate = publicationDate
        self.rights = rights
        self.identifier = identifier
    }
}

//// MARK: - EPUB Parser
class EPUBParser {
    private let fileManager = FileManager.default
    private var imageDirs: [String] = []
    
    func parseEPUB(at filePath: String) throws -> (content: EPUBContent, baseURL: URL) {
        // Create a persistent directory
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        let bookHash = abs((filePath as NSString).lastPathComponent.hash)
        let extractionDir = documentsURL.appendingPathComponent("books/\(bookHash)", isDirectory: true)
        
        // Clean existing directory
        try? fileManager.removeItem(at: extractionDir)
        try fileManager.createDirectory(at: extractionDir, withIntermediateDirectories: true)
        
        // Extract EPUB contents
        let archive = try Archive(url: URL(fileURLWithPath: filePath), accessMode: .read)
        
        // First pass: identify image directories
        for entry in archive {
            let components = entry.path.components(separatedBy: "/")
            let fileExtension = (entry.path as NSString).pathExtension.lowercased()
            let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "svg"]
            
            if imageExtensions.contains(fileExtension) {
                if let dirIndex = components.dropLast().lastIndex(where: { $0 == "image" || $0 == "images" }) {
                    let imageDir = components[0...dirIndex].joined(separator: "/")
                    if !imageDirs.contains(imageDir) {
                        imageDirs.append(imageDir)
                    }
                }
            }
        }
        
        // Second pass: extract files
        var images: [String: Data] = [:]
        for entry in archive {
            let entryURL = extractionDir.appendingPathComponent(entry.path)
            
            // Create containing directory
            try fileManager.createDirectory(
                at: entryURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            // Extract file
            _ = try archive.extract(entry, to: entryURL)
            
            // If it's an image, store its data
            let fileExtension = (entry.path as NSString).pathExtension.lowercased()
            let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "svg"]
            
            if imageExtensions.contains(fileExtension) {
                let imageData = try Data(contentsOf: entryURL)
                images[entry.path] = imageData
            }
        }
        
        // Find and parse chapters with spine order
        let (chapters, spineOrder) = try findAndParseChapters(in: extractionDir, images: images)
        let metadata = try extractMetadata(from: extractionDir)
        
        return (EPUBContent(chapters: chapters, metadata: metadata, images: images, spineOrder: spineOrder), extractionDir)
    }
    
    private func extractImages(from archive: Archive, to directory: URL) throws -> [String: Data] {
        var images: [String: Data] = [:]
        
        for entry in archive {
            let fileExtension = (entry.path as NSString).pathExtension.lowercased()
            let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "svg"]
            
            if imageExtensions.contains(fileExtension) {
                
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
                }
            }
        }
        
        return images
    }
    
    private func findAndParseChapters(in directory: URL, images: [String: Data]) throws -> (chapters: [Chapter], spineOrder: [String]) {
            
            // First find the OPF file
            let opfURL = try findOPFFile(in: directory)
            
            // Parse the OPF to get spine order
            let opfContent = try String(contentsOf: opfURL, encoding: .utf8)
            let spineOrder = try parseSpineOrder(from: opfContent, baseDirectory: opfURL.deletingLastPathComponent())
            
            // Create a dictionary to store chapters by their file path
            var chapterDict: [String: Chapter] = [:]
            
            // Parse all HTML/XHTML files
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
                
                let htmlContent = try String(contentsOf: fileURL, encoding: .utf8)
                let chapterImgRefs = findImageReferences(in: htmlContent)
                
                chapterDict[fileURL.lastPathComponent] = Chapter(
                    title: extractTitle(from: htmlContent) ?? "Untitled Chapter",
                    content: htmlContent,
                    images: chapterImgRefs,
                    filePath: fileURL.lastPathComponent
                )
                
            }
            
            // Create ordered chapter array based on spine
            var orderedChapters: [Chapter] = []
            for href in spineOrder {
                if let fileName = href.components(separatedBy: "/").last,
                   let chapter = chapterDict[fileName] {
                    orderedChapters.append(chapter)
                }
            }
            
            // Append any remaining chapters not in spine (should be rare)
            for (fileName, chapter) in chapterDict {
                if !spineOrder.contains(where: { $0.contains(fileName) }) {
                    orderedChapters.append(chapter)
                }
            }
            
            return (orderedChapters, spineOrder)
        }
        
        private func findOPFFile(in directory: URL) throws -> URL {
            // First look for container.xml in META-INF
            let containerURL = directory.appendingPathComponent("META-INF/container.xml")
            let containerContent = try String(contentsOf: containerURL, encoding: .utf8)
            
            // Extract root file path from container.xml
            let rootFilePattern = "rootfile[^>]+full-path=\"([^\"]+)\""
            guard let regex = try? NSRegularExpression(pattern: rootFilePattern),
                  let match = regex.firstMatch(in: containerContent, range: NSRange(containerContent.startIndex..., in: containerContent)),
                  let range = Range(match.range(at: 1), in: containerContent) else {
                throw EPUBError.invalidArchive
            }
            
            let opfPath = String(containerContent[range])
            return directory.appendingPathComponent(opfPath)
        }
        
    private func parseSpineOrder(from opfContent: String, baseDirectory: URL) throws -> [String] {
        var spineOrder: [String] = []
        
        // First get manifest to map IDs to hrefs
        var manifestMap: [String: String] = [:]
        
        // More flexible pattern that matches item tags with id and href in any order
        let manifestPattern = "<item[^>]*(?:href=\"([^\"]+)\"[^>]*id=\"([^\"]+)\"|id=\"([^\"]+)\"[^>]*href=\"([^\"]+)\")[^>]*>"
        let manifestRegex = try NSRegularExpression(pattern: manifestPattern)
        let manifestMatches = manifestRegex.matches(in: opfContent, range: NSRange(opfContent.startIndex..., in: opfContent))
        
        for match in manifestMatches {
            // Check both possible orders (href-then-id and id-then-href)
            let href: String
            let id: String
            
            if let hrefRange = Range(match.range(at: 1), in: opfContent),
               let idRange = Range(match.range(at: 2), in: opfContent) {
                // href comes before id
                href = String(opfContent[hrefRange])
                id = String(opfContent[idRange])
            } else if let idRange = Range(match.range(at: 3), in: opfContent),
                      let hrefRange = Range(match.range(at: 4), in: opfContent) {
                // id comes before href
                id = String(opfContent[idRange])
                href = String(opfContent[hrefRange])
            } else {
                continue
            }
            
            manifestMap[id] = href
        }
        
        // Then get spine order
        let spinePattern = "<itemref[^>]+idref=\"([^\"]+)\""
        let spineRegex = try NSRegularExpression(pattern: spinePattern)
        let spineMatches = spineRegex.matches(in: opfContent, range: NSRange(opfContent.startIndex..., in: opfContent))
        
        for match in spineMatches {
            guard let idRange = Range(match.range(at: 1), in: opfContent) else { continue }
            let id = String(opfContent[idRange])
            if let href = manifestMap[id] {
                spineOrder.append(href)
            }
        }
        
        return spineOrder
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
            // Find the OPF file
            let opfURL = try findOPFFile(in: directory)
            let opfContent = try String(contentsOf: opfURL, encoding: .utf8)
            
            var title = "Unknown Title"
            var author = "Unknown Author"
            var language = "en"
            
            // Extract title
            if let titleRegex = try? NSRegularExpression(pattern: "<dc:title[^>]*>([^<]+)</dc:title>", options: [.caseInsensitive]),
               let titleMatch = titleRegex.firstMatch(in: opfContent, range: NSRange(opfContent.startIndex..., in: opfContent)),
               let titleRange = Range(titleMatch.range(at: 1), in: opfContent) {
                title = String(opfContent[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Extract author (checking multiple possible tags)
            let authorPatterns = [
                "<dc:creator[^>]*>([^<]+)</dc:creator>",
                "<dc:contributor[^>]*role=\"aut\"[^>]*>([^<]+)</dc:contributor>"
            ]
            
            for pattern in authorPatterns {
                if let authorRegex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                   let authorMatch = authorRegex.firstMatch(in: opfContent, range: NSRange(opfContent.startIndex..., in: opfContent)),
                   let authorRange = Range(authorMatch.range(at: 1), in: opfContent) {
                    author = String(opfContent[authorRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
            
            // Extract language
            if let langRegex = try? NSRegularExpression(pattern: "<dc:language[^>]*>([^<]+)</dc:language>", options: [.caseInsensitive]),
               let langMatch = langRegex.firstMatch(in: opfContent, range: NSRange(opfContent.startIndex..., in: opfContent)),
               let langRange = Range(langMatch.range(at: 1), in: opfContent) {
                language = String(opfContent[langRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Try to extract additional metadata if available
            let additionalMetadataPatterns = [
                "publisher": "<dc:publisher[^>]*>([^<]+)</dc:publisher>",
                "date": "<dc:date[^>]*>([^<]+)</dc:date>",
                "rights": "<dc:rights[^>]*>([^<]+)</dc:rights>",
                "identifier": "<dc:identifier[^>]*>([^<]+)</dc:identifier>"
            ]
            
            var additionalMetadata: [String: String] = [:]
            
            for (key, pattern) in additionalMetadataPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                   let match = regex.firstMatch(in: opfContent, range: NSRange(opfContent.startIndex..., in: opfContent)),
                   let range = Range(match.range(at: 1), in: opfContent) {
                    let value = String(opfContent[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    additionalMetadata[key] = value
                }
            }
            
            return EPUBMetadata(
                title: title,
                author: author,
                language: language
            )
        }
    
}

// MARK: - Errors
enum EPUBError: Error {
    case invalidArchive
    case fileNotFound
}

