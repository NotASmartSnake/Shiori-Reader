import SwiftUI

struct DictionaryEntryView: View {
    let entry: DictionaryEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                // Word and reading section
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(entry.term)
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        if !entry.reading.isEmpty && entry.reading != entry.term {
                            Text("「\(entry.reading)」")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Compact pitch accent badges
                    if entry.hasPitchAccent {
                        PitchAccentBadgeView(pitchAccents: entry.pitchAccents!)
                    }
                }
                
                Spacer()
                
                // Pitch accent graphs on the right
                if entry.hasPitchAccent, let pitchAccents = entry.pitchAccents {
                    PitchAccentGraphsView(
                        pitchAccents: pitchAccents,
                        term: entry.term,
                        reading: entry.reading
                    )
                }
            }
            
            // Show detailed pitch accent information (can be removed if graphs are sufficient)
            // Uncomment the following if you want to keep the detailed text view alongside graphs
            /*
            if entry.hasPitchAccent, let pitchAccents = entry.pitchAccents {
                PitchAccentDetailView(pitchAccents: pitchAccents, term: entry.term, reading: entry.reading)
            }
            */
            
            if !entry.termTags.isEmpty {
                Text(entry.termTags.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.vertical, 2)
            }
            
            ForEach(0..<entry.meanings.count, id: \.self) { index in
                HStack(alignment: .top) {
                    Text("\(index + 1).")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text(entry.meanings[index])
                        .font(.body)
                }
            }
            
            Divider()
        }
        .padding(.vertical, 4)
    }
}

/// A compact badge showing pitch accent numbers
struct PitchAccentBadgeView: View {
    let pitchAccents: PitchAccentData
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(pitchAccents.allPatterns.prefix(3)), id: \.self) { pattern in
                Text("[\(pattern)]")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(pitchAccentColor(for: pattern))
                    .cornerRadius(4)
            }
            
            if pitchAccents.allPatterns.count > 3 {
                Text("+\(pitchAccents.allPatterns.count - 3)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func pitchAccentColor(for pattern: Int) -> Color {
        switch pattern {
        case 0:
            return .green  // Heiban (flat)
        case 1:
            return .orange // Atamadaka (head-high)
        default:
            return .blue   // Nakadaka (middle-high)
        }
    }
}

/// Detailed pitch accent information view
struct PitchAccentDetailView: View {
    let pitchAccents: PitchAccentData
    let term: String
    let reading: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Pitch Accent")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            ForEach(Array(pitchAccents.accents.prefix(3)), id: \.id) { accent in
                HStack {
                    Text("[\(accent.pitchAccent)]")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(pitchAccentColor(for: accent.pitchAccent))
                        .cornerRadius(4)
                    
                    Text(accent.accentTypeEnglish)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if accent.pitchAccent > 0 {
                        Text("(drop after mora \(accent.pitchAccent))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if pitchAccents.accents.count > 3 {
                Text("+ \(pitchAccents.accents.count - 3) more pattern(s)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }
    
    private func pitchAccentColor(for pattern: Int) -> Color {
        switch pattern {
        case 0:
            return .green  // Heiban (flat)
        case 1:
            return .orange // Atamadaka (head-high)
        default:
            return .blue   // Nakadaka (middle-high)
        }
    }
}
