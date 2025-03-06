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
        
        config.userContentController.add(context.coordinator, name: "pageInfoHandler")
        config.userContentController.add(context.coordinator, name: "scrollTrackingHandler")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear
        
        // Ensure proper scrolling behavior
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = true
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.decelerationRate = .normal
        
        let trackingScript = WKUserScript(source: """
            // Calculate total character count once when page loads
            let totalChars = document.getElementById('content').textContent.length;
            
            // Use requestAnimationFrame for smooth performance
            let ticking = false;
            document.addEventListener('scroll', function() {
                if (!ticking) {
                    window.requestAnimationFrame(function() {
                        // Calculate progress based on scroll position
                        const scrollHeight = document.documentElement.scrollHeight - window.innerHeight;
                        const progress = window.scrollY / scrollHeight;
                        
                        // Only send a message when actually scrolling (avoid excess calculations)
                        window.webkit.messageHandlers.scrollTrackingHandler.postMessage({
                            action: "userScrolled",
                            progress: progress,
                            exploredChars: Math.round(totalChars * progress),
                            totalChars: totalChars,
                            currentPage: Math.ceil(progress * 100),
                            scrollY: window.scrollY
                        });
                        
                        ticking = false;
                    });
                    ticking = true;
                }
            }, { passive: true });
        """, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        
        webView.configuration.userContentController.addUserScript(trackingScript)
        
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
            }
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
                    background-color: transparent;
                    color: #333333;
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
                
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #FFFFFF;
                    }
                    .chapter {
                        border-bottom-color: #333;
                    }
                }
            </style>
            <script>
        
                document.addEventListener('DOMContentLoaded', function() {
                    enforceRubyTextSize(\(viewModel.fontSize));
                });
        
                function updateFontSize(size) {
                    document.documentElement.style.setProperty('--shiori-font-size', size + 'px');
                    console.log('Font size updated to: ' + size + 'px');
                    return true;
                }
        
                function enforceRubyTextSize(baseFontSize) {
                    // Get all rt elements
                    const rtElements = document.querySelectorAll('rt');
                    
                    // Apply the reduced font size with highest priority
                    for (const rt of rtElements) {
                        // Remove any existing inline styles that might conflict
                        rt.setAttribute('style', '');
                        // Apply our font size with !important to override everything
                        rt.style.cssText = 'font-size: ' + (baseFontSize * 0.5) + 'px !important';
                    }
                    
                    return rtElements.length;
                }
        
                // Store more detailed position information
                let lastKnownPosition = {
                    percentage: 0,
                    pixelOffset: 0,
                    elementId: null,
                    elementOffset: 0
                };

                // Enhance the tracking function to store more context
                function trackPosition() {
                    const content = document.getElementById('content');
                    if (!content) return;
                    
                    const maxScroll = content.scrollHeight - window.innerHeight;
                    const currentScroll = window.scrollY;
                    
                    // Save detailed position info
                    lastKnownPosition.percentage = maxScroll > 0 ? currentScroll / maxScroll : 0;
                    lastKnownPosition.pixelOffset = currentScroll;
                    
                    // Try to identify a nearby element as a landmark
                    const elements = document.querySelectorAll('p, h1, h2, h3, h4, h5, div.chapter');
                    let closestElement = null;
                    let closestDistance = Number.MAX_VALUE;
                    
                    elements.forEach(el => {
                        const distance = Math.abs(el.offsetTop - currentScroll);
                        if (distance < closestDistance) {
                            closestDistance = distance;
                            closestElement = el;
                        }
                    });
                    
                    if (closestElement && closestElement.id) {
                        lastKnownPosition.elementId = closestElement.id;
                        lastKnownPosition.elementOffset = currentScroll - closestElement.offsetTop;
                    }
                    
                    // Send position data to Swift
                    window.webkit.messageHandlers.pageInfoHandler.postMessage({
                        progress: lastKnownPosition.percentage,
                        currentPage: Math.floor(lastKnownPosition.percentage * 100) + 1,
                        totalPages: 100,
                        pixelOffset: lastKnownPosition.pixelOffset,
                        elementId: lastKnownPosition.elementId,
                        elementOffset: lastKnownPosition.elementOffset
                    });
                }

                // Enhanced restoration function
                function restoreScrollPosition(data) {
                    // First try exact pixel position
                    if (data.pixelOffset && data.pixelOffset > 0) {
                        window.scrollTo(0, data.pixelOffset);
                        console.log('Restored to exact pixel offset: ' + data.pixelOffset);
                        return;
                    }
                    
                    // Next try element-based position if available
                    if (data.elementId) {
                        const element = document.getElementById(data.elementId);
                        if (element) {
                            const targetPosition = element.offsetTop + (data.elementOffset || 0);
                            window.scrollTo(0, targetPosition);
                            console.log('Restored using element position: ' + targetPosition);
                            return;
                        }
                    }
                    
                    // Fall back to percentage-based as last resort
                    const content = document.getElementById('content');
                    if (content && data.percentage) {
                        const maxScroll = content.scrollHeight - window.innerHeight;
                        const targetPosition = maxScroll * data.percentage;
                        window.scrollTo(0, targetPosition);
                        console.log('Restored using percentage: ' + data.percentage);
                    }
                }

                // Make the function globally available
                window.restoreScrollPosition = restoreScrollPosition;

                // Modified scrollToProgress
                function scrollToProgress(progress, savedPixelOffset, elementId, elementOffset) {
                    // Create a data object with all available positioning info
                    const positionData = {
                        percentage: progress,
                        pixelOffset: savedPixelOffset || 0,
                        elementId: elementId || null,
                        elementOffset: elementOffset || 0
                    };
                    
                    // Use the enhanced restoration function
                    restoreScrollPosition(positionData);
                    
                    // After scrolling, update progress tracking
                    setTimeout(function() {
                        trackPosition();
                        console.log('Progress restoration complete');
                    }, 100);
                }
        
                // Function to find the element at a specific character position
                function findElementAtCharPosition(targetPosition) {
                    const content = document.getElementById('content');
                    if (!content) return null;
                    
                    const textContent = content.textContent;
                    if (targetPosition <= 0 || targetPosition >= textContent.length) {
                        return null;
                    }
                    
                    // Get all text nodes in order
                    let textNodes = [];
                    
                    function collectTextNodes(node) {
                        if (node.nodeType === Node.TEXT_NODE) {
                            if (node.textContent.trim().length > 0) {
                                textNodes.push(node);
                            }
                        } else {
                            for (let i = 0; i < node.childNodes.length; i++) {
                                collectTextNodes(node.childNodes[i]);
                            }
                        }
                    }
                    
                    collectTextNodes(content);
                    
                    // Find the text node that contains our target position
                    let currentPosition = 0;
                    let targetNode = null;
                    let positionWithinNode = 0;
                    
                    for (let i = 0; i < textNodes.length; i++) {
                        const nodeLength = textNodes[i].textContent.length;
                        
                        if (currentPosition + nodeLength >= targetPosition) {
                            targetNode = textNodes[i];
                            positionWithinNode = targetPosition - currentPosition;
                            break;
                        }
                        
                        currentPosition += nodeLength;
                    }
                    
                    if (!targetNode) return null;
                    
                    // Return the parent element of the text node
                    return {
                        element: targetNode.parentElement,
                        characterOffset: positionWithinNode,
                        totalNodeChars: targetNode.textContent.length
                    };
                }

                // Function to scroll to a specific character position
                function scrollToCharacterPosition(charPosition) {
                    const result = findElementAtCharPosition(charPosition);
                    if (!result) {
                        console.error('Could not find element at character position: ' + charPosition);
                        return false;
                    }
                    
                    console.log('Found element at char position ' + charPosition + ':', 
                               result.element.tagName, 
                               'with text starting with "' + result.element.textContent.substring(0, 20) + '..."');
                    
                    // Scroll the element into view with center alignment
                    result.element.scrollIntoView({
                        behavior: 'auto',
                        block: 'center'
                    });
                    
                    return true;
                }

                // Improved function to get character position at current scroll position
                function getCurrentCharacterPosition() {
                    const content = document.getElementById('content');
                    if (!content) return { explored: 0, total: 0 };
                    
                    const totalChars = content.textContent.length;
                    const scrollY = window.scrollY;
                    const viewportHeight = window.innerHeight;
                    const scrollHeight = document.documentElement.scrollHeight;
                    const maxScroll = scrollHeight - viewportHeight;
                    const ratio = maxScroll > 0 ? scrollY / maxScroll : 0;
                    
                    // Calculate character count
                    const exploredChars = Math.round(totalChars * ratio);
                    
                    return {
                        explored: exploredChars,
                        total: totalChars,
                        ratio: ratio,
                        scrollY: scrollY
                    };
                }

                // Utility to handle font size changes with exact character position preservation
                function changeFontSizePreservingCharPosition(fontSize, charPosition) {
                    // Save exact character position
                    const position = charPosition || getCurrentCharacterPosition().explored;
                    
                    // Update font size
                    document.documentElement.style.setProperty('--shiori-font-size', fontSize + 'px');
                    
                    // Give browser time to update layout
                    setTimeout(() => {
                        // Scroll to the saved character position
                        scrollToCharacterPosition(position);
                        console.log('Restored to exact character position:', position);
                    }, 50);
                }
            </script>
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
                        let progress = scrollY / maxScroll
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
    
}
