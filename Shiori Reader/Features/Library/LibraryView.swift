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
