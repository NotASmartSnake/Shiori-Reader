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

    func makeCoordinator() -> EPUBNavigatorCoordinator {
        // Create the Coordinator, passing references to self and the viewModel
        EPUBNavigatorCoordinator(viewModel: viewModel)
    }
}
