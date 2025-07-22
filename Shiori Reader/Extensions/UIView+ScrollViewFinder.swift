
import UIKit
import SwiftUI
import WebKit

extension UIView {
    /// Recursively find all UIScrollViews in the view hierarchy
    func findScrollViews() -> [UIScrollView] {
        var scrollViews = [UIScrollView]()
        
        // Check if this view is a UIScrollView
        if let scrollView = self as? UIScrollView {
            scrollViews.append(scrollView)
        }
        
        // Recursively check all subviews
        for subview in subviews {
            scrollViews.append(contentsOf: subview.findScrollViews())
        }
        
        return scrollViews
    }
}

extension WKWebView {
    /// Adjust the content insets for all scroll views within the WebView
    /// - Parameters:
    ///   - topInset: The top inset to apply
    ///   - bottomInset: The bottom inset to apply
    func adjustScrollViewContentInsets(top topInset: CGFloat, bottom bottomInset: CGFloat) {
        let scrollViews = self.findScrollViews()
        for scrollView in scrollViews {
            // Set the content inset
            scrollView.contentInset = UIEdgeInsets(
                top: topInset,
                left: scrollView.contentInset.left,
                bottom: bottomInset,
                right: scrollView.contentInset.right
            )
            
            // Also update the scroll indicator insets to match
            scrollView.scrollIndicatorInsets = scrollView.contentInset
            
            print("DEBUG [ScrollViewFinder]: Adjusted scroll view content insets to top: \(topInset), bottom: \(bottomInset)")
        }
    }
}
