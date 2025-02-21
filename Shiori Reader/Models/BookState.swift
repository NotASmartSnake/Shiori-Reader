//
//  BookState.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/20/25.
//

import Foundation

struct BookState {
    var epubContent: EPUBContent?
    var epubBaseURL: URL?
    var currentChapterIndex: Int = 0
    var isBookmarked: Bool = false
}
