//
//  BookReaderView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//

import SwiftUI
@preconcurrency import WebKit

struct BookReaderView: View {
    let book: Book
    @State private var epubContent: EPUBContent?
    @State private var errorMessage: String?
    @State private var currentChapterIndex: Int = 0
    @State private var showTableOfContents: Bool = true
    @State private var epubBaseURL: URL?
    @State private var isLoading: Bool = true
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading book...")
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Error loading book")
                        .font(.headline)
                    Text(error)
                        .foregroundColor(.gray)
                }
                .padding()
            } else if let content = epubContent {
                bookContent(content)
            }
        }
        .onAppear {
            // Configure WKWebView globally
            let webViewConfig = WKWebViewConfiguration()
            webViewConfig.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
            if let dataContainer = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                try? FileManager.default.createDirectory(at: dataContainer, withIntermediateDirectories: true)
            }
            
            loadEPUB()
        }
    }
    
    private func bookContent(_ content: EPUBContent) -> some View {
        VStack {
            if showTableOfContents {
                tableOfContents(content)
            } else {
                chapterView(content)
            }
        }
    }
    
    private func tableOfContents(_ content: EPUBContent) -> some View {
        VStack {
            // Header
            HStack {
                Text("Table of Contents")
                    .font(.headline)
                Spacer()
                Button("Start Reading") {
                    withAnimation {
                        showTableOfContents = false
                    }
                }
            }
            .padding()
            
            // Chapter List
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(content.chapters.indices, id: \.self) { index in
                        let chapter = content.chapters[index]
                        Button(action: {
                            currentChapterIndex = index
                            withAnimation {
                                showTableOfContents = false
                            }
                        }) {
                            HStack {
                                Text(chapter.title)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
    }
    
    private func chapterView(_ content: EPUBContent) -> some View {
        VStack {
            // Navigation Header
            HStack {
                Button(action: {
                    withAnimation {
                        showTableOfContents = true
                    }
                }) {
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
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Chapter Title
                        if !chapter.title.isEmpty {
                            Text(chapter.title)
                                .font(.title)
                                .padding(.bottom)
                        }
                        
                        // Chapter Content
                        WebView(htmlContent: chapter.content, baseURL: epubBaseURL)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 500)
                    }
                    .padding()
                }
            }
        }
    }
    
    private func nextChapter() {
        guard let content = epubContent else { return }
        if currentChapterIndex < content.chapters.count - 1 {
            withAnimation {
                currentChapterIndex += 1
            }
        }
    }
    
    private func previousChapter() {
        if currentChapterIndex > 0 {
            withAnimation {
                currentChapterIndex -= 1
            }
        }
    }
    
    private func loadEPUB() {
        isLoading = true
        
        guard let epubPath = Bundle.main.path(forResource: book.filePath, ofType: nil) else {
            errorMessage = "Could not find EPUB file in bundle"
            isLoading = false
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let parser = EPUBParser()
                let (content, baseURL) = try parser.parseEPUB(at: epubPath)
                
                // Verify image files exist
                for (path, _) in content.images {
                    let fullPath = baseURL.appendingPathComponent(path)
                    if FileManager.default.fileExists(atPath: fullPath.path) {
                        print("✅ Verified image exists:", fullPath.path)
                    } else {
                        print("❌ Image missing:", fullPath.path)
                    }
                }
                
                DispatchQueue.main.async {
                    self.epubContent = content
                    self.epubBaseURL = baseURL
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load EPUB: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
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
        config.allowsInlineMediaPlayback = true
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear
        
        return webView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("""
                document.querySelectorAll('img, svg image').forEach(img => {
                    const src = img.src || img.getAttribute('xlink:href');
                    console.log('🔍 Found image:', src);
                    
                    img.onerror = () => {
                        console.error('❌ Failed to load image:', src);
                    };
                    
                    img.onload = () => {
                        console.log('✅ Successfully loaded image:', src);
                    };
                });
            """)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                print("🔗 Navigation request to:", url.absoluteString)
            }
            decisionHandler(.allow)
        }
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let baseURL = baseURL else { return }
        
        var processedContent = htmlContent
        
        // Process both types of image references
        let imagePatterns = [
            // SVG images
            ("xlink:href=\"[^\"]*?/?images/([^\"]+)\"", { (imagePath: String) -> String in
                "xlink:href=\"file://\(baseURL.path)/images/\(imagePath)\""
            }),
            // Regular images with ../images/
            ("src=\"\\.\\.?/images/([^\"]+)\"", { (imagePath: String) -> String in
                "src=\"file://\(baseURL.path)/images/\(imagePath)\""
            }),
            // Root-level images
            ("src=\"([^\"]+\\.(?:jpg|jpeg|png|gif))\"", { (imagePath: String) -> String in
                if !imagePath.contains("/") {
                    return "src=\"file://\(baseURL.path)/\(imagePath)\""
                }
                return "src=\"\(imagePath)\""
            })
        ]
        
        for (pattern, replacement) in imagePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(processedContent.startIndex..., in: processedContent)
                let matches = regex.matches(in: processedContent, range: range)
                
                for match in matches.reversed() {
                    if let matchRange = Range(match.range(at: 1), in: processedContent) {
                        let imagePath = String(processedContent[matchRange])
                        let fullPath = baseURL.appendingPathComponent("images").appendingPathComponent(imagePath).path
                        
                        if FileManager.default.fileExists(atPath: fullPath) {
                            print("✅ Image exists at path:", fullPath)
                        } else {
                            print("❌ Image not found at path:", fullPath)
                        }
                        
                        if let fullRange = Range(match.range(at: 0), in: processedContent) {
                            let newValue = replacement(imagePath)
                            processedContent = processedContent.replacingCharacters(in: fullRange, with: newValue)
                            print("🔄 Replaced path:", imagePath, "with:", newValue)
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
                img {
                    max-width: 100% !important;
                    height: auto !important;
                    display: block;
                    margin: 1em auto;
                }
        
                /* SVG handling */
                svg {
                    max-width: 100% !important;
                    height: auto !important;
                    display: block;
                    margin: 1em auto;
                }
        
                svg image {
                    max-width: 100% !important;
                    height: auto !important;
                }
        
                /* Handle fit class */
                .fit {
                    width: 100% !important;
                    max-width: 100% !important;
                    object-fit: contain;
                }
        
                /* Main container */
                .main {
                    max-width: 100%;
                    margin: 0 auto;
                    overflow-x: hidden;
                }
                
                /* Kobo specific */
                .koboSpan img {
                    max-width: 100% !important;
                    height: auto !important;
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
            \(processedContent)
            <script>
                document.addEventListener('DOMContentLoaded', () => {
                    console.log('🔍 Content loaded, checking images...');
                    document.querySelectorAll('img, svg image').forEach(img => {
                        const src = img.src || img.getAttribute('xlink:href');
                        console.log('Found image:', src);
                    });
                });
            </script>
        </body>
        </html>
        """
        
        print("📝 Loading content with base URL:", baseURL.path)
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
    BookReaderView(book: Book(title: "Classroom of the Elite", coverImage: "COTECover", readingProgress: 0.1, filePath: "hakomari.epub"))
//    BookReaderView(book: Book(title: "Danmachi", coverImage: "DanmachiCover", readingProgress: 0.1, filePath: "konosuba.epub"))
}
