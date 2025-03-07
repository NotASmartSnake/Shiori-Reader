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
        }
    }
}
