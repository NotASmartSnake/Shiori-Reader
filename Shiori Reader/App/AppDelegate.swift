//
//  AppDelegate.swift
//  Shiori Reader
//
//  Created by Claude on 4/16/25.
//

import UIKit
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return OrientationManager.shared.orientation
    }
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UINavigationBar.appearance().layoutMargins.left = 30
        return true
    }
}
