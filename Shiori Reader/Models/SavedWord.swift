//
//  SavedWord.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/21/25.
//
import Foundation

struct SavedWord: Identifiable, Equatable, Hashable {
    var id = UUID()
    var word: String
    var reading: String
    var definition: String
    var sentence: String
    var timeAdded: Date
    var sourceBook: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SavedWord, rhs: SavedWord) -> Bool {
        return lhs.id == rhs.id
    }
}
