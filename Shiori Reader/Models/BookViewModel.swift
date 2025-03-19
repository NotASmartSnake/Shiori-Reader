//
//  BookViewModel.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/20/25.
//

import Foundation
import WebKit
import SwiftUI

// NEED TO CLEAN THIS SHIT UP!!!!!

@MainActor
class BookViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var book: Book
    @Published private(set) var state: BookState
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var currentTOCHref: String?
    @Published private(set) var isCurrentPositionSaved = false
    @Published var showDictionary = false
    @Published var selectedWord = ""
    @Published var isLoadingDictionary = false
    @Published var dictionaryMatches: [DictionaryMatch] = []
    @Published var currentTheme: Theme = Theme.original
    @Published var fontSize: Int = 18
    
    // MARK: - Private Properties
    private var webView: WKWebView?
    private var autoSaveWorkItem: DispatchWorkItem?
    private let repository: BookRepository
    private var initialLoadCompleted = false
    private var preventPositionUpdates = false
    private var defaultFontSize = 18
    
    // MARK: - Initialization
    init(book: Book, repository: BookRepository = BookRepository()) {
        self.book = book
        self.state = BookState()
        self.repository = repository
        loadFontPreferences()
        loadThemePreferences()
    }
    
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
    
    func setWebView(_ webView: WKWebView) {
        self.webView = webView
    }
    
    func getWebView() -> WKWebView? {
        return webView
    }
    
    @MainActor
    func webViewContentLoaded() {
        initialLoadCompleted = true
        self.restoreScrollPosition()
    }
    
    // MARK: - Dictionary Management
    
    func handleTextTap(text: String, options: [String: Any] = [:]) {
        print("DEBUG: Word tapped - \(text) with options: \(options)")
            
        // Helper function to extract what looks like a compound part (kanji + hiragana)
        func extractPotentialCompoundPart(from text: String) -> String {
            // Get the first continuous segment of hiragana/small characters
            var result = ""
            
            // Japanese hiragana range
            let hiraganaRange = "ぁ"..."ん"
            let smallCharsAndPunctuation = "っゃゅょ、。？！"
            
            for char in text {
                if hiraganaRange.contains(String(char)) || smallCharsAndPunctuation.contains(char) {
                    result.append(char)
                    // Stop at punctuation
                    if "、。？！".contains(char) {
                        break
                    }
                } else {
                    // Stop when we hit something that's not hiragana or small characters
                    break
                }
            }
            
            return result
        }
        
        // Check if this is a partial ruby compound selection
        if let isPartialCompound = options["isPartialCompound"] as? Bool, isPartialCompound,
           let isRuby = options["isRuby"] as? Bool, isRuby {
            
            // Get all the possible text segments we might want to look up
            let selectedChar = text
            let textFromClickedKanji = options["textFromClickedKanji"] as? String
            let textAfterRuby = options["textAfterRuby"] as? String
            
            // Simply use the selected character plus following text (up to 30 chars)
            // If textFromClickedKanji is available, use that as it already includes the context
            // Otherwise, manually combine the selected character with textAfterRuby
            let lookupText = textFromClickedKanji ?? (selectedChar + (textAfterRuby ?? ""))
            
            print("DEBUG: Looking up text: \(lookupText)")
            
            // Perform the lookup
            identifyJapaneseWords(text: lookupText) { matches in
                if !matches.isEmpty {
                    self.dictionaryMatches = matches
                    self.showDictionary = true
                } else {
                    // If no matches, try just the single character
                    self.identifyJapaneseWords(text: selectedChar) { charMatches in
                        if !charMatches.isEmpty {
                            self.dictionaryMatches = charMatches
                            self.showDictionary = true
                        }
                    }
                }
            }
            } else {
            // Original behavior for regular text or full ruby compounds
            identifyJapaneseWords(text: text) { matches in
                if !matches.isEmpty {
                    self.dictionaryMatches = matches
                    self.showDictionary = true
                }
            }
        }
    }
    
    private func identifyJapaneseWords(text: String, completion: @escaping ([DictionaryMatch]) -> Void) {
        let lookupQueue = DispatchQueue(label: "com.shiori.dictionaryLookup", qos: .userInitiated)
        
        lookupQueue.async {
            // Maximum word length to consider (adjust as needed)
            let maxLength = min(27, text.count)
            
            // Store all valid matches
            var matches: [DictionaryMatch] = []
            
            // Try words of decreasing length, starting from the longest
            for length in stride(from: maxLength, through: 1, by: -1) {
                // Make sure we don't exceed the text length
                guard length <= text.count else { continue }
                
                // Extract the substring of current length
                let endIndex = text.index(text.startIndex, offsetBy: length)
                let candidateWord = String(text[..<endIndex])
                
                // Look up this word in the dictionary
                let entries = DictionaryManager.shared.lookup(word: candidateWord)
                
                // If we found matches, add this as a valid match
                if !entries.isEmpty {
                    let match = DictionaryMatch(word: candidateWord, entries: entries)
                    matches.append(match)
                    
                    // Optional: Limit to a reasonable number of matches (e.g., 5)
                    if matches.count >= 5 {
                        break
                    }
                }
            }
            
            // Return all matches found, ordered by length (longest first)
            DispatchQueue.main.async {
                completion(matches)
            }
        }
    }
    
    // MARK: - Reading Position Management
    
    // Load initial bookmark state
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
    
    func restoreScrollPosition() {
        guard let webView = webView, initialLoadCompleted else { return }
        
        let savedExploredCount = state.exploredCharCount
        let savedTotalCount = state.totalCharCount
        
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
                    }
                }
            }
        }
    }
    
    // MARK: - Navigation Functions
    
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
    
    func navigateToChapter(_ index: Int) {
        guard let content = state.epubContent,
              index >= 0 && index < content.chapters.count else {
            return
        }
        state.currentChapterIndex = index
    }
    
    // MARK: - Font Size Functions
    
    private var lastFontSizeCharPosition: Int = 0

    func increaseFontSize() {
        if fontSize < 36 { // Max font size
            // Store exact character position before font size change
            lastFontSizeCharPosition = state.exploredCharCount
            
            fontSize += 1
            updateFontSizeExact(preservingExactPosition: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.debugFontSizes()
            }
        }
    }

    func decreaseFontSize() {
        if fontSize > 12 { // Min font size
            // Store exact character position before font size change
            lastFontSizeCharPosition = state.exploredCharCount
            
            fontSize -= 1
            updateFontSizeExact(preservingExactPosition: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.debugFontSizes()
            }
        }
    }

    private func updateFontSizeExact(preservingExactPosition: Bool = false) {
        guard let webView = webView else { return }
        
        // Disable position updates
        preventPositionUpdates = true
        
        // First, find and mark the current visible element before changing font size
        let markPositionScript = """
        (function() {
            // Find the element currently at the center of the viewport
            function findVisibleElement() {
                const viewportTop = window.scrollY;
                const viewportMiddle = viewportTop + (window.innerHeight / 2);
                
                // Query all potential elements that might be visible
                const elements = document.querySelectorAll('p, div.chapter-content > *, h1, h2, h3, h4, h5, h6');
                
                let bestElement = null;
                let bestDistance = Infinity;
                
                for (const el of elements) {
                    // Skip elements with no content
                    if (el.textContent.trim().length === 0) continue;
                    
                    const rect = el.getBoundingClientRect();
                    const topRelativeToDocument = rect.top + window.scrollY;
                    const distance = Math.abs(topRelativeToDocument - viewportMiddle);
                    
                    if (distance < bestDistance) {
                        bestDistance = distance;
                        bestElement = el;
                    }
                }
                
                return bestElement;
            }
            
            // Find and mark the current visible element
            const visibleElement = findVisibleElement();
            
            if (!visibleElement) {
                return {
                    found: false,
                    charPosition: \(lastFontSizeCharPosition),
                    message: "No visible element found"
                };
            }
            
            // Calculate character position up to this element
            let charCount = 0;
            function countCharsUpTo(node, target) {
                if (node === target) return true;
                
                if (node.nodeType === 3) { // Text node
                    charCount += node.textContent.length;
                }
                
                // Process child nodes
                if (node.childNodes) {
                    for (let i = 0; i < node.childNodes.length; i++) {
                        if (countCharsUpTo(node.childNodes[i], target)) {
                            return true;
                        }
                    }
                }
                
                return false;
            }
            
            // Add a marker to identify this element after font change
            const markerId = "__position_marker_" + Date.now();
            visibleElement.id = markerId;
            
            // Record where we are in the content
            const contentElement = document.getElementById('content');
            countCharsUpTo(contentElement, visibleElement);
            
            // Get some context about the element
            const elementText = visibleElement.textContent.substring(0, 30) + "...";
            
            return {
                found: true,
                markerId: markerId,
                elementText: elementText,
                charPosition: charCount,
                tagName: visibleElement.tagName,
                originalPosition: \(lastFontSizeCharPosition)
            };
        })();
        """
        
        // Step 1: Mark the current position
        webView.evaluateJavaScript(markPositionScript) { [weak self] markResult, markError in
            guard let self = self else { return }
            
            var markerId = ""
            var charPosition = self.lastFontSizeCharPosition
            
            if let markData = markResult as? [String: Any],
               let found = markData["found"] as? Bool, found,
               let id = markData["markerId"] as? String {
                
                markerId = id
                
                if let elementText = markData["elementText"] as? String,
                   let tagName = markData["tagName"] as? String {
                    print("DEBUG: Marked position at \(tagName) with text: \(elementText)")
                }
                
                // Use the character position if reasonable, otherwise stick with our stored value
                if let position = markData["charPosition"] as? Int, position > 100 {
                    // If the position is reasonably large, use it
                    charPosition = position
                    print("DEBUG: Using element-based character position: \(position)")
                } else {
                    print("DEBUG: Using stored character position: \(charPosition)")
                }
            } else {
                print("DEBUG: Failed to mark position, using stored value: \(charPosition)")
            }
            
            // Step 2: Update font size and restore position
            let updateScript = """
            (function() {
                // Update the font size
                document.documentElement.style.setProperty('--shiori-font-size', \(self.fontSize) + 'px');
                enforceRubyTextSize(\(self.fontSize));
                
                // Give layout time to update
                setTimeout(function() {
                    // First try to find the marked element
                    const markedElement = document.getElementById('\(markerId)');
                    let success = false;
                    
                    if (markedElement) {
                        // Scroll to the marked element
                        markedElement.scrollIntoView({ block: 'center', behavior: 'auto' });
                        console.log('Restored position using marked element');
                        success = true;
                    } else {
                        // If element not found, try character-based position
                        const charPosition = \(charPosition);
                        const content = document.getElementById('content');
                        
                        if (content) {
                            // Count characters and find the element at our position
                            let currentCount = 0;
                            let targetElement = null;
                            
                            function findElementAtPosition(node, targetPos) {
                                if (node.nodeType === 3) { // Text node
                                    currentCount += node.textContent.length;
                                    if (currentCount >= targetPos && !targetElement) {
                                        targetElement = node.parentElement;
                                        return true;
                                    }
                                } else if (node.childNodes) {
                                    for (let i = 0; i < node.childNodes.length; i++) {
                                        if (findElementAtPosition(node.childNodes[i], targetPos)) {
                                            return true;
                                        }
                                    }
                                }
                                return false;
                            }
                            
                            findElementAtPosition(content, charPosition);
                            
                            if (targetElement) {
                                targetElement.scrollIntoView({ block: 'center', behavior: 'auto' });
                                console.log('Restored position using character count');
                                success = true;
                            } else {
                                // Last resort: use a ratio-based approach
                                const totalChars = content.textContent.length;
                                const ratio = charPosition / totalChars;
                                const scrollHeight = document.documentElement.scrollHeight - window.innerHeight;
                                const targetPosition = scrollHeight * ratio;
                                
                                window.scrollTo(0, targetPosition);
                                console.log('Restored position using ratio: ' + ratio);
                                success = true;
                            }
                        }
                    }
                    
                    return {
                        fontSizeApplied: true,
                        positionRestored: success,
                        method: markedElement ? 'marker' : 'character',
                        charPosition: \(charPosition)
                    };
                }, 200);
                
                return { fontSizeUpdating: true };
            })();
            """
            
            webView.evaluateJavaScript(updateScript) { result, error in
                if let error = error {
                    print("DEBUG: Error updating font size: \(error)")
                } else if let resultDict = result as? [String: Any] {
                    print("DEBUG: Font size update: \(resultDict)")
                }
                
                // Force character count to stay the same
                self.state.exploredCharCount = charPosition
                
                // Re-enable position updates after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("DEBUG: Font size updated successfully to \(self.fontSize)px")
                    
                    // Save font size preference
                    UserDefaults.standard.set(self.fontSize, forKey: "global_font_size_preference")
                    
                    // Make sure we maintain position
                    self.state.exploredCharCount = charPosition
                    
                    // Debug font sizes
                    self.debugFontSizes()
                    
                    // Re-enable position updates
                    self.preventPositionUpdates = false
                }
            }
        }
    }
    
    @MainActor
    func loadFontPreferences() {
        // Load saved font size
        let savedFontSize = UserDefaults.standard.integer(forKey: "global_font_size_preference")
        if savedFontSize >= 12 && savedFontSize <= 36 {
            fontSize = savedFontSize
            print("DEBUG: Loaded global font size preference: \(savedFontSize)px")
        } else {
            fontSize = defaultFontSize
            print("DEBUG: Using default font size: \(defaultFontSize)px")
        }

    }
    
    func debugFontSizes() {
        guard let webView = webView else { return }
        
        let script = """
        (function() {
            const elements = ['body', '.chapter-content', 'p', 'div', 'span', 'h1', 'h2', 'ruby', 'rt'];
            const results = {};
            
            for (const selector of elements) {
                const els = document.querySelectorAll(selector);
                if (els.length > 0) {
                    const sizes = Array.from(els).slice(0, 3).map(el => {
                        return window.getComputedStyle(el).fontSize;
                    });
                    results[selector] = sizes;
                }
            }
            
            return results;
        })();
        """
        
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("DEBUG: Error getting font sizes: \(error)")
            } else if let fontSizes = result as? [String: [String]] {
                print("DEBUG: Current font sizes:")
                for (selector, sizes) in fontSizes {
                    print("  \(selector): \(sizes.joined(separator: ", "))")
                }
            }
        }
    }
    
    // MARK: - Font Color/Background Color Functions
    
    // Load saved theme or use default
    func loadThemePreferences() {
        // Get the current dark mode setting
        let isDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool
        
        // Get the appropriate theme name
        if let savedThemeName = UserDefaults.standard.selectedThemeName(forDarkMode: isDarkMode ?? false) {
            // Try to find the saved theme
            let savedTheme = Theme.allThemes.first(where: { $0.name == savedThemeName })
            
            if let theme = savedTheme {
                currentTheme = theme
                print("DEBUG: Loaded saved theme for \(isDarkMode == true ? "dark" : "light") mode: \(savedThemeName)")
                return
            }
        }
        
        // If no saved theme or theme not found, use default for the current mode
        if isDarkMode == true {
            currentTheme = Theme.darkOriginal
        } else {
            currentTheme = Theme.original
        }
        
        print("DEBUG: Using default theme for \(isDarkMode == true ? "dark" : "light") mode: \(currentTheme.name)")
    }
    
    // Apply the selected theme to the WebView
    func applyTheme(_ theme: Theme) {
        guard let webView = webView else { return }
        
        // Save character position before theme change
        let charPosition = state.exploredCharCount
        
        // Prevent position updates during theme change
        preventPositionUpdates = true
        
        // Update the theme
        currentTheme = theme
        
        // Get current dark mode state
        let isDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool
        
        // Save to UserDefaults for the appropriate mode
        UserDefaults.standard.setSelectedThemeName(theme.name, forDarkMode: isDarkMode ?? false)
        
        // Apply theme to WebView
        let script = """
        (function() {
            // Update CSS variables for theme
            document.documentElement.style.setProperty('--shiori-background-color', '\(theme.backgroundColorCSS)');
            document.documentElement.style.setProperty('--shiori-text-color', '\(theme.textColorCSS)');
            
            // Set the data-theme attribute
            document.documentElement.setAttribute('data-theme', '\(theme.name.lowercased())');
            
            // Wait for rendering and then restore position
            setTimeout(function() {
                // Try to restore to saved character position
                scrollToCharacterPosition(\(charPosition));
            }, 100);
            
            return true;
        })();
        """
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            if let error = error {
                print("DEBUG: Error applying theme: \(error)")
            } else {
                print("DEBUG: Applied theme: \(theme.name)")
            }
            
            // Re-enable position updates after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.preventPositionUpdates = false
            }
        }
    }
    
    func handleAppearanceChange(isDarkMode: Bool?) {
        // Get appropriate saved theme for the new mode or use default
        let savedThemeName = UserDefaults.standard.selectedThemeName(forDarkMode: isDarkMode ?? false)
        
        // Find the theme by name, or use default
        if let themeName = savedThemeName,
           let theme = Theme.allThemes.first(where: { $0.name == themeName }) {
            applyTheme(theme)
        } else {
            // Use default theme for the current mode
            let defaultTheme = isDarkMode == true ? Theme.darkOriginal : Theme.original
            applyTheme(defaultTheme)
        }
    }
    
    // MARK: - Bookmarking/Autosave Functions
    
    func toggleBookmark() async {
        // Toggle bookmark state
        state.isBookmarked.toggle()
        
        // Save current progress regardless of bookmark state
        await saveCurrentProgress()
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
    

    // Call this when progress changes significantly
    func updateProgressAndAutoSave(_ progress: Double) async {
        // Don't update progress if we're in the middle of restoring position
        guard !preventPositionUpdates else {
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
    
    func userScrolledHandler(progress: Double, exploredChars: Int, totalChars: Int, currentPage: Int) {
        // Only process user scrolling if we're not in the middle of a font size change
        if preventPositionUpdates {
            print("DEBUG: Ignoring scroll event during font change")
            return
        }
        
        // Sanity check - prevent jumps to beginning or end
        if lastFontSizeCharPosition > 1000 && exploredChars < 1000 {
            print("DEBUG: Preventing unexpected jump to beginning of book")
            return
        }
        
        // Normal handling
        updateReadingState(exploredChars: exploredChars, totalChars: totalChars, currentPage: currentPage)
        
        Task {
            await updateProgressAndAutoSave(progress)
        }
    }
    
    func updatePositionData() {
        guard let webView = webView else { return }
        
        let script = """
        (function() {
            const content = document.getElementById('content');
            if (!content) return null;
            
            const textContent = content.textContent;
            const totalCharCount = textContent.length;
            
            // Get current scroll position
            const scrollY = window.scrollY;
            const viewportHeight = window.innerHeight;
            const scrollHeight = document.documentElement.scrollHeight;
            const maxScroll = scrollHeight - viewportHeight;
            const scrollRatio = maxScroll > 0 ? scrollY / maxScroll : 0;
            
            // Calculate character position
            const exploredCharCount = Math.round(totalCharCount * scrollRatio);
            
            // Return all data
            return {
                exploredChars: exploredCharCount,
                totalChars: totalCharCount,
                scrollRatio: scrollRatio,
                scrollY: scrollY,
                scrollHeight: scrollHeight
            };
        })();
        """
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self,
                  let data = result as? [String: Any],
                  let exploredChars = data["exploredChars"] as? Int,
                  let totalChars = data["totalChars"] as? Int,
                  !self.preventPositionUpdates else {
                return
            }
            
            // Only update if we're not in the middle of a font change operation
            if !self.preventPositionUpdates {
                // Update state with accurate character counts
                self.state.exploredCharCount = exploredChars
                self.state.totalCharCount = totalChars
                
                // Calculate progress based on character position
                let progress = Double(exploredChars) / Double(totalChars)
                if abs(self.book.readingProgress - progress) > 0.01 {
                    self.book.readingProgress = progress
                }
                
                print("DEBUG: Position updated - chars: \(exploredChars)/\(totalChars)")
            }
        }
    }


    // Update the updateReadingState method to be more strict about prevention
    func updateReadingState(exploredChars: Int, totalChars: Int, currentPage: Int) {
        // Don't update state if we're in the middle of restoring position
        if preventPositionUpdates {
            print("DEBUG: Blocking position update during font change - keeping at \(lastFontSizeCharPosition)")
            return
        }
        
        // Normal behavior when not prevented
        state.exploredCharCount = exploredChars
        state.totalCharCount = totalChars
        state.currentPage = currentPage
        state.totalPages = 100
    }
        
}
