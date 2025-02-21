//
//  BottomControlBar.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/18/25.
//

import SwiftUI

struct BottomControlBar: View {
    let book: Book
    @Binding var progress: Double
    @Binding var showThemes: Bool
    @Binding var showSearch: Bool
    @Binding var showTableOfContents: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Progress slider
            Slider(value: $progress, in: 0...1)
                .padding(.horizontal)
                .padding(.top, 8)
            
            // Control buttons
            HStack {
                // Left-aligned contents button
                Button(action: {
                    showTableOfContents.toggle() }
                ) {
                    Image(systemName: "list.bullet")
                        .imageScale(.large)
                }
                .padding(.leading)
                .sheet(isPresented: $showTableOfContents) {
                    TableOfContentsSheet(book: book, showTableOfContents: $showTableOfContents)
                }
                
                Spacer()
                
                // Right-aligned buttons
                HStack(spacing: 20) {
                    Button(action: {
                        showSearch.toggle()
                    }) {
                        Image(systemName: "magnifyingglass")
                            .imageScale(.large)
                    }
                    .sheet(isPresented: $showSearch) {
                        SearchSheet(showSearch: $showSearch)
                    }
                    
                    Button(action: {
                        withAnimation(.spring(duration: 0.25)) {
                            showThemes.toggle()
                        }
                    }) {
                        Image(systemName: "textformat.size")
                            .imageScale(.large)
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .imageScale(.large)
                    }
                }
                .padding(.trailing)
            }
            .padding(.vertical, 8)
                
        }
        .background(.ultraThinMaterial)
        .padding(.bottom, 30)
    }
}

#Preview {
    BookReaderView(book: Book(title: "ようこそ実力至上主義の教室へ (Additional Title Text)", coverImage: "COTECover", readingProgress: 0.1, filePath: "konosuba.epub"))
}
