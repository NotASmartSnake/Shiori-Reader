//
//  ContentView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//

import SwiftUI

struct MainView: View {
    @State private var selectedIndex = 0
    @EnvironmentObject private var isReadingBookState: IsReadingBook
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var savedWordsManager: SavedWordsManager
    
    var body: some View {
        
        ZStack(alignment: .bottom) {

            VStack {
                switch selectedIndex {
                    case 0: LibraryView()
                        .environmentObject(isReadingBookState)
                        .environmentObject(libraryManager)
                        .environmentObject(savedWordsManager)
                    case 1: SavedWordsView()
                        .environmentObject(savedWordsManager)
                    case 2: SearchView()
                        .environmentObject(savedWordsManager)
                    case 3: SettingsView()
                    default: LibraryView()
                        .environmentObject(isReadingBookState)
                        .environmentObject(libraryManager)
                        .environmentObject(savedWordsManager)
                }
            }

            if !isReadingBookState.isReading {
                CustomTabBar(selectedIndex: $selectedIndex)
                    .transition(.opacity.animation(.none))
            }
        }
        .animation(.none, value: isReadingBookState.isReading)
        
    }
}

// Create an environment object to track reading state
class IsReadingBook: ObservableObject {
    @Published var isReading: Bool = false
    
    func setReading(_ value: Bool) {
        print("DEBUG: IsReadingBook.setReading(\(value))")
        isReading = value
    }
}

#Preview {
    MainView()
        .environmentObject(IsReadingBook())
        .environmentObject(LibraryManager())
        .environmentObject(SavedWordsManager())
}

