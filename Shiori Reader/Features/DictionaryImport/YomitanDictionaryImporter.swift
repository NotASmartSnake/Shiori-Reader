//
//  YomitanDictionaryImporter.swift
//  Shiori Reader
//
//  Created by Claude on 1/10/25.
//

import Foundation
import Compression

/// Errors that can occur during Yomitan dictionary import
enum YomitanImportError: Error, LocalizedError {
    case invalidZipFile
    case missingIndexFile
    case invalidIndexFile(String)
    case unsupportedVersion(Int)
    case missingRequiredFiles
    case invalidJSONFile(String, Error)
    case databaseCreationFailed(Error)
    case importCancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidZipFile:
            return "Invalid ZIP file format"
        case .missingIndexFile:
            return "Dictionary index file (index.json) not found"
        case .invalidIndexFile(let details):
            return "Invalid index file: \(details)"
        case .unsupportedVersion(let version):
            return "Unsupported dictionary version: \(version)"
        case .missingRequiredFiles:
            return "Required dictionary files are missing"
        case .invalidJSONFile(let filename, let error):
            return "Invalid JSON in file \(filename): \(error.localizedDescription)"
        case .databaseCreationFailed(let error):
            return "Failed to create database: \(error.localizedDescription)"
        case .importCancelled:
            return "Import was cancelled"
        }
    }
}

/// Progress information for dictionary import
struct YomitanImportProgress {
    let currentStep: String
    let completedSteps: Int
    let totalSteps: Int
    let processedEntries: Int
    let totalEntries: Int
    
    var overallProgress: Double {
        guard totalSteps > 0 else { return 0.0 }
        let stepProgress = Double(completedSteps) / Double(totalSteps)
        let entryProgress = totalEntries > 0 ? Double(processedEntries) / Double(totalEntries) : 0.0
        return (stepProgress + entryProgress / Double(totalSteps)) / 1.0
    }
}

/// Main importer class for Yomitan dictionaries
class YomitanDictionaryImporter {
    
    /// Progress callback type
    typealias ProgressCallback = (YomitanImportProgress) -> Void
    
    private var progressCallback: ProgressCallback?
    private var isCancelled = false
    
    /// Initialize with optional progress callback
    init(progressCallback: ProgressCallback? = nil) {
        self.progressCallback = progressCallback
    }
    
    /// Cancel the current import operation
    func cancel() {
        isCancelled = true
    }
    
    /// Import a Yomitan dictionary from ZIP data
    func importDictionary(
        from zipData: Data,
        to databaseURL: URL
    ) async throws -> YomitanIndex {
        isCancelled = false
        
        updateProgress("Extracting ZIP file...", 0, 6, 0, 0)
        
        // Extract ZIP file
        let extractedFiles = try extractZipFile(zipData)
        
        guard !isCancelled else { throw YomitanImportError.importCancelled }
        
        updateProgress("Reading index file...", 1, 6, 0, 0)
        
        // Read and validate index
        let index = try readAndValidateIndex(from: extractedFiles)
        
        guard !isCancelled else { throw YomitanImportError.importCancelled }
        
        updateProgress("Processing dictionary files...", 2, 6, 0, 0)
        
        // Process dictionary files
        let dictionaryData = try processDictionaryFiles(extractedFiles, index: index)
        
        guard !isCancelled else { throw YomitanImportError.importCancelled }
        
        updateProgress("Creating database...", 3, 6, 0, 0)
        
        // Create database
        try await createDatabase(at: databaseURL, with: dictionaryData, index: index)
        
        updateProgress("Import completed", 6, 6, 0, 0)
        
        return index
    }
    
    // MARK: - Private Methods
    
    private func updateProgress(
        _ step: String,
        _ completed: Int,
        _ total: Int,
        _ processedEntries: Int,
        _ totalEntries: Int
    ) {
        let progress = YomitanImportProgress(
            currentStep: step,
            completedSteps: completed,
            totalSteps: total,
            processedEntries: processedEntries,
            totalEntries: totalEntries
        )
        progressCallback?(progress)
    }
    
    /// Extract ZIP file and return file contents
    private func extractZipFile(_ zipData: Data) throws -> [String: Data] {
        do {
            return try SimpleZipExtractor.extractFiles(from: zipData)
        } catch {
            throw YomitanImportError.invalidZipFile
        }
    }
    
