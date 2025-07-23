
import Foundation
import IPADic
import Mecab_Swift

class JapaneseTextAnalyzer {
    // Singleton for convenience
    static let shared = JapaneseTextAnalyzer()
    
    private let tokenizer: Tokenizer
    
    private init() {
        do {
            let ipaDic = IPADic()
            tokenizer = try Tokenizer(dictionary: ipaDic)
        } catch {
            fatalError("Failed to initialize MeCab tokenizer: \(error)")
        }
    }
    
    // Format word with reading using individual kanji mapping
    func formatWordWithReading(word: String, reading: String) -> String {
        if !containsKanji(word) {
            return word
        }
        
        // Get all individual kanji characters from the word
        let kanjiChars = Array(word).filter { containsKanji(String($0)) }
        
        if kanjiChars.isEmpty {
            return word
        }
        
        // Get the full reading for the word
        let tokens = tokenizer.tokenize(text: word, transliteration: .hiragana)
        let fullReading = tokens.first?.reading ?? reading
        
        var result = ""
        var readingIndex = fullReading.startIndex
        var kanjiGroupCount = 0
        
        // Count total kanji groups (contiguous kanji sequences)
        var i = word.startIndex
        while i < word.endIndex {
            if containsKanji(String(word[i])) {
                kanjiGroupCount += 1
                // Skip through the contiguous kanji
                while i < word.endIndex && containsKanji(String(word[i])) {
                    i = word.index(after: i)
                }
            } else {
                i = word.index(after: i)
            }
        }
        
        // Process each character
        i = word.startIndex
        var processedKanjiGroups = 0
        
        while i < word.endIndex {
            let char = word[i]
            
            if containsKanji(String(char)) {
                // Add space before subsequent kanji groups
                if kanjiGroupCount > 1 && processedKanjiGroups > 0 {
                    result += " "
                }
                
                // Process each kanji in this group individually
                while i < word.endIndex && containsKanji(String(word[i])) {
                    let kanjiChar = String(word[i])
                    
                    // Look ahead to see what character comes next
                    let nextIndex = word.index(after: i)
                    let nextChar = nextIndex < word.endIndex ? String(word[nextIndex]) : nil
                    
                    // Get the reading for this specific kanji
                    let kanjiReading = getReadingForKanji(kanjiChar, from: fullReading, at: &readingIndex, nextCharInWord: nextChar)
                    
                    result += "\(kanjiChar)[\(kanjiReading)]"
                    i = word.index(after: i)
                }
                
                processedKanjiGroups += 1
            } else {
                // Hiragana/katakana - add as-is and advance reading index
                result += String(char)
                if readingIndex < fullReading.endIndex && String(char) == String(fullReading[readingIndex]) {
                    readingIndex = fullReading.index(after: readingIndex)
                }
                i = word.index(after: i)
            }
        }
        
        return result
    }
    
    // Extract reading for a specific kanji from the full reading, considering following hiragana
    private func getReadingForKanji(_ kanji: String, from fullReading: String, at readingIndex: inout String.Index, nextCharInWord: String? = nil) -> String {
        if readingIndex >= fullReading.endIndex {
            return kanji
        }
        
        var kanjiReading = ""
        let startReadingIndex = readingIndex
        
        // If there's a hiragana character following the kanji, we need to stop the reading before that hiragana appears in the reading
        if let nextChar = nextCharInWord, !containsKanji(nextChar) {
            // Look ahead in the reading to find where this hiragana character appears
            var tempIndex = readingIndex
            while tempIndex < fullReading.endIndex {
                let readingChar = String(fullReading[tempIndex])
                
                // If we find the next hiragana character in the reading, stop before it
                if readingChar == nextChar {
                    break
                }
                
                kanjiReading += readingChar
                tempIndex = fullReading.index(after: tempIndex)
                
                // Safety: don't take more than 4 characters for a single kanji
                if kanjiReading.count >= 4 {
                    break
                }
            }
            
            readingIndex = tempIndex
        } else {
            // No following hiragana to consider, take 1-2 characters as before
            let charsToTake = min(2, fullReading.distance(from: readingIndex, to: fullReading.endIndex))
            
            for _ in 0..<charsToTake {
                if readingIndex < fullReading.endIndex {
                    kanjiReading += String(fullReading[readingIndex])
                    readingIndex = fullReading.index(after: readingIndex)
                }
            }
        }
        
        return kanjiReading.isEmpty ? kanji : kanjiReading
    }
    
    
    
    // Helper to check if a string contains kanji
    private func containsKanji(_ text: String) -> Bool {
        let kanjiRange = 0x4E00...0x9FFF
        return text.unicodeScalars.contains { 
            kanjiRange.contains(Int($0.value))
        }
    }
}
