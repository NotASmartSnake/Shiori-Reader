//
//  Chapter.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/20/25.
//

struct Chapter: Codable, Hashable {
    var title: String
    var content: String
    var images: [String]
    var filePath: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(content)
        hasher.combine(images)
        hasher.combine(filePath)
    }
    
    static func == (lhs: Chapter, rhs: Chapter) -> Bool {
        return lhs.title == rhs.title &&
               lhs.content == rhs.content &&
               lhs.images == rhs.images &&
               lhs.filePath == rhs.filePath
    }
}