    /// Read and validate the index.json file
    private func readAndValidateIndex(from files: [String: Data]) throws -> YomitanIndex {
        guard let indexData = files["index.json"] else {
            // Check for index.json in subdirectories
            let indexFile = files.first { $0.key.hasSuffix("/index.json") || $0.key == "index.json" }
            guard let (_, indexData) = indexFile else {
                throw YomitanImportError.missingIndexFile
            }
            return try parseIndex(from: indexData)
        }
        
        return try parseIndex(from: indexData)
    }
    
    /// Parse index data
    private func parseIndex(from data: Data) throws -> YomitanIndex {
        do {
            let index = try JSONDecoder().decode(YomitanIndex.self, from: data)
            
            // Validate required fields
            guard !index.title.isEmpty else {
                throw YomitanImportError.invalidIndexFile("Missing title")
            }
            
            guard !index.revision.isEmpty else {
                throw YomitanImportError.invalidIndexFile("Missing revision")
            }
            
            // Check supported version
            let version = index.actualVersion
            guard version >= 1 && version <= 3 else {
                throw YomitanImportError.unsupportedVersion(version)
            }
            
            return index
            
        } catch let decodingError as DecodingError {
            let jsonString = String(data: data, encoding: .utf8) ?? "<unable to decode data as UTF-8>"
            print("❌ Failed to parse index.json:")
            print("   Error: \(decodingError.localizedDescription)")
            print("   JSON content: \(jsonString.prefix(500))...")
            throw YomitanImportError.invalidIndexFile(decodingError.localizedDescription)
        } catch {
            let jsonString = String(data: data, encoding: .utf8) ?? "<unable to decode data as UTF-8>"
            print("❌ Failed to parse index.json:")
            print("   Error: \(error.localizedDescription)")
            print("   JSON content: \(jsonString.prefix(500))...")
            throw YomitanImportError.invalidIndexFile(error.localizedDescription)
        }
    }
    
