
import SwiftUI
import Combine

class NavigationCoordinator: ObservableObject {
    static let shared = NavigationCoordinator()
    
    @Published var isTabBarVisible: Bool = true
    var cancellables = Set<AnyCancellable>()
    
    private init() {
    }
    
    func hideTabBar() {
        withAnimation(.none) {
            isTabBarVisible = false
        }
    }
    
    func showTabBar() {
        withAnimation(.none) {
            isTabBarVisible = true
        }
    }
}
