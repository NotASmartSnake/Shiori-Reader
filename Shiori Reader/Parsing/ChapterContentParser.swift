//
//  ChapterContentParser.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/16/25.
//

import Foundation
import ZIPFoundation

class ChapterContentParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    private var content = ""
    private var isInBody = false
    private var elementStack: [String] = []
    private var currentAttributes: [String: String] = [:]
    private var rawXML = "" // Store raw XML structure
    
    func parseChapterContent(_ xmlString: String) -> String {
        print("🔄 Starting chapter content parse")
        print("📝 Sample of input XML: \(xmlString.prefix(500))")
        
        // Instead of using XMLParser which might strip tags,
        // let's try to extract just the body content while preserving tags
        if let bodyContent = extractBodyContent(from: xmlString) {
            print("✅ Successfully extracted body content")
            print("📝 Sample of output: \(bodyContent.prefix(500))")
            return bodyContent
        }
        
        print("❌ Failed to extract body content")
        return xmlString // Return original content as fallback
    }
    
    private func extractBodyContent(from xmlString: String) -> String? {
        // Define patterns to match content between body tags
        // This preserves all HTML tags including ruby
        let bodyPattern = try? NSRegularExpression(
            pattern: "<body[^>]*>(.*?)</body>",
            options: [.dotMatchesLineSeparators]
        )
        
        let range = NSRange(xmlString.startIndex..<xmlString.endIndex, in: xmlString)
        
        if let match = bodyPattern?.firstMatch(in: xmlString, options: [], range: range),
           let bodyRange = Range(match.range(at: 1), in: xmlString) {
            return String(xmlString[bodyRange])
        }
        
        return nil
    }
}
