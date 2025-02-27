//
//  BookReaderView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//

import SwiftUI
@preconcurrency import WebKit

struct BookReaderView: View {
    @State private var showControls: Bool = true
    @State private var readingProgress: Double = 0.0
    @State private var showThemes: Bool = false
    @State private var showSearch: Bool = false
    @State private var showTableofContents: Bool = false
    @StateObject private var viewModel: BookViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(book: Book) {
        _viewModel = StateObject(wrappedValue: BookViewModel(book: book))
    }
    
    var body: some View {
        
        ZStack {
            
            if viewModel.isLoading {
                ProgressView("Loading book...")
            } else if let error = viewModel.errorMessage {
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
            } else if let content = viewModel.state.epubContent {
                SingleWebView(viewModel: viewModel, content: content, baseURL: viewModel.state.epubBaseURL)
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
                        TopControlBar(title: viewModel.book.title) {
                            dismiss()
                        }
                        
                        Spacer()
                        
                        // Bottom control bar
                        BottomControlBar(viewModel: viewModel, progress: $readingProgress, showThemes: $showThemes, showSearch: $showSearch, showTableOfContents: $showTableofContents)
                    }
                    .transition(.opacity)
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
            
        }
        .task {
            await viewModel.loadEPUB()
        }
        .toolbar(.hidden)
        .ignoresSafeArea(edges: .bottom)
        
    }
}

#Preview {
    BookReaderView(book: Book(
        title: "実力至上主義者の教室",
        coverImage: "COTECover",
        readingProgress: 0.1,
        filePath: "honzuki.epub"
    ))
}
