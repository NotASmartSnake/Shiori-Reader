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
                                WebView(htmlContent: chapter.content)
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
            epubContent = try parser.parseEPUB(at: epubPath)
        } catch {
            errorMessage = "Failed to parse EPUB: \(error.localizedDescription)"
        }
    }
    
    private func stripHTML(from string: String) -> String {
            do {
                // Create a regular expression pattern to match HTML tags
                let pattern = "<[^>]+>"
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let range = NSRange(string.startIndex..., in: string)
                
                // Replace HTML tags with empty string
                let stripped = regex.stringByReplacingMatches(
                    in: string,
                    options: [],
                    range: range,
                    withTemplate: ""
                )
                
                // Replace common HTML entities
                return stripped
                    .replacingOccurrences(of: "&nbsp;", with: " ")
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&#39;", with: "'")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                return string
            }
        }
}

struct WebView: UIViewRepresentable {
    let htmlContent: String
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .clear
        webView.isOpaque = false
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        print("HTML Content sample: \(htmlContent.prefix(500))")
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
        
        uiView.loadHTMLString(styledHTML, baseURL: nil)
    }
}

#Preview {
    BookReaderView(book: Book(title: "Danmachi", coverImage: "DanmachiCover", readingProgress: 0.1, filePath: "21519.epub"))
}
