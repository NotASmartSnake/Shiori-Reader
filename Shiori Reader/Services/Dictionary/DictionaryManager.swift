import Foundation
import GRDB

class DictionaryManager {
    static let shared = DictionaryManager()
    
    private var dbQueue: DatabaseQueue?
    private var deinflector: Deinflector?
    
    private init() {
        setupDatabase()
        deinflector = loadDeinflector()
    }
    
    private func setupDatabase() {
        do {
            if let dictionaryPath = Bundle.main.path(forResource: "jmdict", ofType: "db") {
                // Configure database options
                var configuration = Configuration()
                configuration.readonly = true // Dictionary is read-only
                
                // Create database queue
                dbQueue = try DatabaseQueue(path: dictionaryPath, configuration: configuration)
                print("Dictionary database loaded successfully")
            } else {
                print("Dictionary database not found in bundle")
            }
        } catch {
            print("Error setting up database: \(error)")
        }
    }
    
    private func loadDeinflector() -> Deinflector? {
        guard let url = Bundle.main.url(forResource: "deinflect", withExtension: "json") else {
            print("Could not find deinflect.json file")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            return Deinflector.loadFromJSON(data)
        } catch {
            print("Error loading deinflection data: \(error)")
            return nil
        }
    }
    
    func lookup(word: String) -> [DictionaryEntry] {
        guard let db = dbQueue else { return [] }
        
        var entries: [DictionaryEntry] = []
        
        do {
            try db.read { db in
                // Query terms that match the word (either expression or reading)
                let rows = try Row.fetchAll(db, sql: """
                    SELECT t.id, t.expression, t.reading, t.term_tags, t.score, t.rules, d.definition, t.popularity
                    FROM terms t
                    JOIN definitions d ON t.id = d.term_id
                    WHERE t.expression = ? OR t.reading = ?
                    ORDER BY t.id, d.id
                    """, arguments: [word, word])
                
                var currentTermId: Int64?
                var currentEntry: DictionaryEntry?
                
                for row in rows {
                    let termId = row["id"] as? Int64 ?? 0
                    let expression = row["expression"] as? String ?? ""
                    let reading = row["reading"] as? String ?? ""
                    let tags = row["term_tags"] as? String ?? ""
                    let score = row["score"] as? String
                    let rules = row["rules"] as? String
                    let definitionText = row["definition"] as? String ?? ""
                    let popularity = row["popularity"] as? Double ?? 0.0
                    
                    // If we're still working with the same term
                    if currentTermId == termId {
                        currentEntry?.meanings.append(definitionText)
                    } else {
                        // Save the previous entry if it exists
                        if let entry = currentEntry {
                            entries.append(entry)
                        }
                        
                        // Create a new entry
                        currentEntry = DictionaryEntry(
                            id: "\(termId)",
                            term: expression,
                            reading: reading,
                            meanings: [definitionText],
                            meaningTags: [],
                            termTags: tags.split(separator: ",").map(String.init),
                            score: score,
                            rules: rules,
                            popularity: popularity
                        )
                        currentTermId = termId
                    }
                }
                
                // Add the last entry if it exists
                if let entry = currentEntry {
                    entries.append(entry)
                }
            }
        } catch {
            print("Error looking up word: \(error)")
        }
        
        return sortEntriesByPopularity(entries)
    }
    
