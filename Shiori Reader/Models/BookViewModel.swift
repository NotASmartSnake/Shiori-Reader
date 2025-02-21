//
//  BookViewModel.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/20/25.
//

import Foundation

@MainActor
class BookViewModel: ObservableObject {
    @Published var book: Book
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var readingProgress: Double = 0.0
    
    init(book: Book) {
        self.book = book
        self.readingProgress = book.readingProgress
    }
    
    func loadEPUB() async {
        guard book.epubContent == nil else { return }
        
        isLoading = true
        do {
            guard let epubPath = Bundle.main.path(forResource: book.filePath, ofType: nil) else {
                throw EPUBError.fileNotFound
            }
            
            let parser = EPUBParser()
            let (content, baseURL) = try parser.parseEPUB(at: epubPath)
            
            // Update book
            book.epubContent = content
            book.epubBaseURL = baseURL
            isLoading = false
            
            // Here you could also load saved progress, bookmarks, etc.
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    // TO DO: Add more functionality here
    func updateProgress(_ progress: Double) {
        readingProgress = progress
        book.readingProgress = progress
        // Save progress to persistent storage
    }
}
