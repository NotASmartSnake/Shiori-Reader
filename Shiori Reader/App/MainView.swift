//
//  ContentView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//

import SwiftUI

struct MainView: View {
    @State private var selectedIndex = 0
    @StateObject private var isReadingBookState = IsReadingBook()
    
    var body: some View {
        
        ZStack(alignment: .bottom) {

            VStack {
                switch selectedIndex {
                    case 0: LibraryView().environmentObject(isReadingBookState)
                    case 1: SavedWordsView()
                    case 2: SearchView()
                    case 3: SettingsView()
                    default: LibraryView().environmentObject(isReadingBookState)
                }
            }

            if !isReadingBookState.isReading {
                CustomTabBar(selectedIndex: $selectedIndex)
                    .animation(.none, value: isReadingBookState.isReading)
            }
        }
        .onAppear {
            isReadingBookState.isReading = false
        }
        
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
}

