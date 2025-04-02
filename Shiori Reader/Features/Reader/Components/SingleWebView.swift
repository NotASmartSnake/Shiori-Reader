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
        
        if let safeAreaScript = loadJavaScriptFile("safeArea") {
            config.userContentController.addUserScript(safeAreaScript)
        }
        
        if let scrollLockScript = loadJavaScriptFile("scrollLock") {
            config.userContentController.addUserScript(scrollLockScript)
        }
        
        if let debugHTMLScript = loadJavaScriptFile("debugHTML") {
            config.userContentController.addUserScript(debugHTMLScript)
        }
        
        // Add support for safe area insets
        let viewportScript = WKUserScript(
            source: """
            var meta = document.createElement('meta');
            meta.name = 'viewport';
            meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover';
            document.getElementsByTagName('head')[0].appendChild(meta);
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(viewportScript)
        
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
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        // Ensure proper bounds and frame
        webView.frame = UIScreen.main.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // This ensures proper scrolling based on reading direction
        let isVertical = viewModel.readingDirection == .vertical
        webView.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        webView.scrollView.alwaysBounceVertical = !isVertical
        webView.scrollView.alwaysBounceHorizontal = isVertical
        
        // Configure scroll indicators
        webView.scrollView.showsVerticalScrollIndicator = !isVertical
        webView.scrollView.showsHorizontalScrollIndicator = isVertical
        
        // Disable user zoom
        webView.scrollView.bouncesZoom = false
        
        // Allow web inspection
        webView.isInspectable = true
        
        // Apply CSS to control overflow in the appropriate direction
        let overflowScript = """
        document.addEventListener('DOMContentLoaded', function() {
            if (\(isVertical)) {
                // Vertical text mode - horizontal scrolling
                document.body.style.overflowX = 'auto';
                document.body.style.overflowY = 'hidden';
                document.documentElement.style.overflowX = 'auto';
                document.documentElement.style.overflowY = 'hidden';
            } else {
                // Horizontal text mode - vertical scrolling
                document.body.style.overflowX = 'hidden';
                document.body.style.overflowY = 'auto';
                document.documentElement.style.overflowX = 'hidden';
                document.documentElement.style.overflowY = 'auto';
            }
        });
        """
        
        let overflowScriptObj = WKUserScript(
            source: overflowScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        
        webView.configuration.userContentController.addUserScript(overflowScriptObj)
        
        let directionClass = viewModel.readingDirection == .horizontal ? "horizontal-text" : "vertical-text"
        webView.evaluateJavaScript("""
            document.addEventListener('DOMContentLoaded', function() {
                document.body.className = '\(directionClass)';
                console.log('Set initial reading direction: \(directionClass)');
            });
        """)
        
        // Ensure proper scrolling behavior
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = true
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.decelerationRate = .normal
        
        if isVertical {
            webView.scrollView.contentOffset.y = 0 // Lock vertical position
            
            // Allow the scroll view to scroll beyond bounds (important for RTL text)
            webView.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            webView.scrollView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }
        
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
                
                // Force reapply direction after page load
                print("DEBUG: Direction after navigation complete: \(self.parent.viewModel.readingDirection)")
                
                let directionClass = self.parent.viewModel.readingDirection == .horizontal ? "horizontal-text" : "vertical-text"
                let script = "document.body.className = '\(directionClass)';"
                webView.evaluateJavaScript(script, completionHandler: { result, error in
                    print("DEBUG: Direction class reapplied: \(directionClass)")
                    
                })
                
                // Apply scroll constraints again after content is loaded
                let isVertical = self.parent.viewModel.readingDirection == .vertical
                
                // Reset scroll position to ensure no unwanted scrolling in locked direction
                if isVertical {
                    webView.scrollView.contentOffset.y = 0
                } else {
                    webView.scrollView.contentOffset.x = 0
                }
                
                // Apply CSS overflow constraints directly
                let overflowScript = """
                if (\(isVertical)) {
                    document.body.style.overflowX = 'auto';
                    document.body.style.overflowY = 'hidden';
                    document.documentElement.style.overflowX = 'auto';
                    document.documentElement.style.overflowY = 'hidden';
                } else {
                    document.body.style.overflowX = 'hidden';
                    document.body.style.overflowY = 'auto';
                    document.documentElement.style.overflowX = 'hidden';
                    document.documentElement.style.overflowY = 'auto';
                }
                """
                
                webView.evaluateJavaScript(overflowScript) { _, error in
                    if let error = error {
                        print("Error applying overflow constraints: \(error)")
                    }
                }
            }
            
//            // Call the debug function after a slight delay to ensure all styles are applied
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                webView.evaluateJavaScript("if (typeof debugHtmlAndCss === 'function') { debugHtmlAndCss(); } else { console.log('Debug function not found!'); }") { result, error in
//                    if let error = error {
//                        print("Error running debug script: \(error)")
//                    } else {
//                        print("Debug function called")
//                    }
//                }
//            }
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
        guard let baseURL = baseURL else {
            print("ERROR: Base URL is nil in loadContent")
            return
        }
        
        let processedChapters = content.chapters.enumerated().map { index, chapter -> String in
            // Extract filename without extension for better ID matching
            let filename = URL(fileURLWithPath: chapter.filePath).deletingPathExtension().lastPathComponent
            
            // Clean up chapter content
            var processedContent = cleanupContent(chapter.content)
            
            // Extract body content if needed
            if processedContent.contains("<body") {
                processedContent = extractBodyContent(processedContent)
            }
                 
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
                    --safe-area-top: env(safe-area-inset-top, 0px);
                    --safe-area-bottom: env(safe-area-inset-bottom, 0px);
                    --safe-area-left: env(safe-area-inset-left, 0px);
                    --safe-area-right: env(safe-area-inset-right, 0px);
                }
        
                /* Global reset - apply to all elements */
                *:not(ruby):not(rt), *:not(ruby):not(rt)::before, *:not(ruby):not(rt)::after {
                    font-size: var(--shiori-font-size) !important;
                    max-width: 100%;
                    box-sizing: border-box;
                }
        
                html {
                    overflow-x: auto !important;
                    overflow-y: hidden !important;
                }
                
                body {
                    font-family: "Hiragino Mincho ProN", "Yu Mincho", "MS Mincho", serif;
                    font-size: var(--shiori-font-size) !important;
                    line-height: 1.8;
                    padding: 16px;
                    background-color: var(--shiori-background-color);
                    color: var(--shiori-text-color);
                }
        
                /* For vertical text */
                body.vertical-text {
                    writing-mode: vertical-rl;
                    text-orientation: upright;
                    width: fit-content !important; /* Let the content determine width */
                    display: inline-block !important; /* Important for vertical text */
                    height: 100vh;
                    width: auto !important;
                    min-width: 200%;
                    padding-top: 50px !important;
                    padding-bottom: 50px !important;
                    margin-bottom: 0 !important;
                }
        
                body.vertical-text #content {
                    display: inline-block !important;
                    min-height: 80vh !important;
                    margin-bottom: 0 !important;
                    padding-bottom: 0 !important;
                }

                /* For horizontal text (default) */
                body.horizontal-text {
                    writing-mode: horizontal-tb;
                    overflow-x: hidden;
                    overflow-y: auto;
                }
        
                /* Specific adjustments for vertical text */
                body.vertical-text img {
                    max-height: 90vh !important;
                    max-width: none !important;
                    height: auto !important;
                    width: auto !important;
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
        
                /* Override for vertical reading (left margin/padding instead of bottom) */
                body.vertical-text .chapter {
                    margin-bottom: 0 !important; /* Remove the bottom margin */
                    padding-bottom: 0 !important; /* Remove the bottom padding */
                    margin-left: 2em !important; /* Add margin to the left instead */
                    padding-left: 2em !important; /* Add padding to the left instead */
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
        <body class="\(viewModel.readingDirection == .horizontal ? "horizontal-text" : "vertical-text")">
            <div id="content">
                \(processedChapters.joined(separator: "\n"))
            </div>
        </body>
        </html>
        """
        
        let tempHTMLFileName = "currentBookView.html"
        // Save it inside the book's extraction directory (baseURL)
        let tempHTMLURL = baseURL.appendingPathComponent(tempHTMLFileName)
        
        do {
            try combinedHTML.write(to: tempHTMLURL, atomically: true, encoding: .utf8)
            print("DEBUG: Saved combined HTML to: \(tempHTMLURL.path)")

            // Load using loadFileURL
            // Grant access to the entire extraction directory
            print("DEBUG: Loading \(tempHTMLURL.lastPathComponent) with read access to: \(baseURL.path)")
            webView.loadFileURL(tempHTMLURL, allowingReadAccessTo: baseURL)
            coordinator.contentLoaded = true

        } catch {
            print("ERROR: Failed to save temporary HTML or load file URL: \(error)")
            // Fallback or error handling
            webView.loadHTMLString("<html><body>Error loading book content.</body></html>", baseURL: nil)
        }
        
        // Apply reading direction class
        let directionClass = viewModel.readingDirection == .horizontal ? "horizontal-text" : "vertical-text"
        let directionScript = """
        (function() {
            // Force add the class to the body
            document.body.className = '\(directionClass)';
            
            console.log('Applied reading direction: \(directionClass)');
        })();
        """
        webView.evaluateJavaScript(directionScript)

        coordinator.contentLoaded = true
        
        ///
        
        // Load the HTML only once
//        webView.loadHTMLString(combinedHTML, baseURL: baseURL)
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

#Preview {
    let isReadingBook = IsReadingBook()
    return BookReaderView(book: Book(
        title: "実力至上主義者の教室",
        coverImage: "COTECover",
        readingProgress: 0.1,
        filePath: "konosuba.epub"
    ))
    .environmentObject(isReadingBook)
}
