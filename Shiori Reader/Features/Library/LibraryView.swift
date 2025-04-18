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

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundColor").ignoresSafeArea(edges: .all)

                if libraryManager.books.isEmpty {
                    ScrollView {
                        EmptyLibraryView(showDocumentPicker: $showDocumentPicker)
                            .padding(.horizontal)
                            .padding(.vertical, 50)
                    }
                } else {
                    ScrollView {
                        VStack {
                            BookGrid(
                                books: libraryManager.books,
                                isReadingBook: isReadingBook,
                                lastViewedBookPath: $lastViewedBookPath
                            )
                            Spacer(minLength: 60)
                        }
                    }
                }

                if showImportStatusOverlay {
                    ImportStatusOverlay(status: importStatus, isPresented: $showImportStatusOverlay)
                        .transition(.opacity)
                        .animation(.easeInOut, value: showImportStatusOverlay)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showDocumentPicker = true }) {
                        Image(systemName: "plus").imageScale(.large)
                    }
                }
            }
            .toolbarBackground(Color.black, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .navigationTitle("Library")
            .sheet(isPresented: $showDocumentPicker, onDismiss: {
                if case .importing = importStatus { importStatus = .cancelled }
            }) {
                DocumentImporter(status: $importStatus) { newBook in
                    libraryManager.addBook(newBook)
                    if importStatus.isSuccess { importStatus = .idle }
                }
            }
            .onChange(of: importStatus) { _, newValue in
                if case .failure = newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showImportStatusOverlay = true
                    }
                }
            }
        }
//        .onAppear { libraryManager.loadLibrary() }
        .onChange(of: isReadingBook.isReading) { _, isReading in
            if !isReading && lastViewedBookPath != nil {
                libraryManager.loadLibrary()
            }
        }
    }
}

// Enhanced preview with a rich collection of books
#Preview {
    let manager = LibraryManager()
    // Add books directly to the manager
    manager.books = [
        // Original sample books with more complete information
        Book(id: UUID(), title: "Classroom of the Elite Vol. 1", author: "Syougo Kinugasa", filePath: "dummy1.epub", coverImagePath: "COTECover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.25, currentLocatorData: nil),
        Book(id: UUID(), title: "My Teen Romantic Comedy SNAFU Vol. 14", author: "Wataru Watari", filePath: "dummy2.epub", coverImagePath: "OregairuCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.90, currentLocatorData: nil),
        Book(id: UUID(), title: "Overlord Vol. 1", author: "Kugane Maruyama", filePath: "dummy6.epub", coverImagePath: "OverlordCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.70, currentLocatorData: nil),
        Book(id: UUID(), title: "Mushoku Tensei Vol. 7", author: "Rifujin na Magonote", filePath: "dummy7.epub", coverImagePath: "MushokuCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.42, currentLocatorData: nil),
        
        // Additional books using your assets
        Book(id: UUID(), title: "Re:Zero Vol. 3", author: "Tappei Nagatsuki", filePath: "dummy8.epub", coverImagePath: "ReZeroCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.15, currentLocatorData: nil),
        Book(id: UUID(), title: "Konosuba Vol. 2", author: "Natsume Akatsuki", filePath: "dummy9.epub", coverImagePath: "KonosubaCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.67, currentLocatorData: nil),
        Book(id: UUID(), title: "No Game No Life Vol. 1", author: "Yuu Kamiya", filePath: "dummy10.epub", coverImagePath: "NoGameCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.33, currentLocatorData: nil),
        Book(id: UUID(), title: "86 -Eighty Six- Vol. 4", author: "Asato Asato", filePath: "dummy11.epub", coverImagePath: "86Cover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.55, currentLocatorData: nil),
        Book(id: UUID(), title: "DanMachi Vol. 12", author: "Fujino Omori", filePath: "dummy12.epub", coverImagePath: "DanmachiCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.81, currentLocatorData: nil),
        Book(id: UUID(), title: "The Empty Box and Zeroth Maria Vol. 1", author: "Eiji Mikage", filePath: "dummy13.epub", coverImagePath: "HakomariCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.05, currentLocatorData: nil),
        Book(id: UUID(), title: "That Time I Got Reincarnated as a Slime Vol. 3", author: "Fuse", filePath: "dummy14.epub", coverImagePath: "SlimeCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.47, currentLocatorData: nil),
        Book(id: UUID(), title: "3 Days of Happiness", author: "Sugaru Miaki", filePath: "dummy15.epub", coverImagePath: "3DaysCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.99, currentLocatorData: nil),
        Book(id: UUID(), title: "I Want to Eat Your Pancreas", author: "Yoru Sumino", filePath: "dummy16.epub", coverImagePath: "DeathCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.22, currentLocatorData: nil),
        Book(id: UUID(), title: "I Had That Same Dream Again", author: "Yoru Sumino", filePath: "dummy17.epub", coverImagePath: "LoveCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.13, currentLocatorData: nil),
        Book(id: UUID(), title: "Alchemist Who Survived Now Dreams of a Quiet City Life", author: "Usata Nonohara", filePath: "dummy18.epub", coverImagePath: "AOABCover", isLocalCover: false, addedDate: Date(), lastOpenedDate: Date(), readingProgress: 0.78, currentLocatorData: nil)
    ]
    
    return LibraryView()
        .environmentObject(IsReadingBook())
        .environmentObject(manager)
        .environmentObject(SavedWordsManager())
}
