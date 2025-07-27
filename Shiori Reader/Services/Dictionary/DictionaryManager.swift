import Foundation
import GRDB

class DictionaryManager {
    static let shared = DictionaryManager()
    
    private var jmdictQueue: DatabaseQueue?
    private var obunshaQueue: DatabaseQueue?
    private var deinflector: Deinflector?
    private let pitchAccentManager = PitchAccentManager.shared
    private let frequencyManager = FrequencyManager.shared
    private let settingsKey = "dictionarySettings"
    
    private init() {
        setupDatabase()
        deinflector = loadDeinflector()
    }
    
    private func setupDatabase() {
        do {
            // Setup JMdict database
            if let jmdictPath = Bundle.main.path(forResource: "jmdict", ofType: "db") {
                var configuration = Configuration()
                configuration.readonly = true
                jmdictQueue = try DatabaseQueue(path: jmdictPath, configuration: configuration)
            } else {
                print("JMdict database not found in bundle")
            }
            
            // Setup Obunsha database
            if let obunshaPath = Bundle.main.path(forResource: "obunsha", ofType: "db") {
                var configuration = Configuration()
                configuration.readonly = true
                obunshaQueue = try DatabaseQueue(path: obunshaPath, configuration: configuration)
                print("Obunsha database loaded successfully")
            } else {
                print("Obunsha database not found in bundle")
            }
        } catch {
            print("Error setting up databases: \(error)")
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
    
    /// Get currently enabled dictionaries from user settings
    func getEnabledDictionaries() -> [String] {
        // Simple struct to decode settings
        struct SimpleDictionarySettings: Codable {
            var enabledDictionaries: [String]
        }
        
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(SimpleDictionarySettings.self, from: data) {
            return settings.enabledDictionaries
        }
        // Default to all dictionaries enabled
        return ["jmdict", "obunsha", "bccwj"]
    }
    
    /// Check if BCCWJ frequency data is enabled
    private func isBCCWJEnabled() -> Bool {
        return getEnabledDictionaries().contains("bccwj")
    }
    
    /// Create dictionary entry with lazy-loaded pitch accents and frequency data
    private func createDictionaryEntry(
        id: String,
        term: String,
        reading: String,
        meanings: [String],
        meaningTags: [String],
        termTags: [String],
        score: String?,
        rules: String?,
        transformed: String? = nil,
        transformationNotes: String? = nil,
        popularity: Double?,
        source: String = "jmdict"
    ) -> DictionaryEntry {
        // Create entry without pitch accents - they will load lazily when accessed
        var entry = DictionaryEntry(
            id: id,
            term: term,
            reading: reading,
            meanings: meanings,
            meaningTags: meaningTags,
            termTags: termTags,
            score: score,
            rules: rules,
            transformed: transformed,
            transformationNotes: transformationNotes,
            popularity: popularity,
            source: source
        )
        
        // Add frequency data if available and BCCWJ is enabled
        if isBCCWJEnabled(), let frequencyData = frequencyManager.getFrequencyData(for: term) {
            entry.frequencyData = frequencyData
        }
        
        // Pitch accents will be loaded lazily via the computed property
        return entry
    }
    

    
    /// Lookup from JMdict database
    private func lookupJMdict(word: String) -> [DictionaryEntry] {
        guard let db = jmdictQueue else { return [] }
        
        var entries: [DictionaryEntry] = []
        
        do {
            try db.read { db in
                // Simple query that matches both expression and reading
                let rows = try Row.fetchAll(db, sql: """
                    SELECT id, expression, reading, term_tags, score, rules, definitions, popularity
                    FROM terms
                    WHERE expression = ? OR reading = ?
                    ORDER BY id
                    """, arguments: [word, word])
                
                for row in rows {
                    let termId = row["id"] as? Int64 ?? 0
                    let expression = row["expression"] as? String ?? ""
                    let reading = row["reading"] as? String ?? ""
                    let tags = row["term_tags"] as? String ?? ""
                    let score = row["score"] as? String
                    let rules = row["rules"] as? String
                    let definitionsText = row["definitions"] as? String ?? ""
                    // Handle popularity stored as string in database
                    let popularity: Double
                    if let popString = row["popularity"] as? String, let popDouble = Double(popString) {
                        popularity = popDouble
                    } else {
                        popularity = 0.0
                    }
                    
                    // Split definitions by newline separator (assuming definitions are stored separated by newlines)
                    let meanings = definitionsText.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
                    
                    // Create a new entry with pitch accent lookup
                    let entry = createDictionaryEntry(
                        id: "jmdict_\(termId)",
                        term: expression,
                        reading: reading,
                        meanings: meanings,
                        meaningTags: [],
                        termTags: tags.split(separator: ",").map(String.init),
                        score: score,
                        rules: rules,
                        popularity: popularity,
                        source: "jmdict"
                    )
                    
                    entries.append(entry)
                }
            }
        } catch {
            print("Error looking up word in JMdict: \(error)")
        }
        
        return entries
    }
    
    /// Lookup from Obunsha dictionary database
    private func lookupObunsha(word: String) -> [DictionaryEntry] {
        guard let db = obunshaQueue else { return [] }
        
        var entries: [DictionaryEntry] = []
        
        do {
            try db.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT id, expression, reading, term_tags, score, rules, definitions, popularity
                    FROM terms
                    WHERE expression = ? OR reading = ?
                    ORDER BY id
                    """, arguments: [word, word])
                
                for row in rows {
                    let termId = row["id"] as? Int64 ?? 0
                    let expression = row["expression"] as? String ?? ""
                    let reading = row["reading"] as? String ?? ""
                    let tags = row["term_tags"] as? String ?? ""
                    let score = row["score"] as? String
                    let rules = row["rules"] as? String
                    let definitionsText = row["definitions"] as? String ?? ""
                    
                    // Handle popularity stored as string in database
                    let popularity: Double
                    if let popString = row["popularity"] as? String, let popDouble = Double(popString) {
                        popularity = popDouble
                    } else {
                        popularity = 0.0
                    }
                    
                    // Split definitions by newline separator (same as imported dictionaries)
                    let meanings = definitionsText.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
                    
                    // Create a new entry
                    let entry = createDictionaryEntry(
                        id: "obunsha_\(termId)",
                        term: expression,
                        reading: reading,
                        meanings: meanings,
                        meaningTags: [],
                        termTags: tags.split(separator: ",").map(String.init),
                        score: score,
                        rules: rules,
                        popularity: popularity,
                        source: "obunsha"
                    )
                    
                    entries.append(entry)
                }
            }
        } catch {
            print("Error looking up word in Obunsha: \(error)")
        }
        
        return entries
    }
    
    /// Main lookup function that searches all enabled dictionaries concurrently
    func lookup(word: String) -> [DictionaryEntry] {
        let startTime = CFAbsoluteTimeGetCurrent()
        let enabledDictionaries = getEnabledDictionaries()
        
        let dispatchGroup = DispatchGroup()
        let concurrentQueue = DispatchQueue(label: "com.shiori.builtinDictionary.concurrent", attributes: .concurrent)
        let resultQueue = DispatchQueue(label: "com.shiori.builtinDictionary.results")
        
        var allEntries: [DictionaryEntry] = []
        
        // Search JMdict if enabled
        if enabledDictionaries.contains("jmdict") {
            dispatchGroup.enter()
            concurrentQueue.async {
                let jmdictEntries = self.lookupJMdict(word: word)
                resultQueue.async {
                    allEntries.append(contentsOf: jmdictEntries)
                    dispatchGroup.leave()
                }
            }
        }
        
        // Search Obunsha if enabled
        if enabledDictionaries.contains("obunsha") {
            dispatchGroup.enter()
            concurrentQueue.async {
                let obunshaEntries = self.lookupObunsha(word: word)
                resultQueue.async {
                    allEntries.append(contentsOf: obunshaEntries)
                    dispatchGroup.leave()
                }
            }
        }
        
        // Wait for all built-in dictionary lookups to complete
        dispatchGroup.wait()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = (endTime - startTime) * 1000
        
        let sortedEntries = sortEntriesByPopularity(allEntries, searchTerm: word)
        
        
        return sortedEntries
    }
    
    func lookupWithDeinflection(word: String) -> [DictionaryEntry] {
        let overallStartTime = CFAbsoluteTimeGetCurrent()
        var allEntries: [DictionaryEntry] = []
        
        // Use DispatchGroup to run built-in and imported lookups concurrently
        let dispatchGroup = DispatchGroup()
        let concurrentQueue = DispatchQueue(label: "com.shiori.dictionaryLookup.main", attributes: .concurrent)
        let resultQueue = DispatchQueue(label: "com.shiori.dictionaryLookup.mainResults")
        
        var directEntries: [DictionaryEntry] = []
        var importedDirectEntries: [DictionaryEntry] = []
        
        // Concurrent direct lookup from built-in dictionaries
        dispatchGroup.enter()
        concurrentQueue.async {
            let entries = self.lookup(word: word)
            resultQueue.async {
                directEntries = entries
                dispatchGroup.leave()
            }
        }
        
        // Concurrent direct lookup from imported dictionaries
        dispatchGroup.enter()
        concurrentQueue.async {
            let entries = self.lookupImportedDictionaries(word: word)
            resultQueue.async {
                importedDirectEntries = entries
                dispatchGroup.leave()
            }
        }
        
        // Wait for direct lookups to complete
        dispatchGroup.wait()
        
        // Combine direct results
        allEntries.append(contentsOf: directEntries)
        allEntries.append(contentsOf: importedDirectEntries)
        
        let directLookupTime = CFAbsoluteTimeGetCurrent()
        let directDuration = (directLookupTime - overallStartTime) * 1000
        
        
        // Always try deinflections if we have them
        if let deinflector = self.deinflector {
            let deinflectionStartTime = CFAbsoluteTimeGetCurrent()
            let deinflections = deinflector.deinflect(word)
            
            // Process deinflections concurrently
            let deinflectionGroup = DispatchGroup()
            let deinflectionQueue = DispatchQueue(label: "com.shiori.deinflection.concurrent", attributes: .concurrent)
            let deinflectionResultQueue = DispatchQueue(label: "com.shiori.deinflection.results")
            
            for result in deinflections {
                // Skip the original form since we already looked it up
                if result.term == word && result.reasons.isEmpty {
                    continue
                }
                
                deinflectionGroup.enter()
                deinflectionQueue.async {
                    // Run built-in and imported lookups concurrently for each deinflected form
                    let innerGroup = DispatchGroup()
                    let innerQueue = DispatchQueue(label: "com.shiori.deinflection.inner", attributes: .concurrent)
                    let innerResultQueue = DispatchQueue(label: "com.shiori.deinflection.innerResults")
                    
                    var builtinEntries: [DictionaryEntry] = []
                    var importedEntries: [DictionaryEntry] = []
                    
                    // Lookup in built-in dictionaries
                    innerGroup.enter()
                    innerQueue.async {
                        let entries = self.lookup(word: result.term)
                        innerResultQueue.async {
                            builtinEntries = entries
                            innerGroup.leave()
                        }
                    }
                    
                    // Lookup in imported dictionaries
                    innerGroup.enter()
                    innerQueue.async {
                        let entries = self.lookupImportedDictionaries(word: result.term)
                        innerResultQueue.async {
                            importedEntries = entries
                            innerGroup.leave()
                        }
                    }
                    
                    // Wait for both lookups to complete
                    innerGroup.wait()
                    
                    // Process results and add to main collection
                    deinflectionResultQueue.async {
                        // Add built-in entries found through deinflection
                        for entry in builtinEntries {
                            let enhancedEntry = self.createDictionaryEntry(
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
                                popularity: entry.popularity,
                                source: entry.source
                            )
                            allEntries.append(enhancedEntry)
                        }
                        
                        // Add imported entries found through deinflection
                        for importedEntry in importedEntries {
                            let enhancedEntry = self.createImportedDictionaryEntry(
                                id: importedEntry.id,
                                term: importedEntry.term,
                                reading: importedEntry.reading,
                                meanings: importedEntry.meanings,
                                meaningTags: importedEntry.meaningTags,
                                termTags: importedEntry.termTags,
                                score: importedEntry.score,
                                rules: importedEntry.rules,
                                transformed: word,
                                transformationNotes: result.reasons.joined(separator: " ← "),
                                popularity: importedEntry.popularity,
                                source: importedEntry.source
                            )
                            allEntries.append(enhancedEntry)
                        }
                        
                        deinflectionGroup.leave()
                    }
                }
            }
            
            // Wait for all deinflection lookups to complete
            deinflectionGroup.wait()
            
            let deinflectionEndTime = CFAbsoluteTimeGetCurrent()
            let deinflectionDuration = (deinflectionEndTime - deinflectionStartTime) * 1000
            
        }
        
        // Debug: Log entries before filtering
        // let sourcesBefore = Set(allEntries.map { $0.source }).sorted()
        // print("🔍 [DEBUG] Before filtering - found \(allEntries.count) entries from: \(sourcesBefore.joined(separator: ", "))")
        
        // Apply conservative filtering to reduce false positives
        let filteredEntries = applyConservativeFiltering(allEntries, originalWord: word)
        
        // Debug: Log entries after filtering
        // let sourcesAfter = Set(filteredEntries.map { $0.source }).sorted()
        // print("🔍 [DEBUG] After filtering - \(filteredEntries.count) entries from: \(sourcesAfter.joined(separator: ", "))")
        
        // Sort the final combined results
        let finalSortedEntries = sortEntriesByPopularity(filteredEntries, searchTerm: word)
        
        let overallEndTime = CFAbsoluteTimeGetCurrent()
        let totalDuration = (overallEndTime - overallStartTime) * 1000
        
        
        return finalSortedEntries
    }
    
    /// Apply conservative filtering to reduce obvious false positives while preserving legitimate results
    private func applyConservativeFiltering(_ entries: [DictionaryEntry], originalWord: String) -> [DictionaryEntry] {
        // If we have very few entries, don't filter to avoid removing valid results
        if entries.count <= 3 {
            return entries
        }
        
        // print("🔍 [DEBUG] Conservative filtering \(entries.count) entries for '\(originalWord)'")
        
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
        
        // Take the best entry from each group - preserve order!
        var seenKeys: Set<String> = []
        var orderedKeys: [String] = []
        
        for entry in entries {
            let groupKey = "\(entry.term)-\(entry.reading)"
            if !seenKeys.contains(groupKey) {
                seenKeys.insert(groupKey)
                orderedKeys.append(groupKey)
            }
        }
        
        // Now process groups in the order they first appeared
        for groupKey in orderedKeys {
            if let groupEntries = groupedEntries[groupKey] {
                // Sort group entries and keep one per dictionary source
                let sortedGroup = sortEntriesByPopularity(groupEntries, searchTerm: originalWord)
                
                // Keep the best entry from each unique dictionary source
                var seenSources: Set<String> = []
                for entry in sortedGroup {
                    if !seenSources.contains(entry.source) {
                        seenSources.insert(entry.source)
                        filteredResults.append(entry)
                    }
                }
            }
        }
        
        // Final sort of the filtered results
        let finalFilteredResults = sortEntriesByPopularity(filteredResults, searchTerm: originalWord)
        
        // Only apply part-of-speech filtering for deinflected entries to avoid breaking direct lookups
        let conservativeFiltered = finalFilteredResults.filter { entry in
            let shouldKeep = shouldKeepEntry(entry, originalWord: originalWord)
            // if !shouldKeep {
            //     print("🔍 [DEBUG] FILTERED OUT: \(entry.source) - \(entry.term) (\(entry.reading)) - transformed: \(entry.transformed ?? "nil")")
            //     if let rules = entry.rules {
            //         print("🔍 [DEBUG]   rules: \(rules)")
            //     }
            //     print("🔍 [DEBUG]   termTags: \(entry.termTags)")
            // }
            return shouldKeep
        }
        
        return conservativeFiltered
    }
    
    private func shouldKeepEntry(_ entry: DictionaryEntry, originalWord: String) -> Bool {
        // Always keep direct matches (no transformation)
        if entry.transformed == nil {
            return true
        }
        
        // For transformed entries, check if the deinflected form matches the original search term
        if entry.term == originalWord {
            return true
        }
        
        // Trust results from built-in dictionaries (jmdict, obunsha) and be less strict
        if entry.source == "jmdict" || entry.source == "obunsha" {
            // For built-in dictionaries, only filter out obvious non-conjugatable entries
            let tagString = entry.termTags.joined(separator: " ")
            let cleanedTagString = tagString.replacingOccurrences(of: "\"", with: "")
            let individualTags = cleanedTagString.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            let hasObviousNonConjugatableTags = individualTags.contains { tag in
                let lowerTag = tag.lowercased()
                return lowerTag == "n" || lowerTag == "pn" || lowerTag == "num" ||
                       lowerTag == "ctr" || lowerTag == "exp" || lowerTag == "int" ||
                       lowerTag == "conj" || lowerTag == "part" || lowerTag == "pref" ||
                       lowerTag == "suf" || lowerTag == "n-suf" || lowerTag == "adv"
            }
            
            // For built-in dictionaries, err on the side of inclusion
            return !hasObviousNonConjugatableTags
        }
        
        // For imported dictionaries, apply stricter filtering
        // First check rules field (most reliable for conjugatable entries)
        if let rules = entry.rules, !rules.isEmpty {
            let lowerRules = rules.lowercased()
            // If it has conjugatable rules, keep it
            if lowerRules.contains("v1") || lowerRules.contains("v5") || lowerRules.contains("vs") ||
               lowerRules.contains("vk") || lowerRules.contains("vz") || lowerRules.contains("adj-i") {
                return true
            }
        }
        
        // Parse termTags properly
        let tagString = entry.termTags.joined(separator: " ")
        let cleanedTagString = tagString.replacingOccurrences(of: "\"", with: "")
        let individualTags = cleanedTagString.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // Check for conjugatable tags
        let hasConjugatableTags = individualTags.contains { tag in
            let lowerTag = tag.lowercased()
            return lowerTag == "v1" || lowerTag == "v5" || lowerTag == "vs" ||
                   lowerTag == "vk" || lowerTag == "vz" || lowerTag == "vi" ||
                   lowerTag == "vt" || lowerTag == "adj-i" ||
                   lowerTag.hasPrefix("v5") || lowerTag.hasPrefix("v1")
        }
        
        if hasConjugatableTags {
            return true
        }
        
        // Filter out entries that are clearly non-conjugatable
        let hasNonConjugatableTags = individualTags.contains { tag in
            let lowerTag = tag.lowercased()
            return lowerTag == "n" || lowerTag == "pn" || lowerTag == "num" ||
                   lowerTag == "ctr" || lowerTag == "exp" || lowerTag == "int" ||
                   lowerTag == "conj" || lowerTag == "part" || lowerTag == "pref" ||
                   lowerTag == "suf" || lowerTag == "n-suf" || lowerTag == "adv" ||
                   lowerTag == "aux-v" || lowerTag == "adj-t" || lowerTag == "adj-no" ||
                   lowerTag == "adj-na" || lowerTag == "adj-pn" || lowerTag == "adj-f" ||
                   (lowerTag.hasPrefix("adj-") && lowerTag != "adj-i")
        }
        
        // If it has non-conjugatable tags and no conjugatable ones, filter it out
        if hasNonConjugatableTags {
            return false
        }
        
        // If we can't determine, err on the side of caution and keep it
        return true
    }
    
    // Advanced lookup with prefix matching
    func searchByPrefix(prefix: String, limit: Int = 10) -> [DictionaryEntry] {
        let enabledDictionaries = getEnabledDictionaries()
        var allEntries: [DictionaryEntry] = []
        
        // Search JMdict if enabled
        if enabledDictionaries.contains("jmdict") {
            allEntries.append(contentsOf: searchByPrefixJMdict(prefix: prefix, limit: limit))
        }
        
        // Search Obunsha if enabled
        if enabledDictionaries.contains("obunsha") {
            allEntries.append(contentsOf: searchByPrefixObunsha(prefix: prefix, limit: limit))
        }
        
        return Array(allEntries.prefix(limit))
    }
    
    private func searchByPrefixJMdict(prefix: String, limit: Int = 10) -> [DictionaryEntry] {
        guard let db = jmdictQueue else { return [] }
        
        var entries: [DictionaryEntry] = []
        
        do {
            try db.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT id, expression, reading, term_tags, score, rules, definitions, popularity
                    FROM terms
                    WHERE expression LIKE ? || '%' OR reading LIKE ? || '%'
                    ORDER BY sequence, id
                    LIMIT ?
                    """, arguments: [prefix, prefix, limit])
                
                for row in rows {
                    let termId = row["id"] as? Int64 ?? 0
                    let expression = row["expression"] as? String ?? ""
                    let reading = row["reading"] as? String ?? ""
                    let tags = row["term_tags"] as? String ?? ""
                    let score = row["score"] as? String
                    let rules = row["rules"] as? String
                    let definitionsText = row["definitions"] as? String ?? ""
                    let popularity: Double
                    if let popString = row["popularity"] as? String, let popDouble = Double(popString) {
                        popularity = popDouble
                    } else {
                        popularity = 0.0
                    }
                    
                    // Split definitions by newline separator
                    let definitions = definitionsText.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
                    
                    let entry = createDictionaryEntry(
                        id: "jmdict_\(termId)",
                        term: expression,
                        reading: reading,
                        meanings: definitions,
                        meaningTags: [],
                        termTags: tags.split(separator: ",").map(String.init),
                        score: score,
                        rules: rules,
                        popularity: popularity,
                        source: "jmdict"
                    )
                    
                    entries.append(entry)
                }
            }
        } catch {
            print("Error searching JMdict by prefix: \(error)")
        }
        
        return entries
    }
    
