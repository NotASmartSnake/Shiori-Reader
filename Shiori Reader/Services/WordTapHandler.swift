import WebKit

class WordTapHandler: NSObject, WKScriptMessageHandler {
    weak var viewModel: ReaderViewModel?
    private var registeredHandlers = Set<String>()
    
    init(viewModel: ReaderViewModel) {
        self.viewModel = viewModel
        super.init()
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let viewModel = viewModel else { 
            Logger.error(category: "WordTapHandler", "ViewModel is nil, cannot process message: \(message.name)")
            return 
        }
        
        switch message.name {
        case "wordTapped":
            // Handle test messages
            if let body = message.body as? [String: Any] {
                if let type = body["type"] as? String, type == "test" {
                    return // Silent test message handling
                }
                
                if let text = body["text"] as? String {
                    viewModel.handleWordSelection(text: text, options: body)
                } else {
                    Logger.error(category: "WordTapHandler", "wordTapped message missing 'text' field")
                }
            } else if let textString = message.body as? String {
                // Try to parse as JSON string
                if let data = textString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let text = json["text"] as? String {
                    viewModel.handleWordSelection(text: text, options: json)
                } else {
                    Logger.error(category: "WordTapHandler", "Failed to parse string message as JSON")
                }
            } else {
                Logger.error(category: "WordTapHandler", "Unexpected message body format for wordTapped")
            }
            
        case "dismissDictionary":
            viewModel.showDictionary = false
            
        default:
            if message.name.starts(with: "shioriLog") {
                Logger.jsLog(category: "Shiori", "\(message.body)")
            } else {
                Logger.warning(category: "WordTapHandler", "Received unhandled message type: \(message.name)")
            }
        }
    }
    
    // Register handlers for a WebView, using a unique key to avoid duplicates
    func registerHandlers(for webView: WKWebView) -> Bool {
        let identifier = "\(Unmanaged.passUnretained(webView).toOpaque())"
        
        // If already registered, forcibly remove and re-register (clean approach for mode switching)
        if registeredHandlers.contains(identifier) {
            unregisterHandlers(for: webView)
        }
        
        let userContentController = webView.configuration.userContentController
        
        // Use unique names with the identifier to prevent conflicts
        let wordTappedName = "wordTapped"
        let dismissName = "dismissDictionary"
        let logName = "shioriLog_\(identifier)"
        
        userContentController.add(self, name: wordTappedName)
        userContentController.add(self, name: dismissName)
        userContentController.add(self, name: logName)
        
        // Mark as registered
        registeredHandlers.insert(identifier)
        
        // Inject script
        injectScript(into: webView, logHandlerName: logName)
        
        return true
    }
    
    // Explicitly unregister handlers for a WebView to clean up and avoid duplicates
    func unregisterHandlers(for webView: WKWebView) {
        let identifier = "\(Unmanaged.passUnretained(webView).toOpaque())"
        
        let userContentController = webView.configuration.userContentController
        
        // Remove existing handlers
        userContentController.removeScriptMessageHandler(forName: "wordTapped")
        userContentController.removeScriptMessageHandler(forName: "dismissDictionary")
        userContentController.removeScriptMessageHandler(forName: "shioriLog_\(identifier)")
        
        // Remove from registered set
        registeredHandlers.remove(identifier)
    }
    
    private func injectScript(into webView: WKWebView, logHandlerName: String) {
        // Load the script
        guard let scriptPath = Bundle.main.path(forResource: "wordSelection", ofType: "js"),
              let scriptContent = try? String(contentsOfFile: scriptPath, encoding: .utf8) else {
            Logger.error(category: "WordTapHandler", "Could not load wordSelection.js")
            return
        }
        
        // Injecting word selection script
        
        // Modify the script to use the unique log handler name
        let modifiedScript = """
        (function() {
            // Set up the specific log handler name
            window.shioriLogHandlerName = "\(logHandlerName)";
            
            // Debugging confirmation
            console.log("Shiori word selection script injected with handler: \(logHandlerName)");
            
            // Main script
            \(scriptContent)
            
            // Extra debug code to confirm script is running
            try {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(logHandlerName)) {
                    window.webkit.messageHandlers.\(logHandlerName).postMessage("Script successfully injected and executed");
                }
            } catch (e) {
                console.error("Error sending confirmation message: " + e);
            }
        })();
        """
        
        // Inject the script
        webView.evaluateJavaScript(modifiedScript) { result, error in
            if let error = error {
                Logger.error(category: "WordTapHandler", "Script injection failed: \(error)")
            } else {
                // Silent test to verify the handler is working
                let testScript = """
                try {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.wordTapped) {
                        window.webkit.messageHandlers.wordTapped.postMessage({type: "test", text: "Test message from script injection"});
                    }
                } catch (e) {
                    console.error("Error in test message: " + e);
                }
                """
                
                webView.evaluateJavaScript(testScript) { _, testError in
                    if let testError = testError {
                        Logger.error(category: "WordTapHandler", "Test message injection failed: \(testError)")
                    }
                }
            }
        }
    }
}
