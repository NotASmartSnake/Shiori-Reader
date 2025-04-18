
//
//  NavigationCoordinator.swift
//  Shiori Reader
//
//  Created by Claude on 4/18/25.
//

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
