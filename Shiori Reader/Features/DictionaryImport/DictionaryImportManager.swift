//
//  DictionaryImportManager.swift
//  Shiori Reader
//
//  Created by Claude on 1/10/25.
//

import Foundation
import GRDB

/// Manages the import of Yomitan dictionaries and integrates with the existing DictionaryManager
class DictionaryImportManager: ObservableObject {
    
    static let shared = DictionaryImportManager()
    
    @Published var isImporting = false
    @Published var importProgress: YomitanImportProgress?
    @Published var lastImportError: Error?
    
    private var currentImporter: YomitanDictionaryImporter?
    
    private init() {}
    
    /// Import a Yomitan dictionary from a ZIP file or single JSON file URL
    @MainActor
    func importDictionary(from fileURL: URL) async {
        guard !isImporting else {
            return
        }
        
        isImporting = true
        importProgress = nil
        lastImportError = nil
        
        do {
            // CRITICAL: Start accessing security-scoped resource
            let shouldStopAccessing = fileURL.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }
            
            // Verify we can access the file
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw ImportError.fileNotAccessible("Cannot access the selected file. Please try selecting it again.")
            }
            
            // Read file data
            let fileData = try Data(contentsOf: fileURL)
            
            // Detect file type and handle accordingly
            let fileExtension = fileURL.pathExtension.lowercased()
            let finalData: Data
            
            if fileExtension == "json" {
                // Convert single JSON file to Yomitan ZIP format
                print("📝 Detected JSON file, converting to Yomitan format...")
                finalData = try convertSingleJSONToYomitanZip(jsonData: fileData, filename: fileURL.lastPathComponent)
            } else if fileExtension == "zip" {
                // Check if this ZIP contains a single JSON that needs conversion
                print("📦 Detected ZIP file, checking contents...")
                finalData = try handleZipFile(zipData: fileData, filename: fileURL.lastPathComponent)
            } else {
                // Assume it's a ZIP file
                finalData = fileData
            }
            
            // Create importer with progress callback
            currentImporter = YomitanDictionaryImporter { [weak self] progress in
                DispatchQueue.main.async {
                    self?.importProgress = progress
                }
            }
            
            // Generate unique database filename
            let databaseURL = try generateDatabaseURL()
            
            // Import dictionary
            let index = try await currentImporter!.importDictionary(
                from: finalData,
                to: databaseURL
            )
            
