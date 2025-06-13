//
//  JapanesePitchAccentUtils.swift
//  Shiori Reader
//
//  Created by Claude on 6/13/25.
//

import Foundation

/// Utilities for handling Japanese text in the context of pitch accent visualization
struct JapanesePitchAccentUtils {
    
    /// Extract mora from Japanese text more accurately
    static func extractMora(from text: String) -> [String] {
        var mora: [String] = []
        var i = text.startIndex
        
        while i < text.endIndex {
            let char = String(text[i])
            
            // Skip if it's a long vowel mark and we already have mora
            if char == "ー" && !mora.isEmpty {
                // Extend the previous mora rather than creating a new one
                let lastIndex = mora.count - 1
                mora[lastIndex] += char
                i = text.index(after: i)
                continue
            }
            
            // Check if next character is a small kana
            let nextIndex = text.index(after: i)
            if nextIndex < text.endIndex {
                let nextChar = String(text[nextIndex])
                if isSmallKana(nextChar) {
                    mora.append(char + nextChar)
                    i = text.index(after: nextIndex)
                    continue
                }
            }
            
            // Handle contracted sounds and special combinations
            if nextIndex < text.endIndex {
                let combination = char + String(text[nextIndex])
                if isSpecialCombination(combination) {
                    mora.append(combination)
                    i = text.index(after: nextIndex)
                    continue
                }
            }
            
            mora.append(char)
            i = nextIndex
        }
        
        return mora
    }
    
    /// Check if character is a small kana (ゃゅょっ etc.)
    private static func isSmallKana(_ char: String) -> Bool {
        let smallKana: Set<String> = [
            // Hiragana small characters
            "ぁ", "ぃ", "ぅ", "ぇ", "ぉ",
            "ゃ", "ゅ", "ょ", "っ",
            // Katakana small characters  
            "ァ", "ィ", "ゥ", "ェ", "ォ",
            "ャ", "ュ", "ョ", "ッ"
        ]
        return smallKana.contains(char)
    }
    
    /// Check for special combinations that form single mora
    private static func isSpecialCombination(_ combination: String) -> Bool {
        // This could be expanded for more complex mora combinations
        // For now, we rely mainly on the small kana detection
        return false
    }
    
    /// Convert pitch accent number to human-readable type
    static func accentTypeName(for pitchValue: Int, english: Bool = true) -> String {
        switch pitchValue {
        case 0:
            return english ? "Flat" : "平板"
        case 1:
            return english ? "Head-high" : "頭高"
        default:
            return english ? "Middle-high" : "中高"
        }
    }
    
    /// Generate pitch pattern array for visualization
    static func generatePitchPattern(moraCount: Int, pitchValue: Int) -> [String] {
        guard moraCount >= 1 else { return [] }
        
        if pitchValue == 0 {
            // Heiban (flat) - L followed by all H
            return ["L"] + Array(repeating: "H", count: moraCount)
        } else if pitchValue == 1 {
            // Atamadaka (head-high) - H followed by all L
            return ["H"] + Array(repeating: "L", count: moraCount)
        } else if pitchValue >= 2 && pitchValue <= moraCount {
            // Nakadaka (middle-high) - L, then H up to the drop point, then L
            var pattern = ["L", "H"]
            
            // Add H's up to the pitch accent position (drop occurs AFTER this position)
            for i in 2..<pitchValue {
                pattern.append("H")
            }
            
            // Add L for the drop
            pattern.append("L")
            
            // Add remaining L's for the rest of the mora
            let remainingMora = moraCount - pitchValue
            if remainingMora > 0 {
                pattern.append(contentsOf: Array(repeating: "L", count: remainingMora))
            }
            
            return pattern
        }
        
        return []
    }
    
    /// Validate if a pitch accent pattern makes sense for the given word
    static func isValidPitchPattern(moraCount: Int, pitchValue: Int) -> Bool {
        // Pitch value should not exceed mora count + 1
        return pitchValue >= 0 && pitchValue <= moraCount
    }
    
    /// Get color for pitch accent type
    static func colorForPitchAccent(_ pitchValue: Int) -> String {
        switch pitchValue {
        case 0:
            return "green"  // Heiban (flat)
        case 1:
            return "orange" // Atamadaka (head-high)
        default:
            return "blue"   // Nakadaka (middle-high)
        }
    }
}
