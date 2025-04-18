//
//  ContentView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//

import SwiftUI
import Combine

struct MainView: View {
    @State private var selectedIndex = 0
    @EnvironmentObject private var isReadingBookState: IsReadingBook
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var savedWordsManager: SavedWordsManager
    
    // Add the navigation coordinator
    @StateObject private var navigationCoordinator = NavigationCoordinator.shared
    
    // Keyboard observer to detect when keyboard appears/disappears
    @StateObject private var keyboardObserver = KeyboardObserver()
    
    // Lock orientation to portrait for MainView
    private let orientationManager = OrientationManager.shared
    
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

            if navigationCoordinator.isTabBarVisible && !keyboardObserver.isKeyboardVisible {
                CustomTabBar(selectedIndex: $selectedIndex)
            }
        }
        // Change to observe the navigationCoordinator instead
        .animation(.none, value: navigationCoordinator.isTabBarVisible)
        .animation(.easeInOut(duration: keyboardObserver.animationDuration), value: keyboardObserver.isKeyboardVisible)
        .onAppear {
            // Lock to portrait when MainView appears
            orientationManager.lockPortrait()
            
            // Observe isReading state changes to control tab bar visibility
            isReadingBookState.$isReading
                .sink { [weak navigationCoordinator] isReading in
                    if isReading {
                        navigationCoordinator?.hideTabBar()
                    } else {
                        navigationCoordinator?.showTabBar()
                    }
                }
                .store(in: &navigationCoordinator.cancellables)
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
        .environmentObject(IsReadingBook())
        .environmentObject(LibraryManager())
        .environmentObject(SavedWordsManager())
}

