//
//  EPUBNavigatorView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/3/25.
//


// EPUBNavigatorView.swift
import SwiftUI
import ReadiumShared
import ReadiumNavigator
import WebKit

struct EPUBNavigatorView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: ReaderViewModel
    let publication: Publication
    let initialLocation: Locator?

    // MARK: - UIViewControllerRepresentable Core Methods

    func makeUIViewController(context: Context) -> EPUBNavigatorViewController {
        print("DEBUG [EPUBNavigatorView]: Making EPUBNavigatorViewController...")

        let server = ServerManager.shared.httpServer

        print("DEBUG [EPUBNavigatorView]: Using server instance provided by ServerManager.")

        let config = EPUBNavigatorViewController.Configuration()

        do {
            let navigator = try EPUBNavigatorViewController(
                publication: publication,
                initialLocation: initialLocation,
                config: config,
                httpServer: server
            )
            
            // Set the delegate to receive callbacks (like location changes)
            navigator.delegate = context.coordinator
            
            // Store the navigator reference in the ViewModel
            viewModel.setNavigatorController(navigator)
            
            return navigator
        } catch {
            print("ERROR [EPUBNavigatorView]: Failed to create EPUBNavigatorViewController: \(error)")
            fatalError("Failed to initialize EPUBNavigatorViewController: \(error.localizedDescription)")
        }
    }

    func updateUIViewController(_ uiViewController: EPUBNavigatorViewController, context: Context) {
        // Submit preferences when they change in the ViewModel
        uiViewController.submitPreferences(viewModel.preferences)
        
        if let targetLocator = viewModel.navigationRequest {
            print("DEBUG [EPUBNavigatorView]: Detected navigation request for locator: \(targetLocator.href)")
            viewModel.clearNavigationRequest()
            
            Task {
                print("DEBUG [EPUBNavigatorView]: Starting async task to navigate to locator...")
                let success = await uiViewController.go(to: targetLocator, options: .init(animated: false))
                print("DEBUG [EPUBNavigatorView]: Navigation to locator finished. Success: \(success)")
            }
        }
        
        // Use the view model's current preferences
        uiViewController.submitPreferences(viewModel.preferences)
    }
    
    // MARK: - Coordinator Setup

    func makeCoordinator() -> Coordinator {
        // Create the Coordinator, passing references to self and the viewModel
        Coordinator(self, viewModel: viewModel)
    }

    // MARK: - Coordinator Class (Delegate Implementation)

    class Coordinator: NSObject, EPUBNavigatorDelegate, WKScriptMessageHandler {
        var parent: EPUBNavigatorView
        @ObservedObject var viewModel: ReaderViewModel // Keep reference to update VM
//        private var webViewManager: WebViewManager?
        private var scriptsInjected = false
        private var webView: WKWebView?
        private let wordTapHandler: WordTapHandler
        
        init(_ parent: EPUBNavigatorView, viewModel: ReaderViewModel) {
            self.parent = parent
            self.viewModel = viewModel
//            self.webViewManager = WebViewManager(viewModel: viewModel)
            self.wordTapHandler = WordTapHandler(viewModel: viewModel)
            super.init()
            print("DEBUG [Coordinator]: Initialized.")
        }
        
        func navigator(_ navigator: Navigator, setupUserScripts userContentController: WKUserContentController) {
            print("DEBUG [Coordinator]: setupUserScripts delegate method called!")
            addMessageHandlers(userContentController)
        }
        
        private func addMessageHandlers(_ userContentController: WKUserContentController) {
            userContentController.add(self, name: "wordTapped")
            userContentController.add(self, name: "dismissDictionary")
            userContentController.add(self, name: "shioriLog")
            print("DEBUG [Coordinator]: Added message handlers via delegate method")
        }

        @MainActor // Ensure UI updates or VM calls happen on the main thread
        func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
            print("DEBUG [Coordinator]: Location changed to \(locator.href)")
            
            // Pass the updated location to ViewModel
            viewModel.handleLocationUpdate(locator)
            
            // Search for WebViews after a slight delay to ensure rendering is complete
            if let epubNavigator = navigator as? EPUBNavigatorViewController {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.findAndSetupWebViews(in: epubNavigator.view)
                }
            }
        }
        
        private func findAndSetupWebViews(in view: UIView) {
            // First check for direct WebViews
            if let webView = view as? WKWebView {
                setupWebView(webView)
            }
            
            // Then check children
            for subview in view.subviews {
                findAndSetupWebViews(in: subview)
            }
        }
        
        private func setupWebView(_ webView: WKWebView) {
            // Register handlers - the WordTapHandler will check for duplicates
            wordTapHandler.registerHandlers(for: webView)
        }
        
        private func injectScripts(_ webView: WKWebView) {
            // Load the word selection script
            guard let scriptPath = Bundle.main.path(forResource: "wordSelection", ofType: "js"),
                  let scriptContent = try? String(contentsOfFile: scriptPath, encoding: .utf8) else {
                print("ERROR: Could not load wordSelection.js")
                return
            }
            
            // Create a wrapper script that ensures our script can communicate
            let scriptWrapper = """
            (function() {
                // Set up window.webkit if it doesn't exist (unlikely but just in case)
                window.webkit = window.webkit || {};
                window.webkit.messageHandlers = window.webkit.messageHandlers || {};
                
                // Set up console logging
                console.log('Script injection starting');
                
                // Main script content
                \(scriptContent)
                
                // Verify script ran successfully
                console.log('Script injection complete');
                
                // Test message
                if (window.webkit.messageHandlers.wordTapped) {
                    window.webkit.messageHandlers.wordTapped.postMessage({
                        test: true,
                        text: "Script injection test"
                    });
                    console.log('Test message sent');
                } else {
                    console.log('ERROR: Message handlers not available');
                }
            })();
            """
            
            // Inject the script
            webView.evaluateJavaScript(scriptWrapper) { result, error in
                if let error = error {
                    print("ERROR: Script injection failed: \(error)")
                } else {
                    print("DEBUG: Script injection completed with result: \(result ?? "nil")")
                }
            }
        }

        @MainActor // Ensure UI updates or VM calls happen on the main thread
        func navigator(_ navigator: Navigator, presentError error: NavigatorError) {
            // Called if the navigator encounters an internal error (e.g., cannot load a resource)
            print("ERROR [Coordinator]: Navigator failed with error: \(error)")
            // Update the ViewModel's error state so the UI can react
            viewModel.errorMessage = "Reader error: \(error.localizedDescription)"
        }
        
        func navigator(_ navigator: any ReadiumNavigator.Navigator, didFailToLoadResourceAt href: ReadiumShared.RelativeURL, withError error: ReadiumShared.ReadError) {
            print("ERROR [Coordinator]: Failed to load resource \(href): \(error)")
        }
        
        // Manual script injection as fallback
        private func injectScriptsManually(navigator: EPUBNavigatorViewController) {
            // Load the script content
            guard let scriptPath = Bundle.main.path(forResource: "wordSelection", ofType: "js"),
                  let scriptContent = try? String(contentsOfFile: scriptPath, encoding: .utf8) else {
                print("ERROR [Coordinator]: Could not load wordSelection.js for manual injection")
                return
            }
            
            // Create a wrapper that first checks if R2NAVIGATOR_SEND_MESSAGE exists
            // If not, set up a polyfill that uses webkit.messageHandlers
            let wrappedScript = """
            (function() {
                // Create R2NAVIGATOR_SEND_MESSAGE polyfill if not available
                if (typeof window.R2NAVIGATOR_SEND_MESSAGE !== 'function') {
                    window.R2NAVIGATOR_SEND_MESSAGE = function(name, payload) {
                        console.log('Using polyfill R2NAVIGATOR_SEND_MESSAGE for: ' + name);
                        // Convert to string if it's not already
                        if (typeof payload !== 'string') {
                            try {
                                payload = JSON.stringify(payload);
                            } catch(e) {
                                payload = String(payload);
                            }
                        }
                        // Use webkit message handlers as fallback
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[name]) {
                            window.webkit.messageHandlers[name].postMessage(payload);
                        }
                    };
                }
                
                // Log a message to confirm script is running
                if (window.R2NAVIGATOR_SEND_MESSAGE) {
                    window.R2NAVIGATOR_SEND_MESSAGE('shioriLog', 'Manual script injection successful');
                } else if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.shioriLog) {
                    window.webkit.messageHandlers.shioriLog.postMessage('Manual script injection successful (webkit)');
                } else {
                    console.log('Manual script injection successful but no communication channel available');
                }
                
                // Now add the actual word selection script
                \(scriptContent)
            })();
            """
            
            // Execute the script
            Task {
                let result = await navigator.evaluateJavaScript(wrappedScript)
                print("DEBUG [Coordinator]: Manual script evaluation result: \(result)")
                
                // Also add message handlers manually
                if let webView = getWebViewFromNavigator(navigator) {
                    webView.configuration.userContentController.add(self, name: "wordTapped")
                    webView.configuration.userContentController.add(self, name: "dismissDictionary")
                    webView.configuration.userContentController.add(self, name: "shioriLog")
                    print("DEBUG [Coordinator]: Added message handlers manually to WebView")
                }
            }
        }
        
        // Helper to get the WebView from the navigator for manual handler addition
        private func getWebViewFromNavigator(_ navigator: EPUBNavigatorViewController) -> WKWebView? {
            // This is a bit fragile but necessary to get the WKWebView when we can't use the delegate method
            // Navigate through the view hierarchy to find the WKWebView
            for subview in navigator.view.subviews {
                if let webView = findWebView(in: subview) {
                    return webView
                }
            }
            return nil
        }
        
        private func findWebView(in view: UIView) -> WKWebView? {
            if let webView = view as? WKWebView {
                return webView
            }
            for subview in view.subviews {
                if let webView = findWebView(in: subview) {
                    return webView
                }
            }
            return nil
        }
        
        // This handles messages sent via `window.webkit.messageHandlers.yourName.postMessage(...)`
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
             print("DEBUG [Coordinator]: userContentController received message: \(message.name)")
             // Forward to the main message handling logic
             handleScriptMessage(name: message.name, body: message.body)
        }
        
        // This handles messages sent via `window.R2NAVIGATOR_SEND_MESSAGE(...)`
        @MainActor // Ensure UI updates happen on main thread
        func navigator(_ navigator: Navigator, didReceiveMessage name: String, body: Any) {
            print("DEBUG [Coordinator]: navigator received message: \(name)")
            // Forward to the main message handling logic
            handleScriptMessage(name: name, body: body)
        }
        
        @MainActor
        private func handleScriptMessage(name: String, body: Any) {
            switch name {
            case "shioriLog":
                if let logMessage = body as? String {
                    print("JS LOG [Shiori]: \(logMessage)")
                } else {
                     print("JS LOG [Shiori]: Received non-string log message: \(body)")
                }

            case "wordTapped":
                print("DEBUG [Coordinator]: Received wordTapped message with body: \(body)")
                guard let bodyString = body as? String, // Readium often sends payload as JSON string
                      let data = bodyString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let text = json["text"] as? String else {
                    // Fallback: Check if body is already a dictionary (might happen with WKScriptMessageHandler)
                     if let json = body as? [String: Any], let text = json["text"] as? String {
                         print("DEBUG [Coordinator]: Parsed wordTapped message directly from dictionary.")
                         viewModel.handleWordSelection(text: text, options: json)
                     } else {
                        print("ERROR [Coordinator]: Failed to parse wordTapped message body. Type: \(type(of: body)), Content: \(body)")
                     }
                    return
                }
                print("DEBUG [Coordinator]: Successfully parsed wordTapped message from JSON string, text: \(text)")
                viewModel.handleWordSelection(text: text, options: json) // Forward to view model

            case "dismissDictionary":
                print("DEBUG [Coordinator]: Received dismissDictionary message")
                viewModel.showDictionary = false

            // Handle console messages if using the console logger script
            case "consoleLog", "consoleWarn", "consoleError":
                 if let message = body as? String {
                     print("JS CONSOLE [\(name)]: \(message)")
                 }

            default:
                print("DEBUG [Coordinator]: Received unknown message: \(name) with body: \(body)")
            }
        }



        
