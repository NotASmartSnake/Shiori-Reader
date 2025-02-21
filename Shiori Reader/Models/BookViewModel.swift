//
//  BookViewModel.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/20/25.
//

import Foundation

@MainActor
class BookViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var book: Book
    @Published private(set) var state: BookState
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    // MARK: - Private Properties
    private let repository: BookRepository
    
    // MARK: - Initialization
    init(book: Book, repository: BookRepository = BookRepository()) {
        self.book = book
        self.state = BookState()
        self.repository = repository
    }
    
    // MARK: - Public Methods
    func loadEPUB() async {
        guard state.epubContent == nil else {
            print("📝 EPUB content already loaded")
            return
        }
        
        isLoading = true
        do {
            let (content, baseURL) = try await repository.loadEPUB(at: book.filePath)
            state.epubContent = content
            state.epubBaseURL = baseURL
            isLoading = false
        } catch {
            print("❌ Error loading EPUB: \(error)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func updateProgress(_ progress: Double) async {
        var updatedBook = book
        updatedBook.readingProgress = progress
        
        do {
            try await repository.saveProgress(for: updatedBook)
            book = updatedBook
        } catch {
            errorMessage = "Failed to save reading progress"
        }
    }
    
    func toggleBookmark() {
        state.isBookmarked.toggle()
    }
    
    func navigateToChapter(_ index: Int) {
        guard let content = state.epubContent,
              index >= 0 && index < content.chapters.count else {
            return
        }
        state.currentChapterIndex = index
    }
}
