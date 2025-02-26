//
//  LibraryView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//

import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var isReadingBook: IsReadingBook
    
    let booksArray: [Book] = [
        Book(title: "COTE", coverImage: "COTECover", readingProgress: 0.4, filePath: "cote.epub"),
        Book(title: "3 Days", coverImage: "3DaysCover", readingProgress: 0.56, filePath: "3Days.epub"),
        Book(title: "Honzuki", coverImage: "AOABCover", readingProgress: 0.3, filePath: "honzuki.epub"),
        Book(title: "Konosuba", coverImage: "KonosubaCover", readingProgress: 0.7, filePath: "konosuba.epub"),
        Book(title: "Hakomari", coverImage: "HakomariCover", readingProgress: 0.6, filePath: "hakomari.epub"),
        Book(title: "Danmachi", coverImage: "DanmachiCover", readingProgress: 0.1, filePath: "cote.epub"),
        Book(title: "86", coverImage: "86Cover", readingProgress: 0.2, filePath: ""),
        Book(title: "Love", coverImage: "LoveCover", readingProgress: 0.8, filePath: ""),
        Book(title: "Mushoku", coverImage: "MushokuCover", readingProgress: 0.9, filePath: ""),
        Book(title: "Oregairu", coverImage: "OregairuCover", readingProgress: 1.0, filePath: ""),
        Book(title: "ReZero", coverImage: "ReZeroCover", readingProgress: 0.0, filePath: ""),
        Book(title: "Slime", coverImage: "SlimeCover", readingProgress: 0.0, filePath: ""),
        Book(title: "Overlord", coverImage: "OverlordCover", readingProgress: 0.0, filePath: ""),
        Book(title: "Death", coverImage: "DeathCover", readingProgress: 0.0, filePath: ""),
        Book(title: "No Game No Life", coverImage: "NoGameCover", readingProgress: 0.0, filePath: "")
    ]
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundColor").ignoresSafeArea(edges: .all)
                
                ScrollView {
                    VStack {
                        // Extract grid to separate view
                        BookGrid(books: booksArray, isReadingBook: isReadingBook)
                        
                        Rectangle()
                            .frame(width: 0, height: 85)
                            .foregroundStyle(.clear)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        print("Settings tapped")
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .toolbarBackground(Color.black, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .navigationTitle("Library")
        }
    }
}

// Separate view for the grid
struct BookGrid: View {
    let books: [Book]
    @ObservedObject var isReadingBook: IsReadingBook
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(books) { book in
                BookCell(book: book, isReadingBook: isReadingBook)
            }
        }
        .padding(.horizontal, 10)
    }
}

// Separate view for each cell
struct BookCell: View {
    let book: Book
    @ObservedObject var isReadingBook: IsReadingBook
    
    var body: some View {
        VStack {
            NavigationLink(destination:
                BookReaderView(book: book)
                    .onAppear { isReadingBook.isReading = true }
                    .onDisappear { isReadingBook.isReading = false }
            ) {
                Image(book.coverImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 250)
                    .cornerRadius(8)
                    .shadow(radius: 4)
            }
            
            HStack {
                Text("\(Int(book.readingProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Spacer()
                Image(systemName: "ellipsis")
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(IsReadingBook(isReading: .constant(false)))
}
