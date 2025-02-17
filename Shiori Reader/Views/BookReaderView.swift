//
//  BookReaderView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//

import SwiftUI
import WebKit

struct BookReaderView: View {
    let book: Book
    @State private var epubContent: EPUBContent?
    @State private var errorMessage: String?
    @State private var currentChapterIndex: Int = 8
    @State private var showTableOfContents: Bool = true
    @State private var epubBaseURL: URL?
    
    var body: some View {
        VStack {
            if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
            }
            
            if let content = epubContent {
                ScrollView {
                    // Table of Contents / Chapter Content
                    if showTableOfContents {
                        // TOC Button Row
                        HStack {
                            Text("Table of Contents")
                                .font(.headline)
                            Spacer()
                            Button("Start Reading") {
                                showTableOfContents = false
                            }
                        }
                        .padding()
                        
                        // Chapter List
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(content.chapters.indices, id: \.self) { index in
                                let chapter = content.chapters[index]
                                Button(action: {
                                    currentChapterIndex = index
                                    showTableOfContents = false
                                }) {
                                    Text("Chapter \(index + 1): \(chapter.title)")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding()
                        
                    } else {
                        // Chapter Reading View
                        VStack(alignment: .leading, spacing: 16) {
                            // Navigation Header
                            HStack {
                                Button(action: { showTableOfContents = true }) {
                                    HStack {
                                        Image(systemName: "list.bullet")
                                        Text("Contents")
                                    }
                                }
                                
                                Spacer()
                                
                                // Chapter Navigation
                                HStack(spacing: 20) {
                                    Button(action: previousChapter) {
                                        Image(systemName: "chevron.left")
                                    }
                                    .disabled(currentChapterIndex <= 0)
                                    
                                    Button(action: nextChapter) {
                                        Image(systemName: "chevron.right")
                                    }
                                    .disabled(currentChapterIndex >= content.chapters.count - 1)
                                }
                            }
                            .padding()
                            
                            if content.chapters.indices.contains(currentChapterIndex) {
                                let chapter = content.chapters[currentChapterIndex]
                                let _ = print("Chapter content sample: \(chapter.content.prefix(500))")
                                
                                // Chapter Title
                                Text(chapter.title)
                                    .font(.title)
                                    .padding(.bottom)
                                
                                // Chapter Content
                                WebView(htmlContent: chapter.content, baseURL: epubBaseURL)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .frame(minHeight: 500)
                            }
                        }
                        .padding()
                    }
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .onAppear {
            loadEPUB()
        }
    }
    
    private func nextChapter() {
        guard let content = epubContent else { return }
        if currentChapterIndex < content.chapters.count - 1 {
            currentChapterIndex += 1
        }
    }
    
    private func previousChapter() {
        if currentChapterIndex > 0 {
            currentChapterIndex -= 1
        }
    }
    
    private func loadEPUB() {
        // Get the EPUB file path from the bundle
        guard let epubPath = Bundle.main.path(forResource: book.filePath, ofType: nil) else {
            errorMessage = "Could not find EPUB file in bundle"
            return
        }
        
        do {
            let parser = EPUBParser()
            let (content, baseURL) = try parser.parseEPUB(at: epubPath)
            epubContent = content
            self.epubBaseURL = baseURL  // Store base URL as a property
            
            // Debug: Print image information
            print("Total images extracted: \(epubContent?.images.count ?? 0)")
            epubContent?.images.keys.forEach { imagePath in
                print("Image path: \(imagePath)")
            }
        } catch {
            errorMessage = "Failed to parse EPUB: \(error.localizedDescription)"
            print("EPUB Parsing Error: \(error)")
        }
    }
    
}

struct WebView: UIViewRepresentable {
    let htmlContent: String
    let baseURL: URL?
    
    init(htmlContent: String, baseURL: URL? = nil) {
        self.htmlContent = htmlContent
        self.baseURL = baseURL
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .clear
        webView.isOpaque = false
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        print("Base URL: \(baseURL?.path ?? "nil")")
        
        // Find and log all image sources, including SVG
        let svgImageRegex = try? NSRegularExpression(pattern: "xlink:href=\"([^\"]+)\"", options: [.caseInsensitive])
        let svgMatches = svgImageRegex?.matches(in: htmlContent, range: NSRange(htmlContent.startIndex..., in: htmlContent))
        
        svgMatches?.forEach { match in
            if let range = Range(match.range(at: 1), in: htmlContent) {
                let imageSrc = String(htmlContent[range])
                print("🖼️ SVG Image Source: \(imageSrc)")
                
                // Try to resolve full path
                if let baseURL = baseURL {
                    let strategies = [
                        URL(fileURLWithPath: imageSrc, relativeTo: baseURL).path,
                        baseURL.appendingPathComponent(imageSrc).path,
                        baseURL.appendingPathComponent(imageSrc.replacingOccurrences(of: "../", with: "")).path
                    ]
                    
                    strategies.forEach { fullPath in
                        print("🔎 Checking SVG path: \(fullPath)")
                        if FileManager.default.fileExists(atPath: fullPath) {
                            print("✅ SVG File exists: \(fullPath)")
                        } else {
                            print("❌ SVG File does not exist: \(fullPath)")
                        }
                    }
                }
            }
        }
        
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: "Hiragino Mincho ProN", "Yu Mincho", "MS Mincho", serif;
                    font-size: 18px;
                    line-height: 1.8;
                    padding: 16px;
                    background-color: transparent;
                    color: #333333;
                }
                
                /* Responsive images */
                img, svg image {
                    max-width: 100%;
                    height: auto;
                    display: block;
                    margin: 1em auto;
                }
                
                /* General paragraph styling */
                p {
                    margin: 1.5em 0;
                    text-align: justify;
                }
                
                /* Specific class styling */
                .label-logo {
                    margin: 1.5em 0;
                    text-indent: 1em;
                }
                
                /* Ruby styling */
                ruby {
                    ruby-position: over;
                    ruby-align: center;
                    -webkit-ruby-position: before;
                }
                
                rt {
                    font-size: 0.5em;
                    color: #666666;
                    line-height: 1;
                    text-align: center;
                }
                
                /* Text combine upright for numbers */
                .tcy {
                    -webkit-text-combine: horizontal;
                    -webkit-text-combine-upright: all;
                    text-combine-upright: all;
                    text-orientation: mixed;
                }
                
                /* Hide ruby parentheses */
                rp {
                    display: none;
                }
                
                /* Proper Japanese text wrapping */
                * {
                    word-wrap: break-word;
                    overflow-wrap: break-word;
                }
            </style>
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
        
        uiView.loadHTMLString(styledHTML, baseURL: baseURL)
    }
    
    private func resolveImagePath(_ imagePath: String, baseURL: URL) -> URL {
        // Handle relative paths with '../'
        let cleanPath = imagePath.replacingOccurrences(of: "../", with: "")
        let resolvedURL = baseURL.appendingPathComponent(cleanPath)
        return resolvedURL.standardizedFileURL
    }
    
    private func modifyImageSources(_ html: String, baseURL: URL?) -> String {
        guard let baseURL = baseURL else { return html }
        
        do {
            // Regex for both <img src="..."> and SVG xlink:href="../images/..."
            let patterns = [
                "src=\"([^\"]+)\"",
                "xlink:href=\"([^\"]+)\""
            ]
            
            var mutableHTML = html
            
            for pattern in patterns {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let matches = regex.matches(in: mutableHTML, range: NSRange(location: 0, length: mutableHTML.utf16.count))
                
                // Iterate in reverse to avoid changing ranges
                for match in matches.reversed() {
                    if let range = Range(match.range(at: 1), in: mutableHTML) {
                        let imagePath = String(mutableHTML[range])
                        
                        // Resolve full file URL
                        let fullImageURL = resolveImagePath(imagePath, baseURL: baseURL)
                        
                        // Replace src/href attribute
                        mutableHTML = (mutableHTML as NSString).replacingCharacters(
                            in: match.range,
                            with: fullImageURL.path
                        )
                        
                        print("🔗 Replaced image path: \(imagePath) -> \(fullImageURL.path)")
                    }
                }
            }
            
            return mutableHTML
        } catch {
            print("🚨 Image source modification error: \(error)")
            return html
        }
    }
    
}

#Preview {
    BookReaderView(book: Book(title: "Danmachi", coverImage: "DanmachiCover", readingProgress: 0.1, filePath: "21519.epub"))
}
