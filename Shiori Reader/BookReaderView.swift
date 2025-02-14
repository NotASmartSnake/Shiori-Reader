//
//  BookReaderView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//

import SwiftUI

struct BookReaderView: View {
    let book: Book
    
    var body: some View {
        Text("Here's the filepath: \(book.filePath)")
    }
    
}

#Preview {
    let book = Book(title: "Danmachi", coverImage: "DanmachiCover", readingProgress: 0.1, filePath: "21519.epub")
    
    BookReaderView(book: book)
}
