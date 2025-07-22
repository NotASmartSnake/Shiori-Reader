
import Foundation
import Combine

class UserPreferences: ObservableObject {
    // Published properties for UI binding
    @Published var isFirstLaunch: Bool {
        didSet {
            UserDefaults.standard.set(!isFirstLaunch, forKey: Keys.hasLaunchedBefore)
        }
    }
    
    // Private storage keys
    private enum Keys {
        static let hasLaunchedBefore = "hasLaunchedBefore"
    }
    
    init() {
        // If hasLaunchedBefore is false or nil, it's the first launch
        isFirstLaunch = !UserDefaults.standard.bool(forKey: Keys.hasLaunchedBefore)
    }
    
    // Reset first launch state (for testing)
    func resetFirstLaunchState() {
        UserDefaults.standard.set(false, forKey: Keys.hasLaunchedBefore)
        isFirstLaunch = true
    }
}
