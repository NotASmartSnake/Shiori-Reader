//
//  BookViewModel.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/20/25.
//

import Foundation
import WebKit

@MainActor
class BookViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var book: Book
    @Published private(set) var state: BookState
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var currentTOCHref: String?
    private var webView: WKWebView?
    
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
            return
        }
        
        isLoading = true
        do {
            let (content, baseURL) = try await repository.loadEPUB(at: book.filePath)
            state.epubContent = content
            state.epubBaseURL = baseURL
            isLoading = false
        } catch {
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
    
    func setWebView(_ webView: WKWebView) {
        self.webView = webView
    }
    
    func navigateToTOCEntry(_ href: String) {
        guard let webView = webView else {
            print("DEBUG: WebView is nil when trying to navigate to \(href)")
            return
        }
        
        print("DEBUG: Navigating to TOC entry with href: \(href)")
        
        // Extract the file path and fragment identifier
        let components = href.components(separatedBy: "#")
        let filePath = components.first ?? ""
        let fragmentId = components.count > 1 ? components[1] : ""
        
        print("DEBUG: Parsed filePath: \(filePath), fragmentId: \(fragmentId)")
        
        // Log content of TOC entries and chapters to understand the structure
        if let epubContent = state.epubContent {
            print("DEBUG: Available TOC entries:")
            for (index, entry) in epubContent.tableOfContents.enumerated() {
                print("  \(index): \(entry.label) -> \(entry.href)")
            }
            
            print("DEBUG: Available chapters:")
            for (index, chapter) in epubContent.chapters.enumerated() {
                print("  \(index): \(chapter.title) (filePath: \(chapter.filePath))")
            }
        }
        
        let inspectionScript = """
            function inspectDOM() {
                let result = {
                    chapterElements: [],
                    fragmentElement: null,
                    allIds: []
                };
                
                // Get all chapter elements
                let chapters = document.querySelectorAll('.chapter');
                for (let i = 0; i < chapters.length; i++) {
                    result.chapterElements.push({
                        id: chapters[i].id,
                        dataFilename: chapters[i].getAttribute('data-filename') || '',
                        offsetTop: chapters[i].offsetTop
                    });
                }
                
                // Check if fragment exists
                if ('\(fragmentId)' !== '') {
                    let elem = document.getElementById('\(fragmentId)');
                    if (elem) {
                        result.fragmentElement = {
                            id: elem.id,
                            tagName: elem.tagName,
                            offsetTop: elem.offsetTop
                        };
                    }
                }
                
                // Get all elements with IDs to see what's available
                let allWithIds = document.querySelectorAll('[id]');
                for (let i = 0; i < allWithIds.length; i++) {
                    if (i < 20) { // Limit to first 20 to avoid excessive logging
                        result.allIds.push(allWithIds[i].id);
                    }
                }
                
                return JSON.stringify(result);
            }
            inspectDOM();
        """

        webView.evaluateJavaScript(inspectionScript) { result, error in
            if let error = error {
                print("DEBUG: Error inspecting DOM: \(error)")
            } else if let jsonString = result as? String,
                      let data = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) {
                print("DEBUG: DOM inspection result: \(json)")
            }
        }
        
        // After the DOM inspection, add this revised navigation code
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let navigationScript = """
            function navigateToContent() {
                console.log('Navigation script running');
                
                // Try to find chapter based on filename in filePath
                let foundChapter = false;
                if ('\(filePath)' !== '') {
                    const chapters = document.querySelectorAll('.chapter');
                    for (let i = 0; i < chapters.length; i++) {
                        const filename = chapters[i].getAttribute('data-filename') || '';
                        const chapterId = chapters[i].id;
                        console.log(`Checking chapter ${i}: ${filename} (id: ${chapterId})`);
                        
                        if (filename && '\(filePath)'.includes(filename)) {
                            console.log(`Found matching chapter: ${filename}`);
                            chapters[i].scrollIntoView();
                            foundChapter = true;
                            
                            // Now try to find the fragment within this chapter
                            if ('\(fragmentId)' !== '') {
                                const fragment = document.getElementById('\(fragmentId)');
                                if (fragment) {
                                    console.log(`Found fragment: ${fragment.id}`);
                                    setTimeout(() => fragment.scrollIntoView(), 100);
                                    return true;
                                }
                            }
                            break;
                        }
                    }
                }
                
                // If we couldn't match by filename, try direct fragment navigation
                if (!foundChapter && '\(fragmentId)' !== '') {
                    const fragment = document.getElementById('\(fragmentId)');
                    if (fragment) {
                        console.log(`Found fragment directly: ${fragment.id}`);
                        fragment.scrollIntoView();
                        return true;
                    }
                }
                
                // If all else fails, use index-based navigation
                if (!foundChapter) {
                    const chapterIndex = \(self.state.currentChapterIndex);
                    const chapterElement = document.getElementById('chapter-' + (chapterIndex + 1));
                    if (chapterElement) {
                        console.log(`Falling back to index navigation: chapter-${chapterIndex + 1}`);
                        chapterElement.scrollIntoView();
                        return true;
                    }
                }
                
                console.log('Navigation failed to find a target');
                return false;
            }
            navigateToContent();
            """
            
            webView.evaluateJavaScript(navigationScript) { result, error in
                if let error = error {
                    print("DEBUG: Navigation script error: \(error)")
                } else if let success = result as? Bool {
                    print("DEBUG: Navigation result: \(success ? "successful" : "failed")")
                }
            }
        }
        
        currentTOCHref = href
    }
        
}
