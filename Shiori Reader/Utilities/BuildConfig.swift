//
//  BuildConfig.swift
//  Shiori Reader
//
//  Created on 4/18/25.
//

import Foundation

/// Provides app-wide configuration based on build type
enum BuildConfig {
    /// Whether the app is running in debug mode
    #if DEBUG
    static let isDebugMode = true
    #else
    static let isDebugMode = false
    #endif
    
    /// Various feature flags that can be toggled for different builds
    enum FeatureFlag {
        /// Whether detailed logging is enabled
        static var enableVerboseLogging: Bool {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }
        
        /// Whether development features are enabled
        static var enableDevFeatures: Bool {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }
    }
    
    /// App Store submission preparation
    static func prepareForAppStoreSubmission() {
        // Disable all debug features
        Logger.isEnabled = false
        
        // Perform any other app store preparation
        print("App prepared for App Store submission")
    }
}
