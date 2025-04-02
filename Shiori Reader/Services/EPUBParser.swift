//
//  EPUBParser.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/14/25.
//

import Foundation
import ZIPFoundation

class EPUBParser {
    private let fileManager = FileManager.default
    private var imageDirs: [String] = []
    
    func parseEPUB(at filePath: String) throws -> (content: EPUBContent, baseURL: URL) {
        print("DEBUG: Beginning EPUB parse of: \(filePath)")
        
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
        
        // Explicitly check file existence
        if !FileManager.default.fileExists(atPath: filePath) {
            print("DEBUG: EPUB file does not exist at: \(filePath)")
            throw EPUBError.fileNotFound
        }
           
        print("DEBUG: Attempting to create Archive with URL: \(URL(fileURLWithPath: filePath))")
        // Extract EPUB contents
        do {
            let archive = try Archive(url: URL(fileURLWithPath: filePath), accessMode: .read)
            
            var entryCount = 0
            for _ in archive {
                entryCount += 1
            }
            
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
            var filesExtracted = 0
            
            for entry in archive {
                let entryURL = extractionDir.appendingPathComponent(entry.path)
                
                // Create containing directory
                do {
                    try fileManager.createDirectory(
                        at: entryURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                    
                    // Extract file
                    _ = try archive.extract(entry, to: entryURL)
                    filesExtracted += 1
                    
                    // If it's an image, store its data
                    let fileExtension = (entry.path as NSString).pathExtension.lowercased()
                    let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "svg"]
                    
                    if imageExtensions.contains(fileExtension) {
                        let imageData = try Data(contentsOf: entryURL)
                        images[entry.path] = imageData
                    }
                } catch {
                    print("DEBUG: Error extracting \(entry.path): \(error)")
                }
            }
            
            // Find and parse chapters with spine order
            let (chapters, spineOrder) = try findAndParseChapters(in: extractionDir, images: images)
            
            let metadata = try extractMetadata(from: extractionDir)
            
            let tableOfContents = try parseTOC(in: extractionDir)
                        
            return (EPUBContent(
                chapters: chapters,
                metadata: metadata,
                images: images,
                spineOrder: spineOrder,
                tableOfContents: tableOfContents
            ), extractionDir)
        } catch {
            print("DEBUG: Archive creation error: \(error)")
            throw error
        }
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
            
            let originalHTMLContent = try String(contentsOf: fileURL, encoding: .utf8) // Process HTML *before* creating the Chapter object
            let processedHTMLContent = processChapterHTML(content: originalHTMLContent, htmlFileURL: fileURL, extractionBaseURL: directory)
            let chapterImgRefs = findImageReferences(in: processedHTMLContent) // Use processed content here too if needed

            chapterDict[fileURL.lastPathComponent] = Chapter(
                title: extractTitle(from: processedHTMLContent) ?? "Untitled Chapter",
                content: processedHTMLContent, // Store the MODIFIED content
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
    
    private func processChapterHTML(content: String, htmlFileURL: URL, extractionBaseURL: URL) -> String {
        var modifiedContent = content
        let fileManager = FileManager.default
        let htmlDirectoryURL = htmlFileURL.deletingLastPathComponent()

        // Regex for src attribute in img tags
        let imgPattern = "<img[^>]+src=[\"']([^\"']+)[\"']"
        if let imgRegex = try? NSRegularExpression(pattern: imgPattern, options: .caseInsensitive) {
            let matches = imgRegex.matches(in: modifiedContent, range: NSRange(modifiedContent.startIndex..., in: modifiedContent))
            for match in matches.reversed() { // Iterate reversed to avoid range issues
                if let srcRange = Range(match.range(at: 1), in: modifiedContent),
                   let fullTagRange = Range(match.range(at: 0), in: modifiedContent) {
                    let originalSrc = String(modifiedContent[srcRange])

                    // Resolve the absolute path of the image
                    let absoluteImageURL = URL(string: originalSrc, relativeTo: htmlDirectoryURL)!.standardizedFileURL

                    // Check if the file exists
                    if fileManager.fileExists(atPath: absoluteImageURL.path) {
                        // Calculate path relative to the extraction root
                        if let relativePath = absoluteImageURL.path.replacingOccurrences(of: extractionBaseURL.path, with: "").removingPercentEncoding {
                            let cleanedRelativePath = relativePath.starts(with: "/") ? String(relativePath.dropFirst()) : relativePath
                            let newSrcAttribute = "src=\"\(cleanedRelativePath)\""
                            // Replace only the src part within the tag
                            let tagString = String(modifiedContent[fullTagRange])
                            let updatedTag = tagString.replacingOccurrences(of: "src=[\"']\(originalSrc)[\"']", with: newSrcAttribute, options: .regularExpression)
                            modifiedContent.replaceSubrange(fullTagRange, with: updatedTag)
                         }
                    } else {
                         print("⚠️ Image not found during parsing: \(absoluteImageURL.path)")
                    }
                }
            }
        }

        // Add similar logic for xlink:href if needed (for SVG images)
        let xlinkPattern = "<image[^>]+xlink:href=[\"']([^\"']+)[\"']"
         if let xlinkRegex = try? NSRegularExpression(pattern: xlinkPattern, options: .caseInsensitive) {
             let matches = xlinkRegex.matches(in: modifiedContent, range: NSRange(modifiedContent.startIndex..., in: modifiedContent))
              for match in matches.reversed() {
                 if let hrefRange = Range(match.range(at: 1), in: modifiedContent),
                    let fullTagRange = Range(match.range(at: 0), in: modifiedContent) {
                     let originalHref = String(modifiedContent[hrefRange])
                     let absoluteImageURL = URL(string: originalHref, relativeTo: htmlDirectoryURL)!.standardizedFileURL
                     if fileManager.fileExists(atPath: absoluteImageURL.path) {
                         if let relativePath = absoluteImageURL.path.replacingOccurrences(of: extractionBaseURL.path, with: "").removingPercentEncoding {
                             let cleanedRelativePath = relativePath.starts(with: "/") ? String(relativePath.dropFirst()) : relativePath
                             let newHrefAttribute = "xlink:href=\"\(cleanedRelativePath)\""
                             let tagString = String(modifiedContent[fullTagRange])
                             let updatedTag = tagString.replacingOccurrences(of: "xlink:href=[\"']\(originalHref)[\"']", with: newHrefAttribute, options: .regularExpression)
                             modifiedContent.replaceSubrange(fullTagRange, with: updatedTag)
                         }
                     } else {
                         print("⚠️ SVG Image not found during parsing: \(absoluteImageURL.path)")
                     }
                 }
             }
         }


        return modifiedContent
    }
        
    private func findOPFFile(in directory: URL) throws -> URL {
        // First look for container.xml in META-INF
        let containerURL = directory.appendingPathComponent("META-INF/container.xml")
        
        guard fileManager.fileExists(atPath: containerURL.path) else {
            
            // List contents of the META-INF directory if it exists
            let metaInfDir = directory.appendingPathComponent("META-INF")
            if fileManager.fileExists(atPath: metaInfDir.path, isDirectory: nil) {
                do {
                    let contents = try fileManager.contentsOfDirectory(at: metaInfDir, includingPropertiesForKeys: nil)
                } catch {
                    print("DEBUG: Error listing META-INF: \(error)")
                }
            } else {
                print("DEBUG: META-INF directory not found")
            }
            
            throw EPUBError.invalidArchive
        }
        
        do {
            let containerContent = try String(contentsOf: containerURL, encoding: .utf8)
            
            // Extract root file path from container.xml
            let rootFilePattern = "rootfile[^>]+full-path=\"([^\"]+)\""
            guard let regex = try? NSRegularExpression(pattern: rootFilePattern),
                  let match = regex.firstMatch(in: containerContent, range: NSRange(containerContent.startIndex..., in: containerContent)),
                  let range = Range(match.range(at: 1), in: containerContent) else {
                throw EPUBError.invalidArchive
            }
            
            let opfPath = String(containerContent[range])
            
            let opfURL = directory.appendingPathComponent(opfPath)
            if fileManager.fileExists(atPath: opfURL.path) {
                return opfURL
            } else {
                throw EPUBError.fileNotFound
            }
        } catch {
            throw error
        }
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
    
    private func parseTOC(in directory: URL) throws -> [TOCEntry] {
        do {
            // First try to find the TOC file (either NCX or EPUB3 nav)
            let tocURL = try findTOCFile(in: directory)
            let tocContent = try String(contentsOf: tocURL, encoding: .utf8)
                        
            // Check if this is an NCX file or an EPUB3 nav document
            let isNavDocument = tocContent.contains("epub:type=\"toc\"") ||
                                tocContent.contains("epub:type='toc'") ||
                                tocURL.pathExtension.lowercased() == "xhtml" ||
                                tocURL.lastPathComponent.contains("nav")
            
            if isNavDocument {
                return try parseNavContent(tocContent)
            } else {
                return try parseNCXContent(tocContent)
            }
        } catch {
            print("DEBUG: Error parsing TOC: \(error.localizedDescription)")
            // Return an empty TOC if we can't parse it
            return []
        }
    }

    
    private func findTOCFile(in directory: URL) throws -> URL {
        
        let commonPaths = [
            "toc.ncx",
            "OEBPS/toc.ncx",
            "OPS/toc.ncx",
            "nav.xhtml",
            "navigation-documents.xhtml",
            "item/navigation-documents.xhtml",
            "OEBPS/nav.xhtml",
            "OEBPS/navigation-documents.xhtml",
            "OPS/nav.xhtml",
            "OPS/navigation-documents.xhtml"
        ]
        
        for path in commonPaths {
            let ncxURL = directory.appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: ncxURL.path) {
                return ncxURL
            }
        }
        
        // If not found in common locations, look for it in the OPF file
        let opfURL = try findOPFFile(in: directory)
        let opfContent = try String(contentsOf: opfURL, encoding: .utf8)
        
        // Try to find NCX reference in OPF
        let ncxPatterns = [
            "href=\"([^\"]+\\.ncx)\"",  // NCX file reference
            "properties=\"nav\"[^>]*href=\"([^\"]+)\"",  // EPUB3 nav file
            "media-type=\"application/x-dtbncx\\+xml\"[^>]*href=\"([^\"]+)\""  // Alternative NCX pattern
        ]
        
        for pattern in ncxPatterns {
            if let ncxRegex = try? NSRegularExpression(pattern: pattern),
               let match = ncxRegex.firstMatch(in: opfContent, range: NSRange(opfContent.startIndex..., in: opfContent)),
               let range = Range(match.range(at: 1), in: opfContent) {
                
                let ncxPath = String(opfContent[range])
                
                let ncxURL = opfURL.deletingLastPathComponent().appendingPathComponent(ncxPath)
                if FileManager.default.fileExists(atPath: ncxURL.path) {
                    return ncxURL
                }
            }
        }
                
        throw EPUBError.fileNotFound
    }
    
    private func parseNCXContent(_ content: String) throws -> [TOCEntry] {
        var entries: [TOCEntry] = []
        
        // Parse navMap entries
        let navPointPattern = "<navPoint[^>]*>([\\s\\S]*?)</navPoint>"
        let navPointRegex = try NSRegularExpression(pattern: navPointPattern)
        let navPointMatches = navPointRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        
        for match in navPointMatches {
            if let range = Range(match.range(at: 1), in: content) {
                let navPointContent = String(content[range])
                if let entry = parseNavPoint(navPointContent, level: 1) {
                    entries.append(entry)
                }
            }
        }
        
        return entries
    }
    
    private func parseNavPoint(_ content: String, level: Int) -> TOCEntry? {
        // Extract label
        guard let labelRegex = try? NSRegularExpression(pattern: "<text>([^<]+)</text>"),
              let labelMatch = labelRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let labelRange = Range(labelMatch.range(at: 1), in: content) else {
            return nil
        }
        let label = String(content[labelRange])
        
        // Extract href
        guard let contentRegex = try? NSRegularExpression(pattern: "src=\"([^\"]+)\""),
              let contentMatch = contentRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let contentRange = Range(contentMatch.range(at: 1), in: content) else {
            return nil
        }
        let href = String(content[contentRange])
        
        // Parse child navPoints recursively
        var children: [TOCEntry] = []
        let childPattern = "<navPoint[^>]*>([\\s\\S]*?)</navPoint>"
        if let childRegex = try? NSRegularExpression(pattern: childPattern) {
            let childMatches = childRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            for match in childMatches {
                if let range = Range(match.range(at: 1), in: content),
                   let child = parseNavPoint(String(content[range]), level: level + 1) {
                    children.append(child)
                }
            }
        }
        
        return TOCEntry(label: label, href: href, level: level, children: children)
    }
    
    private func parseNavContent(_ content: String) throws -> [TOCEntry] {
        var entries: [TOCEntry] = []
        
        // EPUB3 nav documents use <li> elements inside a <nav> element with epub:type="toc"
        // We need a more flexible pattern to account for different namespace declarations
        let navPattern = "<nav[^>]*epub:type=[\"']toc[\"'][^>]*>([\\s\\S]*?)</nav>"
        
        guard let navRegex = try? NSRegularExpression(pattern: navPattern, options: [.dotMatchesLineSeparators]),
              let navMatch = navRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let navRange = Range(navMatch.range(at: 1), in: content) else {
            return []
        }
        
        let navContent = String(content[navRange])
        
        // Extract all li elements with their a child elements directly
        let liAPattern = "<li[^>]*>\\s*<a[^>]*href=[\"']([^\"']+)[\"'][^>]*>([^<]+)</a>\\s*</li>"
        let liARegex = try NSRegularExpression(pattern: liAPattern, options: [.dotMatchesLineSeparators])
        let liAMatches = liARegex.matches(in: navContent, range: NSRange(navContent.startIndex..., in: navContent))
                
        for match in liAMatches {
            if let hrefRange = Range(match.range(at: 1), in: navContent),
               let labelRange = Range(match.range(at: 2), in: navContent) {
                
                let href = String(navContent[hrefRange])
                let label = String(navContent[labelRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                entries.append(TOCEntry(label: label, href: href, level: 1, children: []))
            }
        }
        
        return entries
    }
    
}

// MARK: - Errors
enum EPUBError: Error {
    case invalidArchive
    case fileNotFound
}

