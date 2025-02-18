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
    @State private var currentChapterIndex: Int = 0
    @State private var showTableOfContents: Bool = true
    @State private var epubBaseURL: URL?
    @State private var isLoading: Bool = true
    
    var body: some View {
        VStack {
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
                bookContent(content)
            }
        }
        .onAppear {
            // Configure WKWebView globally
            let webViewConfig = WKWebViewConfiguration()
            webViewConfig.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
            if let dataContainer = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                try? FileManager.default.createDirectory(at: dataContainer, withIntermediateDirectories: true)
            }
            
            loadEPUB()
        }
    }
    
    private func bookContent(_ content: EPUBContent) -> some View {
        VStack {
            if showTableOfContents {
                tableOfContents(content)
            } else {
                chapterView(content)
            }
        }
    }
    
    private func tableOfContents(_ content: EPUBContent) -> some View {
        VStack {
            // Header
            HStack {
                Text("Table of Contents")
                    .font(.headline)
                Spacer()
                Button("Start Reading") {
                    withAnimation {
                        showTableOfContents = false
                    }
                }
            }
            .padding()
            
            // Chapter List
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(content.chapters.indices, id: \.self) { index in
                        let chapter = content.chapters[index]
                        Button(action: {
                            currentChapterIndex = index
                            withAnimation {
                                showTableOfContents = false
                            }
                        }) {
                            HStack {
                                Text(chapter.filePath)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .padding(.bottom)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
    }
    
    private func chapterView(_ content: EPUBContent) -> some View {
        VStack {
            // Navigation Header
            HStack {
                Button(action: {
                    withAnimation {
                        showTableOfContents = true
                    }
                }) {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text("Contents")
                    }
                }
                
                Spacer()
                
                // Chapter Navigation
                HStack(spacing: 20) {
                    Button(action: previousChapter) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(currentChapterIndex <= 0)
                    
                    Button(action: nextChapter) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(currentChapterIndex >= content.chapters.count - 1)
                }
            }
            .padding()
            
            if content.chapters.indices.contains(currentChapterIndex) {
                let chapter = content.chapters[currentChapterIndex]
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Chapter Title
                        if !chapter.title.isEmpty {
                            Text(chapter.filePath)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(.gray)
                                .padding(.bottom)
                        }
                        
                        // Chapter Content
                        WebView(htmlContent: chapter.content, baseURL: epubBaseURL)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 500)
                    }
                    .padding()
                }
            }
        }
    }
    
    private func nextChapter() {
        guard let content = epubContent else { return }
        if currentChapterIndex < content.chapters.count - 1 {
            withAnimation {
                currentChapterIndex += 1
            }
        }
    }
    
    private func previousChapter() {
        if currentChapterIndex > 0 {
            withAnimation {
                currentChapterIndex -= 1
            }
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
                
                // Verify image files exist
                for (path, _) in content.images {
                    let fullPath = baseURL.appendingPathComponent(path)
                    if FileManager.default.fileExists(atPath: fullPath.path) {
                        print("✅ Verified image exists:", fullPath.path)
                    } else {
                        print("❌ Image missing:", fullPath.path)
                    }
                }
                
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

#Preview {
    BookReaderView(book: Book(title: "Classroom of the Elite", coverImage: "COTECover", readingProgress: 0.1, filePath: "konosuba.epub"))
}
