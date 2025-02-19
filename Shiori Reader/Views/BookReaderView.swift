//
//  BookReaderView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//

import SwiftUI
@preconcurrency import WebKit

struct BookReaderView: View {
    let book: Book
    @State private var epubContent: EPUBContent?
    @State private var errorMessage: String?
    @State private var isLoading: Bool = true
    @State private var epubBaseURL: URL?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading book...")
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Error loading book")
                        .font(.headline)
                    Text(error)
                        .foregroundColor(.gray)
                }
                .padding()
            } else if let content = epubContent {
                SingleWebView(content: content, baseURL: epubBaseURL)
                    .ignoresSafeArea(.all)
            }
        }
        .onAppear {
            loadEPUB()
        }
    }
    
    private func loadEPUB() {
        isLoading = true
        
        guard let epubPath = Bundle.main.path(forResource: book.filePath, ofType: nil) else {
            errorMessage = "Could not find EPUB file in bundle"
            isLoading = false
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let parser = EPUBParser()
                let (content, baseURL) = try parser.parseEPUB(at: epubPath)
                
                DispatchQueue.main.async {
                    self.epubContent = content
                    self.epubBaseURL = baseURL
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load EPUB: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}


//struct BookReaderView: View {
//    let book: Book
//    @State private var epubContent: EPUBContent?
//    @State private var errorMessage: String?
//    @State private var isLoading: Bool = true
//    @State private var epubBaseURL: URL?
//    
//    var body: some View {
//        VStack {
//            if isLoading {
//                ProgressView("Loading book...")
//            } else if let error = errorMessage {
//                VStack(spacing: 16) {
//                    Image(systemName: "exclamationmark.triangle")
//                        .font(.largeTitle)
//                        .foregroundColor(.red)
//                    Text("Error loading book")
//                        .font(.headline)
//                    Text(error)
//                        .foregroundColor(.gray)
//                }
//                .padding()
//            } else if let content = epubContent {
//                ScrollView {
//                    LazyVStack(alignment: .leading, spacing: 20) {
//                        // Book Title and Metadata
//                        VStack(alignment: .leading, spacing: 8) {
//                            Text(content.metadata.title)
//                                .font(.largeTitle)
//                                .fontWeight(.bold)
//                            Text(content.metadata.author)
//                                .font(.title2)
//                                .foregroundColor(.gray)
//                        }
//                        .padding(.horizontal)
//                        .padding(.vertical, 30)
//                        
//                        // Chapters Content
//                        ForEach(Array(content.chapters.enumerated()), id: \.1.filePath) { index, chapter in
//                            VStack(alignment: .leading, spacing: 16) {
//                                // Chapter Content
//                                WebView(htmlContent: chapter.content, baseURL: epubBaseURL)
//                                    .frame(maxWidth: .infinity)
//                            }
//                            
//                            // Chapter Separator
//                            if index < content.chapters.count - 1 {
//                                Divider()
//                                    .padding(.horizontal)
//                            }
//                        }
//                        
//                        // Bottom Padding
//                        Color.clear
//                            .frame(height: 60)
//                    }
//                }
//                .background(Color("BackgroundColor"))
//            }
//        }
//        .onAppear {
//            // Configure WKWebView globally
//            let webViewConfig = WKWebViewConfiguration()
//            webViewConfig.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
//            if let dataContainer = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
//                try? FileManager.default.createDirectory(at: dataContainer, withIntermediateDirectories: true)
//            }
//            
//            loadEPUB()
//        }
//    }
//    
//    private func loadEPUB() {
//        isLoading = true
//        
//        guard let epubPath = Bundle.main.path(forResource: book.filePath, ofType: nil) else {
//            errorMessage = "Could not find EPUB file in bundle"
//            isLoading = false
//            return
//        }
//        
//        DispatchQueue.global(qos: .userInitiated).async {
//            do {
//                let parser = EPUBParser()
//                let (content, baseURL) = try parser.parseEPUB(at: epubPath)
//                
//                // Verify image files exist
//                for (path, _) in content.images {
//                    let fullPath = baseURL.appendingPathComponent(path)
//                    if FileManager.default.fileExists(atPath: fullPath.path) {
//                        print("✅ Verified image exists:", fullPath.path)
//                    } else {
//                        print("❌ Image missing:", fullPath.path)
//                    }
//                }
//                
//                DispatchQueue.main.async {
//                    self.epubContent = content
//                    self.epubBaseURL = baseURL
//                    self.isLoading = false
//                }
//            } catch {
//                DispatchQueue.main.async {
//                    self.errorMessage = "Failed to load EPUB: \(error.localizedDescription)"
//                    self.isLoading = false
//                }
//            }
//        }
//    }
//}

#Preview {
    BookReaderView(book: Book(title: "Classroom of the Elite", coverImage: "COTECover", readingProgress: 0.1, filePath: "konosuba.epub"))
}
