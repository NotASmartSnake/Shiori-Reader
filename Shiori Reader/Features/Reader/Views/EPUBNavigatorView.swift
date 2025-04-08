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
        private let wordTapHandler: WordTapHandler
        
        init(_ parent: EPUBNavigatorView, viewModel: ReaderViewModel) {
            self.parent = parent
            self.viewModel = viewModel
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
                wordTapHandler.registerHandlers(for: webView)
            }
            
            // Then check children
            for subview in view.subviews {
                findAndSetupWebViews(in: subview)
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
        
    }
}
