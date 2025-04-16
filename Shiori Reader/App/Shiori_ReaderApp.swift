//
//  Shiori_ReaderApp.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//

import SwiftUI
import UIKit

@main
struct Shiori_ReaderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("isDarkMode") var isDarkMode: Bool?
    @StateObject private var isReadingBookState = IsReadingBook()
    @StateObject private var libraryManager = LibraryManager()
    @StateObject private var savedWordsManager = SavedWordsManager()
    @StateObject private var userPreferences = UserPreferences()
    
    let coreDataManager = CoreDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app content
                MainView()
                    .environmentObject(isReadingBookState)
                    .environmentObject(libraryManager)
                    .environmentObject(savedWordsManager)
                    .environment(\.managedObjectContext, coreDataManager.viewContext)
                    .preferredColorScheme(
                        isDarkMode == nil ? nil : (isDarkMode! ? .dark : .light)
                    )
                
                // Welcome view overlay on first launch
                if userPreferences.isFirstLaunch {
                    WelcomeView(isFirstLaunch: $userPreferences.isFirstLaunch)
                        .transition(.opacity)
                        .zIndex(100) // Ensure it's on top
                }
            }
            .animation(.easeInOut, value: userPreferences.isFirstLaunch)
            .onOpenURL { url in
                if url.scheme == "shiori" {
                    NotificationCenter.default.post(name: Notification.Name("AnkiCardAdded"), object: nil)
                }
            }
        }
    }
}