            // Add to DictionaryManager
            try registerImportedDictionary(at: databaseURL, index: index)
            
            
        } catch {
            lastImportError = error
        }
        
        isImporting = false
        currentImporter = nil
    }
    
    /// Cancel current import operation
    func cancelImport() {
        currentImporter?.cancel()
    }
    
    /// Force reload of imported dictionaries (for debugging)
    func reloadImportedDictionaries() {
        DictionaryManager.shared.reloadImportedDictionaries()
    }
    
    /// Clear all registry entries - useful for testing
    func clearRegistry() {
        UserDefaults.standard.removeObject(forKey: "ImportedDictionaries")
    }
    
    /// Get list of imported dictionaries
    func getImportedDictionaries() -> [ImportedDictionaryInfo] {
        return loadRegistry()
    }
    
    /// Delete an imported dictionary
    @MainActor
    func deleteImportedDictionary(_ info: ImportedDictionaryInfo) throws {
        
        // First, notify DictionaryManager to release any database connections
        DictionaryManager.shared.reloadImportedDictionaries()
        
        // Small delay to ensure connections are closed
        Thread.sleep(forTimeInterval: 0.1)
        
        // Get current database URL (this handles path resolution properly)
        let databaseURL = info.databaseURL
        
        // Remove database file
        if FileManager.default.fileExists(atPath: databaseURL.path) {
            do {
                try FileManager.default.removeItem(at: databaseURL)
            } catch {
                // Don't throw here - continue with registry cleanup
            }
        } else {
        }
        
        // Remove from registry
        var registry = loadRegistry()
        let originalCount = registry.count
        registry.removeAll { $0.id == info.id }
        
        if registry.count < originalCount {
        } else {
        }
        
        // Save updated registry
        do {
            let data = try JSONEncoder().encode(registry)
            UserDefaults.standard.set(data, forKey: "ImportedDictionaries")
        } catch {
            throw error
        }
        
        // Final cleanup - reload dictionaries
        DictionaryManager.shared.reloadImportedDictionaries()
        
    }
    
    // MARK: - Private Methods
    
    /// Handle ZIP file - check if it needs conversion or can be used as-is
    private func handleZipFile(zipData: Data, filename: String) throws -> Data {
        do {
            // Try to extract the ZIP to see what's inside
            let extractedFiles = try SimpleZipExtractor.extractFiles(from: zipData)
            print("📂 ZIP contents: \(extractedFiles.keys.sorted())")
            
            // Check if it already has index.json (standard Yomitan format)
            if extractedFiles.keys.contains("index.json") {
                print("✅ Standard Yomitan ZIP detected with index.json")
                return zipData
            }
            
            // Check if it contains a single JSON file that needs conversion
            let jsonFiles = extractedFiles.filter { $0.key.hasSuffix(".json") }
            if jsonFiles.count == 1,
               let (jsonFilename, jsonData) = jsonFiles.first,
               let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]],
               let firstEntry = jsonArray.first,
               firstEntry.keys.contains("term") && firstEntry.keys.contains("definition") {
                
                print("🔄 Found single JSON dictionary in ZIP, converting...")
                return try convertSingleJSONToYomitanZip(entries: jsonArray, filename: jsonFilename)
            }
            
            // If none of the above, return as-is and let the importer handle errors
            print("⚠️ ZIP doesn't contain standard Yomitan format or convertible JSON")
            return zipData
            
        } catch {
            print("❌ Error extracting ZIP: \(error)")
            // If extraction fails, return as-is and let the importer handle it
            return zipData
        }
    }
    
    /// Convert a single JSON dictionary file to Yomitan ZIP format
    private func convertSingleJSONToYomitanZip(jsonData: Data, filename: String) throws -> Data {
        // Parse the JSON to determine structure
        guard let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]],
              let firstEntry = jsonArray.first else {
            throw ImportError.invalidJSONFormat("Unable to parse JSON as dictionary array")
        }
        
        // Detect if this is a single JSON dictionary (has term, definition fields)
        if firstEntry.keys.contains("term") && firstEntry.keys.contains("definition") {
            return try convertSingleJSONToYomitanZip(entries: jsonArray, filename: filename)
        }
        
        // If it's already in Yomitan format, wrap it in a ZIP
        throw ImportError.unsupportedJSONFormat("JSON format not recognized. Only single JSON dictionaries with term/definition format are currently supported.")
    }
    
    /// Convert single JSON dictionary format to Yomitan ZIP
    private func convertSingleJSONToYomitanZip(entries: [[String: Any]], filename: String) throws -> Data {
        // Extract dictionary name from filename
        let dictionaryName = filename.replacingOccurrences(of: ".json", with: "")
        print("🏷️ Converting \(entries.count) entries for dictionary: \(dictionaryName)")
        
        // Create index.json
        let index: [String: Any] = [
            "title": dictionaryName,
            "revision": "1.0",
            "format": 3,
            "version": 3,
            "description": "Imported from \(filename)",
            "author": "Unknown",
            "url": "",
            "tags": [:] as [String: Any]
        ]
        
        print("📋 Created index with title: \(dictionaryName)")
        
        // Convert entries to Yomitan term format
        var yomitanTerms: [[Any]] = []
        
        for entry in entries {
            guard let term = entry["term"] as? String,
                  let definition = entry["definition"] as? String else {
                continue
            }
            
            let altterm = entry["altterm"] as? String ?? ""
            let pos = entry["pos"] as? String ?? ""
            let pronunciation = entry["pronunciation"] as? String ?? ""
            
            // Create reading (use altterm if available, otherwise same as term)
            let reading = !altterm.isEmpty ? altterm : term
            
            // Parse definitions from HTML format
            let cleanDefinition = definition
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Create Yomitan V3 format: [expression, reading, definitionTags, rules, score, glossary, sequence, termTags]
            let yomitanTerm: [Any] = [
                term,                    // expression
                reading,                 // reading
                pos.isEmpty ? "" : pos,  // definitionTags
                "",                      // rules
                0,                       // score
                [cleanDefinition],       // glossary (array of definitions)
                0,                       // sequence
                ""                       // termTags
            ]
            
            yomitanTerms.append(yomitanTerm)
        }
        
        print("✅ Converted \(yomitanTerms.count) terms successfully")
        
        // Create ZIP archive
        let zipData = try createYomitanZip(index: index, terms: yomitanTerms)
        print("📦 Created ZIP archive with \(zipData.count) bytes")
        
        return zipData
    }
    
    /// Create a Yomitan-compatible ZIP archive
    private func createYomitanZip(index: [String: Any], terms: [[Any]]) throws -> Data {
        // Convert to JSON data
        let indexData = try JSONSerialization.data(withJSONObject: index, options: [])
        let termsData = try JSONSerialization.data(withJSONObject: terms, options: [])
        
        print("📄 Created index.json: \(indexData.count) bytes")
        print("📄 Created term_bank_1.json: \(termsData.count) bytes")
        
        // Create a simple ZIP using a basic implementation
        let zipData = try createSimpleZip(files: [
            "index.json": indexData,
            "term_bank_1.json": termsData
        ])
        
        print("🗂️ Final ZIP contains files: index.json, term_bank_1.json")
        return zipData
    }
    
    /// Create a simple ZIP archive with the given files
    private func createSimpleZip(files: [String: Data]) throws -> Data {
        // Create a minimal ZIP file structure manually
        // This creates a basic ZIP file compatible with the existing extractor
        
        var zipData = Data()
        var centralDirectory = Data()
        var localHeaderOffset: UInt32 = 0
        
        for (filename, fileData) in files {
            // Local file header
            let localHeader = createLocalFileHeader(filename: filename, fileData: fileData)
            let localHeaderSize = UInt32(localHeader.count)
            
            // Add local header and file data to ZIP
            zipData.append(localHeader)
            zipData.append(fileData)
            
            // Create central directory entry
            let centralDirEntry = createCentralDirectoryEntry(
                filename: filename,
                fileData: fileData,
                localHeaderOffset: localHeaderOffset
            )
            centralDirectory.append(centralDirEntry)
            
            localHeaderOffset += localHeaderSize + UInt32(fileData.count)
        }
        
        // Add central directory to ZIP
        let centralDirOffset = UInt32(zipData.count)
        zipData.append(centralDirectory)
        
        // Add end of central directory record
        let endRecord = createEndOfCentralDirectoryRecord(
            entryCount: UInt16(files.count),
            centralDirSize: UInt32(centralDirectory.count),
            centralDirOffset: centralDirOffset
        )
        zipData.append(endRecord)
        
        return zipData
    }
    
    private func createLocalFileHeader(filename: String, fileData: Data) -> Data {
        var header = Data()
        let filenameData = filename.data(using: .utf8)!
        
        header.append(UInt32(0x04034b50).littleEndianData) // Local file header signature
        header.append(UInt16(20).littleEndianData)          // Version needed to extract
        header.append(UInt16(0).littleEndianData)           // General purpose bit flag
        header.append(UInt16(0).littleEndianData)           // Compression method (no compression)
        header.append(UInt16(0).littleEndianData)           // Last mod file time
        header.append(UInt16(0).littleEndianData)           // Last mod file date
        header.append(UInt32(0).littleEndianData)           // CRC-32 (we'll skip for simplicity)
        header.append(UInt32(fileData.count).littleEndianData) // Compressed size
        header.append(UInt32(fileData.count).littleEndianData) // Uncompressed size
        header.append(UInt16(filenameData.count).littleEndianData) // Filename length
        header.append(UInt16(0).littleEndianData)           // Extra field length
        header.append(filenameData)                         // Filename
        
        return header
    }
    
    private func createCentralDirectoryEntry(filename: String, fileData: Data, localHeaderOffset: UInt32) -> Data {
        var entry = Data()
        let filenameData = filename.data(using: .utf8)!
        
        entry.append(UInt32(0x02014b50).littleEndianData)   // Central directory signature
        entry.append(UInt16(20).littleEndianData)           // Version made by
        entry.append(UInt16(20).littleEndianData)           // Version needed to extract
        entry.append(UInt16(0).littleEndianData)            // General purpose bit flag
        entry.append(UInt16(0).littleEndianData)            // Compression method
        entry.append(UInt16(0).littleEndianData)            // Last mod file time
        entry.append(UInt16(0).littleEndianData)            // Last mod file date
        entry.append(UInt32(0).littleEndianData)            // CRC-32
        entry.append(UInt32(fileData.count).littleEndianData) // Compressed size
        entry.append(UInt32(fileData.count).littleEndianData) // Uncompressed size
        entry.append(UInt16(filenameData.count).littleEndianData) // Filename length
        entry.append(UInt16(0).littleEndianData)            // Extra field length
        entry.append(UInt16(0).littleEndianData)            // File comment length
        entry.append(UInt16(0).littleEndianData)            // Disk number start
        entry.append(UInt16(0).littleEndianData)            // Internal file attributes
        entry.append(UInt32(0).littleEndianData)            // External file attributes
        entry.append(localHeaderOffset.littleEndianData)    // Local header offset
        entry.append(filenameData)                          // Filename
        
        return entry
    }
    
    private func createEndOfCentralDirectoryRecord(entryCount: UInt16, centralDirSize: UInt32, centralDirOffset: UInt32) -> Data {
        var record = Data()
        
        record.append(UInt32(0x06054b50).littleEndianData)  // End of central dir signature
        record.append(UInt16(0).littleEndianData)           // Number of this disk
        record.append(UInt16(0).littleEndianData)           // Disk where central directory starts
        record.append(entryCount.littleEndianData)          // Number of central directory records on this disk
        record.append(entryCount.littleEndianData)          // Total number of central directory records
        record.append(centralDirSize.littleEndianData)      // Size of central directory
        record.append(centralDirOffset.littleEndianData)    // Offset of start of central directory
        record.append(UInt16(0).littleEndianData)           // ZIP file comment length
        
        return record
    }
    
    private func generateDatabaseURL() throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        let dictionariesURL = documentsURL.appendingPathComponent("ImportedDictionaries")
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(
            at: dictionariesURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Generate unique filename
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "imported_dictionary_\(timestamp).db"
        
        return dictionariesURL.appendingPathComponent(filename)
    }
    
    private func registerImportedDictionary(at databaseURL: URL, index: YomitanIndex) throws {
        // Store dictionary metadata for future reference - only store filename
        let filename = databaseURL.lastPathComponent
        let info = ImportedDictionaryInfo(
            title: index.title,
            revision: index.revision,
            version: index.actualVersion,
            author: index.author,
            description: index.description,
            databaseFilename: filename,
            importDate: Date()
        )
        
        // Save to registry
        saveToRegistry(info)
        
        // Notify DictionaryManager about new dictionary
        DictionaryManager.shared.reloadImportedDictionaries()
    }
    
    private func saveToRegistry(_ info: ImportedDictionaryInfo) {
        var registry = loadRegistry()
        registry.append(info)
        
        if let data = try? JSONEncoder().encode(registry) {
            UserDefaults.standard.set(data, forKey: "ImportedDictionaries")
        }
    }
    
    private func loadRegistry() -> [ImportedDictionaryInfo] {
        guard let data = UserDefaults.standard.data(forKey: "ImportedDictionaries"),
              let registry = try? JSONDecoder().decode([ImportedDictionaryInfo].self, from: data) else {
            return []
        }
        
        // Clean up registry: remove entries for files that no longer exist
        let validEntries = registry.filter { info in
            let fileExists = FileManager.default.fileExists(atPath: info.databaseURL.path)
            if !fileExists {
            }
            return fileExists
        }
        
        // Save cleaned registry if it changed
        if validEntries.count != registry.count {
            if let data = try? JSONEncoder().encode(validEntries) {
                UserDefaults.standard.set(data, forKey: "ImportedDictionaries")
            }
        }
        
        return validEntries
    }
}

