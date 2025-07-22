import Foundation

/// Represents a pitch accent entry for a Japanese word
struct PitchAccent: Identifiable, Equatable, Hashable {
    let id = UUID()
    let term: String          // The Japanese word/expression
    let reading: String       // The reading (hiragana/katakana)
    let pitchAccent: Int      // Pitch accent number (0 = heiban, 1+ = accent position)
    
    /// Returns the English name for this accent type
    var accentTypeEnglish: String {
        switch pitchAccent {
        case 0:
            return "Flat (Heiban)"
        case 1:
            return "Head-high (Atamadaka)"
        default:
            return "Middle-high (Nakadaka)"
        }
    }
    
    static func == (lhs: PitchAccent, rhs: PitchAccent) -> Bool {
        return lhs.term == rhs.term && 
               lhs.reading == rhs.reading && 
               lhs.pitchAccent == rhs.pitchAccent
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(term)
        hasher.combine(reading)
        hasher.combine(pitchAccent)
    }
}

/// Represents pitch accent data associated with a dictionary entry
struct PitchAccentData {
    let accents: [PitchAccent]
    
    var isEmpty: Bool {
        return accents.isEmpty
    }
    
    /// Returns the primary (most common) pitch accent
    var primary: PitchAccent? {
        return accents.first
    }
    
    /// Returns all pitch accent patterns for display
    var allPatterns: [Int] {
        return accents.map { $0.pitchAccent }
    }
}
