//
//  BookCell.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/29/25.
//

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
                    print("DEBUG: Book appeared, set lastViewedBookPath = \(book.filePath)")
                }
                .onDisappear {
                    isReadingBook.setReading(false)
                    print("DEBUG: Book disappeared")
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

            HStack {
                // Progress indicator with integer percentage (matching ReaderView)
                Text(String(format: "%d%%", Int(book.readingProgress * 100)))
                    .font(deviceType == .iPad ? .caption2 : .caption) // Smaller font on iPad
                    .foregroundStyle(.gray)
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

// Add a preview for BookCell
#Preview("BookCell Preview") {
    // Create necessary environment for preview
    // Must provide LibraryManager and SavedWordsManager as environment objects
    let isReadingBook = IsReadingBook()
    let libraryManager = LibraryManager()
    let savedWordsManager = SavedWordsManager()
    
    // Sample book
    let sampleBook = Book(
        id: UUID(), 
        title: "Classroom of the Elite Vol. 1", 
        author: "Syougo Kinugasa", 
        filePath: "dummy1.epub", 
        coverImagePath: "COTECover", 
        isLocalCover: false, 
        addedDate: Date(), 
        lastOpenedDate: Date(), 
        readingProgress: 0.25, 
        currentLocatorData: nil
    )
    
    // Use a StateObject wrapper to provide the binding
    struct PreviewWrapper: View {
        @State var lastViewedBookPath: String? = nil
        let book: Book
        let isReadingBook: IsReadingBook
        
        var body: some View {
            BookCell(book: book, isReadingBook: isReadingBook, lastViewedBookPath: $lastViewedBookPath)
        }
    }
    
    return PreviewWrapper(book: sampleBook, isReadingBook: isReadingBook)
        .environmentObject(libraryManager)
        .environmentObject(savedWordsManager)
}
