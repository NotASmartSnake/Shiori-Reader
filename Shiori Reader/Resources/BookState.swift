//
//  BookState.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/20/25.
//

import Foundation
import WebKit

struct BookState {
    var epubContent: EPUBContent?
    var epubBaseURL: URL?
    var currentChapterIndex: Int = 0
    var isBookmarked: Bool = false
    var exploredCharCount: Int = 0   // Current reading position in characters
    var totalCharCount: Int = 0      // Total book length in characters
    var currentPage: Int = 1         // Keep for UI display purposes
    var totalPages: Int = 0          // Keep for UI display purposes
}
