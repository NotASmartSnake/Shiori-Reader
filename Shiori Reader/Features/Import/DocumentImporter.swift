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
                    // Set success status AFTER successful processing
                    self.status = .success(url)
                }
            } catch let error as EPUBImportProcessor.ImportError {
                // Handle specific import errors
                DispatchQueue.main.async {
                    print("ERROR [DocumentImporter]: EPUB Processing Failed - \(error.localizedDescription)")
                    self.status = .failure(error.localizedDescription)
                }
            } catch {
                // Handle generic errors
                DispatchQueue.main.async {
                     print("ERROR [DocumentImporter]: Unexpected error processing book - \(error.localizedDescription)")
                    self.status = .failure("Failed to process book: \(error.localizedDescription)")
                }
            }
        }
    }
}
