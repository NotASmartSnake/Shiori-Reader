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
}

struct Chapter: Codable {
    var title: String
    var content: String
}

struct EPUBMetadata: Codable {
    var title: String
    var author: String
    var language: String
}

// MARK: - EPUB Parser
class EPUBParser {
    private let fileManager = FileManager.default
    
    func parseEPUB(at filePath: String) throws -> EPUBContent {
        // Create temporary directory for extracted files
        let tempDir = try createTempDirectory()
        
        // Executes just before the function exits to ensure tempDir is always cleaned
        // try? returns nil when an error occurs
        defer { try? fileManager.removeItem(at: tempDir) }
        
        // Extract EPUB (ZIP) contents
        let fileURL = URL(fileURLWithPath: filePath)
        do {
            let archive = try Archive(url: fileURL, accessMode: .read)
            try extractArchive(archive, to: tempDir)
        } catch {
            throw EPUBError.invalidArchive
        }
        
        // Find HTML files and parse them
         let chapters = try findAndParseChapters(in: tempDir)
         
         // Extract basic metadata
         let metadata = try extractMetadata(from: tempDir)
         
         return EPUBContent(chapters: chapters, metadata: metadata)
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
    
    private func findAndParseChapters(in directory: URL) throws -> [Chapter] {
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
                
                chapters.append(Chapter(
                    title: title,
                    content: htmlContent
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

