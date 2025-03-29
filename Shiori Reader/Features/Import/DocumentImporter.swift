//
//  DocumentImporter.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/29/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentImporter: UIViewControllerRepresentable {
    @Binding var status: ImportStatus
    var onBookImported: ((Book) -> Void)
    
    func makeCoordinator() -> DocumentPickerCoordinator {
        return DocumentPickerCoordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Set up supported types
        let supportedTypes = [UTType.epub]
        
        // Create the document picker
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = false
        
        // Update status
        status = .importing
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // Nothing to update
    }
    
    func processImportedBook(at url: URL, fullPath: String) {
        Task {
            do {
                let bookProcessor = EPUBImportProcessor()
                let book = try await bookProcessor.processEPUB(at: url, fullPath: fullPath)
                
                DispatchQueue.main.async {
                    self.onBookImported(book)
                }
            } catch {
                DispatchQueue.main.async {
                    self.status = .failure("Failed to process book: \(error.localizedDescription)")
                }
            }
        }
    }
}
