//
//  OrientationManager.swift
//  Shiori Reader
//
//  Created by Claude on 4/16/25.
//

import SwiftUI
import UIKit

/// ObservableObject to manage and control device orientation
class OrientationManager: ObservableObject {
    static let shared = OrientationManager()
    
    @Published var orientation: UIInterfaceOrientationMask = .portrait
    
    private init() {}
    
    func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
        self.orientation = orientation
    }
    
    func lockPortrait() {
        lockOrientation(.portrait)
    }
    
    func unlockOrientation() {
        lockOrientation([.portrait, .landscapeLeft, .landscapeRight])
    }
}

/// Custom SceneDelegate modifier to apply the orientation settings
struct OrientationLockModifier: ViewModifier {
    @ObservedObject var manager = OrientationManager.shared
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            }
    }
}

extension View {
    func orientationLock() -> some View {
        self.modifier(OrientationLockModifier())
    }
}
