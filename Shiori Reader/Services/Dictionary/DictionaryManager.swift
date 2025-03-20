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
                    SELECT t.id, t.expression, t.reading, t.term_tags, t.score, d.definition, t.popularity
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
        
        // Then try deinflections if we have them and didn't find enough matches
        if allEntries.isEmpty, let deinflector = self.deinflector {
            let deinflections = deinflector.deinflect(word)
            
            for result in deinflections {
                // Skip the original form since we already looked it up
                if result.term == word && result.reasons.isEmpty {
                    continue
                }
                
                let entries = lookup(word: result.term)
                
                // For each entry found, add information about how it was deinflected
                for var entry in entries {
                    entry.transformed = word
                    
                    // Optionally, add the deinflection reasons to help explain the conjugation
                    // entry.transformationNotes = result.reasons.joined(separator: ", ")
                    
                    allEntries.append(entry)
                }
            }
        }
        
        return sortEntriesByPopularity(allEntries)
    }
    
    // Advanced lookup with prefix matching
    func searchByPrefix(prefix: String, limit: Int = 10) -> [DictionaryEntry] {
        guard let db = dbQueue else { return [] }
        
        var entries: [DictionaryEntry] = []
        
        do {
            try db.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT DISTINCT t.id, t.expression, t.reading, t.term_tags
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
    
    // Simple reverse lookup (search by English meaning)
    func searchByMeaning(text: String, limit: Int = 20) -> [DictionaryEntry] {
        guard let db = dbQueue else { return [] }
        
        var entries: [DictionaryEntry] = []
        
        do {
            try db.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT DISTINCT t.id, t.expression, t.reading, t.term_tags
                    FROM terms t
                    JOIN definitions d ON t.id = d.term_id
                    WHERE d.definition LIKE '%' || ? || '%'
                    ORDER BY t.sequence, t.id
                    LIMIT ?
                    """, arguments: [text.lowercased(), limit])
                
                for row in rows {
                    let termId = row["id"] as? Int64 ?? 0
                    let expression = row["expression"] as? String ?? ""
                    let reading = row["reading"] as? String ?? ""
                    let tags = row["term_tags"] as? String ?? ""
                    let score = row["score"] as? String
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
                        popularity: popularity
                    )
                    
                    entries.append(entry)
                }
            }
        } catch {
            print("Error searching by meaning: \(error)")
        }
        
        return entries
    }
    
    func sortEntriesByPopularity(_ entries: [DictionaryEntry]) -> [DictionaryEntry] {
        return entries.sorted { first, second in
            // Primary sort by popularity (higher values indicate more common terms)
            if let firstPop = first.popularity, let secondPop = second.popularity,
               abs(firstPop - secondPop) > 0.001 {
                return firstPop > secondPop
            }
            
            // Secondary sort by frequency tags in the score column
            let firstScore = getScoreValue(from: first.score)
            let secondScore = getScoreValue(from: second.score)
            if firstScore != secondScore {
                // Lower scores indicate higher priority
                return firstScore < secondScore
            }
            
            // Check for archaism tags in the score column
            let firstHasArchaism = hasArchaism(in: first.score)
            let secondHasArchaism = hasArchaism(in: second.score)
            if firstHasArchaism != secondHasArchaism {
                return !firstHasArchaism
            }
            
            // Tertiary sort by term length (shorter is better)
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
    
}
