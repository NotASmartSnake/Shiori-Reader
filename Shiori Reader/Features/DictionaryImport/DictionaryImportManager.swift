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
    
    /// Import a Yomitan dictionary from a ZIP file URL
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
            
            // Read ZIP file data
            let zipData = try Data(contentsOf: fileURL)
            
            
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
                from: zipData,
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
    
    var errorDescription: String? {
        switch self {
        case .fileNotAccessible(let message):
            return message
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
