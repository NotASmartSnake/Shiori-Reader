import SwiftUI

struct BookCell: View {
    // Access the device type using the UIDevice extension
    private var deviceType: UIDevice.DeviceType {
        return UIDevice.current.deviceType
    }
    let book: Book
    @ObservedObject var isReadingBook: IsReadingBook
    @Binding var lastViewedBookPath: String?
    @State private var showingRenameDialog = false
    @State private var newTitle = ""
    @State private var showingDeleteConfirmation = false
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var savedWordsManager: SavedWordsManager
    
    var body: some View {
        VStack(spacing: 2) { // Reduced spacing between elements
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
                VStack {
                    Spacer()
                    BookCoverImage(book: book)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .layoutPriority(1)
            .contextMenu {
                Button(action: {
                    print("BookCell: Opening rename dialog from context menu for book '\(book.title)'")
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
            }

            HStack {
                // Progress indicator with integer percentage (matching ReaderView)
                Text(String(format: "%d%%", Int(book.readingProgress * 100)))
                    .font(deviceType == .iPad ? .caption2 : .caption) // Smaller font on iPad
                    .foregroundStyle(.gray)
                Spacer()
                
                Menu {
                    Button(action: {
                        print("BookCell: Opening rename dialog for book '\(book.title)'")
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
                        .padding(deviceType == .iPad ? 6 : 8) // Smaller padding on iPad
                }
            }
            .padding(.horizontal, 6)
        }
        .alert("Rename Book", isPresented: $showingRenameDialog) {
            TextField("Title", text: $newTitle)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if !newTitle.isEmpty {
                    print("BookCell: Saving new title '\(newTitle)' for book '\(book.title)'")
                    libraryManager.renameBook(book, newTitle: newTitle)
                } else {
                    print("BookCell: New title is empty, not saving")
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
