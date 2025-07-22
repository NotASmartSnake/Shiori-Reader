import UIKit
import SwiftUI
import Foundation

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return OrientationManager.shared.orientation
    }
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UINavigationBar.appearance().layoutMargins.left = 30
        
        // Initialize and apply appearance settings
        _ = AppearanceManager.shared
                
        // Configure logging based on build type
        #if DEBUG
            Logger.isEnabled = true
            Logger.info(category: "App", "Application started in DEBUG mode")
        #else
            // Disable logging for release builds (App Store submission)
            Logger.isEnabled = false
            
            // Call any other App Store preparation methods
            BuildConfig.prepareForAppStoreSubmission()
        #endif
        
        return true
    }
}
