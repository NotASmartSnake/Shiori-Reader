//
//  ContentView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//

import SwiftUI

struct MainView: View {
    @State private var selectedIndex = 0
    @State private var isReadingBook = false
    
    var body: some View {
        
        ZStack(alignment: .bottom) {

            VStack {
                switch selectedIndex {
                    case 0: LibraryView().environmentObject(IsReadingBook(isReading: $isReadingBook))
                    case 1: SavedWordsView()
                    case 2: SearchView()
                    case 3: SettingsView()
                    default: LibraryView()
                }
            }

            if !isReadingBook {
                CustomTabBar(selectedIndex: $selectedIndex)
            }
        }
        
    }
}

// Create an environment object to track reading state
class IsReadingBook: ObservableObject {
    @Binding var isReading: Bool
    
    init(isReading: Binding<Bool>) {
        _isReading = isReading
    }
}

#Preview {
    MainView()
}

