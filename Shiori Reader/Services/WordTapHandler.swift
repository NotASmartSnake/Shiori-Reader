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
        guard let viewModel = viewModel else { 
            print("ERROR [WordTapHandler]: ViewModel is nil, cannot process message: \(message.name)")
            return 
        }
        
        print("DEBUG [WordTapHandler]: Received message: \(message.name) with body type: \(type(of: message.body))")
        
        switch message.name {
        case "wordTapped":
            print("DEBUG [WordTapHandler]: Processing wordTapped message: \(message.body)")
            
            // Handle test messages
            if let body = message.body as? [String: Any] {
                if let type = body["type"] as? String, type == "test" {
                    print("DEBUG [WordTapHandler]: Received test message, handler is working")
                    return
                }
                
                if let text = body["text"] as? String {
                    // Process the message
                    print("DEBUG [WordTapHandler]: Processing wordTapped with text: '\(text)' and \(body.keys.count) options")
                    viewModel.handleWordSelection(text: text, options: body)
                } else {
                    print("ERROR [WordTapHandler]: wordTapped message missing 'text' field: \(body)")
                }
            } else if let textString = message.body as? String {
                // Try to parse as JSON string
                print("DEBUG [WordTapHandler]: Received message as string, attempting to parse JSON")
                if let data = textString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let text = json["text"] as? String {
                    print("DEBUG [WordTapHandler]: Successfully parsed JSON, processing with text: '\(text)'")
                    viewModel.handleWordSelection(text: text, options: json)
                } else {
                    print("ERROR [WordTapHandler]: Failed to parse string message as JSON: \(textString)")
                }
            } else {
                print("ERROR [WordTapHandler]: Unexpected message body format for wordTapped: \(message.body)")
            }
            
        case "dismissDictionary":
            print("DEBUG [WordTapHandler]: Processing dismissDictionary message")
            viewModel.showDictionary = false
            
        default:
            if message.name.starts(with: "shioriLog") {
                print("JS LOG [Shiori]: \(message.body)")
            } else {
                print("DEBUG [WordTapHandler]: Received unhandled message type: \(message.name)")
            }
        }
    }
    
    // Register handlers for a WebView, using a unique key to avoid duplicates
    func registerHandlers(for webView: WKWebView) -> Bool {
        let identifier = "\(Unmanaged.passUnretained(webView).toOpaque())"
        
        // If already registered, forcibly remove and re-register (clean approach for mode switching)
        if registeredHandlers.contains(identifier) {
            print("DEBUG [WordTapHandler]: Re-registering handlers for WebView: \(identifier)")
            unregisterHandlers(for: webView)
        } else {
            print("DEBUG [WordTapHandler]: First-time registering handlers for WebView: \(identifier)")
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
        print("DEBUG [WordTapHandler]: Unregistering handlers for WebView: \(identifier)")
        
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
            print("ERROR [WordTapHandler]: Could not load wordSelection.js")
            return
        }
        
        print("DEBUG [WordTapHandler]: Injecting script into WebView with log handler: \(logHandlerName)")
        
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
                print("ERROR [WordTapHandler]: Script injection failed: \(error)")
            } else {
                print("DEBUG [WordTapHandler]: Script injection succeeded for \(logHandlerName)")
                
                // Now inject a test to verify the handler is working
                let testScript = """
                try {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.wordTapped) {
                        window.webkit.messageHandlers.wordTapped.postMessage({type: "test", text: "Test message from script injection"});
                    } else {
                        console.error("wordTapped handler not found");
                    }
                } catch (e) {
                    console.error("Error in test message: " + e);
                }
                """
                
                webView.evaluateJavaScript(testScript) { _, testError in
                    if let testError = testError {
                        print("ERROR [WordTapHandler]: Test message injection failed: \(testError)")
                    } else {
                        print("DEBUG [WordTapHandler]: Test message injection succeeded")
                    }
                }
            }
        }
    }
}
