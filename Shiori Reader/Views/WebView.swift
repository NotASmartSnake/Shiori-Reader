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
                console.log('Page loaded');
                document.querySelectorAll('img').forEach(img => {
                    console.log('Image found:', {
                        src: img.src,
                        class: img.className,
                        loaded: img.complete
                    });
                });
            """)
        }
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let baseURL = baseURL else { return }
        
        // Process koboSpan content first
        var processedContent = htmlContent
        
        // Remove all script tags (both self-closing and regular)
        if let regex = try? NSRegularExpression(pattern: "<script[^>]*/?>", options: [.caseInsensitive]) {
            processedContent = regex.stringByReplacingMatches(
                in: processedContent,
                options: [],
                range: NSRange(processedContent.startIndex..., in: processedContent),
                withTemplate: ""
            )
        }
        if let regex = try? NSRegularExpression(pattern: "<script\\b[^<]*(?:(?!</script>)<[^<]*)*</script>", options: [.caseInsensitive]) {
            processedContent = regex.stringByReplacingMatches(
                in: processedContent,
                options: [],
                range: NSRange(processedContent.startIndex..., in: processedContent),
                withTemplate: ""
            )
        }
        
        // Remove koboSpan style block
        if let regex = try? NSRegularExpression(pattern: "<style[^>]*id=\"koboSpanStyle\"[^>]*>[\\s\\S]*?</style>", options: [.caseInsensitive]) {
            processedContent = regex.stringByReplacingMatches(
                in: processedContent,
                options: [],
                range: NSRange(processedContent.startIndex..., in: processedContent),
                withTemplate: ""
            )
        }
        
        // Remove koboSpan wrapping but keep content
        if let regex = try? NSRegularExpression(pattern: "<span[^>]*class=\"koboSpan\"[^>]*>([\\s\\S]*?)</span>", options: [.caseInsensitive]) {
            processedContent = regex.stringByReplacingMatches(
                in: processedContent,
                options: [],
                range: NSRange(processedContent.startIndex..., in: processedContent),
                withTemplate: "$1"
            )
        }
        
        // Remove kobo-style comments
        if let regex = try? NSRegularExpression(pattern: "<!-- kobo-style -->", options: []) {
            processedContent = regex.stringByReplacingMatches(
                in: processedContent,
                options: [],
                range: NSRange(processedContent.startIndex..., in: processedContent),
                withTemplate: ""
            )
        }
        
        print("Processed content:", processedContent)
        
        // Function to resolve relative paths
        func resolveImagePath(_ originalPath: String) -> String {
            print("\n🔍 Resolving path for:", originalPath)
            
            let cleanPath = originalPath
                .replacingOccurrences(of: "file://", with: "")
                .replacingOccurrences(of: "../", with: "")
                .replacingOccurrences(of: "./", with: "")
            
            print("🧹 Cleaned path:", cleanPath)
            
            let imageName = cleanPath.components(separatedBy: "/").last ?? cleanPath
            print("📎 Image name:", imageName)
            
            // Always try the full path first if it contains directory info
            if cleanPath.contains("/") {
                let fullPath = baseURL.appendingPathComponent(cleanPath).path
                if FileManager.default.fileExists(atPath: fullPath) {
                    print("✅ Found image at full path:", fullPath)
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
                    print("✅ Found image at:", path)
                    return "file://\(path)"
                }
            }
            
            print("⚠️ Could not resolve path for:", originalPath)
            return originalPath
        }
        
        // Process image references
        let patterns = [
            "src=\"([^\"]+)\"",
            "src='([^']+)'",
            "xlink:href=\"([^\"]+)\"",
            "xlink:href='([^']+)'"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(processedContent.startIndex..., in: processedContent)
                let matches = regex.matches(in: processedContent, range: range)
                
                for match in matches.reversed() {
                    if let pathRange = Range(match.range(at: 1), in: processedContent),
                       let fullRange = Range(match.range(at: 0), in: processedContent) {
                        let originalPath = String(processedContent[pathRange])
                        
                        if originalPath.contains(".jpg") || originalPath.contains(".jpeg") ||
                           originalPath.contains(".png") || originalPath.contains(".gif") {
                            let resolvedPath = resolveImagePath(originalPath)
                            let attributeName = pattern.contains("src") ? "src" : "xlink:href"
                            let newValue = "\(attributeName)=\"\(resolvedPath)\""
                            processedContent = processedContent.replacingCharacters(in: fullRange, with: newValue)
                            print("🔄 Updated image path:", newValue)
                        }
                    }
                }
            }
        }
        
        // Add our styles while preserving the original structure
        if let headEndIndex = processedContent.range(of: "</head>") {
            let additionalStyles = """
                <style>
                    body {
                        margin: 0;
                        padding: 0;
                        background-color: transparent;
                    }
                    
                    img {
                        max-width: 100% !important;
                        height: auto !important;
                        display: block;
                        margin: 0 auto;
                    }
                    
                    img.fit {
                        width: 100% !important;
                        object-fit: contain;
                    }
                    
                    .main {
                        max-width: 100%;
                        margin: 0;
                        padding: 0;
                    }
                    
                    .p-image {
                        padding: 0;
                        margin: 0;
                    }
                    
                    .hltr {
                        writing-mode: horizontal-tb;
                    }
                </style>
            """
            processedContent.insert(contentsOf: additionalStyles, at: headEndIndex.lowerBound)
        }
        
        print("📝 Loading content...")
        print("Base URL:", baseURL.path)
        uiView.loadHTMLString(processedContent, baseURL: baseURL)
    }
}
