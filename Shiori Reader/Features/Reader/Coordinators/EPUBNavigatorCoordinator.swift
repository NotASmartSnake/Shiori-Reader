//
//  EPUBNavigatorCoordinator.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/8/25.
//

import SwiftUI
import ReadiumShared
import ReadiumNavigator
import WebKit

class EPUBNavigatorCoordinator: NSObject, EPUBNavigatorDelegate, WKScriptMessageHandler {
    weak var viewModel: ReaderViewModel?
    private let wordTapHandler: WordTapHandler
    
    // Track the last known scroll mode to detect changes
    var lastKnownScrollMode: Bool = false
    
    init(viewModel: ReaderViewModel) {
        self.viewModel = viewModel
        self.wordTapHandler = WordTapHandler(viewModel: viewModel)
        self.lastKnownScrollMode = viewModel.preferences.scroll ?? false
        super.init()
        print("DEBUG [Coordinator]: Initialized with WordTapHandler.")
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
        viewModel?.handleLocationUpdate(locator)
        
        // Search for WebViews after a slight delay to ensure rendering is complete
        if let epubNavigator = navigator as? EPUBNavigatorViewController {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.findAndSetupWebViews(in: epubNavigator.view)
                
                // Apply appropriate content insets to scroll views if in scroll mode
                self.applyScrollModeContentInsets(in: epubNavigator)
            }
        }
    }
    
    private func findAndSetupWebViews(in view: UIView) {
        // First check for direct WebViews
        if let webView = view as? WKWebView {
            wordTapHandler.registerHandlers(for: webView)
        }
        
        // Then check children
        for subview in view.subviews {
            findAndSetupWebViews(in: subview)
        }
    }
    
    /// Apply content insets specifically for scroll mode
    func applyScrollModeContentInsets(in navigator: EPUBNavigatorViewController) {
        // Only apply special scroll mode insets when in scroll mode
        guard let viewModel = viewModel, viewModel.preferences.scroll == true else {
            print("DEBUG [Coordinator]: Not in scroll mode, skipping scroll insets")
            return
        }
        
        print("DEBUG [Coordinator]: Applying scroll mode insets")
        
        // Find all WKWebViews in the navigator's view hierarchy
        findWebViews(in: navigator.view) { webView in
            // Determine appropriate insets based on device type
            let topInset: CGFloat = 100.0
            let bottomInset: CGFloat = 100.0
            
            // Apply the insets to the scroll views within the WebView
            webView.adjustScrollViewContentInsets(top: topInset, bottom: bottomInset)
            print("DEBUG [Coordinator]: Applied scroll mode insets - top: \(topInset), bottom: \(bottomInset)")
        }
    }
    
    /// Find all WKWebViews in a view hierarchy and apply the given action
    private func findWebViews(in view: UIView, action: (WKWebView) -> Void) {
        // Check if this view is a WKWebView
        if let webView = view as? WKWebView {
            action(webView)
        }
        
        // Recursively check all subviews
        for subview in view.subviews {
            findWebViews(in: subview, action: action)
        }
    }
    
    /// Detect if the current device is an iPad
    private func isIpad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    @MainActor // Ensure UI updates or VM calls happen on the main thread
    func navigator(_ navigator: Navigator, presentError error: NavigatorError) {
        // Called if the navigator encounters an internal error (e.g., cannot load a resource)
        print("ERROR [Coordinator]: Navigator failed with error: \(error)")
        // Update the ViewModel's error state so the UI can react
        viewModel?.errorMessage = "Reader error: \(error.localizedDescription)"
    }
    
    func navigator(_ navigator: any ReadiumNavigator.Navigator, didFailToLoadResourceAt href: ReadiumShared.RelativeURL, withError error: ReadiumShared.ReadError) {
        print("ERROR [Coordinator]: Failed to load resource \(href): \(error)")
    }
    
    // Called when a resource has been loaded successfully
    func navigator(_ navigator: Navigator, didLoadResourceAt href: ReadiumShared.RelativeURL) {
        print("DEBUG [Coordinator]: Loaded resource at \(href)")
        
        // When in scroll mode, ensure content insets are reapplied after resource is loaded
        if viewModel?.preferences.scroll == true, let epubNavigator = navigator as? EPUBNavigatorViewController {
            // Apply insets after a short delay to ensure the content has rendered
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.applyScrollModeContentInsets(in: epubNavigator)
            }
        }
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
                     viewModel?.handleWordSelection(text: text, options: json)
                 } else {
                    print("ERROR [Coordinator]: Failed to parse wordTapped message body. Type: \(type(of: body)), Content: \(body)")
                 }
                return
            }
            print("DEBUG [Coordinator]: Successfully parsed wordTapped message from JSON string, text: \(text)")
            viewModel?.handleWordSelection(text: text, options: json) // Forward to view model

        case "dismissDictionary":
            print("DEBUG [Coordinator]: Received dismissDictionary message")
            viewModel?.showDictionary = false

        // Handle console messages if using the console logger script
        case "consoleLog", "consoleWarn", "consoleError":
             if let message = body as? String {
                 print("JS CONSOLE [\(name)]: \(message)")
             }

        default:
            print("DEBUG [Coordinator]: Received unknown message: \(name) with body: \(body)")
        }
    }
    
}
