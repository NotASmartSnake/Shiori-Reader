//
//  ScrollAxisLock.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/27/25.
//

import SwiftUI
import UIKit
import WebKit

struct ScrollAxisLock: ViewModifier {
    let axis: Axis
    
    func body(content: Content) -> some View {
        content
            .background(ScrollAxisLockUIViewRepresentable(axis: axis))
    }
}

struct ScrollAxisLockUIViewRepresentable: UIViewRepresentable {
    let axis: Axis
    
    // We need a coordinator to handle the pan gesture
    class Coordinator: NSObject {
        let axis: Axis
        
        init(axis: Axis) {
            self.axis = axis
            super.init()
        }
        
        // Make sure the method is exposed to Objective-C
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }
            
            let translation = gesture.translation(in: scrollView)
            
            if axis == .vertical {
                // Only allow vertical scrolling
                if abs(translation.x) > abs(translation.y) {
                    gesture.state = .failed
                }
            } else {
                // Only allow horizontal scrolling
                if abs(translation.y) > abs(translation.x) {
                    gesture.state = .failed
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(axis: axis)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Find WebView in the view hierarchy and apply scroll constraints
        DispatchQueue.main.async {
            if let window = uiView.window {
                self.findAndConfigureWebViews(in: window, coordinator: context.coordinator)
            }
        }
    }
    
    private func findAndConfigureWebViews(in view: UIView, coordinator: Coordinator) {
        // Check each subview recursively
        for subview in view.subviews {
            if let webView = subview as? WKWebView {
                configureWebViewScrolling(webView, coordinator: coordinator)
            } else if subview.subviews.count > 0 {
                findAndConfigureWebViews(in: subview, coordinator: coordinator)
            }
        }
    }
    
    private func configureWebViewScrolling(_ webView: WKWebView, coordinator: Coordinator) {
        let scrollView = webView.scrollView
        
        // Configure scroll indicators
        scrollView.showsVerticalScrollIndicator = axis == .vertical
        scrollView.showsHorizontalScrollIndicator = axis == .horizontal
        
        // Configure bounce behavior
        scrollView.alwaysBounceVertical = axis == .vertical
        scrollView.alwaysBounceHorizontal = axis == .horizontal
        
        // Prevent scrolling in the non-preferred direction
        if axis == .vertical {
            // Vertical scrolling - lock horizontal
            scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            scrollView.contentOffset.x = 0
            
            // Add the pan gesture handler
            scrollView.panGestureRecognizer.addTarget(coordinator, action: #selector(Coordinator.handlePan(_:)))
            
            // Additional settings for vertical mode
            webView.evaluateJavaScript("""
            document.body.style.overflowX = 'hidden';
            document.body.style.overflowY = 'auto';
            """)
        } else {
            // Horizontal scrolling - lock vertical
            scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            scrollView.contentOffset.y = 0
            
            // Add the pan gesture handler
            scrollView.panGestureRecognizer.addTarget(coordinator, action: #selector(Coordinator.handlePan(_:)))
            
            // Additional settings for horizontal mode
            webView.evaluateJavaScript("""
            document.body.style.overflowX = 'auto';
            document.body.style.overflowY = 'hidden';
            """)
        }
    }
}

// Extension to make it easy to use
extension View {
    func lockScrollAxis(_ axis: Axis) -> some View {
        modifier(ScrollAxisLock(axis: axis))
    }
}
