//
//  JapaneseSearchHelper.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/4/25.
//

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
    
    /// Get the dictionary form of Japanese words to improve search
    func getDictionaryForms(_ text: String) -> [String] {
        guard let tokenizer = tokenizer else {
            return [text]
        }
        
        var results = [text] // Always include the original text
        
        // Get annotations for the text
        let tokens = tokenizer.tokenize(text: text)
        
        for token in tokens {
            // Use the reading and surface form instead of trying to access internal features
            // Most basic approach - just add the base form
            if token.base != token.reading && token.base != text {
                results.append(token.base)
            }
            
            // We don't have direct access to dictionary forms through the public API
            // so we'll just use the base forms which are still helpful
        }
        
        return results
    }
}