    /// Process all dictionary files
    private func processDictionaryFiles(
        _ files: [String: Data],
        index: YomitanIndex
    ) throws -> ProcessedDictionaryData {
        
        let version = index.actualVersion
        var processedData = ProcessedDictionaryData(
            index: index,
            terms: [],
            tags: [],
            termMeta: []
        )
        
        // Find and process term bank files
        let termBankFiles = files.filter { $0.key.matches(#"term_bank_\d+\.json"#) }
        let tagBankFiles = files.filter { $0.key.matches(#"tag_bank_\d+\.json"#) }
        let termMetaBankFiles = files.filter { $0.key.matches(#"term_meta_bank_\d+\.json"#) }
        
        let totalFiles = termBankFiles.count + tagBankFiles.count + termMetaBankFiles.count
        var processedFiles = 0
        
        // Process term banks
        for (filename, data) in termBankFiles.sorted(by: { $0.key < $1.key }) {
            guard !isCancelled else { throw YomitanImportError.importCancelled }
            
            updateProgress(
                "Processing \(filename)...",
                4, 6,
                processedFiles, totalFiles
            )
            
            let terms = try processTermBank(data, version: version, dictionary: index.title)
            processedData.terms.append(contentsOf: terms)
            
            processedFiles += 1
        }
        
        // Process tag banks
        for (filename, data) in tagBankFiles.sorted(by: { $0.key < $1.key }) {
            guard !isCancelled else { throw YomitanImportError.importCancelled }
            
            updateProgress(
                "Processing \(filename)...",
                4, 6,
                processedFiles, totalFiles
            )
            
            let tags = try processTagBank(data, dictionary: index.title)
            processedData.tags.append(contentsOf: tags)
            
            processedFiles += 1
        }
        
        // Process term meta banks
        for (filename, data) in termMetaBankFiles.sorted(by: { $0.key < $1.key }) {
            guard !isCancelled else { throw YomitanImportError.importCancelled }
            
            updateProgress(
                "Processing \(filename)...",
                4, 6,
                processedFiles, totalFiles
            )
            
            let termMeta = try processTermMetaBank(data, dictionary: index.title)
            processedData.termMeta.append(contentsOf: termMeta)
            
            processedFiles += 1
        }
        
        // Add tags from index.json if present
        if let tagMeta = index.tagMeta {
            for (name, meta) in tagMeta {
                let tag = ProcessedYomitanTag(
                    name: name,
                    category: meta.category,
                    order: meta.order,
                    notes: meta.notes,
                    score: meta.score,
                    dictionary: index.title
                )
                processedData.tags.append(tag)
            }
        }
        
        return processedData
    }
    
    /// Process term bank file
    private func processTermBank(
        _ data: Data,
        version: Int,
        dictionary: String
    ) throws -> [ProcessedYomitanTerm] {
        
        do {
            let rawTerms: [[YomitanTermValue]]
            
            if version == 1 {
                rawTerms = try JSONDecoder().decode([YomitanTermV1].self, from: data)
            } else {
                rawTerms = try JSONDecoder().decode([YomitanTermV3].self, from: data)
            }
            
            var processedTerms: [ProcessedYomitanTerm] = []
            
            for rawTerm in rawTerms {
                if version == 1 {
                    if let processed = ProcessedYomitanTerm.fromV1(rawTerm, dictionary: dictionary) {
                        processedTerms.append(processed)
                    }
                } else {
                    if let processed = ProcessedYomitanTerm.fromV3(rawTerm, dictionary: dictionary) {
                        processedTerms.append(processed)
                    }
                }
            }
            
            return processedTerms
            
        } catch {
            let jsonString = String(data: data, encoding: .utf8) ?? "<unable to decode data as UTF-8>"
            print("❌ Failed to parse term bank JSON:")
            print("   Error: \(error.localizedDescription)")
            print("   JSON content (first 500 chars): \(jsonString.prefix(500))...")
            if let decodingError = error as? DecodingError {
                print("   Decoding error details: \(decodingError)")
            }
            throw YomitanImportError.invalidJSONFile("term_bank", error)
        }
    }
    
    /// Process tag bank file
    private func processTagBank(_ data: Data, dictionary: String) throws -> [ProcessedYomitanTag] {
        do {
            let rawTags = try JSONDecoder().decode([YomitanTag].self, from: data)
            
            var processedTags: [ProcessedYomitanTag] = []
            
            for rawTag in rawTags {
                if let processed = ProcessedYomitanTag.fromYomitanTag(rawTag, dictionary: dictionary) {
                    processedTags.append(processed)
                }
            }
            
            return processedTags
            
        } catch {
            let jsonString = String(data: data, encoding: .utf8) ?? "<unable to decode data as UTF-8>"
            print("❌ Failed to parse tag bank JSON:")
            print("   Error: \(error.localizedDescription)")
            print("   JSON content (first 500 chars): \(jsonString.prefix(500))...")
            if let decodingError = error as? DecodingError {
                print("   Decoding error details: \(decodingError)")
            }
            throw YomitanImportError.invalidJSONFile("tag_bank", error)
        }
    }
    
    /// Process term meta bank file
    private func processTermMetaBank(_ data: Data, dictionary: String) throws -> [ProcessedYomitanTermMeta] {
        do {
            let rawTermMeta = try JSONDecoder().decode([YomitanTermMeta].self, from: data)
            
            var processedTermMeta: [ProcessedYomitanTermMeta] = []
            
            for rawMeta in rawTermMeta {
                if let processed = ProcessedYomitanTermMeta.fromYomitanTermMeta(rawMeta, dictionary: dictionary) {
                    processedTermMeta.append(processed)
                }
            }
            
            return processedTermMeta
            
        } catch {
            let jsonString = String(data: data, encoding: .utf8) ?? "<unable to decode data as UTF-8>"
            print("❌ Failed to parse term meta bank JSON:")
            print("   Error: \(error.localizedDescription)")
            print("   JSON content (first 500 chars): \(jsonString.prefix(500))...")
            if let decodingError = error as? DecodingError {
                print("   Decoding error details: \(decodingError)")
            }
            throw YomitanImportError.invalidJSONFile("term_meta_bank", error)
        }
    }
    
    /// Create SQLite database from processed data
    private func createDatabase(
        at databaseURL: URL,
        with data: ProcessedDictionaryData,
        index: YomitanIndex
    ) async throws {
        
        do {
            let dbCreator = SQLiteYomitanDictionary()
            try await dbCreator.createDatabase(
                at: databaseURL,
                with: data,
                progressCallback: { [weak self] current, total in
                    self?.updateProgress(
                        "Writing database entries...",
                        5, 6,
                        current, total
                    )
                }
            )
        } catch {
            throw YomitanImportError.databaseCreationFailed(error)
        }
    }
}

/// Processed dictionary data ready for database creation
struct ProcessedDictionaryData {
    let index: YomitanIndex
    var terms: [ProcessedYomitanTerm]
    var tags: [ProcessedYomitanTag]
    var termMeta: [ProcessedYomitanTermMeta]
}

// MARK: - String Extension for Regex

extension String {
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression) != nil
    }
}
