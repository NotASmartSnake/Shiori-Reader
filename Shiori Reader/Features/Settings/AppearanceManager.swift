//
//  AppearanceManager.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/18/25.
//

import SwiftUI

/// Key for storing appearance mode in UserDefaults
let kAppearanceModeKey = "shiori.appearance.mode"

/// Class to manage the app's appearance (light/dark mode)
class AppearanceManager {
    static let shared = AppearanceManager()
    
    private init() {
        applyAppearanceMode()
    }
    
    /// Get the current appearance mode
    func getCurrentAppearanceMode() -> String {
        return UserDefaults.standard.string(forKey: kAppearanceModeKey) ?? "system"
    }
    
    /// Set and apply a new appearance mode
    func setAppearanceMode(_ mode: String) {
        UserDefaults.standard.set(mode, forKey: kAppearanceModeKey)
        applyAppearanceMode()
    }
    
    /// Apply the app appearance mode from settings
    func applyAppearanceMode() {
        let mode = getCurrentAppearanceMode()
        
        // Apply the appearance mode
        switch mode {
        case "light":
            // Use the newer API for setting interface style
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.overrideUserInterfaceStyle = .light
            }
        case "dark":
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.overrideUserInterfaceStyle = .dark
            }
        case "system", _:
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.overrideUserInterfaceStyle = .unspecified
            }
        }
    }
}

// SwiftUI modifier to apply appearance settings
struct AppearanceModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var currentMode: String
    
    init() {
        // Initialize with the current mode
        self._currentMode = State(initialValue: AppearanceManager.shared.getCurrentAppearanceMode())
    }
    
    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    // Reapply appearance settings when app becomes active
                    AppearanceManager.shared.applyAppearanceMode()
                }
            }
            .onAppear {
                // Apply appearance settings when view appears
                AppearanceManager.shared.applyAppearanceMode()
            }
            // Listen for changes to the appearance mode in UserDefaults
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                let newMode = AppearanceManager.shared.getCurrentAppearanceMode()
                if newMode != currentMode {
                    currentMode = newMode
                    AppearanceManager.shared.applyAppearanceMode()
                }
            }
    }
}

// Extension to easily apply appearance settings to any view
extension View {
    func withAppearanceSettings() -> some View {
        modifier(AppearanceModifier())
    }
}
