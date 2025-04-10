//
//  DocumentPickerCoordinator.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/29/25.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Document Picker Coordinator
class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
    let parent: DocumentImporter
    
    init(parent: DocumentImporter) {
        self.parent = parent
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        // Get security-scoped access
        guard url.startAccessingSecurityScopedResource() else {
            parent.status = .failure("Access denied to file")
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            // Create app Books directory if needed
            let destinationDirectory = try getOrCreateBooksDirectory()
            
            // Create a unique filename
            let uniqueFileName = createUniqueFilename(for: url.lastPathComponent)
            let destinationURL = destinationDirectory.appendingPathComponent(uniqueFileName)
            
            // Copy the file
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.copyItem(at: url, to: destinationURL)
            
            // Store the FULL PATH in the Book object
            parent.processImportedBook(at: destinationURL, fullPath: destinationURL.path)
            
            parent.status = .success(destinationURL)
        } catch {
            parent.status = .failure(error.localizedDescription)
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        parent.status = .cancelled
    }
    
    // Helper to create or get the Books directory
    private func getOrCreateBooksDirectory() throws -> URL {
        let fileManager = FileManager.default
        let documentsDirectory = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        let booksDirectory = documentsDirectory.appendingPathComponent("Books", isDirectory: true)
        
        if !fileManager.fileExists(atPath: booksDirectory.path) {
            try fileManager.createDirectory(at: booksDirectory, withIntermediateDirectories: true)
        }
        
        return booksDirectory
    }
    
    // Create a unique filename to avoid conflicts
    private func createUniqueFilename(for filename: String) -> String {
        let name = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        let ext = URL(fileURLWithPath: filename).pathExtension
        
        // Add timestamp to make it unique
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        
        return "\(name)_\(timestamp).\(ext)"
    }
}

// MARK: - Document Import Status
enum ImportStatus: Equatable {
    case idle
    case importing
    case success(URL)
    case failure(String)
    case cancelled
    
    static func == (lhs: ImportStatus, rhs: ImportStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.importing, .importing),
             (.cancelled, .cancelled):
            return true
        case (.success(let lhsURL), .success(let rhsURL)):
            return lhsURL == rhsURL
        case (.failure(let lhsMsg), .failure(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
    
    var isIdle: Bool {
        if case .idle = self {
            return true
        }
        return false
    }
    
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    var message: String {
        switch self {
        case .idle: return ""
        case .importing: return "Importing book..."
        case .success: return "Import successful!"
        case .failure(let message): return "Error: \(message)"
        case .cancelled: return "Import cancelled"
        }
    }
}


