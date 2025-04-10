// 
// BookmarkView.swift
// Shiori Reader
//
// Created by Russell Graviet on 4/10/25.
//

import SwiftUI
import ReadiumShared

struct BookmarkView: View {
    @ObservedObject var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.bookmarks.isEmpty {
                    Text("No bookmarks yet")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(viewModel.bookmarks) { bookmark in
                        BookmarkRow(bookmark: bookmark)
                            .onTapGesture {
                                viewModel.navigateToBookmark(bookmark)
                                dismiss()
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.removeBookmark(bookmark)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .refreshable {
                await viewModel.refreshBookmarks()
            }
        }
    }
}

struct BookmarkRow: View {
    let bookmark: Bookmark
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Display title from the locator if available
            Text(bookmark.locator.title ?? "Untitled")
                .font(.headline)
                .lineLimit(1)
            
            // Show creation date
            Text(bookmark.created, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let viewModel = ReaderViewModel(book: Book(
        title: "Test Book",
        filePath: "test.epub",
        readingProgress: 0.5
    ))
    
    return BookmarkView(viewModel: viewModel)
}
