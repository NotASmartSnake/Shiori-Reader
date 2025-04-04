//
//  ReaderView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/3/25.
//


import SwiftUI
import ReadiumShared // For Locator

struct ReaderView: View {
    @StateObject var viewModel: ReadiumBookViewModel
    @State private var showOverlay = true
    @State private var showSearchSheet = false
    @State private var showSettingsSheet = false
    @State private var showTocSheet = false
    @Environment(\.dismiss) var dismiss

    init(book: Book) {
        _viewModel = StateObject(wrappedValue: ReadiumBookViewModel(book: book))
    }

    var body: some View {
        ZStack {
            // Layer 1: Main Content (Loading/Error/Navigator)
            contentLayer

            // Layer 2: Transparent Tap Area for Toggling Overlay
            tapAreas
            
            // Layer 3: Overlay UI (only shown if showOverlay is true)
            if showOverlay {
                overlayControls
            }
        }
        .navigationTitle(viewModel.book.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(!showOverlay)
        .statusBarHidden(!showOverlay)
        .onAppear {
            if viewModel.publication == nil && !viewModel.isLoading {
                print("DEBUG [ReaderView]: onAppear - Triggering loadPublication")
                Task {
                    await viewModel.loadPublication()
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // --- View Components ---

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
                Button {
                    showSearchSheet = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .imageScale(.large)
                        .padding(8)
                }
                .foregroundStyle(.blue)
                .sheet(isPresented: $showSearchSheet) {
                    // Placeholder Search View
                    NavigationView { // Add NavigationView for title/bar
                        Text("Search View Placeholder")
                            .navigationTitle("Search")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") { showSearchSheet = false }
                                }
                            }
                    }
                }

                // Bookmark Button
                Button {
                    print("DEBUG: Bookmark button tapped")
                    // TODO: Implement bookmark logic -> viewModel.addBookmark(at: viewModel.currentLocation)
                } label: {
                    Image(systemName: "bookmark") // Use "bookmark.fill" if bookmarked?
                        .imageScale(.large)
                        .padding(8)
                }
                .foregroundStyle(.blue)

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
                    // Placeholder Settings View
                    NavigationView {
                         Text("Settings View Placeholder")
                            .navigationTitle("Reader Settings")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") { showSettingsSheet = false }
                                }
                            }
                    }
                    // Consider passing the viewModel or preferences editor here
                    // Example: ReaderSettingsView(editor: viewModel.editor(of: viewModel.preferences))
                }


                // TOC Button
                Button {
                    showTocSheet = true
                } label: {
                    Image(systemName: "list.bullet")
                        .imageScale(.large)
                        .padding(8)
                }
                .foregroundStyle(.blue)
                .sheet(isPresented: $showTocSheet) {
                    // Placeholder TOC View
                     NavigationView {
                         List {
                             ForEach(viewModel.tableOfContents, id: \.href) { link in
                                 Button(link.title ?? "Unknown Chapter") {
                                     print("Navigate to: \(link.title ?? link.href)")
                                     // Need a way to tell the navigator to go to this link
                                     // This might require calling a method on the viewModel
                                     // or interacting directly with the navigator instance
                                     // (which is tricky with UIViewControllerRepresentable)
                                     viewModel.navigateToLink(link) // Add this method to ViewModel
                                     showTocSheet = false // Dismiss sheet after selection
                                 }
                             }
                         }
                         .navigationTitle("Table of Contents")
                         .navigationBarTitleDisplayMode(.inline)
                         .toolbar {
                             ToolbarItem(placement: .confirmationAction) {
                                 Button("Done") { showTocSheet = false }
                             }
                         }
                     }
                }

            } // End of HStack
            .padding(.horizontal)
            .padding(.top, 4)

            Spacer()

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.combined(with: .move(edge: .top)))
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
}

// --- Preview ---
// Update your preview provider if needed
// #Preview {
//     // You'll need a way to provide a dummy Book for the preview
//     // and potentially mock EnvironmentObjects if your LibraryView relies on them heavily
//     NavigationView { // Add NavigationView for preview context
//          ReaderView(book: Book(title: "Preview Book", coverImage: "", readingProgress: 0.0, filePath: "dummy.epub"))
//              // .environmentObject(IsReadingBook()) // If needed
//              // .environmentObject(LibraryManager()) // If needed
//              // .environmentObject(SavedWordsManager()) // If needed
//     }
//}

#Preview {
    ReaderView(book: Book(
        title: "実力至上主義者の教室",
        coverImage: "COTECover",
        readingProgress: 0.1,
        filePath: "konosuba.epub"
    ))
}
