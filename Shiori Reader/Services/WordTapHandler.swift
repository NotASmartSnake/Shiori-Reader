//
//  WordTapHandler.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/6/25.
//

import WebKit

class WordTapHandler: NSObject, WKScriptMessageHandler {
    weak var viewModel: ReaderViewModel?
    private var registeredHandlers = Set<String>()
    
    init(viewModel: ReaderViewModel) {
        self.viewModel = viewModel
        super.init()
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let viewModel = viewModel else { return }
        
        switch message.name {
        case "wordTapped":
            print("DEBUG: Received wordTapped message: \(message.body)")
            // Handle test messages
            if let body = message.body as? [String: Any],
               let text = body["text"] as? String {
                // Process the message
                viewModel.handleWordSelection(text: text, options: body)
            }
            
        case "dismissDictionary":
            viewModel.showDictionary = false
            
        default:
            if message.name.starts(with: "shioriLog") {
                print("JS LOG: \(message.body)")
            }
        }
    }
    
    // Register handlers for a WebView, using a unique key to avoid duplicates
    func registerHandlers(for webView: WKWebView) -> Bool {
        let identifier = "\(Unmanaged.passUnretained(webView).toOpaque())"
        
        // Skip if already registered
        guard !registeredHandlers.contains(identifier) else {
            print("DEBUG: Handlers already registered for WebView: \(identifier)")
            return false
        }
        
        print("DEBUG: Registering handlers for WebView: \(identifier)")
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
    
    private func injectScript(into webView: WKWebView, logHandlerName: String) {
        // Load the script
        guard let scriptPath = Bundle.main.path(forResource: "wordSelection", ofType: "js"),
              let scriptContent = try? String(contentsOfFile: scriptPath, encoding: .utf8) else {
            print("ERROR: Could not load wordSelection.js")
            return
        }
        
        // Modify the script to use the unique log handler name
        let modifiedScript = """
        (function() {
            // Set up the specific log handler name
            window.shioriLogHandlerName = "\(logHandlerName)";
            
            // Main script
            \(scriptContent)
        })();
        """
        
        // Inject the script
        webView.evaluateJavaScript(modifiedScript) { result, error in
            if let error = error {
                print("ERROR: Script injection failed: \(error)")
            } else {
                print("DEBUG: Script injection succeeded for \(logHandlerName)")
            }
        }
    }
}
