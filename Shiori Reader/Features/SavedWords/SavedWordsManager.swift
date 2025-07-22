import Foundation
import Combine
import UIKit

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
            definitions: word.definitions,
            sentence: word.sentence,
            sourceBook: word.sourceBook,
            pitchAccents: word.pitchAccents
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
    
    // Function to delete all words
    func deleteAllWords() {
        // Create a copy of the word IDs to avoid modifying the array while iterating
        let wordIds = savedWords.map { $0.id }
        
        // Delete each word from the repository
        for id in wordIds {
            repository.deleteSavedWord(with: id)
        }
        
        // Clear the array
        savedWords.removeAll()
    }
    
    // MARK: - Word Checking
    
    /// Check if a word is already saved in the vocabulary list
    /// - Parameters:
    ///   - word: The word (kanji) to check
    ///   - reading: The reading (hiragana/katakana) to check
    /// - Returns: True if the word with this specific reading is already saved, false otherwise
    func isWordSaved(_ word: String, reading: String = "") -> Bool {
        return savedWords.contains { savedWord in
            savedWord.word == word && savedWord.reading == reading
        }
    }
    
    /// Check if a word is already saved and return the saved word if found
    /// - Parameters:
    ///   - word: The word (kanji) to check
    ///   - reading: The reading (hiragana/katakana) to check
    /// - Returns: The SavedWord if found, nil otherwise
    func getSavedWord(for word: String, reading: String = "") -> SavedWord? {
        return savedWords.first { savedWord in
            savedWord.word == word && savedWord.reading == reading
        }
    }
    
    // MARK: - CSV Export
    
    /// Exports all saved words to a CSV file and returns the file URL
    /// - Returns: A tuple containing the URL of the saved file and its filename
    func exportToCSV() -> (fileURL: URL, filename: String)? {
        // Create CSV content
        var csvString = "Word,Reading,Definition,Example Sentence,Source Book,Date Added,Pitch Accent\n"
        
        // Add each word's data as a row
        for word in savedWords {
            // Format date as string
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            let dateString = dateFormatter.string(from: word.timeAdded)
            
            // Get pitch accent string
            let pitchAccentString = word.pitchAccentString ?? ""
            
            // Escape CSV fields properly
            let escapedWord = escapeCSVField(word.word)
            let escapedReading = escapeCSVField(word.reading)
            let escapedDefinition = escapeCSVField(word.definition)
            let escapedSentence = escapeCSVField(word.sentence)
            let escapedSource = escapeCSVField(word.sourceBook)
            let escapedDate = escapeCSVField(dateString)
            let escapedPitchAccent = escapeCSVField(pitchAccentString)
            
            // Add row to CSV
            csvString.append("\(escapedWord),\(escapedReading),\(escapedDefinition),\(escapedSentence),\(escapedSource),\(escapedDate),\(escapedPitchAccent)\n")
        }
        
        // Create a temporary directory URL
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        
        // Create filename with date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let filename = "shiori_vocabulary_\(dateString).csv"
        let fileURL = temporaryDirectoryURL.appendingPathComponent(filename)
        
        do {
            // Write to file
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Successfully saved CSV to \(fileURL.path)")
            return (fileURL, filename)
        } catch {
            print("Error writing CSV file: \(error)")
            return nil
        }
    }
    
    // Helper to properly escape CSV fields
    private func escapeCSVField(_ field: String) -> String {
        var escaped = field
        
        // If the field contains commas, quotes, or newlines, it needs to be quoted
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            // Double any quotes within the field
            escaped = escaped.replacingOccurrences(of: "\"", with: "\"\"")
            // Wrap the field in quotes
            escaped = "\"\(escaped)\""
        }
        
        return escaped
    }
    
}
