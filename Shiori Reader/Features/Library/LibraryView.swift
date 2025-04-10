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
    @State private var showImportAlert = false
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundColor").ignoresSafeArea(edges: .all)
                
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    addImportButton()
                }
            }
            .toolbarBackground(Color.black, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .navigationTitle("Library")
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
    
    func addImportButton() -> some View {
            Button(action: {
                showDocumentPicker = true
            }) {
                Image(systemName: "plus")
                    .imageScale(.large)
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentImporter(status: $importStatus) { newBook in
                    // Add the book to the library manager
                    libraryManager.addBook(newBook)
                    
                    // Reset status
                    importStatus = .idle
                }
            }
            .alert(isPresented: $showImportAlert) {
                Alert(
                    title: Text("Import Book"),
                    message: Text(importStatus.message),
                    dismissButton: .default(Text("OK")) {
                        if !importStatus.isSuccess {
                            importStatus = .idle
                        }
                    }
                )
            }
        }
}


#Preview {
    LibraryView()
        .environmentObject(IsReadingBook())
        .environmentObject(LibraryManager())
        .environmentObject(SavedWordsManager())
}
