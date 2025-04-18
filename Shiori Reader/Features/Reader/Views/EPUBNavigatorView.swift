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
import UIKit

struct EPUBNavigatorView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: ReaderViewModel
    let publication: Publication
    let initialLocation: Locator?

    // MARK: - UIViewControllerRepresentable Core Methods

    func makeUIViewController(context: Context) -> EPUBNavigatorViewController {
        print("DEBUG [EPUBNavigatorView]: Making EPUBNavigatorViewController...")

        let server = ServerManager.shared.httpServer

        print("DEBUG [EPUBNavigatorView]: Using server instance provided by ServerManager.")

        // Create a configuration with custom content insets for iPad
        let config = createNavigatorConfiguration()

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
        
        // Check if scroll mode has changed and trigger a scroll inset update
        let isScrollMode = viewModel.preferences.scroll ?? false
        let wasScrollMode = context.coordinator.lastKnownScrollMode
        
        if isScrollMode != wasScrollMode {
            print("DEBUG [EPUBNavigatorView]: Scroll mode changed from \(wasScrollMode) to \(isScrollMode)")
            context.coordinator.lastKnownScrollMode = isScrollMode
            
            // Allow time for the preference to be applied before adjusting insets
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                context.coordinator.applyScrollModeContentInsets(in: uiViewController)
                
                // When changing modes, forcibly reload the handlers and scripts on all WebViews
                // This is more aggressive than just reinjecting scripts
                print("DEBUG [EPUBNavigatorView]: Forcibly reloading scripts after mode change")
                context.coordinator.forceReloadScriptsInAllWebViews(in: uiViewController.view)
            }
        }
        
        // Use the view model's current preferences
        uiViewController.submitPreferences(viewModel.preferences)
    }
    
    // MARK: - Coordinator Setup

    func makeCoordinator() -> EPUBNavigatorCoordinator {
        // Create the Coordinator, passing references to self and the viewModel
        EPUBNavigatorCoordinator(viewModel: viewModel)
    }
    
    // MARK: - Helper Methods
    
    /// Creates a navigator configuration with device-specific settings
    private func createNavigatorConfiguration() -> EPUBNavigatorViewController.Configuration {
        // Create a configuration with default values based on the Readium code you shared
        let config = EPUBNavigatorViewController.Configuration(
            contentInset: getDeviceSpecificContentInsets()
        )
        
        return config
    }
    
    /// Creates device-specific content insets based on device type
    private func getDeviceSpecificContentInsets() -> [UIUserInterfaceSizeClass: (top: CGFloat, bottom: CGFloat)] {
        if isIpad() {
            // Apply larger top inset for iPads to keep text away from the top navigation bar
            print("DEBUG [EPUBNavigatorView]: Applying iPad-specific content insets")
            return [
                .compact: (top: 60, bottom: 20),
                .regular: (top: 95, bottom: 40)
            ]
        } else {
            // For iPhone, use smaller insets
            print("DEBUG [EPUBNavigatorView]: Applying iPhone-specific content insets")
            return [
                .compact: (top: 16, bottom: 16),  
                .regular: (top: 40, bottom: 20)
            ]
        }
    }
    
    /// Detects if the current device is an iPad
    private func isIpad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
}
