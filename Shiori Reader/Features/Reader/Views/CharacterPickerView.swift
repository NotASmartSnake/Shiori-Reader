import SwiftUI

struct CharacterPickerView: View {
    let currentText: String
    let selectedOffset: Int  // The current offset
    let onCharacterSelected: (String, Int) -> Void
    
    // Calculate the character ranges to display - improved with better bounds checking
    private func getCharactersToDisplay() -> [(character: String, offset: Int)] {
        guard !currentText.isEmpty else { return [] }
        
        var characters: [(character: String, offset: Int)] = []
        
        // Ensure selectedOffset is within valid bounds
        let safeSelectedOffset = max(0, min(selectedOffset, currentText.count - 1))
        
        // Helper function to safely get character at offset
        func safeCharacterAt(_ offset: Int) -> (character: String, isValid: Bool) {
            guard offset >= 0 && offset < currentText.count else {
                return ("", false)
            }
            let index = currentText.index(currentText.startIndex, offsetBy: offset)
            return (String(currentText[index]), true)
        }
        
        // Get 2 characters to the left
        for i in [-2, -1] {
            let targetIndex = safeSelectedOffset + i
            let (character, isValid) = safeCharacterAt(targetIndex)
            if isValid {
                characters.append((character, targetIndex))
            }
        }
        
        // Add current character
        let (currentChar, currentIsValid) = safeCharacterAt(safeSelectedOffset)
        if currentIsValid {
            characters.append((currentChar, safeSelectedOffset))
        }
        
        // Add 2 characters to the right
        for i in [1, 2] {
            let targetIndex = safeSelectedOffset + i
            let (character, isValid) = safeCharacterAt(targetIndex)
            if isValid {
                characters.append((character, targetIndex))
            }
        }
        
        return characters
    }
    
    var body: some View {
        HStack(spacing: 5) {
            ForEach(getCharactersToDisplay(), id: \.offset) { charInfo in
                Button(action: {
                    print("👉 PICKER: Selected character '\(charInfo.character)' with offset: \(charInfo.offset)")
                    onCharacterSelected(charInfo.character, charInfo.offset)
                }) {
                    Text(charInfo.character)
                        .font(.system(size: 18))
                        .padding(8)
                        .background(charInfo.offset == max(0, min(selectedOffset, currentText.count - 1)) ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(charInfo.offset == max(0, min(selectedOffset, currentText.count - 1)) ? .blue : .primary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 5)
    }
}
