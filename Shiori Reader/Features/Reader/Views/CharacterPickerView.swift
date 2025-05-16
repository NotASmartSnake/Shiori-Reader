//
//  CharacterPickerView.swift
//  Shiori Reader
//
//  Created by Claude on 5/16/25.
//

import SwiftUI

struct CharacterPickerView: View {
    let currentText: String
    let selectedOffset: Int  // The current offset
    let onCharacterSelected: (String, Int) -> Void
    
    // Calculate the character ranges to display - completely rewritten
    private func getCharactersToDisplay() -> [(character: String, offset: Int)] {
        guard !currentText.isEmpty else { return [] }
        
        var characters: [(character: String, offset: Int)] = []
        
        // Print debugging info
        print("✨ PICKER - Current text: \(currentText.prefix(20))...")
        print("✨ PICKER - Selected offset: \(selectedOffset)")
        
        // Get 2 characters to the left
        for i in [-2, -1] {
            let targetIndex = selectedOffset + i
            if targetIndex >= 0 && targetIndex < currentText.count {
                let index = currentText.index(currentText.startIndex, offsetBy: targetIndex)
                let character = String(currentText[index])
                characters.append((character, targetIndex))
                print("✨ PICKER - Adding Left Char: '\(character)' at offset \(targetIndex)")
            }
        }
        
        // Add current character
        if selectedOffset >= 0 && selectedOffset < currentText.count {
            let index = currentText.index(currentText.startIndex, offsetBy: selectedOffset)
            let character = String(currentText[index])
            characters.append((character, selectedOffset))
            print("✨ PICKER - Adding Current Char: '\(character)' at offset \(selectedOffset)")
        }
        
        // Add 2 characters to the right
        for i in [1, 2] {
            let targetIndex = selectedOffset + i
            if targetIndex < currentText.count {
                let index = currentText.index(currentText.startIndex, offsetBy: targetIndex)
                let character = String(currentText[index])
                characters.append((character, targetIndex))
                print("✨ PICKER - Adding Right Char: '\(character)' at offset \(targetIndex)")
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
                        .background(charInfo.offset == selectedOffset ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(charInfo.offset == selectedOffset ? .blue : .primary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 5)
    }
}