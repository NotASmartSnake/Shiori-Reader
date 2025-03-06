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
    @EnvironmentObject var isReadingBook: IsReadingBook
    
    init(book: Book) {
        _viewModel = StateObject(wrappedValue: BookViewModel(book: book))
        _readingProgress = State(initialValue: book.readingProgress)
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
                                // Reset auto-save timer when user interacts
                                viewModel.resetAutoSave()
                            }
                            .onEnded { _ in
                                // Start auto-save timer when user finishes interaction
                                viewModel.autoSaveProgress()
                            }
                    )
                    // Add a tap gesture to detect user interactions
                    .onTapGesture {
                        // This tap will toggle controls but also serves to detect user interaction
                        withAnimation {
                            showControls.toggle()
                        }
                        // Reset auto-save timer when user interacts
                        viewModel.resetAutoSave()
                        // Start auto-save timer when user finishes interaction
                        viewModel.autoSaveProgress()
                    }
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
                        TopControlBar(
                            title: viewModel.book.title,
                            onBack: {
                                let readingState = self.isReadingBook
                                readingState.setReading(false)
                                // Save progress before dismissing
                                Task {
                                    await viewModel.saveCurrentProgress()
                                    dismiss()
                                }
                            },
                            viewModel: viewModel
                        )
                        
                        Spacer()
                        
                        // Bottom control bar
                        BottomControlBar(
                            viewModel: viewModel,
                            progress: $readingProgress,
                            showThemes: $showThemes,
                            showSearch: $showSearch,
                            showTableOfContents: $showTableofContents)
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
                                viewModel.resetAutoSave()
                                viewModel.autoSaveProgress()
                            }
                            .zIndex(1)
                        
                        Spacer()
                        
                        ThemePanel(viewModel: viewModel)
                            .shadow(radius: 10)
                            .transition(.move(edge: .bottom))
                            .zIndex(2)
                    }
                }
            

            }
            
        }
        .task {
            await viewModel.loadEPUB()
            await viewModel.loadProgress()
            viewModel.loadFontPreferences()
            if !viewModel.isCurrentPositionSaved {
                viewModel.autoSaveProgress()
            }
        }
        .toolbar(.hidden)
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: readingProgress) { oldValue, newValue in
            if abs(oldValue - newValue) > 0.01 {
                Task {
                    await viewModel.updateProgressAndAutoSave(newValue)
                }
            }
        }
        .onChange(of: viewModel.book.readingProgress) { _, newValue in
            readingProgress = newValue
        }
        // Save progress when view disappears
        .onAppear {
            print("DEBUG: BookReaderView appeared")
            viewModel.loadFontPreferences()
            
            Task {
                print("DEBUG: Loading book and progress")
                await viewModel.loadEPUB()
                await viewModel.loadProgress()
                print("DEBUG: Starting auto-save timer")
                viewModel.autoSaveProgress()
            }
        }
        .onDisappear {
            Task {
                // If user is closing the book, we want to ensure we're returning to the
                // last explicitly saved position, not the current scroll position
                if viewModel.isCurrentPositionSaved {
                    print("DEBUG: Book closed with saved position - no need for final save")
                } else {
                    print("DEBUG: Book closed with unsaved changes - saving last auto-saved position only")
                    // Don't save current position, but ensure auto-save work is cancelled
                    viewModel.resetAutoSave()
                }
            }
        }
        
    }
}

#Preview {
    let isReadingBook = IsReadingBook()
    return BookReaderView(book: Book(
        title: "実力至上主義者の教室",
        coverImage: "COTECover",
        readingProgress: 0.1,
        filePath: "honzuki.epub"
    ))
    .environmentObject(isReadingBook)
}
