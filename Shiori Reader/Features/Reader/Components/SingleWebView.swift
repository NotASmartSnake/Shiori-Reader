import SwiftUI
@preconcurrency import WebKit

struct SingleWebView: UIViewRepresentable {
    @ObservedObject var viewModel: BookViewModel
    let content: EPUBContent
    let baseURL: URL?
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // Set up configuration
        config.allowsInlineMediaPlayback = true
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.userContentController.add(context.coordinator, name: "pageInfoHandler")
        config.userContentController.add(context.coordinator, name: "scrollTrackingHandler")
        config.userContentController.add(context.coordinator, name: "wordTapped")
        config.userContentController.add(context.coordinator, name: "dismissDictionary")
        
        // Load JavaScript files
        if let wordSelectionScript = loadJavaScriptFile("wordSelection") {
            config.userContentController.addUserScript(wordSelectionScript)
        }
        
        if let scrollTrackingScript = loadJavaScriptFile("scrollTracking") {
            config.userContentController.addUserScript(scrollTrackingScript)
        }
        
        if let positionManagementScript = loadJavaScriptFile("positionManagement") {
            config.userContentController.addUserScript(positionManagementScript)
        }
        
        if let fontUtilitiesScript = loadJavaScriptFile("fontUtilities") {
            config.userContentController.addUserScript(fontUtilitiesScript)
        }
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear
        
