//
//  TopControlBar.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/18/25.
//

import SwiftUI

struct TopControlBar: View {
    let title: String
    let onBack: () -> Void
    @ObservedObject var viewModel: BookViewModel
    
    var body: some View {
        ZStack {
            // Background blur
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            // Content
            VStack {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .imageScale(.large)
                    }
                    .padding(.leading)
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            await viewModel.toggleBookmark()
                        }
                    }) {
                        Image(systemName: viewModel.state.isBookmarked ? "bookmark.fill" : "bookmark")
                            .imageScale(.large)
                    }
                    .padding(.trailing)
                }
                .padding(.top, 30)
                
                HStack {
                    Spacer()
                    
                    Text(title)
                        .font(.subheadline)
                    
                    Spacer()
                }
                .padding(.bottom, 15)
            }
            
        }
        .frame(height: 30)
    }
}

#Preview {
    BookReaderView(book: Book(title: "Classroom of the Elite", coverImage: "COTECover", readingProgress: 0.1, filePath: "konosuba.epub"))
}
