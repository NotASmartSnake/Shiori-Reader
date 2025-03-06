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
    @Published private(set) var isCurrentPositionSaved = false
    private var webView: WKWebView?
    private var autoSaveWorkItem: DispatchWorkItem?
    private let repository: BookRepository
    private var initialLoadCompleted = false
    private var preventPositionUpdates = false
    
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
    
    @MainActor
    func updateProgress(_ progress: Double) async {
        book.readingProgress = progress
        print("DEBUG: Book progress updated to \(progress)")
    }
    
    func setProgress(_ progress: Double) {
        // Only update if the change is significant enough (to avoid minute changes)
        if abs(book.readingProgress - progress) > 0.01 {
            book.readingProgress = progress
            Task {
                await updateProgress(progress)
            }
        }
    }
    
    func toggleBookmark() async {
        // Toggle bookmark state
        state.isBookmarked.toggle()
        
        // Save current progress regardless of bookmark state
        await saveCurrentProgress()
    }

    func autoSaveProgress() {
        print("DEBUG: Auto-save timer started")
        autoSaveWorkItem?.cancel()
        
        // Update UI to show bookmark is NOT active
        if state.isBookmarked {
            state.isBookmarked = false
        }
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            Task {
                await self.saveCurrentProgress()
                
                await MainActor.run {
                    self.state.isBookmarked = true
                    self.isCurrentPositionSaved = true
                }
            }
        }
        
        autoSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
    }
    
    func resetAutoSave() {
        print("DEBUG: Auto-save timer reset (user interaction)")
        autoSaveWorkItem?.cancel()
        autoSaveWorkItem = nil
        
        // Immediately set bookmark to not active when user interacts
        if state.isBookmarked {
            state.isBookmarked = false
            print("DEBUG: Setting bookmark indicator to false due to user interaction")
        }
        
        // Mark that current position is not saved
        isCurrentPositionSaved = false
    }


    func saveCurrentProgress() async {
        if state.exploredCharCount > 0 && state.totalCharCount > 0 {
            do {
                try await repository.saveProgress(
                    for: book,
                    exploredCharCount: state.exploredCharCount,
                    totalCharCount: state.totalCharCount
                )
                
                print("DEBUG: Saved progress: \(book.readingProgress) (\(state.exploredCharCount)/\(state.totalCharCount) chars)")
            } catch {
                print("DEBUG: Error saving progress: \(error.localizedDescription)")
            }
        }
    }
    
    func updatePositionData() {
        guard let webView = webView else { return }
        
        let script = """
        function getPositionData() {
            const content = document.getElementById('content');
            const totalCharCount = content.textContent.length;
            
            // Calculate character count up to current viewport position
            const visibleTop = window.scrollY;
            const visibleBottom = visibleTop + window.innerHeight;
            const scrollHeight = document.documentElement.scrollHeight;
            
            // Create a range from the beginning to the middle of the viewport
            const viewportMiddle = visibleTop + (window.innerHeight / 2);
            const progress = viewportMiddle / scrollHeight;
            
            // Estimate character count based on scroll position
            const exploredCharCount = Math.round(totalCharCount * progress);
            
            // Calculate page numbers for display
            const totalPages = Math.ceil(scrollHeight / window.innerHeight);
            const currentPage = Math.ceil(visibleTop / (scrollHeight / totalPages)) + 1;
            
            return {
                exploredCharCount: exploredCharCount,
                totalCharCount: totalCharCount,
                progress: progress,
                currentPage: currentPage,
                totalPages: totalPages
            };
        }
        getPositionData();
        """
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self, let data = result as? [String: Any] else {
                if let error = error {
                    print("DEBUG: Error getting position data: \(error)")
                }
                return
            }
            
            if let exploredCharCount = data["exploredCharCount"] as? Int {
                self.state.exploredCharCount = exploredCharCount
            }
            
            if let totalCharCount = data["totalCharCount"] as? Int {
                self.state.totalCharCount = totalCharCount
            }
            
            if let progress = data["progress"] as? Double {
                // Only update if the change is significant enough
                if abs(self.book.readingProgress - progress) > 0.01 {
                    Task {
                        await self.updateProgressAndAutoSave(progress)
                    }
                }
            }
            
            if let currentPage = data["currentPage"] as? Int,
               let totalPages = data["totalPages"] as? Int {
                self.updatePositionData()
            }
        }
    }
    
    func updateReadingState(exploredChars: Int, totalChars: Int, currentPage: Int) {
        // Don't update state if we're in the middle of restoring position
        guard !preventPositionUpdates else {
            print("DEBUG: Ignoring position update during restoration")
            return
        }
        
        state.exploredCharCount = exploredChars
        state.totalCharCount = totalChars
        state.currentPage = currentPage
        state.totalPages = 100
    }

    // Call this when progress changes significantly
    func updateProgressAndAutoSave(_ progress: Double) async {
        // Don't update progress if we're in the middle of restoring position
        guard !preventPositionUpdates else {
            print("DEBUG: Ignoring progress update during restoration")
            return
        }
        
        // Update the progress value
        let significantChange = abs(book.readingProgress - progress) > 0.01
        
        // Only log if it's meaningful
        if progress > 0.001 {
            print("DEBUG: Progress update - Current: \(book.readingProgress), New: \(progress), Significant: \(significantChange)")
        }
        
        book.readingProgress = progress
        
        if significantChange {
            // Trigger auto-save timer
            autoSaveProgress()
        }
    }


    // Load initial bookmark state - simplify to just loading progress
    @MainActor
    func loadProgress() async {
        let exploredCharCount = repository.getExploredCharCount(for: book.filePath)
        let totalCharCount = repository.getTotalCharCount(for: book.filePath)
        
        if exploredCharCount > 0 && totalCharCount > 0 {
            await MainActor.run {
                // Calculate and set progress percentage
                let progress = Double(exploredCharCount) / Double(totalCharCount)
                book.readingProgress = progress
                
                // Store character count data
                state.exploredCharCount = exploredCharCount
                state.totalCharCount = totalCharCount
                
                // Mark as bookmarked
                state.isBookmarked = true
                isCurrentPositionSaved = true
                
                // Set the initial load flag
                initialLoadCompleted = true
                
                print("DEBUG: Loaded position for \(book.title): \(exploredCharCount)/\(state.totalCharCount) chars with progress \(progress)")
            }
        }
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
        
        // Extract the file path and fragment identifier
        let components = href.components(separatedBy: "#")
        let filePath = components.first ?? ""
        let fragmentId = components.count > 1 ? components[1] : ""
        
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
    
    func restoreScrollPosition() {
        guard let webView = webView, initialLoadCompleted else {
            print("DEBUG: Cannot restore - initial load not completed or webView missing")
            return
        }
        
        // Save the loaded values to local variables to prevent them being changed
        let savedExploredCount = state.exploredCharCount
        let savedTotalCount = state.totalCharCount
        
        // Make sure we have valid character counts
        if savedExploredCount > 0 && savedTotalCount > 0 {
            // Add a delay to ensure WebView is fully loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                
                print("DEBUG: Attempting to restore to position \(savedExploredCount) of \(savedTotalCount) chars")
                
                // Improved restoration script that's less prone to issues
                let script = """
                (function() {
                    // Get the content element
                    const content = document.getElementById('content');
                    if (!content) {
                        console.error('Content element not found');
                        return false;
                    }
                    
                    // Calculate the target position based on saved character count
                    const targetRatio = \(Double(savedExploredCount)) / \(Double(savedTotalCount));
                    const scrollHeight = document.documentElement.scrollHeight - window.innerHeight;
                    const targetPosition = Math.max(0, Math.round(scrollHeight * targetRatio));
                    
                    // Block any scroll event handlers temporarily to prevent overriding our position
                    const oldScrollHandler = window.onscroll;
                    window.onscroll = null;
                    
                    // Actually perform the scroll
                    window.scrollTo({
                        top: targetPosition,
                        left: 0,
                        behavior: 'auto'
                    });
                    
                    // After a short delay, restore the scroll handler
                    setTimeout(function() {
                        window.onscroll = oldScrollHandler;
                    }, 100);
                    
                    return {
                        success: true,
                        targetRatio: targetRatio,
                        targetPosition: targetPosition,
                        scrollHeight: scrollHeight
                    };
                })();
                """
                
                webView.evaluateJavaScript(script) { result, error in
                    if let error = error {
                        print("DEBUG: Error restoring position: \(error)")
                    } else if let resultDict = result as? [String: Any],
                              let success = resultDict["success"] as? Bool,
                              success {
                        print("DEBUG: Successfully restored to character position \(savedExploredCount) (ratio: \(resultDict["targetRatio"] ?? "unknown"), position: \(resultDict["targetPosition"] ?? "unknown"))")
                        
                        // Disable position updates briefly to avoid overwriting restored position
                        self.preventPositionUpdates = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.preventPositionUpdates = false
                        }
                    } else {
                        print("DEBUG: Position restoration failed")
                    }
                }
            }
        } else {
            print("DEBUG: Cannot restore position - invalid character counts: \(savedExploredCount)/\(savedTotalCount)")
        }
    }

    func getWebView() -> WKWebView? {
        return webView
    }
        
}
