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
                .layoutPriority(1)  // Give term highest priority
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
                        .padding(.leading, 8)  // Small gap from the word
                        .layoutPriority(0)  // Lower priority than term
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

            // Dictionary source badges and frequency data with flow layout
            FlowLayout(spacing: 4) {
                // Frequency data first (if available and BCCWJ is enabled)
                if isBCCWJEnabled() {
                    ForEach(entry.frequencyData, id: \.source) { frequencyData in
                        getFrequencyBadge(
                            for: frequencyData.source, frequencyRank: "\(frequencyData.frequency)")
                    }
                }

                // Show dictionary badges based on source
                if entry.source == "combined" {
                    // For combined entries, show all available dictionary badges
                    let allEntries = getAllEntriesForWord()
                    let uniqueSources = Array(Set(allEntries.map { $0.source })).sorted()

                    ForEach(uniqueSources, id: \.self) { source in
                        getDictionarySourceBadge(for: source)
                    }
                } else {
                    // Single source entry
                    getDictionarySourceBadge(for: entry.source)
                }
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

    private func getAllEntriesForWord() -> [DictionaryEntry] {
        // Use the same lookup method as SearchViewModel to include imported dictionaries
        let allEntries = DictionaryManager.shared.lookupWithDeinflection(word: entry.term)
        return allEntries.filter { $0.term == entry.term && $0.reading == entry.reading }
    }

    @ViewBuilder
    private func getDictionarySourceBadge(for source: String) -> some View {
        let color = getDictionaryColor(for: source)

        if source == "jmdict" {
            Text("JMdict")
                .font(.caption2)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .cornerRadius(4)
        } else if source.hasPrefix("imported_") {
            let displayName = getImportedDictionaryDisplayName(source: source)

            Text(displayName)
                .font(.caption2)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .cornerRadius(4)
        } else {
            // Fallback for any other source types
            Text(source.capitalized)
                .font(.caption2)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .cornerRadius(4)
        }
    }

    @ViewBuilder
    private func getFrequencyBadge(for source: String, frequencyRank: String) -> some View {
        let color = getDictionaryColor(for: source)

        if source == "BCCWJ" {
            Text("BCCWJ: \(frequencyRank)")
                .font(.caption2)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .cornerRadius(4)
        } else if source.hasPrefix("imported_") {
            let displayName = getImportedDictionaryDisplayName(source: source)

            Text("\(displayName): \(frequencyRank)")
                .font(.caption2)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .cornerRadius(4)
        }
    }

    private func getImportedDictionaryDisplayName(source: String) -> String {
        // Extract UUID from source string (format: "imported_UUID")
        let importedId = source.replacingOccurrences(of: "imported_", with: "")
        if let uuid = UUID(uuidString: importedId) {
            let importedDictionaries = DictionaryImportManager.shared.getImportedDictionaries()
            if let dict = importedDictionaries.first(where: { $0.id == uuid }) {
                return dict.title
            }
        }
        return "Imported"
    }

    /// Check if BCCWJ frequency data is enabled in settings
    private func isBCCWJEnabled() -> Bool {
        // Simple struct to decode settings
        struct SimpleDictionarySettings: Codable {
            var enabledDictionaries: [String]
        }

        if let data = UserDefaults.standard.data(forKey: "dictionarySettings"),
            let settings = try? JSONDecoder().decode(SimpleDictionarySettings.self, from: data)
        {
            return settings.enabledDictionaries.contains("bccwj")
        }
        // Default to true for backward compatibility
        return true
    }
}
