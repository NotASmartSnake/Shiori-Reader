//
//  Book.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//

import SwiftUI

struct Book: Identifiable, Hashable {
    let id = UUID() // Unique identifier
    let title: String
    let coverImage: String // Store the name of the image or `UIImage`
    var readingProgress: Double // 0 to 1
    let filePath: String
//    let author: String
}
