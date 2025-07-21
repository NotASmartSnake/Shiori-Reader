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
                // Term with furigana reading above it - gets layout priority
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
                .layoutPriority(1) // Give term highest priority
                .fixedSize(horizontal: false, vertical: true)
                
                // Pitch accent graphs in horizontal scroll view
                if entry.hasPitchAccent, let pitchAccents = entry.pitchAccents {
                    // Filter to only show graphs that match both term AND reading
                    let matchingAccents = pitchAccents.accents.filter { accent in
                        accent.term == entry.term && accent.reading == entry.reading
                    }
                    
                    if !matchingAccents.isEmpty {
                        // Scrollable container for pitch accent graphs
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 6) {
                                ForEach(Array(matchingAccents), id: \.id) { accent in
                                    SimplePitchAccentGraphView(
                                        word: accent.term,
                                        reading: accent.reading,
                                        pitchValue: accent.pitchAccent
                                    )
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        .padding(.leading, 8) // Small gap from the word
                        .layoutPriority(0) // Lower priority than term
                    }
                }
                
                Spacer(minLength: 8)
                
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
            
            // Dictionary source badges and frequency data on their own line
            HStack(spacing: 4) {
                // Frequency data first (if available and BCCWJ is enabled)
                if isBCCWJEnabled(), let frequencyRank = entry.frequencyRankString {
                    Text(frequencyRank)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }
                
                if entry.source == "obunsha" {
                    let color = getDictionaryColor(for: "obunsha")
                    Text("旺文社")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(color.opacity(0.2))
                        .foregroundColor(color)
                        .cornerRadius(4)
                } else if entry.source == "jmdict" {
                    let color = getDictionaryColor(for: "jmdict")
                    Text("JMdict")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(color.opacity(0.2))
                        .foregroundColor(color)
                        .cornerRadius(4)
                } else if entry.source == "combined" {
                    let jmdictColor = getDictionaryColor(for: "jmdict")
                    let obunshaColor = getDictionaryColor(for: "obunsha")
                    HStack(spacing: 4) {
                        Text("JMdict")
                            .font(.caption2)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(jmdictColor.opacity(0.2))
                            .foregroundColor(jmdictColor)
                            .cornerRadius(3)
                        Text("旺文社")
                            .font(.caption2)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(obunshaColor.opacity(0.2))
                            .foregroundColor(obunshaColor)
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
    
    private func getDictionaryColor(for source: String) -> Color {
        return DictionaryColorProvider.shared.getColor(for: source)
    }
    
    /// Check if BCCWJ frequency data is enabled in settings
    private func isBCCWJEnabled() -> Bool {
        // Simple struct to decode settings
        struct SimpleDictionarySettings: Codable {
            var enabledDictionaries: [String]
        }
        
        if let data = UserDefaults.standard.data(forKey: "dictionarySettings"),
           let settings = try? JSONDecoder().decode(SimpleDictionarySettings.self, from: data) {
            return settings.enabledDictionaries.contains("bccwj")
        }
        // Default to true for backward compatibility
        return true
    }
}
