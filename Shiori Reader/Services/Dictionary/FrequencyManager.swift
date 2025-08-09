import Foundation
import GRDB

struct FrequencyData {
    let word: String
    let reading: String?
    let frequency: Int
    let rank: Int
    let source: String
}

struct YomitanFrequencyData {
    let frequency: Int
    var reading: String?
    
    init(frequency: Int, reading: String? = nil) {
        self.frequency = frequency
        self.reading = reading
    }
}

class FrequencyManager {
    static let shared = FrequencyManager()
    
    private var bccwjQueue: DatabaseQueue?
    
    private init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        do {
            // Setup BCCWJ frequency database
            if let bccwjPath = Bundle.main.path(forResource: "bccwj", ofType: "db") {
                var configuration = Configuration()
                configuration.readonly = true
                bccwjQueue = try DatabaseQueue(path: bccwjPath, configuration: configuration)
                print("BCCWJ frequency database loaded successfully")
            } else {
                print("BCCWJ frequency database not found in bundle")
            }
        } catch {
            print("Error setting up BCCWJ frequency database: \(error)")
        }
    }
    
    /// Get frequency data for a specific word (optimized version)
    func getBCCWJFrequencyData(for word: String) -> FrequencyData? {
        guard let db = bccwjQueue else { return nil }
        
        do {
            return try db.read { db in
                // Fast exact match query
                let rows = try Row.fetchAll(db, sql: """
                    SELECT term, frequency_value
                    FROM frequency
                    WHERE term = ?
                    LIMIT 1
                    """, arguments: [word])
                
                if let row = rows.first {
                    let term = row["term"] as? String ?? word
                    
                    // Optimized parsing - try Int64 first (most common)
                    let frequencyValue: Int
                    if let int64Value = row["frequency_value"] as? Int64 {
                        frequencyValue = Int(int64Value)
                    } else if let intValue = row["frequency_value"] as? Int {
                        frequencyValue = intValue
                    } else {
                        frequencyValue = (try? Int.fromDatabaseValue(row["frequency_value"])) ?? 0
                    }
                    
                    if frequencyValue > 0 {
                        return FrequencyData(
                            word: term,
                            reading: nil,
                            frequency: frequencyValue,
                            rank: frequencyValue,
                            source: "bccwj"
                        )
                    }
                }

                return nil
            }
        } catch {
            return nil
        }
    }

    /// Get the frequency data from the "data" field json string in a term bank.
    func decodeFrequencyJson(json jsonData: Data) -> YomitanFrequencyData? {
        let json = try! JSONSerialization.jsonObject(with: jsonData, options: [JSONSerialization.ReadingOptions.fragmentsAllowed])
        
        // frequency is just a number
        if let frequency = json as? NSNumber {
            return YomitanFrequencyData(frequency: frequency.intValue)
        }
        
        // frequency is a number stored in a string value
        if let frequencyString = json as? NSString {
            if let frequency = Int(frequencyString as String) {
                return YomitanFrequencyData(frequency: frequency)
            }
        }

        if let jsonObj = json as? [String: Any] {
            // frequency is an object with a value and an optional display value
            if let value = jsonObj["value"],
                let jsonFrequency = value as? NSNumber
            {
                return YomitanFrequencyData(frequency: jsonFrequency.intValue)
            }

            // frequency is nested in another object with a reading value
            if let jsonFrequency = jsonObj["frequency"] {
                let data = try! JSONSerialization.data(withJSONObject: jsonFrequency, options: [JSONSerialization.WritingOptions.fragmentsAllowed])
                // call this function again to get the inner frequency value
                let frequency = decodeFrequencyJson(json: data)
                
                guard var frequencyData = frequency else {
                    return nil
                }
                
                // assign reading data to frequency data
                if let reading = jsonObj["reading"] as? String {
                    frequencyData.reading = reading
                }
                
                return frequencyData
            }
        }

        return nil
    }

    /// Get frequency data from an imported dictionary
    func getImportedFrequencyData(for word: String, with reading: String, db: DatabaseQueue, dictionaryKey: String)
        -> FrequencyData?
    {
        var rows: [Row] = []
        
        do {
            try db.read { db in
                rows = try Row.fetchAll(
                    db,
                    sql: """
                        SELECT id, expression, mode, data, dictionary
                        FROM term_meta
                        WHERE expression = ?
                        ORDER BY id
                        """, arguments: [word])
            }

            for row in rows {
                let term = row["expression"] as! String
                let mode = row["mode"] as! String
                let data = row["data"] as! String

                if mode == "freq" {
                    let jsonData = data.data(using: .utf8)!
                    let yomitanFrequencyData = decodeFrequencyJson(json: jsonData)

                    if let frequency = yomitanFrequencyData {
                        if let frequencyReading = frequency.reading,
                           frequencyReading != reading {
                            continue
                        }
                        
                        return FrequencyData(
                            word: term,
                            reading: reading,
                            frequency: frequency.frequency,
                            rank: frequency.frequency,
                            source: dictionaryKey
                        )
                    }
                }
            }

            return nil
        } catch {
            return nil
        }
    }
    
    /// Get frequency rank for display (returns a formatted string)
    func getFrequencyRank(for word: String) -> String? {
        guard let frequencyData = getBCCWJFrequencyData(for: word) else { return nil }
        
        if frequencyData.rank > 0 {
            return "#\(frequencyData.rank)"
        } else if frequencyData.frequency > 0 {
            return "f:\(frequencyData.frequency)"
        }
        
        return nil
    }
    
    /// Test the BCCWJ database integration
    func testBCCWJDatabaseIntegration() {
        print("🧪 [BCCWJ TEST] Testing BCCWJ database integration...")
        
        guard let db = bccwjQueue else {
            print("🧪 [BCCWJ TEST] ERROR: BCCWJ database queue is nil!")
            return
        }
        
        do {
            try db.read { db in
                // Check database structure
                let tableRows = try Row.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table'")
                let tableNames = tableRows.map { $0["name"] as? String ?? "unknown" }
                print("🧪 [BCCWJ TEST] Available tables: \(tableNames)")
                
                // For each table, show its structure
                for tableName in tableNames {
                    let schemaRows = try Row.fetchAll(db, sql: "PRAGMA table_info(\(tableName))")
                    print("🧪 [BCCWJ TEST] Table '\(tableName)' schema:")
                    for row in schemaRows {
                        let name = row["name"] as? String ?? "unknown"
                        let type = row["type"] as? String ?? "unknown"
                        print("  - \(name): \(type)")
                    }
                    
                    // Show sample data
                    let sampleRows = try Row.fetchAll(db, sql: "SELECT * FROM \(tableName) LIMIT 3")
                    print("🧪 [BCCWJ TEST] Sample data from '\(tableName)':")
                    for (index, row) in sampleRows.enumerated() {
                        print("  Sample \(index + 1):")
                        for column in row.columnNames {
                            let value = row[column]
                            print("    \(column): \(value ?? "NULL")")
                        }
                    }
                    print()
                }
                
                // Test frequency lookup for common words
                let testWords = ["猫", "日本", "最初", "食べる", "の", "は", "を", "に"]
                print("🧪 [BCCWJ TEST] Testing frequency lookup for common words:")
                for word in testWords {
                    // Test direct database query
                    let directRows = try Row.fetchAll(db, sql: "SELECT term, frequency_value FROM frequency WHERE term = ? LIMIT 1", arguments: [word])
                    if let row = directRows.first {
                        let term = row["term"] as? String ?? "unknown"
                        let freq = row["frequency_value"] as? Int ?? 0
                        print("🧪 [BCCWJ TEST] Direct query '\(word)': term='\(term)', freq=\(freq)")
                    } else {
                        print("🧪 [BCCWJ TEST] Direct query '\(word)': No match found")
                    }
                    
                    // Test using our frequency manager
                    if let frequencyData = getBCCWJFrequencyData(for: word) {
                        print("🧪 [BCCWJ TEST] FrequencyManager '\(word)': rank=\(frequencyData.rank), freq=\(frequencyData.frequency)")
                    } else {
                        print("🧪 [BCCWJ TEST] FrequencyManager '\(word)': No frequency data found")
                    }
                }
            }
        } catch {
            print("🧪 [BCCWJ TEST] ERROR: \(error)")
        }
    }
}
