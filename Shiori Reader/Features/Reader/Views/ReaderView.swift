//
//  ReaderView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/3/25.
//


import SwiftUI
import ReadiumShared // For Locator

struct ReaderView: View {
    @StateObject var viewModel: ReadiumBookViewModel // Use StateObject if this view owns the VM

    init(book: Book) {
        _viewModel = StateObject(wrappedValue: ReadiumBookViewModel(book: book))
    }

    var body: some View {
        ZStack { // Use ZStack to overlay loading/error states
            if let publication = viewModel.publication {
                // Publication loaded, show the navigator
                EPUBNavigatorView(
                    viewModel: viewModel,
                    publication: publication,
                    initialLocation: viewModel.initialLocation // Pass initial location from VM
                )
                .ignoresSafeArea() // Often want the reader content edge-to-edge

            } else if viewModel.isLoading {
                // Show loading indicator
                ProgressView("Loading Book...")

            } else if let errorMessage = viewModel.errorMessage {
                // Show error message
                VStack {
                    Text("Error Loading Book")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.caption)
                        .padding()
                    Button("Retry") {
                        Task { await viewModel.loadPublication() }
                    }
                }
            } else {
                // Initial state before loading starts (or if loading is skipped)
                Text("Book details loaded. Ready to open.")
                // Maybe add a button to explicitly trigger loadPublication if not using onAppear
            }
        }
        .navigationTitle(viewModel.book.title) // Set title from the book
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Start loading the publication when the view appears
            if viewModel.publication == nil && !viewModel.isLoading {
                 print("DEBUG [ReaderView]: onAppear - Triggering loadPublication")
                Task {
                    await viewModel.loadPublication()
                }
            }
        }
        // Add Toolbar items later for settings, TOC, etc.
        // .toolbar { ... }
    }
}

#Preview {
    ReaderView(book: Book(
        title: "実力至上主義者の教室",
        coverImage: "COTECover",
        readingProgress: 0.1,
        filePath: "hakomari.epub"
    ))
}