        // Allow console.log output to show in terminal
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        let loggingScript = WKUserScript(source: """
            console.originalLog = console.log;
            console.log = function(message) {
                console.originalLog(message);
                window.webkit.messageHandlers.consoleLog.postMessage(message);
            };
            """, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(loggingScript)
        config.userContentController.add(context.coordinator, name: "consoleLog")
        
        // Ensure proper scrolling behavior
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = true
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.decelerationRate = .normal
        
        viewModel.setWebView(webView)
        
        // Load the content immediately
        loadContent(webView: webView, coordinator: context.coordinator)
        
        return webView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: SingleWebView
        var contentLoaded: Bool = false
        var lastScrollPosition: CGFloat = 0
        @State private var showDictionary = false
        @State private var selectedWord: String = ""
        
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
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Calculate total character count when content loads
            DispatchQueue.main.async {
                self.parent.viewModel.updatePositionData()
                // Notify the ViewModel that WebView content is fully loaded and ready for position restoration
                self.parent.viewModel.webViewContentLoaded()
            }
        }
        
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "scrollTrackingHandler",
               let info = message.body as? [String: Any],
               let action = info["action"] as? String,
               action == "userScrolled" {
                
                // Get all data in one go
                let progress = info["progress"] as? Double ?? 0
                let exploredChars = info["exploredChars"] as? Int ?? 0
                let totalChars = info["totalChars"] as? Int ?? 1
                let currentPage = info["currentPage"] as? Int ?? 1
                
                DispatchQueue.main.async {
                    // Use the new handler that checks preventPositionUpdates
                    self.parent.viewModel.userScrolledHandler(
                        progress: progress,
                        exploredChars: exploredChars,
                        totalChars: totalChars,
                        currentPage: currentPage
                    )
                    
                    // Always reset auto-save timer on user interaction
                    self.parent.viewModel.resetAutoSave()
                    self.parent.viewModel.autoSaveProgress()
                }
            } else if message.name == "wordTapped" {
                if let body = message.body as? [String: Any],
                   let text = body["text"] as? String {
                    
                    DispatchQueue.main.async {
                        self.parent.viewModel.handleTextTap(text: text, options: body)
                    }
                }
            } else if message.name == "dismissDictionary" {
                DispatchQueue.main.async {
                    self.parent.viewModel.showDictionary = false
                }
            } else if message.name == "consoleLog" {
                print("JS Console: \(message.body)")
            }
        }
        
        // Functions for console.log JS output
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            print("JS Alert: \(message)")
            completionHandler()
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            print("JS Confirm: \(message)")
            completionHandler(true)
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            print("JS Prompt: \(prompt)")
            completionHandler(defaultText)
        }
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {

    }
    
    // Separate method to load content once
    private func loadContent(webView: WKWebView, coordinator: Coordinator) {
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
            <style id="shiori-base-styles">
                :root {
                    color-scheme: light dark;
                    --shiori-font-size: \(viewModel.fontSize)px;
                    --shiori-background-color: \(viewModel.currentTheme.backgroundColorCSS);
                    --shiori-text-color: \(viewModel.currentTheme.textColorCSS);
                }
        
                /* Global reset - apply to all elements */
                *:not(ruby):not(rt), *:not(ruby):not(rt)::before, *:not(ruby):not(rt)::after {
                    font-size: var(--shiori-font-size) !important;
                    max-width: 100%;
                    box-sizing: border-box;
                }
                
                body {
                    font-family: "Hiragino Mincho ProN", "Yu Mincho", "MS Mincho", serif;
                    font-size: var(--shiori-font-size) !important;
                    line-height: 1.8;
                    padding: 16px;
                    background-color: var(--shiori-background-color);
                    color: var(--shiori-text-color);
                }
        
                /* More specific selectors with !important to ensure they override */
                #content, #content * {
                    font-size: var(--shiori-font-size) !important;
                }
                
                .chapter, .chapter * {
                    font-size: var(--shiori-font-size) !important;
                }
                
                .chapter-content, .chapter-content * {
                    font-size: var(--shiori-font-size) !important;
                }
                
                /* Specific element overrides */
                p, div, span, h1, h2, h3, h4, h5, h6 {
                    font-size: var(--shiori-font-size) !important;
                    font-weight: normal !important;
                }
        
                /* Relative sizing for headings */
                h1 { font-size: calc(var(--shiori-font-size) * 1.5) !important; }
                h2 { font-size: calc(var(--shiori-font-size) * 1.3) !important; }
                h3 { font-size: calc(var(--shiori-font-size) * 1.2) !important; }
                
                /* Ruby text (furigana) should stay smaller */
                html body ruby {
                    font-size: var(--shiori-font-size) !important;
                }

                html body ruby rt {
                    font-size: calc(var(--shiori-font-size) * 0.5) !important;
                }

                /* Ensure standard text weight */
                .main {
                    font-weight: normal !important;
                }
                
                .chapter {
                    margin-bottom: 2em;
                    padding-bottom: 2em;
                }
                
                .chapter:last-child {
                    border-bottom: none;
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
                
                p {
                    margin: 1em 0;
                }
                
                h1, h2, h3, h4, h5, h6 {
                    margin: 1.5em 0 0.5em;
                }
                
                html[data-theme="dark"] body {
                    color: var(--shiori-text-color);
                    background-color: var(--shiori-background-color);
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
        
        // Load the HTML only once
        webView.loadHTMLString(combinedHTML, baseURL: baseURL)
        
        // Mark that content is loaded
        coordinator.contentLoaded = true
    }
    
    
    func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        // Save the final position before dismantling
        webView.evaluateJavaScript("window.scrollY") { (result, error) in
            if let scrollY = result as? CGFloat {
                coordinator.lastScrollPosition = scrollY
                
                // Calculate and save progress
                webView.evaluateJavaScript("document.getElementById('content').scrollHeight - window.innerHeight") { (maxScrollResult, maxScrollError) in
                    if let maxScroll = maxScrollResult as? CGFloat, maxScroll > 0 {
                        Task {
                            await self.viewModel.saveCurrentProgress()
                        }
                    }
                }
            }
        }
        
        // Clean up message handlers
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "pageInfoHandler")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "scrollTrackingHandler")
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
    
    private func loadJavaScriptFile(_ filename: String) -> WKUserScript? {
        guard let scriptPath = Bundle.main.path(forResource: filename, ofType: "js"),
              let scriptContent = try? String(contentsOfFile: scriptPath, encoding: .utf8) else {
            print("ERROR: Failed to load \(filename).js")
            
            // Debug: List all available resource paths
            let resources = Bundle.main.paths(forResourcesOfType: "js", inDirectory: nil)
            print("Available JS files: \(resources)")
            
            return nil
        }
        
        print("Successfully loaded \(filename).js with \(scriptContent.count) characters")
        return WKUserScript(source: scriptContent, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
    }
    
}
