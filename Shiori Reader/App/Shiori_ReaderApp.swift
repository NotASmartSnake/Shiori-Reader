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
    
    var body: some Scene {
        WindowGroup {
            MainView()
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