/// Custom import errors for better user feedback
enum ImportError: Error, LocalizedError {
    case fileNotAccessible(String)
    case invalidJSONFormat(String)
    case unsupportedJSONFormat(String)
    case zipCreationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotAccessible(let message):
            return message
        case .invalidJSONFormat(let message):
            return "Invalid JSON format: \(message)"
        case .unsupportedJSONFormat(let message):
            return "Unsupported JSON format: \(message)"
        case .zipCreationFailed(let message):
            return "Failed to create ZIP archive: \(message)"
        }
    }
}

/// Information about an imported dictionary
struct ImportedDictionaryInfo: Codable, Identifiable {
    let id: UUID
    let title: String
    let revision: String
    let version: Int
    let author: String?
    let description: String?
    let databaseFilename: String  // Store just the filename, not full path
    let importDate: Date
    
    // Support for legacy entries that stored full URLs
    private let legacyDatabaseURL: URL?
    
    init(title: String, revision: String, version: Int, author: String?, description: String?, databaseFilename: String, importDate: Date) {
        self.id = UUID()
        self.title = title
        self.revision = revision
        self.version = version
        self.author = author
        self.description = description
        self.databaseFilename = databaseFilename
        self.importDate = importDate
        self.legacyDatabaseURL = nil
    }
    
