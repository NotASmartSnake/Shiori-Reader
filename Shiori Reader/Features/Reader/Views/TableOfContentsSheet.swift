//
//  TableOfContentsSheet.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/20/25.
//

import SwiftUI

struct TableOfContentsSheet: View {
    @ObservedObject var viewModel: BookViewModel
    @Binding var showTableOfContents: Bool
    
    var body: some View {
        VStack {
                
            HStack (spacing: 0) {
                
                VStack (alignment: .leading) {
                    Image(viewModel.book.coverImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .clipShape(.rect(cornerRadius: 10))
                        .shadow(radius: 2)
                        .padding()
                }
                
                VStack (alignment: .leading) {
                    Text(viewModel.book.title)
                        .font(.title3.bold())
                        .padding(.trailing, 15)
                        .padding(.bottom, 3)
                    
                    Text("\(String(format: "%.1f", viewModel.book.readingProgress * 100))%")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        
                }
                
                Spacer()
                    
                VStack (alignment: .trailing) {
                    
                    Button(action: {
                        showTableOfContents.toggle()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .padding(.trailing, 25)
                    }
                    .foregroundStyle(.tertiary)
                    .padding(.top, 20)
                    
                    Spacer()
                }
            }
            .frame(height: 150)
            
            if let chapters = viewModel.state.epubContent?.chapters {
                List {
                    ForEach(chapters, id: \.self) { chapter in
                        Text(chapter.title)
                    }
                }
                .listStyle(PlainListStyle())
            } else {
                // Show placeholder when no chapters are available
                Text("No chapters available")
                    .foregroundStyle(.secondary)
                    .padding()
            }
            
            Spacer()
        }
    }
    
}

#Preview {
    BookReaderView(book: Book(title: "ようこそ実力至上主義の教室へ", coverImage: "COTECover", readingProgress: 0.1, filePath: "konosuba.epub"))
}
