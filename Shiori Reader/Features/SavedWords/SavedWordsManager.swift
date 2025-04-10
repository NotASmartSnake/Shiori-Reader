//
//  SavedWordsManager.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/21/25.
//

import Foundation
import Combine

// ViewModel to handle saved words data
class SavedWordsManager: ObservableObject {
    @Published var savedWords: [SavedWord] = []
    private let repository = SavedWordRepository()
    
    init() {
        loadSavedWords()
    }
    
    private func loadSavedWords() {
        savedWords = repository.getAllSavedWords()
    }
    
    func addWord(_ word: SavedWord) {
        let newWord = repository.addSavedWord(
            word: word.word,
            reading: word.reading,
            definition: word.definition,
            sentence: word.sentence,
            sourceBook: word.sourceBook
        )
        savedWords.append(newWord)
    }
    
    func updateWord(updated: SavedWord) {
        repository.updateSavedWord(updated)
        if let index = savedWords.firstIndex(where: { $0.id == updated.id }) {
            savedWords[index] = updated
        }
    }
    
    func deleteWord(at indexSet: IndexSet) {
        for index in indexSet {
            let word = savedWords[index]
            repository.deleteSavedWord(with: word.id)
        }
        // Remove from the array
        savedWords.remove(atOffsets: indexSet)
    }
    
    func deleteWord(with id: UUID) {
        repository.deleteSavedWord(with: id)
        if let index = savedWords.firstIndex(where: { $0.id == id }) {
            savedWords.remove(at: index)
        }
    }
    
    // Refresh all saved words
    func refreshWords() {
        loadSavedWords()
    }
}