    func lookupWithDeinflection(word: String) -> [DictionaryEntry] {
        var allEntries: [DictionaryEntry] = []
        
        // First try direct lookup
        let directEntries = lookup(word: word)
        allEntries.append(contentsOf: directEntries)
        
        // Enhanced debug logging for problematic words
        let debugWords = ["よ", "よって", "陽", "杳", "防ぎ", "防ぎきれない"]
        let shouldDebug = debugWords.contains(word)
        
        if shouldDebug {
            print("🔍 [DEBUG] Enhanced lookup for '\(word)': found \(directEntries.count) direct entries")
            for (index, entry) in directEntries.enumerated() {
                print("   Direct[\(index)]: \(entry.term) (\(entry.reading)) - \(entry.meanings.first ?? "no meaning")")
                if let rules = entry.rules {
                    print("      Rules: \(rules)")
                }
            }
        }
        
        // Always try deinflections if we have them (not just when no direct entries)
        if let deinflector = self.deinflector {
            if shouldDebug {
                print("🔍 [DEBUG] Also trying deinflection for '\(word)'...")
            }
            
            let deinflections = deinflector.deinflect(word)
            
            for result in deinflections {
                // Skip the original form since we already looked it up
                if result.term == word && result.reasons.isEmpty {
                    continue
                }
                
                let entries = lookup(word: result.term)
                
                if shouldDebug && !entries.isEmpty {
                    print("🔍 [DEBUG] Deinflection '\(result.term)' found \(entries.count) entries via: \(result.reasons.joined(separator: " ← "))")
                    for entry in entries {
                        let verbCheck = isVerbEntry(entry) ? "[VERB]" : ""
                        let adjCheck = isAdjectiveEntry(entry) ? "[ADJ-I]" : ""
                        let posInfo = !verbCheck.isEmpty || !adjCheck.isEmpty ? " \(verbCheck)\(adjCheck)" : ""
                        print("      \(entry.term) (\(entry.reading))\(posInfo) - \(entry.meanings.first ?? "no meaning")")
                    }
                }
                
                // Add entries found through deinflection
                for entry in entries {
                    let enhancedEntry = DictionaryEntry(
                        id: entry.id,
                        term: entry.term,
                        reading: entry.reading,
                        meanings: entry.meanings,
                        meaningTags: entry.meaningTags,
                        termTags: entry.termTags,
                        score: entry.score,
                        rules: entry.rules,
                        transformed: word,
                        transformationNotes: result.reasons.joined(separator: " ← "),
                        popularity: entry.popularity
                    )
                    allEntries.append(enhancedEntry)
                }
            }
        }
        
        // Apply conservative filtering to reduce false positives
        let filteredEntries = applyConservativeFiltering(allEntries, originalWord: word)
        
        if shouldDebug {
            print("🔍 [DEBUG] After filtering: \(filteredEntries.count) entries (from \(allEntries.count))")
            print("🔍 [DEBUG] Filtering details:")
            for (index, entry) in filteredEntries.enumerated() {
                let transformInfo = entry.transformed != nil ? " [\(entry.transformationNotes ?? "transformed")]" : " [direct]"
                let rules = entry.rules ?? "no-rules"
                let tags = entry.termTags.joined(separator: ",")
                print("   Final[\(index)]: \(entry.term) (\(entry.reading))\(transformInfo)")
                print("      Rules: \(rules), Tags: \(tags)")
            }
        }
        
        return sortEntriesByPopularity(filteredEntries)
    }
    