    private func searchByPrefixObunsha(prefix: String, limit: Int = 10) -> [DictionaryEntry] {
        guard let db = obunshaQueue else { return [] }
        
        var entries: [DictionaryEntry] = []
        
        do {
            try db.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT id, expression, reading, term_tags, score, rules, definitions, popularity
                    FROM terms
                    WHERE expression LIKE ? || '%' OR reading LIKE ? || '%'
                    ORDER BY sequence, id
                    LIMIT ?
                    """, arguments: [prefix, prefix, limit])
                
                for row in rows {
                    let termId = row["id"] as? Int64 ?? 0
                    let expression = row["expression"] as? String ?? ""
                    let reading = row["reading"] as? String ?? ""
                    let tags = row["term_tags"] as? String ?? ""
                    let score = row["score"] as? String
                    let rules = row["rules"] as? String
                    let definitionsText = row["definitions"] as? String ?? ""
                    let popularity: Double
                    if let popString = row["popularity"] as? String, let popDouble = Double(popString) {
                        popularity = popDouble
                    } else {
                        popularity = 0.0
                    }
                    
                    // Split definitions by newline separator (same as imported dictionaries)
                    let definitions = definitionsText.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
                    
                    let entry = createDictionaryEntry(
                        id: "obunsha_\(termId)",
                        term: expression,
                        reading: reading,
                        meanings: definitions,
                        meaningTags: [],
                        termTags: tags.split(separator: ",").map(String.init),
                        score: score,
                        rules: rules,
                        popularity: popularity,
                        source: "obunsha"
                    )
                    
                    entries.append(entry)
                }
            }
        } catch {
            print("Error searching Obunsha by prefix: \(error)")
        }
        
        return entries
    }
    
    // Search by English meaning
    func searchByMeaning(text: String, limit: Int = 20) -> [DictionaryEntry] {
        let enabledDictionaries = getEnabledDictionaries()
        var allEntries: [DictionaryEntry] = []
        
        // Search JMdict if enabled (English meanings are most useful here)
        if enabledDictionaries.contains("jmdict") {
            allEntries.append(contentsOf: searchByMeaningJMdict(text: text, limit: limit))
        }
        
        // Search Obunsha if enabled (though English meaning search may not be as useful for monolingual dictionary)
        if enabledDictionaries.contains("obunsha") {
            allEntries.append(contentsOf: searchByMeaningObunsha(text: text, limit: limit))
        }
        
        return sortEntriesByPopularity(Array(allEntries.prefix(limit)))
    }
    
    private func searchByMeaningJMdict(text: String, limit: Int = 20) -> [DictionaryEntry] {
        guard let db = jmdictQueue else { return [] }
        
        var entries: [DictionaryEntry] = []
        let searchTerm = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            try db.read { db in
                let sql = """
                    SELECT id, expression, reading, term_tags, score, rules, definitions, popularity,
                        (CASE
                            WHEN definitions LIKE '% \(searchTerm) %' OR definitions LIKE '\(searchTerm) %' OR definitions LIKE '% \(searchTerm)' OR definitions = '\(searchTerm)' THEN 1
                            WHEN definitions LIKE '%\(searchTerm)%' THEN 2
                            ELSE 3
                        END) AS match_quality
                    FROM terms
                    WHERE definitions LIKE '%\(searchTerm)%'
                    ORDER BY match_quality, popularity DESC, sequence
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
                    let definitionsText = row["definitions"] as? String ?? ""
                    let popularity: Double
                    if let popString = row["popularity"] as? String, let popDouble = Double(popString) {
                        popularity = popDouble
                    } else {
                        popularity = 0.0
                    }
                    
                    // Split definitions by newline separator
                    let definitions = definitionsText.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
                    
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
                        let entry = createDictionaryEntry(
                            id: "jmdict_\(termId)",
                            term: expression,
                            reading: reading,
                            meanings: definitions,
                            meaningTags: [],
                            termTags: tags.split(separator: ",").map(String.init),
                            score: score,
                            rules: rules,
                            popularity: popularity,
                            source: "jmdict"
                        )
                        
                        entries.append(entry)
                    }
                }
            }
        } catch {
            print("Error searching JMdict by meaning: \(error)")
        }
        
        return entries
    }
    
    private func searchByMeaningObunsha(text: String, limit: Int = 20) -> [DictionaryEntry] {
        guard let db = obunshaQueue else { return [] }
        
        var entries: [DictionaryEntry] = []
        let searchTerm = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            try db.read { db in
                // For Obunsha (Japanese monolingual), we'll search in definitions but this may not be as useful
                let sql = """
                    SELECT id, expression, reading, term_tags, score, rules, definitions, popularity,
                        (CASE
                            WHEN definitions LIKE '% \(searchTerm) %' OR definitions LIKE '\(searchTerm) %' OR definitions LIKE '% \(searchTerm)' OR definitions = '\(searchTerm)' THEN 1
                            WHEN definitions LIKE '%\(searchTerm)%' THEN 2
                            ELSE 3
                        END) AS match_quality
                    FROM terms
                    WHERE definitions LIKE '%\(searchTerm)%'
                    ORDER BY match_quality, popularity DESC, sequence
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
                    let definitionsText = row["definitions"] as? String ?? ""
                    let popularity: Double
                    if let popString = row["popularity"] as? String, let popDouble = Double(popString) {
                        popularity = popDouble
                    } else {
                        popularity = 0.0
                    }
                    
                    // Split definitions by newline separator (same as imported dictionaries)
                    let definitions = definitionsText.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
                    
                    let entry = createDictionaryEntry(
                        id: "obunsha_\(termId)",
                        term: expression,
                        reading: reading,
                        meanings: definitions,
                        meaningTags: [],
                        termTags: tags.split(separator: ",").map(String.init),
                        score: score,
                        rules: rules,
                        popularity: popularity,
                        source: "obunsha"
                    )
                    
                    entries.append(entry)
                }
            }
        } catch {
            print("Error searching Obunsha by meaning: \(error)")
        }
        
        return entries
    }
    
    func sortEntriesByPopularity(_ entries: [DictionaryEntry]) -> [DictionaryEntry] {
        return sortEntriesByPopularity(entries, searchTerm: nil)
    }
    
    func sortEntriesByPopularity(_ entries: [DictionaryEntry], searchTerm: String?) -> [DictionaryEntry] {
        let sortedEntries = entries.sorted { first, second in
            // 0. HIGHEST PRIORITY: Exact term matches (term exactly matches search term)
            if let searchTerm = searchTerm {
                let firstExactTermMatch = (first.term == searchTerm)
                let secondExactTermMatch = (second.term == searchTerm)
                if firstExactTermMatch != secondExactTermMatch {
                    return firstExactTermMatch
                }
                
                // 0.5. Second priority: Exact reading matches (reading exactly matches search term)
                let firstExactReadingMatch = (first.reading == searchTerm)
                let secondExactReadingMatch = (second.reading == searchTerm)
                if firstExactReadingMatch != secondExactReadingMatch {
                    return firstExactReadingMatch
                }
                
                // 0.7. Term length preference - longer terms first for exact matches
                if firstExactTermMatch || secondExactTermMatch || firstExactReadingMatch || secondExactReadingMatch {
                    if first.term.count != second.term.count {
                        return first.term.count > second.term.count
                    }
                }
                
                // 0.8. Script type preference (hiragana to hiragana, kanji to kanji)
                let searchIsHiragana = searchTerm.isAllHiragana()
                let firstIsHiragana = first.term.isAllHiragana()
                let secondIsHiragana = second.term.isAllHiragana()
                
                if searchIsHiragana && firstIsHiragana != secondIsHiragana {
                    return firstIsHiragana
                } else if !searchIsHiragana && firstIsHiragana != secondIsHiragana {
                    return !firstIsHiragana
                }
            }
            
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
            
            // 7. Longer terms preferred for remaining entries
            if first.term.count != second.term.count {
                return first.term.count > second.term.count
            }
            
            // 8. Stable sort by term name as final tiebreaker
            return first.term < second.term
        }
        
        return sortedEntries
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
    
    // MARK: - Testing Functions
    
    /// Test the BCCWJ frequency integration
    func testFrequencyIntegration() {
        print("🧪 [FREQUENCY TEST] Testing BCCWJ frequency integration...")
        
        let testWords = ["猫", "日本", "最初", "食べる", "本", "私", "今日"]
        
        for word in testWords {
            if let frequencyData = frequencyManager.getFrequencyData(for: word) {
                print("🧪 [FREQUENCY TEST] '\(word)': rank=\(frequencyData.rank), freq=\(frequencyData.frequency), source=\(frequencyData.source)")
            } else {
                print("🧪 [FREQUENCY TEST] '\(word)': No frequency data found")
            }
        }
        
        // Test with actual dictionary lookup
        print("🧪 [FREQUENCY TEST] Testing with dictionary lookup...")
        let testEntries = lookupWithDeinflection(word: "猫")
        for entry in testEntries {
            print("🧪 [FREQUENCY TEST] Entry '\(entry.term)' has frequency: \(entry.hasFrequencyData ? entry.frequencyRankString ?? "unknown" : "none")")
        }
    }
    
    /// Test the Obunsha database integration
    func testObunshaDatabaseIntegration() {
        print("🧪 [OBUNSHA TEST] Testing Obunsha database integration...")
        
        guard let db = obunshaQueue else {
            print("🧪 [OBUNSHA TEST] ERROR: Obunsha database queue is nil!")
            return
        }
        
        do {
            try db.read { db in
                // Check database structure
                let tableRows = try Row.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table'")
                let tableNames = tableRows.map { $0["name"] as? String ?? "unknown" }
                print("🧪 [OBUNSHA TEST] Available tables: \(tableNames)")
                
                // If terms table exists, get some stats
                if tableNames.contains("terms") {
                    let countRow = try Row.fetchOne(db, sql: "SELECT COUNT(*) as count FROM terms")
                    let totalCount = countRow?["count"] as? Int64 ?? 0
                    print("🧪 [OBUNSHA TEST] Total entries in database: \(totalCount)")
                    
                    // Check schema
                    let schemaRows = try Row.fetchAll(db, sql: "PRAGMA table_info(terms)")
                    print("🧪 [OBUNSHA TEST] Terms table schema:")
                    for row in schemaRows {
                        let name = row["name"] as? String ?? "unknown"
                        let type = row["type"] as? String ?? "unknown"
                        print("  - \(name): \(type)")
                    }
                    
                    // Try a direct query for some common words
                    let testWords = ["猫", "日本", "最初"]
                    
                    for word in testWords {
                        let rows = try Row.fetchAll(db, sql: """
                            SELECT expression, reading, definitions
                            FROM terms
                            WHERE expression = ? OR reading = ?
                            LIMIT 3
                            """, arguments: [word, word])
                        
                        print("🧪 [OBUNSHA TEST] Direct query for '\(word)': \(rows.count) results")
                        
                        for (index, row) in rows.enumerated() {
                            let expression = row["expression"] as? String ?? ""
                            let reading = row["reading"] as? String ?? ""
                            let definitions = row["definitions"] as? String ?? ""
                            print("  [\(index + 1)] \(expression) (\(reading)): \(definitions.prefix(50))...")
                        }
                        
                        if !rows.isEmpty {
                            print("🧪 [OBUNSHA TEST] SUCCESS: Found entries in database!")
                            break
                        }
                    }
                } else {
                    print("🧪 [OBUNSHA TEST] ERROR: No 'terms' table found in database")
                }
            }
        } catch {
            print("🧪 [OBUNSHA TEST] ERROR: \(error)")
        }
        
        // Now test the lookup method separately (outside the transaction)
        print("🧪 [OBUNSHA TEST] Testing lookup method...")
        let testResults = lookupObunsha(word: "猫")
        print("🧪 [OBUNSHA TEST] Lookup method returned \(testResults.count) entries")
    }

}

// MARK: - String Extensions for Japanese Script Detection
extension String {
    func isAllHiragana() -> Bool {
        guard !isEmpty else { return false }
        let pattern = "^[\\p{Hiragana}]+$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return false
        }
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }
}
