import SwiftUI

enum ViewMode: String, CaseIterable {
    case grid = "grid"
    case list = "list"
}

struct LibraryView: View {
    @EnvironmentObject var isReadingBook: IsReadingBook
    @EnvironmentObject private var libraryManager: LibraryManager
    @State private var lastViewedBookPath: String? = nil
    @State private var showDocumentPicker = false
    @State private var importStatus: ImportStatus = .idle
    @State private var showImportStatusOverlay = false
    @State private var viewMode: ViewMode = ViewMode(rawValue: UserDefaults.standard.string(forKey: "libraryViewMode") ?? "grid") ?? .grid

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
                            switch viewMode {
                            case .grid:
                                BookGrid(
                                    isReadingBook: isReadingBook,
                                    lastViewedBookPath: $lastViewedBookPath
                                )
                            case .list:
                                BookList(
                                    isReadingBook: isReadingBook,
                                    lastViewedBookPath: $lastViewedBookPath
                                )
                            }
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
                    HStack(spacing: 16) {
                        Menu {
                            Button(action: { 
                                viewMode = .grid
                                UserDefaults.standard.set(viewMode.rawValue, forKey: "libraryViewMode")
                            }) {
                                Label("Grid View", systemImage: viewMode == .grid ? "checkmark" : "square.grid.3x3")
                            }
                            Button(action: { 
                                viewMode = .list
                                UserDefaults.standard.set(viewMode.rawValue, forKey: "libraryViewMode")
                            }) {
                                Label("List View", systemImage: viewMode == .list ? "checkmark" : "list.bullet")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .imageScale(.large)
                        }
                        
                        Button(action: { showDocumentPicker = true }) {
                            Image(systemName: "plus").imageScale(.large)
                        }
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
                // Refresh the specific book that was being read
                if let bookPath = lastViewedBookPath,
                   let book = libraryManager.books.first(where: { $0.filePath == bookPath }) {
                    libraryManager.refreshBook(withId: book.id)
                }
                lastViewedBookPath = nil
            }
        }
    }
}
