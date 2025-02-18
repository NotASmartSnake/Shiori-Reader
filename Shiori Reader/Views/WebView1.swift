//
//  WebView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/17/25.
//

import SwiftUI
@preconcurrency import WebKit

struct WebView1: UIViewRepresentable {
    let htmlContent: String
    let baseURL: URL?
    
    init(htmlContent: String, baseURL: URL? = nil) {
        self.htmlContent = htmlContent
        self.baseURL = baseURL
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear
        
        return webView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView1
        
        init(_ parent: WebView1) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("""
                console.log('Document class:', document.documentElement.className);
                document.querySelectorAll('img').forEach(img => {
                    console.log('Image found:', {
                        src: img.src,
                        class: img.className,
                        parent: img.parentElement.tagName
                    });
                });
            """)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                print("🔗 Navigation requested to:", url.absoluteString)
            }
            decisionHandler(.allow)
        }
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let baseURL = baseURL else { return }
        
        var processedContent = htmlContent
        
        // Function to resolve relative paths
        func resolveImagePath(_ originalPath: String) -> String {
            let cleanPath = originalPath
                .replacingOccurrences(of: "file://", with: "")
                .replacingOccurrences(of: "../", with: "")
                .replacingOccurrences(of: "./", with: "")
            
            let imageName = cleanPath.components(separatedBy: "/").last ?? cleanPath
            
            // Common image directory patterns to check
            let possiblePaths = [
                baseURL.appendingPathComponent("images/\(imageName)").path,
                baseURL.appendingPathComponent("item/image/\(imageName)").path,
                baseURL.appendingPathComponent("image/\(imageName)").path,
                baseURL.appendingPathComponent(imageName).path
            ]
            
            // Try each possible path
            for path in possiblePaths {
                if FileManager.default.fileExists(atPath: path) {
                    print("✅ Found image at:", path)
                    return "file://\(path)"
                }
            }
            
            // If the original path contains a full path structure, try that
            if cleanPath.contains("item/image/") || cleanPath.contains("images/") {
                let fullPath = baseURL.appendingPathComponent(cleanPath).path
                if FileManager.default.fileExists(atPath: fullPath) {
                    print("✅ Found image at original path:", fullPath)
                    return "file://\(fullPath)"
                }
            }
            
            print("⚠️ Could not resolve path for:", originalPath)
            return originalPath
        }
        
        // Process image references
        let patterns = [
            "src=\"([^\"]+)\"",
            "xlink:href=\"([^\"]+)\"",
            "src='([^']+)'",
            "xlink:href='([^']+)'"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(processedContent.startIndex..., in: processedContent)
                let matches = regex.matches(in: processedContent, range: range)
                
                for match in matches.reversed() {
                    if let pathRange = Range(match.range(at: 1), in: processedContent),
                       let fullRange = Range(match.range(at: 0), in: processedContent) {
                        let originalPath = String(processedContent[pathRange])
                        
                        // Only process image files
                        if originalPath.contains(".jpg") || originalPath.contains(".jpeg") ||
                           originalPath.contains(".png") || originalPath.contains(".gif") {
                            let resolvedPath = resolveImagePath(originalPath)
                            let attributeName = pattern.contains("src") ? "src" : "xlink:href"
                            let newValue = "\(attributeName)=\"\(resolvedPath)\""
                            processedContent = processedContent.replacingCharacters(in: fullRange, with: newValue)
                            
                            print("🔄 Resolved path:", originalPath, "->", resolvedPath)
                        }
                    }
                }
            }
        }
        
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: "Hiragino Mincho ProN", "Yu Mincho", "MS Mincho", serif;
                    font-size: 18px;
                    line-height: 1.8;
                    padding: 16px;
                    background-color: transparent;
                    color: #333333;
                }
                
                img {
                    max-width: 100% !important;
                    height: auto !important;
                    display: block;
                    margin: 1em auto;
                }
                
                svg {
                    max-width: 100% !important;
                    height: auto !important;
                    display: block;
                    margin: 1em auto;
                }
                
                svg image {
                    max-width: 100% !important;
                    height: auto !important;
                }
                
                .fit {
                    width: 100% !important;
                    max-width: 100% !important;
                    object-fit: contain;
                }
                
                .main {
                    max-width: 100%;
                    margin: 0 auto;
                    overflow-x: hidden;
                }
                
                p {
                    margin: 1.5em 0;
                    text-align: justify;
                }
                
                ruby {
                    ruby-position: over;
                    ruby-align: center;
                    -webkit-ruby-position: before;
                }
                
                rt {
                    font-size: 0.5em;
                    color: #666666;
                    line-height: 1;
                    text-align: center;
                }
                
                .tcy {
                    -webkit-text-combine: horizontal;
                    -webkit-text-combine-upright: all;
                    text-combine-upright: all;
                    text-orientation: mixed;
                }
                
                rp {
                    display: none;
                }
                
                * {
                    word-wrap: break-word;
                    overflow-wrap: break-word;
                }
            </style>
        </head>
        <body>
            \(processedContent)
        </body>
        </html>
        """
        
        print("📝 Loading content with base URL:", baseURL.path)
        uiView.loadHTMLString(styledHTML, baseURL: baseURL)
    }
}
