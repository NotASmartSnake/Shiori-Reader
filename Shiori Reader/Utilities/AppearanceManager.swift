//
//  AppearanceManager.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/6/25.
//


//
//  AppearanceManager.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/6/25.
//

import SwiftUI

// This is a singleton that manages the app-wide appearance settings
class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()
    
    @Published var appearanceMode: AppearanceMode = .system {
        didSet {
            applyAppearanceMode()
            saveAppearanceMode()
        }
    }
    
    private init() {
        // Load saved appearance mode on initialization
        if let savedMode = UserDefaults.standard.string(forKey: "app_appearance_mode"),
           let mode = AppearanceMode(rawValue: savedMode) {
            self.appearanceMode = mode
        }
        applyAppearanceMode()
    }
    
    private func saveAppearanceMode() {
        UserDefaults.standard.set(appearanceMode.rawValue, forKey: "app_appearance_mode")
    }
    
    func applyAppearanceMode() {
        DispatchQueue.main.async {
            let scenes = UIApplication.shared.connectedScenes
            guard let windowScene = scenes.first as? UIWindowScene,
                  let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) else {
                return
            }
            
            keyWindow.overrideUserInterfaceStyle = self.getUserInterfaceStyle(for: self.appearanceMode)
        }
    }
    
    private func getUserInterfaceStyle(for mode: AppearanceMode) -> UIUserInterfaceStyle {
        switch mode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return .unspecified
        }
    }
}