//        func navigator(_ navigator: VisualNavigator, didTapOn text: String, at point: CGPoint, in frame: CGRect, textInfo: [String: Any]?) {
//            print("DEBUG [Coordinator]: Text tapped: \(text), info: \(textInfo ?? [:])")
//            // Forward to view model
//            viewModel.handleWordSelection(text: text, options: textInfo ?? [:])
//        }
//        
//        func navigator(_ navigator: VisualNavigator, didTapAt point: CGPoint) {
//            print("DEBUG [Coordinator]: Tap detected at \(point)")
//            
//            // Cast to get access to JavaScript evaluation
//            guard let epubNavigator = navigator as? EPUBNavigatorViewController else { return }
//            
//            let correctedPoint = CGPoint(x: point.x, y: point.y - 110)
//            print("DEBUG [Coordinator]: Corrected point: \(correctedPoint)")
//            
//            // Create JavaScript to find the word at this tap point
//            let javascriptToFindWord = """
//            (function() {
//                const range = document.caretRangeFromPoint(\(point.x), \(point.y));
//                if (!range) return null;
//                
//                const node = range.startContainer;
//                if (node.nodeType !== Node.TEXT_NODE) return null;
//                
//                const text = node.textContent;
//                const offset = range.startOffset;
//                
//                if (offset >= text.length) return null;
//                
//                // Get context text (the tapped character + following characters)
//                const contextText = text.substring(offset, Math.min(text.length, offset + 30));
//                
//                // Check if it contains Japanese characters
//                if (!/[\\u3000-\\u303F]|[\\u3040-\\u309F]|[\\u30A0-\\u30FF]|[\\uFF00-\\uFFEF]|[\\u4E00-\\u9FAF]|[\\u2605-\\u2606]|[\\u2190-\\u2195]|\\u203B/g.test(contextText)) {
//                    return null;
//                }
//                
//                // Get surrounding text for context (one sentence or paragraph)
//                let surroundingText = '';
//                let currentNode = node.parentNode;
//                while (currentNode && currentNode.nodeName !== 'P' && currentNode.nodeName !== 'DIV') {
//                    currentNode = currentNode.parentNode;
//                }
//                
//                if (currentNode) {
//                    surroundingText = currentNode.textContent.trim();
//                    if (surroundingText.length > 250) {
//                        surroundingText = surroundingText.substring(0, 250) + '...';
//                    }
//                }
//                
//                return {
//                    text: contextText,
//                    surroundingText: surroundingText
//                };
//            })();
//            """
//            
//            // Execute the JavaScript
//            Task {
//                let result = await epubNavigator.evaluateJavaScript(javascriptToFindWord)
//                
//                // Properly handle the Result type
//                switch result {
//                case .success(let value):
//                    // Now try to cast the value
//                    if let jsResult = value as? [String: String],
//                       let text = jsResult["text"] {
//                        // We successfully found text at the tap point
//                        var options: [String: Any] = [:]
//                        if let surroundingText = jsResult["surroundingText"] {
//                            options["surroundingText"] = surroundingText
//                        }
//                        
//                        // Forward to view model
//                        viewModel.handleWordSelection(text: text, options: options)
//                    }
//                case .failure(let error):
//                    print("ERROR [Coordinator]: JavaScript evaluation failed: \(error)")
//                }
//            }
//            
//        }
        
    }
}



