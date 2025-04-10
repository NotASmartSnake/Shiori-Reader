//
//  TableOfContentsView.swift
//  Shiori Reader
//
//  Created by Claude on 4/10/25.
//

import SwiftUI
import ReadiumShared

struct TableOfContentsView: View {
    @ObservedObject var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: String = "toc"
    
    var body: some View {
        NavigationView {
            VStack {
                // Segmented control to switch between TOC and Bookmarks
                Picker("Content", selection: $selectedTab) {
                    Text("Contents").tag("toc")
                    Text("Bookmarks").tag("bookmarks")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Contents based on selected tab
                if selectedTab == "toc" {
                    tocContent
                } else {
                    bookmarksContent
                }
            }
            .navigationTitle(selectedTab == "toc" ? "Table of Contents" : "Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    // Table of Contents content
    private var tocContent: some View {
        List {
            if viewModel.tableOfContents.isEmpty {
                Text("No table of contents available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.tableOfContents, id: \.href) { link in
                    Button(link.title ?? "Unknown Chapter") {
                        viewModel.navigateToLink(link)
                        dismiss()
                    }
                }
            }
        }
    }
    
    // Bookmarks content
    private var bookmarksContent: some View {
        List {
            if viewModel.bookmarks.isEmpty {
                Text("No bookmarks yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.bookmarks) { bookmark in
                    EnhancedBookmarkRow(bookmark: bookmark)
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
        .refreshable {
            await viewModel.refreshBookmarks()
        }
    }
}

// Enhanced bookmark row that shows more context
struct EnhancedBookmarkRow: View {
    let bookmark: Bookmark
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Chapter title
            Text(bookmark.locator.title ?? "Untitled")
                .font(.headline)
                .lineLimit(1)
            
            // Progress information
            HStack(spacing: 8) {
                // Show date
                Text(bookmark.created, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Show progression if available
                if let progression = bookmark.locator.locations.progression {
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(progression * 100))% of chapter")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Show total progression if available
                if let totalProgression = bookmark.locator.locations.totalProgression {
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(totalProgression * 100))% of book")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    let viewModel = ReaderViewModel(book: Book(
        title: "Test Book",
        filePath: "test.epub",
        readingProgress: 0.5
    ))
    
    return TableOfContentsView(viewModel: viewModel)
}
