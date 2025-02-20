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
    @State private var showThemes: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack (alignment: .bottom) {
            // Detect taps anywhere on the screen
            Color.clear
                .onTapGesture {
                    if showControls {
                        withAnimation {
                            showControls = false
                        }
                    }
                }
                .zIndex(0)
            
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
            
            ZStack(alignment: .bottom) {
                
                VStack() {
                    // Tap areas for top and bottom control bars
                    Rectangle()
                        .frame(maxWidth: .infinity, maxHeight: 125)
                        .ignoresSafeArea(.all)
                        .opacity(0.000001)
                        .onTapGesture {
                            withAnimation {
                                showControls.toggle()
                            }
                        }
                    
                    Spacer()
                    
                    Rectangle()
                        .frame(maxWidth: .infinity, maxHeight: 80)
                        .ignoresSafeArea(.all)
                        .opacity(0.000001)
                        .onTapGesture {
                            withAnimation {
                                showControls.toggle()
                            }
                        }
                }
                
                if showControls {
                    VStack {
                        // Top control bar
                        TopControlBar(title: book.title) {
                            dismiss()
                        }

                        Spacer()

                        // Bottom control bar
                        BottomControlBar(progress: $readingProgress, showThemes: $showThemes)
                    }
                    .transition(.opacity)
                }
                
            }
    
            // Theme panel overlay
            if showThemes {
                Group {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation {
                                showThemes.toggle()
                            }
                        }
                        .zIndex(1)
                    
                    Spacer()
                    
                    ThemePanel()
                        .shadow(radius: 10)
                        .transition(.move(edge: .bottom))
                        .zIndex(2)
                }
                
            
            }
            
        }
        .onAppear {
            loadEPUB()
        }
        .toolbar(.hidden)
        .ignoresSafeArea(edges: .bottom)
        
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
    BookReaderView(book: Book(title: "実力至上主義者の教室", coverImage: "COTECover", readingProgress: 0.1, filePath: "konosuba.epub"))
}
