import SwiftUI
@preconcurrency import WebKit

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
        
        // Disable scrolling within the WebView since we're using SwiftUI ScrollView
        webView.scrollView.isScrollEnabled = false
        
        // Set size constraints
        webView.translatesAutoresizingMaskIntoConstraints = false
        
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
            // JavaScript to calculate the full content height
            let heightScript = """
                Math.max(
                    document.body.scrollHeight,
                    document.body.offsetHeight,
                    document.documentElement.scrollHeight,
                    document.documentElement.offsetHeight
                );
            """
            
            webView.evaluateJavaScript(heightScript) { (height, error) in
                if let height = height as? CGFloat {
                    // Update the webView's height constraint
                    DispatchQueue.main.async {
                        webView.frame.size.height = height
                    }
                }
            }
        }
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let baseURL = baseURL else { return }
        
        // Process koboSpan content first
        var processedContent = htmlContent
        
        // Clean up content (remove scripts, koboSpan, etc.)
        processedContent = cleanupContent(processedContent)
        
        // Process image paths
        processedContent = processImagePaths(processedContent, baseURL: baseURL)
        
        // Add custom styles for better reading experience
        let readingStyles = """
            <style>
                :root {
                    color-scheme: light dark;
                }
                
                body {
                    margin: 0;
                    padding: 16px;
                    background-color: transparent;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    line-height: 1.6;
                    font-size: 18px;
                }
        
                * {
                    max-width: 100%;
                    box-sizing: border-box;
                }
                
                img {
                    max-width: 100% !important;
                    height: auto !important;
                    display: block;
                    margin: 16px auto;
                }
                
                p {
                    margin: 1em 0;
                }
                
                h1, h2, h3, h4, h5, h6 {
                    margin: 1.5em 0 0.5em;
                }
                
                /* Ruby text support */
                ruby {
                    font-size: 0.8em;
                }
                
                rt {
                    font-size: 0.6em;
                }
                
                /* Dark mode support */
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #FFFFFF;
                    }
                }
            </style>
        """
        
        // Ensure the HTML structure is complete
        if !processedContent.contains("<html") {
            processedContent = """
                <!DOCTYPE html>
                <html>
                <head>
                    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                    \(readingStyles)
                </head>
                <body>
                    \(processedContent)
                </body>
                </html>
                """
        } else if let headEndIndex = processedContent.range(of: "</head>") {
            processedContent.insert(contentsOf: readingStyles, at: headEndIndex.lowerBound)
        }
        
        uiView.loadHTMLString(processedContent, baseURL: baseURL)
    }
    
    private func cleanupContent(_ content: String) -> String {
        var processed = content
        
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
        
        return processed
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
    
    // Function to resolve relative paths
    func resolveImagePath(_ originalPath: String, baseURL: URL) -> String {
        let cleanPath = originalPath
            .replacingOccurrences(of: "file://", with: "")
            .replacingOccurrences(of: "../", with: "")
            .replacingOccurrences(of: "./", with: "")
        
        let imageName = cleanPath.components(separatedBy: "/").last ?? cleanPath
        
        // Always try the full path first if it contains directory info
        if cleanPath.contains("/") {
            let fullPath = baseURL.appendingPathComponent(cleanPath).path
            if FileManager.default.fileExists(atPath: fullPath) {
                return "file://\(fullPath)"
            }
        }
        
        // Common image directory patterns to check
        let possiblePaths = [
            baseURL.appendingPathComponent("images/\(imageName)").path,
            baseURL.appendingPathComponent("item/image/\(imageName)").path,
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