    // Custom decoder to handle legacy format
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.revision = try container.decode(String.self, forKey: .revision)
        self.version = try container.decode(Int.self, forKey: .version)
        self.author = try? container.decode(String.self, forKey: .author)
        self.description = try? container.decode(String.self, forKey: .description)
        self.importDate = try container.decode(Date.self, forKey: .importDate)
        
        // Handle legacy databaseURL vs new databaseFilename
        if let filename = try? container.decode(String.self, forKey: .databaseFilename) {
            // New format
            self.databaseFilename = filename
            self.legacyDatabaseURL = nil
        } else if let url = try? container.decode(URL.self, forKey: .legacyDatabaseURL) {
            // Legacy format - extract filename
            self.databaseFilename = url.lastPathComponent
            self.legacyDatabaseURL = url
        } else {
            throw DecodingError.keyNotFound(CodingKeys.databaseFilename, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing databaseFilename or legacyDatabaseURL"))
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, title, revision, version, author, description, databaseFilename, importDate
        case legacyDatabaseURL = "databaseURL"
    }
    
    var displayName: String {
        return title
    }
    
    var detailText: String {
        var details: [String] = []
        
        if let author = author, !author.isEmpty {
            details.append("by \(author)")
        }
        
        details.append("v\(revision)")
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        details.append("imported \(formatter.string(from: importDate))")
        
        return details.joined(separator: " • ")
    }
    
    /// Get the full database URL using current Documents directory
    var databaseURL: URL {
        do {
            let documentsURL = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            return documentsURL
                .appendingPathComponent("ImportedDictionaries")
                .appendingPathComponent(databaseFilename)
        } catch {
            // Fallback - this shouldn't happen in normal cases
            return URL(fileURLWithPath: "/tmp/\(databaseFilename)")
        }
    }
}

// MARK: - Extensions for ZIP creation

extension UInt16 {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<UInt16>.size)
    }
}

extension UInt32 {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
    }
}
