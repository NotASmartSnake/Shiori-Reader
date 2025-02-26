import SwiftUI
@preconcurrency import WebKit

struct SingleWebView: UIViewRepresentable {
    @ObservedObject var viewModel: BookViewModel
    let content: EPUBContent
    let baseURL: URL?
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear
        
        viewModel.setWebView(webView)
        return webView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: SingleWebView
        
        init(_ parent: SingleWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url,
               url.scheme == "file",
               let fragment = url.fragment {
                // Handle internal navigation
                let script = "document.getElementById('\(fragment)').scrollIntoView();"
                webView.evaluateJavaScript(script)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let baseURL = baseURL else { return }
        
        let processedChapters = content.chapters.enumerated().map { index, chapter -> String in
            // Extract filename without extension for better ID matching
            let filename = URL(fileURLWithPath: chapter.filePath).deletingPathExtension().lastPathComponent
            
            // Clean up chapter content
            var processedContent = cleanupContent(chapter.content)
            
            // Extract body content if needed
            if processedContent.contains("<body") {
                processedContent = extractBodyContent(processedContent)
            }
            
            // Process image paths
            processedContent = processImagePaths(processedContent, baseURL: baseURL)
            
            return """
                <div class='chapter' id='chapter-\(index + 1)' data-filename='\(filename)'>
                    <div class='chapter-content'>\(processedContent)</div>
                </div>
            """
        }
        
        let combinedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                :root {
                    color-scheme: light dark;
                }
                
                body {
                    font-family: "Hiragino Mincho ProN", "Yu Mincho", "MS Mincho", serif;
                    font-size: 18px;
                    line-height: 1.8;
                    padding: 16px;
                    background-color: transparent;
                    color: #333333;
                }
                        
                /* Reset inherited properties */
                div, p, span {
                    font-size: inherit !important;
                    font-weight: normal !important;
                }

                /* Override publisher-specific styles */
                .chapter-content {
                    font-size: 18px !important;
                    font-weight: normal !important;
                }

                .chapter-content p, 
                .chapter-content div {
                    font-size: inherit !important;
                    font-weight: normal !important;
                    margin: 1em 0;
                    line-height: inherit;
                }

                /* Ensure standard text weight */
                .main {
                    font-weight: normal !important;
                }
                
                .book-title {
                    font-size: 2em;
                    font-weight: bold;
                    margin-bottom: 0.5em;
                }
                
                .book-author {
                    font-size: 1.5em;
                    color: #666;
                    margin-bottom: 2em;
                }
                
                .chapter {
                    margin-bottom: 2em;
                    padding-bottom: 2em;
                }
                
                .chapter:last-child {
                    border-bottom: none;
                }
                
                .chapter-title {
                    font-size: 1.5em;
                    margin: 1em 0;
                }
                
                .chapter-content {
                    width: 100%;
                }
                
                img {
                    max-width: 100% !important;
                    height: auto !important;
                    display: block;
                    margin: 1em auto;
                }
                
                * {
                    max-width: 100%;
                    box-sizing: border-box;
                }
                
                p {
                    margin: 1em 0;
                }
                
                h1, h2, h3, h4, h5, h6 {
                    margin: 1.5em 0 0.5em;
                }
                
                ruby {
                    font-size: 0.8em;
                }
                
                rt {
                    font-size: 0.6em;
                }
                
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #FFFFFF;
                    }
                    .book-author {
                        color: #999;
                    }
                    .chapter {
                        border-bottom-color: #333;
                    }
                }
            </style>
        </head>
        <body>
            <div id="content">
                \(processedChapters.joined(separator: "\n"))
            </div>
        </body>
        </html>
        """
        
        webView.loadHTMLString(combinedHTML, baseURL: baseURL)
    }
    
    // MARK: - Helper Functions
    
    private func cleanupContent(_ content: String) -> String {
        var processed = content
        
        // Remove inline font sizes and weights
        let stylePatterns = [
            "font-size:\\s*[^;]+;",
            "font-weight:\\s*[^;]+;",
            "-webkit-text-size-adjust:\\s*[^;]+;"
        ]
        
        for pattern in stylePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                processed = regex.stringByReplacingMatches(
                    in: processed,
                    options: [],
                    range: NSRange(processed.startIndex..., in: processed),
                    withTemplate: ""
                )
            }
        }
        
        // Remove style attributes that might contain font sizes
        if let styleAttrRegex = try? NSRegularExpression(pattern: "style=\"[^\"]*font-size[^\"]*\"", options: [.caseInsensitive]) {
            processed = styleAttrRegex.stringByReplacingMatches(
                in: processed,
                options: [],
                range: NSRange(processed.startIndex..., in: processed),
                withTemplate: ""
            )
        }
        
        // Remove scripts
        if let regex = try? NSRegularExpression(pattern: "<script[^>]*/?>|<script\\b[^<]*(?:(?!</script>)<[^<]*)*</script>", options: [.caseInsensitive]) {
            processed = regex.stringByReplacingMatches(
                in: processed,
                options: [],
                range: NSRange(processed.startIndex..., in: processed),
                withTemplate: ""
            )
        }
        
        // Remove koboSpan style
        if let regex = try? NSRegularExpression(pattern: "<style[^>]*id=\"koboSpanStyle\"[^>]*>[\\s\\S]*?</style>", options: [.caseInsensitive]) {
            processed = regex.stringByReplacingMatches(
                in: processed,
                options: [],
                range: NSRange(processed.startIndex..., in: processed),
                withTemplate: ""
            )
        }
        
        // Remove koboSpan wrapping but keep content
        if let regex = try? NSRegularExpression(pattern: "<span[^>]*class=\"koboSpan\"[^>]*>([\\s\\S]*?)</span>", options: [.caseInsensitive]) {
            processed = regex.stringByReplacingMatches(
                in: processed,
                options: [],
                range: NSRange(processed.startIndex..., in: processed),
                withTemplate: "$1"
            )
        }
        
        return processed
    }
    
    private func extractBodyContent(_ html: String) -> String {
        let bodyPattern = try? NSRegularExpression(
            pattern: "<body[^>]*>(.*?)</body>",
            options: [.dotMatchesLineSeparators]
        )
        
        if let match = bodyPattern?.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let bodyRange = Range(match.range(at: 1), in: html) {
            return String(html[bodyRange])
        }
        
        return html
    }
    
    private func processImagePaths(_ content: String, baseURL: URL) -> String {
        var processed = content
        
        let patterns = [
            "src=\"([^\"]+)\"",
            "src='([^']+)'",
            "xlink:href=\"([^\"]+)\"",
            "xlink:href='([^']+)'"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = regex.matches(
                    in: processed,
                    range: NSRange(processed.startIndex..., in: processed)
                )
                
                for match in matches.reversed() {
                    if let pathRange = Range(match.range(at: 1), in: processed),
                       let fullRange = Range(match.range(at: 0), in: processed) {
                        let originalPath = String(processed[pathRange])
                        let resolvedPath = resolveImagePath(originalPath, baseURL: baseURL)
                        let attributeName = pattern.contains("src") ? "src" : "xlink:href"
                        processed = processed.replacingCharacters(
                            in: fullRange,
                            with: "\(attributeName)=\"\(resolvedPath)\""
                        )
                    }
                }
            }
        }
        
        return processed
    }
    
    private func resolveImagePath(_ originalPath: String, baseURL: URL) -> String {
        let cleanPath = originalPath
            .replacingOccurrences(of: "file://", with: "")
            .replacingOccurrences(of: "../", with: "")
            .replacingOccurrences(of: "./", with: "")
        
        let imageName = cleanPath.components(separatedBy: "/").last ?? cleanPath
        
        // Try full path first if it contains directory info
        if cleanPath.contains("/") {
            let fullPath = baseURL.appendingPathComponent(cleanPath).path
            if FileManager.default.fileExists(atPath: fullPath) {
                return "file://\(fullPath)"
            }
        }
        
        // Common image directory patterns to check
        let possiblePaths = [
            baseURL.appendingPathComponent("images/\(imageName)").path,
            baseURL.appendingPathComponent("Images/\(imageName)").path,
            baseURL.appendingPathComponent("item/image/\(imageName)").path,
            baseURL.appendingPathComponent("OEBPS/images/\(imageName)").path,
            baseURL.appendingPathComponent("OEBPS/Images/\(imageName)").path,
            baseURL.appendingPathComponent("image/\(imageName)").path,
            baseURL.appendingPathComponent(imageName).path
        ]
        
        // Try each possible path
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return "file://\(path)"
            }
        }
        
        return originalPath
    }
}
