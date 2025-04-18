//
//  EmptySavedWordsView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/18/25.
//

import SwiftUI

struct EmptySavedWordsView: View {
    var body: some View {
        VStack(spacing: 25) {
            // Icon
            Image(systemName: "rectangle.stack.fill.badge.plus")
                .font(.system(size: 70))
                .foregroundColor(.gray.opacity(0.7))
            
            // Title
            Text("No saved words")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Description
            Text("Words you save while reading will appear here for review and study")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Tips section
            VStack(alignment: .leading, spacing: 12) {
                Text("How to save words:")
                    .font(.headline)
                    .padding(.bottom, 5)
                
                tipRow(icon: "hand.tap", text: "Tap on a word while reading")
                tipRow(icon: "bookmark", text: "Select 'Save Word' in the dictionary view")
                tipRow(icon: "square.and.arrow.up", text: "Export your words to CSV for use in other apps (e.g. bulk export to Anki)")
                tipRow(icon: "plus.rectangle.on.rectangle", text: "Send individual words to Anki for spaced repetition study")
            }
            .padding(20)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.top, 5)
            .padding(.horizontal, 20)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.blue)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    EmptySavedWordsView()
}
