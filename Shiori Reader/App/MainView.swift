import SwiftUI
import Combine

struct MainView: View {
    @State private var selectedIndex = 0
    @EnvironmentObject private var isReadingBookState: IsReadingBook
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var savedWordsManager: SavedWordsManager
    
    // Tab bar visibility state
    @State private var isTabBarVisible: Bool = true
    
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

            if isTabBarVisible && !keyboardObserver.isKeyboardVisible {
                CustomTabBar(selectedIndex: $selectedIndex)
            }
        }
        .animation(.none, value: isTabBarVisible)
        .animation(.easeInOut(duration: keyboardObserver.animationDuration), value: keyboardObserver.isKeyboardVisible)
        .onChange(of: isReadingBookState.isReading) { isReading in
            withAnimation(.none) {
                isTabBarVisible = !isReading
            }
        }
        .onAppear {
            // Lock to portrait when MainView appears
            orientationManager.lockPortrait()
        }
    }
}

// Create an environment object to track reading state
class IsReadingBook: ObservableObject {
    @Published var isReading: Bool = false
    
    func setReading(_ value: Bool) {
        isReading = value
    }
}

#Preview {
    MainView()
        .environmentObject(IsReadingBook())
        .environmentObject(LibraryManager())
        .environmentObject(SavedWordsManager())
}

