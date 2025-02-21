//
//  Book.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//

import SwiftUI

struct Book: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let coverImage: String
    let filePath: String
    var readingProgress: Double
    
    init(title: String, coverImage: String, readingProgress: Double, filePath: String) {
        self.title = title
        self.coverImage = coverImage
        self.readingProgress = readingProgress
        self.filePath = filePath
    }
}