    /// Apply conservative filtering to reduce obvious false positives while preserving legitimate results
    private func applyConservativeFiltering(_ entries: [DictionaryEntry], originalWord: String) -> [DictionaryEntry] {
        // If we have very few entries, don't filter to avoid removing valid results
        if entries.count <= 3 {
            return entries
        }
        
        var groupedEntries: [String: [DictionaryEntry]] = [:]
        
        // Group entries by term-reading combination for better deduplication
        for entry in entries {
            let groupKey = "\(entry.term)-\(entry.reading)"
            if groupedEntries[groupKey] == nil {
                groupedEntries[groupKey] = []
            }
            groupedEntries[groupKey]?.append(entry)
        }
        
        var filteredResults: [DictionaryEntry] = []
        
        // Take the best entry from each group
        for (_, groupEntries) in groupedEntries {
            // Sort group entries and take the first (best) one
            let sortedGroup = sortEntriesByPopularity(groupEntries)
            if let bestEntry = sortedGroup.first {
                filteredResults.append(bestEntry)
            }
        }
        
        // Only apply part-of-speech filtering for deinflected entries to avoid breaking direct lookups
        let conservativeFiltered = filteredResults.filter { entry in
            // Always keep direct matches (no transformation)
            if entry.transformed == nil {
                return true
            }
            
            // For transformed entries, check if the deinflected form matches the original search term
            // If it does, it means we're showing results for a direct search (e.g., searching "よ" directly)
            // In this case, we should show all results including nouns
            if entry.term == originalWord {
                return true
            }
            
            // Debug logging for specific problematic entries
            let isProblematic = ["幼", "用", "四つ", "要", "益", "洋", "癰", "容", "俑", "４つ"].contains(entry.term)
            if isProblematic {
                print("🔍 [FILTER DEBUG] Checking \(entry.term): rules='\(entry.rules ?? "nil")', tags='\(entry.termTags.joined(separator: " "))', originalWord='\(originalWord)'")
            }
            
            // For transformed entries that are NOT the original search term (true deinflections),
            // check if they can actually be conjugated
            
            // First check rules field (most reliable for conjugatable entries)
            if let rules = entry.rules, !rules.isEmpty {
                let lowerRules = rules.lowercased()
                // If it has conjugatable rules, keep it
                if lowerRules.contains("v1") || lowerRules.contains("v5") || lowerRules.contains("vs") ||
                   lowerRules.contains("vk") || lowerRules.contains("vz") || lowerRules.contains("adj-i") {
                    if isProblematic {
                        print("   → KEPT: Has conjugatable rules")
                    }
                    return true
                }
            }
            
            // Parse termTags properly (they're space-separated and may have quotes)
            let tagString = entry.termTags.joined(separator: " ")
            // Remove quotes and split by whitespace
            let cleanedTagString = tagString.replacingOccurrences(of: "\"", with: "")
            let individualTags = cleanedTagString.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            if isProblematic {
                print("   → Individual tags: \(individualTags)")
            }
            
            // Check for conjugatable tags
            let hasConjugatableTags = individualTags.contains { tag in
                let lowerTag = tag.lowercased()
                return lowerTag == "v1" || lowerTag == "v5" || lowerTag == "vs" ||
                       lowerTag == "vk" || lowerTag == "vz" || lowerTag == "vi" ||
                       lowerTag == "vt" || lowerTag == "adj-i" ||  // Only i-adjectives are conjugatable
                       lowerTag.hasPrefix("v5") || lowerTag.hasPrefix("v1") // v5r, v5u, etc.
            }
            
            if hasConjugatableTags {
                if isProblematic {
                    print("   → KEPT: Has conjugatable tags")
                }
                return true
            }
            
            // Filter out entries that are clearly non-conjugatable
            let hasNonConjugatableTags = individualTags.contains { tag in
                let lowerTag = tag.lowercased()
                return lowerTag == "n" ||           // noun
                       lowerTag == "pn" ||          // proper noun
                       lowerTag == "num" ||         // number
                       lowerTag == "ctr" ||         // counter
                       lowerTag == "exp" ||         // expression
                       lowerTag == "int" ||         // interjection
                       lowerTag == "conj" ||        // conjunction
                       lowerTag == "part" ||        // particle
                       lowerTag == "pref" ||        // prefix
                       lowerTag == "suf" ||         // suffix
                       lowerTag == "n-suf" ||       // noun suffix
                       lowerTag == "adv" ||         // adverb
                       lowerTag == "aux-v" ||       // auxiliary verb (usually not conjugatable in the same way)
                       lowerTag == "adj-t" ||       // adjectival noun (na-adjective) - not conjugatable like i-adjectives
                       lowerTag == "adj-no" ||      // noun taking 'no' - not conjugatable
                       lowerTag == "adj-na" ||      // na-adjective - not conjugatable like i-adjectives
                       lowerTag == "adj-pn" ||      // pre-noun adjective - not conjugatable
                       lowerTag == "adj-f" ||       // noun taking genitive case - not conjugatable
                       lowerTag.hasPrefix("adj-") && lowerTag != "adj-i" // Any other adjective type except i-adjectives
            }
            
            // If it has non-conjugatable tags and no conjugatable ones, filter it out
            if hasNonConjugatableTags {
                if isProblematic {
                    print("   → FILTERED OUT: Has non-conjugatable tags (not original search term)")
                }
                return false
            }
            
            // If we can't determine, err on the side of caution and keep it
            // This handles cases where entries might not have clear tagging
            if isProblematic {
                print("   → KEPT: Unclear tagging, erring on side of caution")
            }
            return true
        }
        
        return conservativeFiltered
    }
    // Advanced lookup with prefix matching
    func searchByPrefix(prefix: String, limit: Int = 10) -> [DictionaryEntry] {
        guard let db = dbQueue else { return [] }
        
        var entries: [DictionaryEntry] = []
        
        do {
            try db.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT DISTINCT t.id, t.expression, t.reading, t.term_tags, t.score, t.rules, t.popularity
                    FROM terms t
                    WHERE t.expression LIKE ? || '%' OR t.reading LIKE ? || '%'
                    ORDER BY t.sequence, t.id
                    LIMIT ?
                    """, arguments: [prefix, prefix, limit])
                
                for row in rows {
                    let termId = row["id"] as? Int64 ?? 0
                    let expression = row["expression"] as? String ?? ""
                    let reading = row["reading"] as? String ?? ""
                    let tags = row["term_tags"] as? String ?? ""
                    let score = row["score"] as? String
                    let rules = row["rules"] as? String
                    let popularity = row["popularity"] as? Double ?? 0.0
                    
                    // Fetch definitions for this term
                    let definitions = try String.fetchAll(db, sql: """
                        SELECT definition FROM definitions
                        WHERE term_id = ?
                        ORDER BY id
                        """, arguments: [termId])
                    
                    let entry = DictionaryEntry(
                        id: "\(termId)",
                        term: expression,
                        reading: reading,
                        meanings: definitions,
                        meaningTags: [],
                        termTags: tags.split(separator: ",").map(String.init),
                        score: score,
                        rules: rules,
                        popularity: popularity
                    )
                    
                    entries.append(entry)
                }
            }
        } catch {
            print("Error searching by prefix: \(error)")
        }
        
        return entries
    }
    
    // Search by English meaning
    func searchByMeaning(text: String, limit: Int = 20) -> [DictionaryEntry] {
        guard let db = dbQueue else { return [] }
        
        var entries: [DictionaryEntry] = []
        let searchTerm = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            try db.read { db in
                // Build query that prioritizes exact word matches
                let sql = """
                    SELECT DISTINCT t.id, t.expression, t.reading, t.term_tags, t.score, t.rules, t.popularity,
                        (CASE
                            WHEN d.definition LIKE '% \(searchTerm) %' OR d.definition LIKE '\(searchTerm) %' OR d.definition LIKE '% \(searchTerm)' OR d.definition = '\(searchTerm)' THEN 1
                            WHEN d.definition LIKE '%\(searchTerm)%' THEN 2
                            ELSE 3
                        END) AS match_quality
                    FROM terms t
                    JOIN definitions d ON t.id = d.term_id
                    WHERE d.definition LIKE '%\(searchTerm)%'
                    ORDER BY match_quality, t.popularity DESC, t.sequence
                    LIMIT ?
                    """
                
                let rows = try Row.fetchAll(db, sql: sql, arguments: [limit])
                
                for row in rows {
                    let termId = row["id"] as? Int64 ?? 0
                    let expression = row["expression"] as? String ?? ""
                    let reading = row["reading"] as? String ?? ""
                    let tags = row["term_tags"] as? String ?? ""
                    let score = row["score"] as? String
                    let rules = row["rules"] as? String
                    let popularity = row["popularity"] as? Double ?? 0.0
                    
                    // Fetch all definitions for this term
                    let definitions = try String.fetchAll(db, sql: """
                        SELECT definition FROM definitions
                        WHERE term_id = ?
                        ORDER BY id
                        """, arguments: [termId])
                    
                    // Filter out false positive matches
                    let containsExactMatch = definitions.contains { definition in
                        let lowerDef = definition.lowercased()
                        
                        // Check for exact phrase match
                        if lowerDef.contains(" \(searchTerm) ") ||
                           lowerDef.hasPrefix("\(searchTerm) ") ||
                           lowerDef.hasSuffix(" \(searchTerm)") ||
                           lowerDef == searchTerm {
                            return true
                        }
                        
                        // Check for word boundary matches with punctuation
                        let defWords = lowerDef.components(separatedBy: CharacterSet.alphanumerics.inverted)
                        return defWords.contains(searchTerm)
                    }
                    
                    // Only add entries where the search term appears as a complete word
                    // or include partial matches if we have very few results
                    if containsExactMatch || entries.count < 5 {
                        let entry = DictionaryEntry(
                            id: "\(termId)",
                            term: expression,
                            reading: reading,
                            meanings: definitions,
                            meaningTags: [],
                            termTags: tags.split(separator: ",").map(String.init),
                            score: score,
                            rules: rules,
                            popularity: popularity
                        )
                        
                        entries.append(entry)
                    }
                }
            }
        } catch {
            print("Error searching by meaning: \(error)")
        }
        
        return sortEntriesByPopularity(entries)
    }
    
    func sortEntriesByPopularity(_ entries: [DictionaryEntry]) -> [DictionaryEntry] {
        return entries.sorted { first, second in
            // 1. Direct matches (no transformation) first
            let firstIsDirect = first.transformed == nil
            let secondIsDirect = second.transformed == nil
            if firstIsDirect != secondIsDirect {
                return firstIsDirect
            }
            
            // 2. Exact reading matches (for transformed entries)
            if !firstIsDirect && !secondIsDirect {
                let firstExactReading = first.transformed == first.reading
                let secondExactReading = second.transformed == second.reading
                if firstExactReading != secondExactReading {
                    return firstExactReading
                }
                
                // 3. Simple transformations over complex ones
                let firstTransformationCount = first.transformationNotes?.components(separatedBy: " ← ").count ?? 0
                let secondTransformationCount = second.transformationNotes?.components(separatedBy: " ← ").count ?? 0
                if firstTransformationCount != secondTransformationCount {
                    return firstTransformationCount < secondTransformationCount
                }
            }
            
            // 4. Popularity scores (higher values indicate more common terms)
            if let firstPop = first.popularity, let secondPop = second.popularity,
               abs(firstPop - secondPop) > 0.001 {
                return firstPop > secondPop
            }
            
            // 5. Frequency tags in the score column
            let firstScore = getScoreValue(from: first.score)
            let secondScore = getScoreValue(from: second.score)
            if firstScore != secondScore {
                // Lower scores indicate higher priority
                return firstScore < secondScore
            }
            
            // 6. Non-archaic entries preferred
            let firstHasArchaism = hasArchaism(in: first.score)
            let secondHasArchaism = hasArchaism(in: second.score)
            if firstHasArchaism != secondHasArchaism {
                return !firstHasArchaism
            }
            
            // 7. Shorter terms preferred
            return first.term.count < second.term.count
        }
    }

    // Helper function to interpret score value
    private func getScoreValue(from scoreTag: String?) -> Int {
        guard let scoreTag = scoreTag else { return 0 }
        
        if scoreTag.contains("⭐") {
            return -10  // Higher priority
        }
        
        if scoreTag.contains("news") ||
           scoreTag.contains("ichi") ||
           scoreTag.contains("spec") ||
           scoreTag.contains("gai") {
            return -2
        }
        
        if scoreTag.contains("P") {
            return -5  // Common word indicator
        }
        
        return 0
    }

    // Helper function to check for archaism in score
    private func hasArchaism(in scoreTag: String?) -> Bool {
        guard let scoreTag = scoreTag else { return false }
        
        return scoreTag.contains("R") ||
               scoreTag.contains("r") ||
               scoreTag.contains("⚠️") ||
               scoreTag.contains("⛬") ||
               scoreTag.contains("arch") ||
               scoreTag.contains("obso")
    }
    
    // MARK: - Part-of-Speech Detection Helper Functions
    
    /// Check if entry is a verb using both rules and termTags
    private func isVerbEntry(_ entry: DictionaryEntry) -> Bool {
        // Check rules field first (more reliable)
        if let rules = entry.rules {
            let lowerRules = rules.lowercased()
            if lowerRules.contains("v1") ||      // ichidan verb
               lowerRules.contains("v5") ||      // godan verb
               lowerRules.contains("vs") ||      // suru verb
               lowerRules.contains("vk") ||      // kuru verb
               lowerRules.contains("vz") ||      // zuru verb
               lowerRules.contains("vi") ||      // intransitive verb
               lowerRules.contains("vt") ||      // transitive verb
               lowerRules.contains("verb") {
                return true
            }
        }
        
        // Fallback to termTags
        let tags = entry.termTags.map { $0.lowercased() }
        return tags.contains { tag in
            tag.contains("v1") || tag.contains("v5") || tag.contains("vs") ||
            tag.contains("vk") || tag.contains("vz") || tag.contains("vi") ||
            tag.contains("vt") || tag.contains("verb")
        }
    }
    
    /// Check if entry is an i-adjective using both rules and termTags
    private func isAdjectiveEntry(_ entry: DictionaryEntry) -> Bool {
        // Check rules field first (more reliable)
        if let rules = entry.rules {
            let lowerRules = rules.lowercased()
            if lowerRules.contains("adj-i") ||   // i-adjective
               lowerRules.contains("adj-ix") ||  // irregular i-adjective
               lowerRules.contains("i-adj") {
                return true
            }
        }
        
        // Fallback to termTags
        let tags = entry.termTags.map { $0.lowercased() }
        return tags.contains { tag in
            tag.contains("adj-i") || tag.contains("adj-ix") || tag.contains("i-adj")
        }
    }
    
}
