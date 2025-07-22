import Foundation
import GRDB

/// Utility for inspecting and debugging imported dictionary databases
class DictionaryDatabaseInspector {
    
    static let shared = DictionaryDatabaseInspector()
    private init() {}
    
    /// Export database to Documents folder for easy access
    func exportDatabaseToDocuments(_ info: ImportedDictionaryInfo) throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        let exportURL = documentsURL.appendingPathComponent("exported_\(info.title).db")
        
        // Copy database to Documents folder
        if FileManager.default.fileExists(atPath: exportURL.path) {
            try FileManager.default.removeItem(at: exportURL)
        }
        
        try FileManager.default.copyItem(at: info.databaseURL, to: exportURL)
        
        print("📱 Database exported to: \(exportURL.path)")
        return exportURL
    }
    
    /// Get detailed database statistics
    func getDatabaseStats(_ info: ImportedDictionaryInfo) -> DatabaseStats? {
        do {
            var configuration = Configuration()
            configuration.readonly = true
            let queue = try DatabaseQueue(path: info.databaseURL.path, configuration: configuration)
            
            return try queue.read { db in
                let termCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM terms") ?? 0
                let tagCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM tags") ?? 0
                let termMetaCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM term_meta") ?? 0
                
                // Get sample terms
                let sampleTerms = try Row.fetchAll(db, sql: """
                    SELECT expression, reading, definitions 
                    FROM terms 
                    LIMIT 10
                    """)
                
                // Get database file size
                let fileSize = try FileManager.default.attributesOfItem(atPath: info.databaseURL.path)[.size] as? Int64 ?? 0
                
                return DatabaseStats(
                    termCount: termCount,
                    tagCount: tagCount,
                    termMetaCount: termMetaCount,
                    fileSize: fileSize,
                    sampleTerms: sampleTerms
                )
            }
        } catch {
            print("❌ Error getting database stats: \(error)")
            return nil
        }
    }
    
    /// Search specific terms in the database for debugging
    func searchTermsInDatabase(_ info: ImportedDictionaryInfo, searchTerm: String) -> [DebugTerm] {
        do {
            var configuration = Configuration()
            configuration.readonly = true
            let queue = try DatabaseQueue(path: info.databaseURL.path, configuration: configuration)
            
            return try queue.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT expression, reading, definitions, rules, term_tags
                    FROM terms 
                    WHERE expression LIKE ? OR reading LIKE ?
                    LIMIT 20
                    """, arguments: ["%\(searchTerm)%", "%\(searchTerm)%"])
                
                return rows.map { row in
                    DebugTerm(
                        expression: row["expression"] ?? "",
                        reading: row["reading"] ?? "",
                        definitions: row["definitions"] ?? "",
                        rules: row["rules"] ?? "",
                        termTags: row["term_tags"] ?? ""
                    )
                }
            }
        } catch {
            print("❌ Error searching database: \(error)")
            return []
        }
    }
    
    /// Get all table schemas for debugging
    func getTableSchemas(_ info: ImportedDictionaryInfo) -> [String] {
        do {
            var configuration = Configuration()
            configuration.readonly = true
            let queue = try DatabaseQueue(path: info.databaseURL.path, configuration: configuration)
            
            return try queue.read { db in
                let tables = try Row.fetchAll(db, sql: """
                    SELECT name FROM sqlite_master 
                    WHERE type='table' AND name NOT LIKE 'sqlite_%'
                    """)
                
                var schemas: [String] = []
                
                for table in tables {
                    if let tableName = table["name"] as? String {
                        let schema = try Row.fetchAll(db, sql: "PRAGMA table_info(\(tableName))")
                        let columnInfo = schema.map { row in
                            let name = row["name"] as? String ?? ""
                            let type = row["type"] as? String ?? ""
                            return "\(name): \(type)"
                        }.joined(separator: ", ")
                        
                        schemas.append("\(tableName): [\(columnInfo)]")
                    }
                }
                
                return schemas
            }
        } catch {
            print("❌ Error getting schemas: \(error)")
            return []
        }
    }
}

// MARK: - Data Structures

struct DatabaseStats {
    let termCount: Int
    let tagCount: Int
    let termMetaCount: Int
    let fileSize: Int64
    let sampleTerms: [Row]
    
    var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        return formatter.string(fromByteCount: fileSize)
    }
}

struct DebugTerm {
    let expression: String
    let reading: String
    let definitions: String
    let rules: String
    let termTags: String
}
