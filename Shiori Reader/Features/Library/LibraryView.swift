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
    
    let initialBooks: [Book] = [
        Book(title: "COTE", coverImage: "COTECover", readingProgress: 0.4, filePath: "cote.epub"),
        Book(title: "3 Days", coverImage: "3DaysCover", readingProgress: 0.56, filePath: "3Days.epub"),
        Book(title: "Honzuki", coverImage: "AOABCover", readingProgress: 0.3, filePath: "honzuki.epub"),
//        Book(title: "Konosuba", coverImage: "KonosubaCover", readingProgress: 0.7, filePath: "konosuba.epub"),
//        Book(title: "Hakomari", coverImage: "HakomariCover", readingProgress: 0.6, filePath: "hakomari.epub"),
//        Book(title: "Danmachi", coverImage: "DanmachiCover", readingProgress: 0.1, filePath: "cote.epub"),
//        Book(title: "86", coverImage: "86Cover", readingProgress: 0.2, filePath: ""),
//        Book(title: "Love", coverImage: "LoveCover", readingProgress: 0.8, filePath: ""),
//        Book(title: "Mushoku", coverImage: "MushokuCover", readingProgress: 0.9, filePath: ""),
//        Book(title: "Oregairu", coverImage: "OregairuCover", readingProgress: 1.0, filePath: ""),
//        Book(title: "ReZero", coverImage: "ReZeroCover", readingProgress: 0.0, filePath: ""),
//        Book(title: "Slime", coverImage: "SlimeCover", readingProgress: 0.0, filePath: ""),
//        Book(title: "Overlord", coverImage: "OverlordCover", readingProgress: 0.0, filePath: ""),
//        Book(title: "Death", coverImage: "DeathCover", readingProgress: 0.0, filePath: ""),
//        Book(title: "No Game No Life", coverImage: "NoGameCover", readingProgress: 0.0, filePath: "")
    ]
    
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
                // We just returned from reading a book
                libraryManager.loadReadingProgress()
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
}
