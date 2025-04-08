////
////  class.swift
////  Shiori Reader
////
////  Created by Russell Graviet on 4/8/25.
////
//
//import SwiftUI
//import ReadiumShared
//import ReadiumNavigator
//import WebKit
//
//// Create a dedicated WebViewManager class
//class WebViewManager {
//    weak var viewModel: ReaderViewModel?
//    private var registeredWebViews = Set<ObjectIdentifier>()
//    private var checkTimer: Timer?
//    private var navigatorViewController: EPUBNavigatorViewController?
//    
//    init(viewModel: ReaderViewModel) {
//        self.viewModel = viewModel
//    }
//    
//    func startMonitoring(navigatorViewController: EPUBNavigatorViewController) {
//        self.navigatorViewController = navigatorViewController
//        
//        // Immediately check for WebViews
//        findAndSetupWebViews(in: navigatorViewController.view)
//        
//        // Setup a timer to check periodically
//        checkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
//            guard let self = self, let navigator = self.navigatorViewController else { return }
//            self.findAndSetupWebViews(in: navigator.view)
//        }
//    }
//    
//    func stopMonitoring() {
//        checkTimer?.invalidate()
//        checkTimer = nil
//    }
//    
//    private func findAndSetupWebViews(in view: UIView) {
//        // First check for direct WebViews
//        for subview in view.subviews {
//            if let webView = subview as? WKWebView {
//                setupWebView(webView)
//            }
//            
//            // Always recursively search
//            findAndSetupWebViews(in: subview)
//        }
//    }
//    
//    private func setupWebView(_ webView: WKWebView) {
//        let identifier = ObjectIdentifier(webView)
//        
//        // Only setup WebViews we haven't seen before
//        guard !registeredWebViews.contains(identifier) else { return }
//        
//        print("DEBUG: Setting up new WebView")
//        registeredWebViews.insert(identifier)
//        
//        // Add message handlers
//        let userContentController = webView.configuration.userContentController
//        let messageHandler = WordTapHandler(viewModel: viewModel)
//        
//        userContentController.add(messageHandler, name: "wordTapped")
//        userContentController.add(messageHandler, name: "dismissDictionary")
//        userContentController.add(messageHandler, name: "log")
//        
//        // Inject our scripts
//        injectScripts(webView)
//    }
//    
//    private func injectScripts(_ webView: WKWebView) {
//        // Load the word selection script
//        guard let scriptPath = Bundle.main.path(forResource: "wordSelection", ofType: "js"),
//              let scriptContent = try? String(contentsOfFile: scriptPath, encoding: .utf8) else {
//            print("ERROR: Could not load wordSelection.js")
//            return
//        }
//        
//        // Create a wrapper script with mutation observer to persist through DOM changes
//        let scriptWrapper = """
//        (function() {
//            console.log("Starting script injection attempt");
//            
//            // Only run this script once per page
//            if (window._shioriScriptInjected) {
//                console.log("Script already injected, skipping");
//                return;
//            }
//            
//            window._shioriScriptInjected = true;
//            
//            // First ensure all required interfaces exist
//            window.webkit = window.webkit || {};
//            window.webkit.messageHandlers = window.webkit.messageHandlers || {};
//            
//            // Setup a console redirect for debugging
//            const originalConsoleLog = console.log;
//            console.log = function() {
//                // First call original function
//                originalConsoleLog.apply(console, arguments);
//                
//                // Then try to send to our handler if available
//                try {
//                    if (window.webkit.messageHandlers.log) {
//                        const message = Array.from(arguments).map(arg => {
//                            return typeof arg === 'object' ? JSON.stringify(arg) : String(arg);
//                        }).join(' ');
//                        window.webkit.messageHandlers.log.postMessage(message);
//                    }
//                } catch(e) {
//                    // Silent fail
//                }
//            };
//            
//            console.log("Shiori script injection starting");
//            
//            // Main script content
//            \(scriptContent)
//            
//            // Add a mutation observer to re-initialize on DOM changes
//            const observer = new MutationObserver(function(mutations) {
//                console.log("DOM mutation detected, ensuring script functionality");
//                
//                // Just trigger a test message to verify connection still works
//                try {
//                    window.webkit.messageHandlers.log.postMessage("DOM mutation detected");
//                    
//                    // Test the wordTapped handler too
//                    window.webkit.messageHandlers.wordTapped.postMessage({
//                        test: true,
//                        text: "Connection check after DOM mutation"
//                    });
//                } catch(e) {
//                    console.log("Error in mutation observer: " + e);
//                }
//            });
//            
//            // Start observing the document
//            observer.observe(document, { 
//                childList: true,
//                subtree: true 
//            });
//            
//            console.log("Script injection complete with mutation observer");
//        })();
//        """
//        
//        // Inject the script
//        webView.evaluateJavaScript(scriptWrapper) { result, error in
//            if let error = error {
//                print("ERROR: Script injection failed: \(error)")
//            } else {
//                print("DEBUG: Script injection completed with result: \(result ?? "nil")")
//            }
//        }
//    }
//}
