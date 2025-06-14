//
//  PitchAccentManager.swift
//  Shiori Reader
//
//  Created by Claude on 6/13/25.
//

import Foundation
import GRDB

class PitchAccentManager {
    static let shared = PitchAccentManager()
    
    private var dbQueue: DatabaseQueue?
    
    private init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        do {
            if let pitchAccentPath = Bundle.main.path(forResource: "kanjium_pitch_accents", ofType: "db") {
                print("✅ [PITCH ACCENT] Found database at: \(pitchAccentPath)")
                
                // Configure database options
                var configuration = Configuration()
                configuration.readonly = true // Pitch accent database is read-only
                
                // Create database queue
                dbQueue = try DatabaseQueue(path: pitchAccentPath, configuration: configuration)
                print("✅ [PITCH ACCENT] Database connected successfully")
                
                // Debug: Check database structure
                checkDatabaseStructure()
            } else {
                print("❌ [PITCH ACCENT] Database file 'kanjium_pitch_accents.db' not found in bundle")
                
                // Let's check what files ARE in the bundle
                if let resourcePath = Bundle.main.resourcePath {
                    let fileManager = FileManager.default
                    do {
                        let files = try fileManager.contentsOfDirectory(atPath: resourcePath)
                        print("📁 [PITCH ACCENT] Files in bundle:")
                        for file in files.sorted() {
                            print("   - \(file)")
                        }
                        
                        // Look for any .db files
                        let dbFiles = files.filter { $0.hasSuffix(".db") }
                        print("🗃️ [PITCH ACCENT] Database files found: \(dbFiles)")
                    } catch {
                        print("❌ [PITCH ACCENT] Could not list bundle contents: \(error)")
                    }
                }
            }
        } catch {
            print("❌ [PITCH ACCENT] Error setting up database: \(error)")
        }
    }
    
    /// Check the database structure to understand the schema
    private func checkDatabaseStructure() {
        guard let db = dbQueue else { 
            print("❌ [PITCH ACCENT] No database connection for structure check")
            return 
        }
        
        do {
            try db.read { db in
                // Get all table names
                let tableNames = try String.fetchAll(db, sql: """
                    SELECT name FROM sqlite_master WHERE type='table' ORDER BY name
                    """)
                
                print("📊 [PITCH ACCENT DB] Available tables: \(tableNames)")
                
                if tableNames.isEmpty {
                    print("⚠️ [PITCH ACCENT DB] No tables found in database!")
                    return
                }
                
                // Check the structure of each table
                for tableName in tableNames.prefix(5) { // Limit to first 5 tables
                    let columns = try Row.fetchAll(db, sql: "PRAGMA table_info(\(tableName))")
                    print("📊 [PITCH ACCENT DB] Table '\(tableName)' columns:")
                    for column in columns {
                        let name = column["name"] as? String ?? "unknown"
                        let type = column["type"] as? String ?? "unknown"
                        print("   - \(name): \(type)")
                    }
                    
                    // Sample a few rows to understand the data format
                    let sampleRows = try Row.fetchAll(db, sql: "SELECT * FROM \(tableName) LIMIT 3")
                    print("📊 [PITCH ACCENT DB] Sample data from '\(tableName)':")
                    for (index, row) in sampleRows.enumerated() {
                        print("   Row \(index + 1):")
                        for columnName in row.columnNames {
                            let value = row[columnName]
                            print("      \(columnName): \(value ?? "NULL")")
                        }
                    }
                    
                    // If this is the pitch_accents table, show some stats
                    if tableName == "pitch_accents" {
                        let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM pitch_accents") ?? 0
                        print("📊 [PITCH ACCENT DB] Total entries in optimized table: \(count)")
                    }
                }
            }
        } catch {
            print("❌ [PITCH ACCENT] Error checking database structure: \(error)")
        }
    }
    
    /// Look up pitch accents for a given term
    func lookupPitchAccents(for term: String) -> PitchAccentData {
        guard let db = dbQueue else { 
            return PitchAccentData(accents: []) 
        }
        
        var accents: [PitchAccent] = []
        
        do {
            try db.read { db in
                // Optimized single-table query (no JOIN needed)
                let query = """
                    SELECT term, reading, pitch_accent
                    FROM pitch_accents
                    WHERE term = ? OR reading = ?
                    ORDER BY pitch_accent
                    LIMIT 5
                """
                
                let rows = try Row.fetchAll(db, sql: query, arguments: [term, term])
                
                for row in rows {
                    if let extractedTerm = row["term"] as? String,
                       let reading = row["reading"] as? String,
                       let pitchValue = row["pitch_accent"] as? Int64 {
                        
                        let accent = PitchAccent(
                            term: extractedTerm,
                            reading: reading,
                            pitchAccent: Int(pitchValue)
                        )
                        accents.append(accent)
                    }
                }
            }
        } catch {
            // Silent failure for performance
        }
        
        return PitchAccentData(accents: accents)
    }
    

    /// Look up pitch accents for a term and reading combination (used by lazy loading)
    func lookupPitchAccents(for term: String, reading: String) -> PitchAccentData {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let db = dbQueue else { 
            return PitchAccentData(accents: []) 
        }
        
        var accents: [PitchAccent] = []
        
        do {
            try db.read { db in
                // Optimized single-table query for both term and reading
                let query = """
                    SELECT DISTINCT term, reading, pitch_accent
                    FROM pitch_accents
                    WHERE term = ? OR reading = ? OR term = ? OR reading = ?
                    ORDER BY pitch_accent
                    LIMIT 5
                """
                
                let rows = try Row.fetchAll(db, sql: query, arguments: [term, term, reading, reading])
                
                for row in rows {
                    if let extractedTerm = row["term"] as? String,
                       let readingValue = row["reading"] as? String,
                       let pitchValue = row["pitch_accent"] as? Int64 {
                        
                        let accent = PitchAccent(
                            term: extractedTerm,
                            reading: readingValue,
                            pitchAccent: Int(pitchValue)
                        )
                        accents.append(accent)
                    }
                }
            }
        } catch {
            // Silent failure for performance
        }
        
        // Remove duplicates and sort by accent value
        let uniqueAccents = Array(Set(accents)).sorted { $0.pitchAccent < $1.pitchAccent }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        Logger.debug(category: "Performance", "Pitch accent lookup for '\(term)'/\"\(reading)\" found \(uniqueAccents.count) accents in \(String(format: "%.3f", timeElapsed))s")
        
        return PitchAccentData(accents: uniqueAccents)
    }
    

    /// Look up pitch accents for multiple terms
    func lookupPitchAccents(for terms: [String]) -> PitchAccentData {
        var allAccents: [PitchAccent] = []
        
        for term in terms {
            let pitchData = lookupPitchAccents(for: term)
            allAccents.append(contentsOf: pitchData.accents)
        }
        
        // Remove duplicates and sort by accent value
        let uniqueAccents = Array(Set(allAccents)).sorted { $0.pitchAccent < $1.pitchAccent }
        
        return PitchAccentData(accents: uniqueAccents)
    }
    
    /// Test the database connection and schema
    func testDatabase() {
        print("🧪 [PITCH ACCENT] Testing database connection...")
        
        // Check if database exists
        if dbQueue == nil {
            print("❌ [PITCH ACCENT] Database not connected!")
            return
        }
        
        // Test with some common Japanese words
        let testWords = ["こんにちは", "ありがとう", "日本", "にほん", "猫", "ねこ"]
        
        for word in testWords {
            let result = lookupPitchAccents(for: word)
            print("🧪 [PITCH ACCENT] Test word '\(word)': found \(result.accents.count) accent(s)")
            for accent in result.accents {
                print("   \(accent.term) (\(accent.reading)) - [\(accent.pitchAccent)]")
            }
        }
    }
}
