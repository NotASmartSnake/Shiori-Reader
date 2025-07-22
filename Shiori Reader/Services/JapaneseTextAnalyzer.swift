
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
    
    // Format word with reading using MeCab's furigana annotations
    func formatWordWithReading(word: String, reading: String) -> String {
        // Get furigana annotations
        let annotations = tokenizer.furiganaAnnotations(for: word, 
                                                      transliteration: .hiragana, 
                                                      options: [.kanjiOnly])
        
        if annotations.isEmpty {
            // If no annotations (all hiragana or no kanji), return the word
            return word
        }
        
        // Create a mutable copy of the word
        var result = word
        
        // Process annotations in reverse order to avoid index shifting
        for annotation in annotations.reversed() {
            let range = annotation.range
            // Insert the reading in brackets after the kanji
            result.insert(contentsOf: "[\(annotation.reading)]", at: range.upperBound)
        }
        
        return result
    }
    
    // Alternative implementation if the range approach doesn't work well
    func formatWordWithReadingAlternative(word: String, reading: String) -> String {
        // Tokenize the word
        let tokens = tokenizer.tokenize(text: word, transliteration: .hiragana)
        
        // Build the result with readings
        var result = ""
        
        for token in tokens {
            let base = token.base
            let tokenReading = token.reading
            
            // Check if the token contains kanji
            if containsKanji(base) && base != tokenReading {
                result += "\(base)[\(tokenReading)]"
            } else {
                result += base
            }
        }
        
        return result
    }
    
    // Helper to check if a string contains kanji
    private func containsKanji(_ text: String) -> Bool {
        let kanjiRange = 0x4E00...0x9FFF
        return text.unicodeScalars.contains { 
            kanjiRange.contains(Int($0.value))
        }
    }
}
