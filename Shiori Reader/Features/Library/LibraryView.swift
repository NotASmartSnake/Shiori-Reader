import SwiftUI

enum ViewMode: String, CaseIterable {
    case grid = "grid"
    case list = "list"
}

enum SortOption: String, CaseIterable {
    case recent = "recent"
    case title = "title"
    case author = "author"
    
    var displayName: String {
        switch self {
        case .recent:
            return "Recent"
        case .title:
            return "Title"
        case .author:
            return "Author"
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject var isReadingBook: IsReadingBook
    @EnvironmentObject private var libraryManager: LibraryManager
    @State private var lastViewedBookPath: String? = nil
    @State private var showDocumentPicker = false
    @State private var importStatus: ImportStatus = .idle
    @State private var showImportStatusOverlay = false
    @State private var viewMode: ViewMode = ViewMode(rawValue: UserDefaults.standard.string(forKey: "libraryViewMode") ?? "grid") ?? .grid
    @State private var sortOption: SortOption = SortOption(rawValue: UserDefaults.standard.string(forKey: "librarySortOption") ?? "recent") ?? .recent

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
                                    lastViewedBookPath: $lastViewedBookPath,
                                    sortOption: sortOption
                                )
                            case .list:
                                BookList(
                                    isReadingBook: isReadingBook,
                                    lastViewedBookPath: $lastViewedBookPath,
                                    sortOption: sortOption
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
                            
                            Section("Sort by...") {
                                Button(action: {
                                    sortOption = .recent
                                    UserDefaults.standard.set(sortOption.rawValue, forKey: "librarySortOption")
                                }) {
                                    Label("Recent", systemImage: sortOption == .recent ? "checkmark" : "clock")
                                }
                                Button(action: {
                                    sortOption = .title
                                    UserDefaults.standard.set(sortOption.rawValue, forKey: "librarySortOption")
                                }) {
                                    Label("Title", systemImage: sortOption == .title ? "checkmark" : "textformat")
                                }
                                Button(action: {
                                    sortOption = .author
                                    UserDefaults.standard.set(sortOption.rawValue, forKey: "librarySortOption")
                                }) {
                                    Label("Author", systemImage: sortOption == .author ? "checkmark" : "person")
                                }
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
