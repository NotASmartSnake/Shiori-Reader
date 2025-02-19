//
//  BottomControlBar.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/18/25.
//

import SwiftUI

struct BottomControlBar: View {
    @Binding var progress: Double
    @State private var showingContents = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress slider
            Slider(value: $progress, in: 0...1)
                .padding(.horizontal)
                .padding(.top, 8)
            
            // Control buttons
            HStack {
                // Left-aligned contents button
                Button(action: { showingContents.toggle() }) {
                    Image(systemName: "list.bullet")
                        .imageScale(.large)
                }
                .padding(.leading)
                
                Spacer()
                
                // Right-aligned buttons
                HStack(spacing: 20) {
                    Button(action: {}) {
                        Image(systemName: "magnifyingglass")
                            .imageScale(.large)
                    }
                    
                    Button(action: {}) {
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
    }
}

#Preview {
    BookReaderView(book: Book(title: "Classroom of the Elite", coverImage: "COTECover", readingProgress: 0.1, filePath: "konosuba.epub"))
}
