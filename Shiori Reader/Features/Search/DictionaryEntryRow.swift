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
            HStack(alignment: .center) {
                // Term with furigana reading above it
                VStack(alignment: .leading, spacing: 0) {
                    if !entry.reading.isEmpty && entry.reading != entry.term {
                        // Furigana reading
                        Text(entry.reading)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 1)
                    }
                    
                    // Main term
                    Text(entry.term)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                // Pitch accent graphs right after the word/reading (left-aligned)
                if entry.hasPitchAccent, let pitchAccents = entry.pitchAccents {
                    // Filter to only show graphs that match both term AND reading
                    let matchingAccents = pitchAccents.accents.filter { accent in
                        accent.term == entry.term && accent.reading == entry.reading
                    }
                    
                    if !matchingAccents.isEmpty {
                        // Show matching graphs side by side
                        HStack(alignment: .top, spacing: 6) {
                            ForEach(Array(matchingAccents.prefix(2)), id: \.id) { accent in
                                SimplePitchAccentGraphView(
                                    word: accent.term,
                                    reading: accent.reading,
                                    pitchValue: accent.pitchAccent
                                )
                            }
                        }
                        .padding(.leading, 8) // Small gap from the word
                    }
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
            
            // Dictionary source badges on their own line
            HStack {
                if entry.source == "obunsha" {
                    Text("旺文社")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                } else if entry.source == "jmdict" {
                    Text("JMdict")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                } else if entry.source == "combined" {
                    HStack(spacing: 4) {
                        Text("JMdict")
                            .font(.caption2)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(3)
                        Text("旺文社")
                            .font(.caption2)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(3)
                    }
                }
                
                Spacer()
            }
            .padding(.bottom, 2)
            
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
