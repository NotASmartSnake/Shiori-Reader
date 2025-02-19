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
    @State private var showControls: Bool = true
    @State private var readingProgress: Double = 0.0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
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
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { _ in
                                // Hide controls when scrolling
                                if showControls {
                                    withAnimation {
                                        showControls = false
                                    }
                                }
                            }
                    )
            }
            
            if showControls {
                VStack {
                    // Top control bar
                    TopControlBar(title: book.title) {
                        dismiss()
                    }

                    Spacer()

                    // Bottom control bar
                    BottomControlBar(progress: $readingProgress)
                }
                .transition(.opacity)
            }
            
        }
        .onAppear {
            loadEPUB()
        }
        .toolbar(.hidden)
        
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

#Preview {
    BookReaderView(book: Book(title: "Classroom of the Elite", coverImage: "COTECover", readingProgress: 0.1, filePath: "konosuba.epub"))
}
