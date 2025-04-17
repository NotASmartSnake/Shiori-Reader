//
//  ReaderView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/3/25.
//


import SwiftUI
import ReadiumShared
import ReadiumNavigator

struct ReaderView: View {
    @StateObject var viewModel: ReaderViewModel
    @StateObject private var settingsViewModel: ReaderSettingsViewModel
    @EnvironmentObject private var savedWordsManager: SavedWordsManager
    @EnvironmentObject private var isReadingBookState: IsReadingBook
    @State private var showOverlay = true
    @State private var showSearchSheet = false
    @State private var showSettingsSheet = false
    @State private var showContentsSheet = false
    @Environment(\.dismiss) var dismiss
    
    // Access the orientation manager
    private let orientationManager = OrientationManager.shared

    init(book: Book) {
        _viewModel = StateObject(wrappedValue: ReaderViewModel(book: book))
        _settingsViewModel = StateObject(wrappedValue: ReaderSettingsViewModel(bookId: book.id))
    }

    var body: some View {
        ZStack {
            // Contents sheet (TOC + Bookmarks)
            Color.clear.opacity(0)
                .sheet(isPresented: $showContentsSheet) {
                    TableOfContentsView(viewModel: viewModel)
                }
            contentLayer
            
            tapAreas
            
            if showOverlay {
                overlayControls
                
                progressIndicator(viewModel: viewModel, settingsViewModel: settingsViewModel)
            }
            
            Group {
                if viewModel.showDictionary {
                    dictionaryPopup
                }
            }
            .animation(.spring(duration: 0.3, bounce: 0.2), value: viewModel.showDictionary)
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarHidden(true)
        .statusBarHidden(!showOverlay)
        .onAppear {
            // Allow all orientations when reading
            orientationManager.unlockOrientation()
            // Set reading state
            isReadingBookState.setReading(true)
            
            if viewModel.publication == nil && !viewModel.isLoading {
                print("DEBUG [ReaderView]: onAppear - Triggering loadPublication")
                Task {
                    await viewModel.loadPublication()
                }
            }
            updateReaderPreferences()
        }
        .onDisappear {
            // Lock back to portrait when leaving
            orientationManager.lockPortrait()
            // Reset reading state
            isReadingBookState.setReading(false)
        }
        .onChange(of: settingsViewModel.preferences) { _, _ in
            updateReaderPreferences()
            if let navigator = viewModel.navigatorController {
                navigator.submitPreferences(viewModel.preferences)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // View components

    /// The main content area handling loading, errors, and the navigator.
    private var contentLayer: some View {
        Group {
            if let publication = viewModel.publication {
                EPUBNavigatorView(
                    viewModel: viewModel,
                    publication: publication,
                    initialLocation: viewModel.initialLocation
                )
                .ignoresSafeArea(edges: .top)

            } else if viewModel.isLoading {
                ProgressView("Loading Book...")

            } else if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)

            } else {
                // Initial state before loading
                Text("").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    /// The tap areas to toggle the overlay controls.
    private var tapAreas: some View {
        VStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showOverlay.toggle()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 100)
                .ignoresSafeArea(edges: .all)
            
            Spacer()
            
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showOverlay.toggle()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 75)
                .ignoresSafeArea(edges: .all)
        }
    }

    /// The overlay controls (buttons) that appear on top.
    private var overlayControls: some View {
        VStack {
            // Top Controls HStack
            HStack {
                // Back Button (Left)
                Button {
                    dismiss() // Use the environment dismiss action
                } label: {
                    Image(systemName: "chevron.backward")
                        .imageScale(.large)
                        .padding(8) // Add padding for easier tapping
                }
                .foregroundStyle(.blue) // Use primary accent color

                Spacer()

                // Right Buttons
                // Search Button
                searchButton()

                // Bookmark Button
                Button {
                    Task {
                        await viewModel.toggleBookmark()
                    }
                } label: {
                    Image(systemName: viewModel.isCurrentLocationBookmarked ? "bookmark.fill" : "bookmark")
                        .imageScale(.large)
                        .padding(8)
                }
                .foregroundStyle(.blue)
                .contextMenu {
                    Button {
                        showContentsSheet = true
                    } label: {
                        Label("View Bookmarks", systemImage: "bookmark.circle")
                    }
                }

                // Settings Button
                Button {
                    showSettingsSheet = true
                } label: {
                    Image(systemName: "gear")
                        .imageScale(.large)
                        .padding(8)
                }
                .foregroundStyle(.blue)
                .sheet(isPresented: $showSettingsSheet) {
                    ReaderSettingsView(
                        viewModel: settingsViewModel,
                        isPresented: $showSettingsSheet
                    )
                }


                // Contents Button (TOC + Bookmarks)
                Button {
                    showContentsSheet = true
                } label: {
                    Image(systemName: "list.bullet")
                        .imageScale(.large)
                        .padding(8)
                }
                .foregroundStyle(.blue)

            } // End of HStack
            .padding(.horizontal)
            .padding(.top, 4)

            Spacer()

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    struct progressIndicator: View {
        @StateObject var viewModel: ReaderViewModel
        @ObservedObject var settingsViewModel: ReaderSettingsViewModel
        
        var body: some View {
            VStack {
                Spacer()
                // Display progress information in the format "x% of chapter • x% of book"
                Text("\(Int(viewModel.currentChapterProgression * 100))% of chapter • \(Int(viewModel.totalBookProgression * 100))% of book")
                    .font(.caption)
                    .foregroundStyle(getTextColor())
                    .shadow(color: getContrastingShadowColor(), radius: 0.5, x: 0, y: 0.5)
                    .padding(.vertical,20)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
        }
        
        // Helper function to get the text color based on the current theme
        private func getTextColor() -> SwiftUI.Color {
            // Use the theme from settingsViewModel
            let theme = settingsViewModel.preferences.theme
            
            switch theme {
            case "dark":
                return SwiftUI.Color(UIColor(hex: "#FEFEFE") ?? .white)
            case "sepia": 
                return SwiftUI.Color(UIColor(hex: "#121212") ?? .black)
            case "light":
                return SwiftUI.Color(UIColor(hex: "#121212") ?? .black)
            case "custom":
                // For custom theme, use the text color directly
                return SwiftUI.Color(UIColor(hex: settingsViewModel.preferences.textColor) ?? .black)
            default:
                return .gray
            }
        }
        
        // Helper function to get a contrasting shadow color
        private func getContrastingShadowColor() -> SwiftUI.Color {
            // Use a shadow color that contrasts with the text color but is very transparent
            let theme = settingsViewModel.preferences.theme
            
            switch theme {
            case "dark":
                // For dark theme (white text), use a dark shadow
                return SwiftUI.Color.black.opacity(0.3)
            case "sepia", "light", "custom":
                // For light theme (dark text), use a light shadow
                return SwiftUI.Color.white.opacity(0.3)
            default:
                return SwiftUI.Color.gray.opacity(0.2)
            }
        }
    }
    
    private var dictionaryPopup: some View {
        VStack {
            Spacer()
            DictionaryPopupView(
                matches: viewModel.dictionaryMatches,
                onDismiss: {
                    withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                        viewModel.showDictionary = false
                    }
                },
                sentenceContext: viewModel.currentSentenceContext,
                bookTitle: viewModel.book.title
            )
            .environmentObject(savedWordsManager)
        }
        .transition(.move(edge: .bottom))
        .zIndex(2)
        .ignoresSafeArea(edges: .bottom)
    }


    /// A helper view to display errors.
    private func errorView(message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text("Error Loading Book")
                .font(.headline)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                Task { await viewModel.loadPublication() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    func searchButton() -> some View {
        Button(action: {
            showSearchSheet = true
        }) {
            Image(systemName: "magnifyingglass")
                .imageScale(.large)
                .padding(8)
        }
        .foregroundStyle(.blue)
        .sheet(isPresented: $showSearchSheet) {
            if let publication = viewModel.publication {
                ReaderSearchView(
                    viewModel: ReaderSearchViewModel(
                        publication: publication,
                        readiumViewModel: self.viewModel
                    ),
                    isShowing: $showSearchSheet
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    // Helper method to update reader preferences
    private func updateReaderPreferences() {
        viewModel.preferences = settingsViewModel.toReadiumPreferences()
        if let navigator = viewModel.navigatorController {
            Task { @MainActor in
                navigator.submitPreferences(viewModel.preferences)
            }
        }
    }
}

#Preview {
    ReaderView(book: Book(
        title: "実力至上主義者の教室",
        filePath: "3Days.epub", readingProgress: 0.1
    ))
    .environmentObject(SavedWordsManager())
    .environmentObject(IsReadingBook())
}
