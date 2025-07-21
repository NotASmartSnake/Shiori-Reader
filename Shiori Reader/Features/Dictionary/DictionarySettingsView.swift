//
//  DictionarySettingsView.swift
//  Shiori Reader
//
//  Created by Claude on 4/16/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct DictionarySettingsView: View {
    @StateObject private var viewModel = DictionarySettingsViewModel()
    @StateObject private var importManager = DictionaryImportManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showFileImporter = false
    @Environment(\.editMode) private var editMode
    
    var body: some View {
        VStack {
            Form {
                // MARK: - Dictionary List Section
                Section(header: Text("Dictionaries")) {
                    ForEach(viewModel.availableDictionaries) { dictionary in
                        dictionaryRow(dictionary)
                    }
                    .onMove(perform: editMode?.wrappedValue == .active ? viewModel.reorderDictionaries : nil)
                    .onDelete(perform: deleteDictionary)
                }
                
                // MARK: - Import Dictionary Section
                Section("Import Dictionary") {
                    Button(action: {
                        showFileImporter = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Import Yomitan Dictionary")
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                    .disabled(importManager.isImporting)
                    
                    if importManager.isImporting {
                        importProgressView
                    }
                }
            }
            .navigationTitle("Dictionary Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(editMode?.wrappedValue == .active ? "Done" : "Edit") {
                        withAnimation {
                            editMode?.wrappedValue = editMode?.wrappedValue == .active ? .inactive : .active
                        }
                    }
                }
            }
            .onAppear {
                viewModel.refreshSettings()
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [UTType.zip],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task {
                            await importManager.importDictionary(from: url)
                            DispatchQueue.main.async {
                                viewModel.loadImportedDictionaries()
                            }
                        }
                    }
                case .failure(let error):
                    importManager.lastImportError = error
                }
            }
            .alert("Dictionary Settings", isPresented: $viewModel.showAlert) {
                Button("OK") { }
            } message: {
                Text(viewModel.alertMessage)
            }
            .alert("Import Error", isPresented: .constant(importManager.lastImportError != nil)) {
                Button("OK") {
                    importManager.lastImportError = nil
                }
            } message: {
                Text(importManager.lastImportError?.localizedDescription ?? "")
            }
            
            // Spacer at the bottom for tab bar
            Rectangle()
                .frame(width: 0, height: 40)
                .foregroundStyle(Color.clear)
        }
    }
    
    // MARK: - UI Components
    
    private func dictionaryRow(_ dictionary: DictionaryInfo) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dictionary.name)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(dictionary.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                // Color preview and selection
                HStack(spacing: 8) {
                    Text("Tag Color:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Current color preview
                    RoundedRectangle(cornerRadius: 4)
                        .fill(dictionary.tagColor.swiftUIColor.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(dictionary.tagColor.swiftUIColor, lineWidth: 1)
                        )
                        .frame(width: 20, height: 16)
                    
                    // Color selection menu
                    Menu {
                        ForEach(DictionaryTagColor.allCases, id: \.self) { color in
                            Button(action: {
                                viewModel.updateDictionaryColor(id: dictionary.id, color: color)
                            }) {
                                HStack {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(color.swiftUIColor)
                                        .frame(width: 16, height: 12)
                                    Text(color.displayName)
                                    if color == dictionary.tagColor {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(dictionary.tagColor.displayName)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.top, 2)
            }
            
            Spacer()
            
            if editMode?.wrappedValue != .active {
                Toggle("", isOn: Binding(
                    get: { dictionary.isEnabled },
                    set: { viewModel.toggleDictionary(id: dictionary.id, isEnabled: $0) }
                ))
                .disabled(!dictionary.canDisable)
                .fixedSize()
            }
        }
        .padding(.vertical, 6)
    }
    
    private var importProgressView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Importing...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Cancel") {
                    importManager.cancelImport()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if let progress = importManager.importProgress {
                ProgressView(value: progress.overallProgress) {
                    Text(progress.currentStep)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                ProgressView()
                    .progressViewStyle(LinearProgressViewStyle())
            }
        }
        .padding(.vertical, 4)
    }
    
    private func deleteDictionary(at offsets: IndexSet) {
        for index in offsets {
            let dictionary = viewModel.availableDictionaries[index]
            
            // Only allow deletion of imported dictionaries
            if !dictionary.isBuiltIn {
                // Extract the original UUID from the ID
                let importedId = dictionary.id.replacingOccurrences(of: "imported_", with: "")
                if let uuid = UUID(uuidString: importedId) {
                    // Find the ImportedDictionaryInfo with this UUID
                    let importedDictionaries = DictionaryImportManager.shared.getImportedDictionaries()
                    if let importedDict = importedDictionaries.first(where: { $0.id == uuid }) {
                        viewModel.deleteImportedDictionary(importedDict)
                    }
                }
            }
        }
    }
}

struct DictionarySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DictionarySettingsView()
        }
    }
}
