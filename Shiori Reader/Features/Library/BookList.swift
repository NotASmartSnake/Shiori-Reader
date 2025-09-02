import SwiftUI

struct BookList: View {
    @ObservedObject var isReadingBook: IsReadingBook
    @Binding var lastViewedBookPath: String?
    @EnvironmentObject private var libraryManager: LibraryManager
    
    private var books: [Book] {
        libraryManager.books
    }
    
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(books) { book in
                BookListRow(book: book, isReadingBook: isReadingBook, lastViewedBookPath: $lastViewedBookPath)
                
                if book.id != books.last?.id {
                    Divider()
                        .background(Color.gray.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, 30)
    }
}

struct BookListRow: View {
    let book: Book
    @ObservedObject var isReadingBook: IsReadingBook
    @Binding var lastViewedBookPath: String?
    @State private var showingRenameDialog = false
    @State private var newTitle = ""
    @State private var showingDeleteConfirmation = false
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var savedWordsManager: SavedWordsManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Book cover on the left (small)
            NavigationLink(destination:
                ReaderView(book: book)
                .environmentObject(savedWordsManager)
                .onAppear {
                    isReadingBook.setReading(true)
                    lastViewedBookPath = book.filePath
                }
                .onDisappear {
                    isReadingBook.setReading(false)
                }
            ) {
                BookCoverImage(book: book)
                    .frame(width: 60, height: 90)
            }
            .buttonStyle(.plain)
            
            // Book information - vertically centered
            VStack(alignment: .leading, spacing: 2) {
                // Title in bold
                Text(book.title)
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Author in grey (if available)
                if let author = book.author, !author.isEmpty {
                    Text(author)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                // Reading progress in grey
                Text(String(format: "%d%%", Int(book.readingProgress * 100)))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Three dots menu at bottom right
            VStack {
                Spacer()
                
                Menu {
                    Button(action: {
                        showingRenameDialog = true
                        newTitle = book.title
                    }) {
                        Label("Rename", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: {
                        showingDeleteConfirmation = true
                    }) {
                        Label("Remove", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.gray)
                        .padding(8)
                }
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .alert("Rename Book", isPresented: $showingRenameDialog) {
            TextField("Title", text: $newTitle)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if !newTitle.isEmpty {
                    libraryManager.renameBook(book, newTitle: newTitle)
                }
            }
        }
        .confirmationDialog(
            "Remove Book",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                libraryManager.removeBook(book)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to remove '\(book.title)'? This action cannot be undone.")
        }
    }
}
