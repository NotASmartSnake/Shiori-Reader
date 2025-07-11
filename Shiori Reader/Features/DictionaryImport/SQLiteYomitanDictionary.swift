//
//  SQLiteYomitanDictionary.swift
//  Shiori Reader
//
//  Created by Claude on 1/10/25.
//

import Foundation
import GRDB

/// Creates SQLite databases compatible with your existing DictionaryManager
class SQLiteYomitanDictionary {
    
    typealias ProgressCallback = (Int, Int) -> Void
    
    /// Create a SQLite database from processed Yomitan data
    func createDatabase(
        at databaseURL: URL,
        with data: ProcessedDictionaryData,
        progressCallback: ProgressCallback? = nil
    ) async throws {
        
        // Remove existing database if it exists
        if FileManager.default.fileExists(atPath: databaseURL.path) {
            try FileManager.default.removeItem(at: databaseURL)
        }
        
        // Create database
        let dbQueue = try DatabaseQueue(path: databaseURL.path)
        
        // Perform all operations in a single transaction
        try await dbQueue.write { db in
            // Create tables with schema compatible with your existing DictionaryManager
            try self.createTables(db)
            
            // Insert data without nested transactions
            try self.insertTermsDirectly(db, terms: data.terms, progressCallback: progressCallback)
            try self.insertTagsDirectly(db, tags: data.tags)
            try self.insertTermMetaDirectly(db, termMeta: data.termMeta)
            
            // Create indexes for better performance
            try self.createIndexes(db)
        }
    }
    
    // MARK: - Table Creation
    
    private func createTables(_ db: Database) throws {
        // Create terms table compatible with your existing schema
        try db.execute(sql: """
            CREATE TABLE terms (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                expression TEXT NOT NULL,
                reading TEXT NOT NULL,
                term_tags TEXT,
                score TEXT,
                rules TEXT,
                definitions TEXT NOT NULL,
                sequence INTEGER,
                popularity TEXT,
                dictionary TEXT NOT NULL DEFAULT 'imported'
            )
            """)
        
        // Create tags table for part-of-speech and other metadata
        try db.execute(sql: """
            CREATE TABLE tags (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                category TEXT NOT NULL,
                order_num INTEGER NOT NULL,
                notes TEXT,
                score INTEGER NOT NULL,
                dictionary TEXT NOT NULL
            )
            """)
        
        // Create term_meta table for frequency and other metadata
        try db.execute(sql: """
            CREATE TABLE term_meta (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                expression TEXT NOT NULL,
                mode TEXT NOT NULL,
                data TEXT NOT NULL,
                dictionary TEXT NOT NULL
            )
            """)
        
        // Create dictionary_info table to store metadata
        try db.execute(sql: """
            CREATE TABLE dictionary_info (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                revision TEXT NOT NULL,
                version INTEGER NOT NULL,
                author TEXT,
                url TEXT,
                description TEXT,
                attribution TEXT,
                source_language TEXT,
                target_language TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
            """)
    }
    
    // MARK: - Data Insertion (No nested transactions)
    
    private func insertTermsDirectly(
        _ db: Database,
        terms: [ProcessedYomitanTerm],
        progressCallback: ProgressCallback?
    ) throws {
        
        let totalTerms = terms.count
        var processedTerms = 0
        
        // Insert terms in batches but within the existing transaction
        let batchSize = 1000
        for batch in terms.chunked(into: batchSize) {
            for term in batch {
                try self.insertTerm(db, term: term)
                processedTerms += 1
                
                if processedTerms % 100 == 0 {
                    progressCallback?(processedTerms, totalTerms)
                }
            }
        }
        
        progressCallback?(processedTerms, totalTerms)
    }
    
    private func insertTerm(_ db: Database, term: ProcessedYomitanTerm) throws {
        // Convert glossary array to newline-separated string (matching your existing format)
        let definitionsText = term.glossary.joined(separator: "\n")
        
        // Convert score to string format
        let scoreText = term.score == 0 ? nil : String(term.score)
        
        // Convert sequence to string for popularity field (maintaining compatibility)
        let popularityText = term.sequence.map { String($0) }
        
        try db.execute(
            sql: """
                INSERT INTO terms (
                    expression, reading, term_tags, score, rules, 
                    definitions, sequence, popularity, dictionary
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                term.expression,
                term.reading,
                term.termTags.isEmpty ? nil : term.termTags,
                scoreText,
                term.rules.isEmpty ? nil : term.rules,
                definitionsText,
                term.sequence,
                popularityText,
                term.dictionary
            ]
        )
    }
    
    private func insertTagsDirectly(_ db: Database, tags: [ProcessedYomitanTag]) throws {
        for tag in tags {
            try db.execute(
                sql: """
                    INSERT INTO tags (
                        name, category, order_num, notes, score, dictionary
                    ) VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    tag.name,
                    tag.category,
                    tag.order,
                    tag.notes,
                    tag.score,
                    tag.dictionary
                ]
            )
        }
    }
    
    private func insertTermMetaDirectly(_ db: Database, termMeta: [ProcessedYomitanTermMeta]) throws {
        for meta in termMeta {
            try db.execute(
                sql: """
                    INSERT INTO term_meta (
                        expression, mode, data, dictionary
                    ) VALUES (?, ?, ?, ?)
                    """,
                arguments: [
                    meta.expression,
                    meta.mode,
                    meta.data,
                    meta.dictionary
                ]
            )
        }
    }
    
    // MARK: - Index Creation
    
    private func createIndexes(_ db: Database) throws {
        // Create indexes for optimal lookup performance
        try db.execute(sql: "CREATE INDEX idx_terms_expression ON terms(expression)")
        try db.execute(sql: "CREATE INDEX idx_terms_reading ON terms(reading)")
        try db.execute(sql: "CREATE INDEX idx_terms_dictionary ON terms(dictionary)")
        try db.execute(sql: "CREATE INDEX idx_terms_sequence ON terms(sequence)")
        
        try db.execute(sql: "CREATE INDEX idx_tags_name ON tags(name)")
        try db.execute(sql: "CREATE INDEX idx_tags_dictionary ON tags(dictionary)")
        
        try db.execute(sql: "CREATE INDEX idx_term_meta_expression ON term_meta(expression)")
        try db.execute(sql: "CREATE INDEX idx_term_meta_mode ON term_meta(mode)")
        try db.execute(sql: "CREATE INDEX idx_term_meta_dictionary ON term_meta(dictionary)")
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
