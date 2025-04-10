//
//  LibraryView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//

import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var isReadingBook: IsReadingBook
    @EnvironmentObject private var libraryManager: LibraryManager
    @State private var lastViewedBookPath: String? = nil
    @State private var showDocumentPicker = false
    @State private var importStatus: ImportStatus = .idle
    @State private var showImportStatusOverlay = false
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundColor").ignoresSafeArea(edges: .all)
                
                if libraryManager.books.isEmpty {
                    ScrollView {
                        // Show empty state when no books are available
                        EmptyLibraryView(showDocumentPicker: $showDocumentPicker)
                    }
                } else {
                    ScrollView {
                        VStack {
                            // Extract grid to separate view
                            BookGrid(books: libraryManager.books, isReadingBook: isReadingBook, lastViewedBookPath: $lastViewedBookPath)
                            
                            Rectangle()
                                .frame(width: 0, height: 60)
                                .foregroundStyle(.clear)
                        }
                    }
                }
                
                // Import status overlay
                if showImportStatusOverlay {
                    ImportStatusOverlay(status: importStatus, isPresented: $showImportStatusOverlay)
                        .transition(.opacity)
                        .animation(.easeInOut, value: showImportStatusOverlay)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showDocumentPicker = true
                    }) {
                        Image(systemName: "plus")
                            .imageScale(.large)
                    }
                }
            }
            .toolbarBackground(Color.black, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .navigationTitle("Library")
            .sheet(isPresented: $showDocumentPicker, onDismiss: {
                if case .importing = importStatus {
                    importStatus = .cancelled
                }
            }) {
                DocumentImporter(status: $importStatus) { newBook in
                    libraryManager.addBook(newBook)
                    
                    if importStatus.isSuccess {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showImportStatusOverlay = false
                            importStatus = .idle
                        }
                    }
                }
            }
            .onChange(of: importStatus) { _, newValue in
                if newValue != .idle {
                    // Delay showing the overlay slightly for smoother UX
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        // Only show if we're still not idle (user didn't cancel super fast)
                        if importStatus != .idle {
                            showImportStatusOverlay = true
                        }
                    }
                }
            }
        }
        .onAppear {
            libraryManager.loadLibrary()
        }
        .onChange(of: isReadingBook.isReading) { _, isReading in
            if !isReading && lastViewedBookPath != nil {
                // We just returned from reading a book, refresh library
                libraryManager.loadLibrary()
            }
        }
    }
}


#Preview {
    LibraryView()
        .environmentObject(IsReadingBook())
        .environmentObject(LibraryManager())
        .environmentObject(SavedWordsManager())
}
