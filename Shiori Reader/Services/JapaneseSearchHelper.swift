import Foundation
import ReadiumShared
import ReadiumNavigator
import IPADic
import Mecab_Swift

// MARK: - Japanese Search Helper

class JapaneseSearchHelper {
    static let shared = JapaneseSearchHelper()
    
    private let tokenizer: Mecab_Swift.Tokenizer?
    
    private init() {
        // Initialize MeCab tokenizer if possible
        do {
            let ipaDic = IPADic()
            tokenizer = try Tokenizer(dictionary: ipaDic)
            print("JapaneseSearchHelper: Successfully initialized MeCab tokenizer")
        } catch {
            print("JapaneseSearchHelper: Failed to initialize MeCab tokenizer: \(error)")
            tokenizer = nil
        }
    }
    
    /// Tokenize Japanese text to help with search
    func tokenizeText(_ text: String) -> [String] {
        guard let tokenizer = tokenizer else {
            // Fallback to simple character-by-character tokenization
            return text.map { String($0) }
        }
        
        // Use MeCab to tokenize
        let tokens = tokenizer.tokenize(text: text)
        return tokens.map { $0.base }
    }
    
    /// Check if the text contains Japanese characters
    func containsJapanese(_ text: String) -> Bool {
        // Check for Hiragana, Katakana, or Kanji
        let pattern = "[\\p{Hiragana}\\p{Katakana}\\p{Han}]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
    
    func getAllDictionaryForms(_ text: String) -> [String] { // Renamed for clarity
        guard let tokenizer = tokenizer, !text.isEmpty else {
            return [text].filter { !$0.isEmpty }
        }
        var uniqueForms: Set<String> = [text]
        let tokens = tokenizer.tokenize(text: text)
        for token in tokens {
            let dictForm = token.dictionaryForm
            if !dictForm.isEmpty {
                uniqueForms.insert(dictForm)
            }
        }
        let result = Array(uniqueForms)
        print("DEBUG [JapaneseSearchHelper]: All Dictionary forms for '\(text)': \(result)")
        return result
    }
    
    /// Attempts to find the dictionary form of the first primary content word (verb/adjective).
    /// Returns nil if no suitable token is found or if the dictionary form is empty.
    func getPrimaryDictionaryForm(_ text: String) -> String? {
        guard let tokenizer = tokenizer, !text.isEmpty else {
            return nil
        }
        let tokens = tokenizer.tokenize(text: text)

        // Find the first token that is a verb or adjective
        if let mainToken = tokens.first(where: { $0.partOfSpeech == .verb || $0.partOfSpeech == .adjective }) {
            let dictForm = mainToken.dictionaryForm
            // Return the dictionary form only if it's not empty
            if !dictForm.isEmpty {
                print("DEBUG [JapaneseSearchHelper]: Primary form found for '\(text)': \(dictForm)")
                return dictForm
            } else {
                 print("DEBUG [JapaneseSearchHelper]: Primary token (\(mainToken.base)) found for '\(text)', but dictionary form is empty.")
                 return nil
            }
        } else {
             print("DEBUG [JapaneseSearchHelper]: No primary verb/adjective token found in '\(text)'.")
            // Optional: Could add fallback to first noun here if desired
            return nil
        }
    }
}
