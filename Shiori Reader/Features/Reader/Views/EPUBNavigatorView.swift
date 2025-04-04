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

struct EPUBNavigatorView: UIViewControllerRepresentable {
    // Use @ObservedObject if the ViewModel is passed in from a parent
    // Use @StateObject if this View *creates* and owns the ViewModel
    @ObservedObject var viewModel: ReadiumBookViewModel
    let publication: Publication
    let initialLocation: Locator?

    // MARK: - UIViewControllerRepresentable Core Methods

    func makeUIViewController(context: Context) -> EPUBNavigatorViewController {
        print("DEBUG [EPUBNavigatorView]: Making EPUBNavigatorViewController...")

        // 1. Get the shared server instance from the ServerManager singleton
        //    The ServerManager ensures the server is initialized.
        let server = ServerManager.shared.httpServer

        print("DEBUG [EPUBNavigatorView]: Using server instance provided by ServerManager.")

        // 2. Prepare the Navigator Configuration
        let config = EPUBNavigatorViewController.Configuration(
            preferences: viewModel.preferences
            // Add other configurations like editingActions if needed later
            // editingActions: [ EditingAction(title: "Highlight", action: #selector(Coordinator.highlightSelection)) ]
        )

        // 3. Initialize the EPUBNavigatorViewController
        do {
            let navigator = try EPUBNavigatorViewController(
                publication: publication,
                initialLocation: initialLocation,
                config: config,
                httpServer: server // <-- Pass the shared instance
            )
            // Set the delegate to receive callbacks (like location changes)
            navigator.delegate = context.coordinator
            print("DEBUG [EPUBNavigatorView]: EPUBNavigatorViewController created successfully.")
            return navigator

        } catch {
            // Handle initialization errors robustly in production
            print("ERROR [EPUBNavigatorView]: Failed to create EPUBNavigatorViewController: \(error)")
            // Maybe update viewModel's error state here?
            // viewModel.errorMessage = "Failed to create reader view: \(error.localizedDescription)"
            // Returning a basic UIViewController or using fatalError during dev
            fatalError("Failed to initialize EPUBNavigatorViewController: \(error.localizedDescription)")
        }
    }

    func updateUIViewController(_ uiViewController: EPUBNavigatorViewController, context: Context) {
        // Log entry point
        print("DEBUG [EPUBNavigatorView]: updateUIViewController called.") // Add this to confirm it runs

        // 1. Submit Preferences
        print("DEBUG [EPUBNavigatorView]: Submitting preferences...")
        uiViewController.submitPreferences(viewModel.preferences)
        print("DEBUG [EPUBNavigatorView]: Submitted preferences.")

        // 2. Handle Navigation Request using Locator
        if let targetLocator = viewModel.navigationRequest {
            print("DEBUG [EPUBNavigatorView]: Detected navigation request for locator: \(targetLocator.href)")
            
            // Clear the request immediately on the main thread to prevent re-triggering
            // Do this *before* starting the async navigation task
            viewModel.clearNavigationRequest() // Call synchronously on main thread
            
            // Perform the actual navigation asynchronously
            Task {
                print("DEBUG [EPUBNavigatorView]: Starting async task to navigate to locator...")
                let success = await uiViewController.go(to: targetLocator, options: .init(animated: false))
                print("DEBUG [EPUBNavigatorView]: Navigation to locator finished. Success: \(success)")
                // Optional: If !success, maybe set an error message on viewModel?
                // if !success {
                //     viewModel.errorMessage = "Failed to navigate to requested location."
                // }
            }
        }
        
        // Use the view model's current preferences
        uiViewController.submitPreferences(viewModel.preferences)
        print("DEBUG [EPUBNavigatorView]: Submitted preferences to navigator.")
    }

    // MARK: - Coordinator Setup

    func makeCoordinator() -> Coordinator {
        // Create the Coordinator, passing references to self and the viewModel
        Coordinator(self, viewModel: viewModel)
    }

    // MARK: - Coordinator Class (Delegate Implementation)

    // The Coordinator acts as the delegate for the EPUBNavigatorViewController
    // It bridges events from the UIKit world (Navigator) back to SwiftUI/ViewModel.
    class Coordinator: NSObject, EPUBNavigatorDelegate {
        func navigator(_ navigator: any ReadiumNavigator.Navigator, didFailToLoadResourceAt href: ReadiumShared.RelativeURL, withError error: ReadiumShared.ReadError) {
            
        }
        
        var parent: EPUBNavigatorView
        @ObservedObject var viewModel: ReadiumBookViewModel // Keep reference to update VM

        init(_ parent: EPUBNavigatorView, viewModel: ReadiumBookViewModel) {
            self.parent = parent
            self.viewModel = viewModel
            super.init()
            print("DEBUG [Coordinator]: Initialized.")
        }

        // --- NavigatorDelegate Callbacks ---

        @MainActor // Ensure UI updates or VM calls happen on the main thread
        func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
            // Called when the user navigates within the publication (scroll, turn page, tap link)
            print("DEBUG [Coordinator]: Location did change (received from navigator): \(locator.locations.progression?.description ?? "N/A")%")
            // Pass the updated location to the ViewModel
            viewModel.handleLocationUpdate(locator)
        }

        @MainActor // Ensure UI updates or VM calls happen on the main thread
        func navigator(_ navigator: Navigator, presentError error: NavigatorError) {
            // Called if the navigator encounters an internal error (e.g., cannot load a resource)
            print("ERROR [Coordinator]: Navigator failed with error: \(error)")
            // Update the ViewModel's error state so the UI can react
            viewModel.errorMessage = "Reader error: \(error.localizedDescription)"
        }

        // --- Optional Delegate Methods (Uncomment and implement as needed) ---

        /*
        @MainActor
        func navigator(_ navigator: VisualNavigator, didTapAt point: CGPoint) {
            // Handle taps within the navigator's view (e.g., for toggling UI, activating links)
            print("DEBUG [Coordinator]: Navigator tapped at point: \(point)")
            // Example: Toggle fullscreen on tap
            // viewModel.toggleFullscreen()

            // Use DirectionalNavigationAdapter for edge taps to turn pages:
            // guard !DirectionalNavigationAdapter(navigator: navigator).didTap(at: point) else {
            //     return // Tap handled for page turn
            // }
            // Handle center tap...
        }

        @MainActor
        func navigator(_ navigator: Navigator, presentExternalURL url: URL) {
             // Handle external links opened from the EPUB content
             print("DEBUG [Coordinator]: Navigator wants to open external URL: \(url)")
             // Typically use UIApplication.shared.open(url)
        }

        // Add methods for selection changes, bookmark requests, etc.
        // func navigator(_ navigator: SelectableNavigator, selectionDidChange selection: Selection?) { ... }
        */
    }
}
