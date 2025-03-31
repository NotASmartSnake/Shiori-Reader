//
//  BookGrid.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/29/25.
//

import SwiftUI

struct BookGrid: View {
    let books: [Book]
    @ObservedObject var isReadingBook: IsReadingBook
    @Binding var lastViewedBookPath: String?
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(books) { book in
                BookCell(book: book, isReadingBook: isReadingBook, lastViewedBookPath: $lastViewedBookPath)
            }
        }
        .padding(.horizontal, 10)
    }
}
