
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
        let server = ServerManager.shared.httpServer

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
            Logger.debug(category: "EPUBNavigator", "Failed to create EPUBNavigatorViewController: \(error)")
            fatalError("Failed to initialize EPUBNavigatorViewController: \(error.localizedDescription)")
        }
    }

    func updateUIViewController(_ uiViewController: EPUBNavigatorViewController, context: Context) {
        // Submit preferences when they change in the ViewModel
        uiViewController.submitPreferences(viewModel.preferences)
        
        if let targetLocator = viewModel.navigationRequest {
            viewModel.clearNavigationRequest()
            
            Task {
                _ = await uiViewController.go(to: targetLocator, options: .init(animated: false))
            }
        }
        
        // Check if scroll mode has changed and trigger a scroll inset update
        let isScrollMode = viewModel.preferences.scroll ?? false
        let wasScrollMode = context.coordinator.lastKnownScrollMode
        
        if isScrollMode != wasScrollMode {
            context.coordinator.lastKnownScrollMode = isScrollMode
            
            // Allow time for the preference to be applied before adjusting insets
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                context.coordinator.applyScrollModeContentInsets(in: uiViewController)
                
                // When changing modes, forcibly reload the handlers and scripts on all WebViews
                // This is more aggressive than just reinjecting scripts
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
        // Create a configuration with default values including one column layout
        let config = EPUBNavigatorViewController.Configuration(
            defaults: EPUBDefaults(columnCount: .one), // Force 1 column layout for all devices
            contentInset: getDeviceSpecificContentInsets()
        )
        
        return config
    }
    
    /// Creates device-specific content insets based on device type
    private func getDeviceSpecificContentInsets() -> [UIUserInterfaceSizeClass: (top: CGFloat, bottom: CGFloat)] {
        if isIpad() {
            // Apply larger top inset for iPads to keep text away from the top navigation bar
            return [
                .compact: (top: 60, bottom: 20),
                .regular: (top: 95, bottom: 40)
            ]
        } else {
            // For iPhone, use smaller insets
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
