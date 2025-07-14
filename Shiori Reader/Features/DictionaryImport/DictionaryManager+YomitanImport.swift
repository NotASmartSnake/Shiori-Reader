//
//  DictionaryManager+YomitanImport.swift
//  Shiori Reader
//
//  Created by Claude on 1/10/25.
//

import Foundation
import GRDB

/// Extension to integrate imported Yomitan dictionaries with the existing DictionaryManager
extension DictionaryManager {
    
    /// Dictionary queue storage for imported dictionaries
    private static var importedDictionaryQueues: [String: DatabaseQueue] = [:]
    
    /// Track whether imported dictionaries have been set up
    private static var importedDictionariesSetup = false
    
    /// Setup imported dictionaries on app launch
    func setupImportedDictionaries() {
        // Prevent multiple setup calls
        guard !Self.importedDictionariesSetup else {
            return
        }
        
        let importManager = DictionaryImportManager.shared
        let importedDictionaries = importManager.getImportedDictionaries()
        
        for dictionary in importedDictionaries {
            loadImportedDictionary(dictionary)
        }
        
        if !Self.importedDictionaryQueues.isEmpty {
            print("📚 [DICT] Loaded \(Self.importedDictionaryQueues.count) imported dictionaries: \(Array(Self.importedDictionaryQueues.keys).sorted().joined(separator: ", "))")
        }
        Self.importedDictionariesSetup = true
    }
    
    /// Load an imported dictionary into the manager
    private func loadImportedDictionary(_ info: ImportedDictionaryInfo) {
        do {
            let databaseURL = info.databaseURL
            
            // Verify file exists before trying to create queue
            guard FileManager.default.fileExists(atPath: databaseURL.path) else {
                return
            }
            
            var configuration = Configuration()
            configuration.readonly = true
            let queue = try DatabaseQueue(path: databaseURL.path, configuration: configuration)
            // Use the UUID as the key to match the source format
            let dictionaryKey = "imported_\(info.id.uuidString)"
            Self.importedDictionaryQueues[dictionaryKey] = queue
        } catch {
        }
    }
    
    /// Get all enabled dictionaries including imported ones
    func getAllEnabledDictionaries() -> [String] {
        var enabled = ["jmdict", "obunsha", "bccwj"] // Default built-in dictionaries
        
        // Add imported dictionaries using the UUID format
        let importedDictionaries = DictionaryImportManager.shared.getImportedDictionaries()
        for dictionary in importedDictionaries {
            enabled.append("imported_\(dictionary.id.uuidString)")
        }
        
        return enabled
    }
    
    
    
    /// Lookup from imported dictionaries only
    func lookupImportedDictionaries(word: String) -> [DictionaryEntry] {
        var allEntries: [DictionaryEntry] = []
        let enabledDictionaries = getAllEnabledDictionaries()
        
        for (dictionaryKey, queue) in Self.importedDictionaryQueues {
            guard enabledDictionaries.contains(dictionaryKey) else { continue }
            
            let entries = lookupImportedDictionary(word: word, queue: queue, dictionaryKey: dictionaryKey)
            allEntries.append(contentsOf: entries)
        }
        
        return allEntries
    }
    
    /// Create dictionary entry for imported dictionaries (public version)
    func createImportedDictionaryEntry(
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
        source: String
    ) -> DictionaryEntry {
        // Create entry - frequency data and pitch accents will load lazily
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
        
        // Try to add frequency data if available
        if let frequencyData = FrequencyManager.shared.getFrequencyData(for: term) {
            entry.frequencyData = frequencyData
        }
        
        return entry
    }
    
    /// Lookup from a specific imported dictionary
    private func lookupImportedDictionary(
        word: String,
        queue: DatabaseQueue,
        dictionaryKey: String
    ) -> [DictionaryEntry] {
        
        var entries: [DictionaryEntry] = []
        
        do {
            try queue.read { db in
                // Only exact match - same as built-in dictionaries
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
                    
                    // Split definitions by newline separator
                    let meanings = definitionsText.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
                    
                    // Create entry with the UUID-based source
                    let entry = createImportedDictionaryEntry(
                        id: "\(dictionaryKey)_\(termId)",
                        term: expression,
                        reading: reading,
                        meanings: meanings,
                        meaningTags: [],
                        termTags: tags.split(separator: ",").map(String.init),
                        score: score,
                        rules: rules,
                        popularity: popularity,
                        source: dictionaryKey
                    )
                    
                    entries.append(entry)
                }
            }
        } catch {
        }
        
        return entries
    }
    
    /// Search imported dictionaries by prefix
    func searchImportedDictionariesByPrefix(prefix: String, limit: Int = 10) -> [DictionaryEntry] {
        var allEntries: [DictionaryEntry] = []
        let enabledDictionaries = getAllEnabledDictionaries()
        
        for (dictionaryKey, queue) in Self.importedDictionaryQueues {
            guard enabledDictionaries.contains(dictionaryKey) else { continue }
            
            let entries = searchImportedDictionaryByPrefix(
                prefix: prefix,
                queue: queue,
                dictionaryKey: dictionaryKey,
                limit: limit
            )
            allEntries.append(contentsOf: entries)
        }
        
        return Array(allEntries.prefix(limit))
    }
    
    /// Search a specific imported dictionary by prefix
    private func searchImportedDictionaryByPrefix(
        prefix: String,
        queue: DatabaseQueue,
        dictionaryKey: String,
        limit: Int
    ) -> [DictionaryEntry] {
        
        var entries: [DictionaryEntry] = []
        
        do {
            try queue.read { db in
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
                    
                    let meanings = definitionsText.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
                    
                    let entry = createImportedDictionaryEntry(
                        id: "\(dictionaryKey)_\(termId)",
                        term: expression,
                        reading: reading,
                        meanings: meanings,
                        meaningTags: [],
                        termTags: tags.split(separator: ",").map(String.init),
                        score: score,
                        rules: rules,
                        popularity: popularity,
                        source: dictionaryKey
                    )
                    
                    entries.append(entry)
                }
            }
        } catch {
        }
        
        return entries
    }
    
    
    /// Debug property to check loaded imported dictionaries
    var loadedImportedDictionaryNames: [String] {
        return Array(Self.importedDictionaryQueues.keys).sorted()
    }
}

// MARK: - Notification for Dictionary Updates

extension DictionaryManager {
    
    /// Reload imported dictionaries (call this when new dictionaries are imported)
    func reloadImportedDictionaries() {
        
        // Clear existing imported dictionary queues to release connections
        for (title, queue) in Self.importedDictionaryQueues {
            // Close database connections explicitly
            // Note: GRDB DatabaseQueue closes automatically when deallocated
        }
        Self.importedDictionaryQueues.removeAll()
        
        // Reset setup flag to allow re-setup
        Self.importedDictionariesSetup = false
        
        // Small delay to ensure connections are fully released
        Thread.sleep(forTimeInterval: 0.05)
        
        // Reload all imported dictionaries
        setupImportedDictionaries()
        
    }
}
