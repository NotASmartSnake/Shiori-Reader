//
//  DictionaryEntryRow.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/21/25.
//

import SwiftUI

// Component for dictionary entry row
struct DictionaryEntryRow: View {
    let entry: DictionaryEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.term)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if !entry.reading.isEmpty && entry.reading != entry.term {
                    Text("「\(entry.reading)」")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Optional: Show tags or indicators for word types
                if !entry.termTags.isEmpty {
                    Text(entry.termTags.first ?? "")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.7))
                        .cornerRadius(4)
                }
            }
            
            // Show first meaning
            Text(entry.meanings.first ?? "")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            // Indicate if there are more meanings
            if entry.meanings.count > 1 {
                Text("+\(entry.meanings.count - 1) more meanings")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}
