//
//  Shiori_ReaderApp.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//

import SwiftUI

@main
struct Shiori_ReaderApp: App {
    @AppStorage("isDarkMode") var isDarkMode: Bool?
    @StateObject private var isReadingBookState = IsReadingBook()
    @StateObject private var libraryManager = LibraryManager()
    @StateObject private var savedWordsManager = SavedWordsManager()
    let coreDataManager = CoreDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(isReadingBookState)
                .environmentObject(libraryManager)
                .environmentObject(savedWordsManager)
                .environment(\.managedObjectContext, coreDataManager.viewContext)
                .preferredColorScheme(
                    isDarkMode == nil ? nil : (isDarkMode! ? .dark : .light)
                )
                .onOpenURL { url in
                    // Handle URL callback from AnkiMobile
                    if url.scheme == "shiori" {
                        // The app was opened via the URL scheme
                        // Post a notification that a card was successfully added
                        NotificationCenter.default.post(name: Notification.Name("AnkiCardAdded"), object: nil)
                    }
                }
        }
    }
}
