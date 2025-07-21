//
//  DefinitionSelectionPopupView.swift
//  Shiori Reader
//
//  Created by Claude on 6/16/25.
//

import SwiftUI
import UIKit

struct DefinitionSelectionPopupView: View {
    let word: String
    let reading: String
    let availableDefinitions: [DictionarySourceDefinition]
    let onDefinitionsSelected: ([String: [String]]) -> Void
    let onCancel: () -> Void
    
    @State private var selectedDefinitions: [String: [String]] = [:]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Text("Select Definitions for Anki")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.blue)
                }
                
                // Word and reading with "All" button
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if !reading.isEmpty && reading != word {
                            Text(reading)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(word)
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    // Select/Deselect All button
                    Button(action: {
                        toggleAllDictionaries()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isAllDictionariesSelected() ? "checkmark.square.fill" : "square")
                                .foregroundColor(.blue)
                            Text("All")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            Divider()
            
            // Dictionary definitions
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(availableDefinitions, id: \.source) { dictionaryDef in
                        VStack(alignment: .leading, spacing: 12) {
                            // Dictionary source header with "All" toggle
                            HStack {
                                Text(dictionarySourceName(dictionaryDef.source))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                // "All" toggle button
                                Button(action: {
                                    toggleAllDefinitions(for: dictionaryDef.source, definitions: dictionaryDef.definitions)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: isAllSelected(for: dictionaryDef.source, totalCount: dictionaryDef.definitions.count) ? "checkmark.square.fill" : "square")
                                            .foregroundColor(.blue)
                                        Text("All")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // Definition options with checkboxes
                            ForEach(Array(dictionaryDef.definitions.enumerated()), id: \.offset) { index, definition in
                                Button(action: {
                                    toggleDefinitionSelection(for: dictionaryDef.source, definition: definition)
                                }) {
                                    HStack(alignment: .top, spacing: 12) {
                                        // Checkbox
                                        Image(systemName: isDefinitionSelected(for: dictionaryDef.source, definition: definition) ? "checkmark.square.fill" : "square")
                                            .foregroundColor(.blue)
                                            .font(.title3)
                                            .padding(.top, 2)
                                        
                                        // Definition text
                                        Text(definition)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(isDefinitionSelected(for: dictionaryDef.source, definition: definition) ? 
                                                  Color.blue.opacity(0.1) : Color.clear)
                                            .stroke(isDefinitionSelected(for: dictionaryDef.source, definition: definition) ? 
                                                   Color.blue.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        
                        if dictionaryDef.source != availableDefinitions.last?.source {
                            Divider()
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            
            // Footer with action buttons
            VStack(spacing: 12) {
                Divider()
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                    
                    Button("Add to Anki") {
                        // selectedDefinitions is already [String: [String]]
                        onDefinitionsSelected(selectedDefinitions)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(canProceed ? Color.blue : Color.gray.opacity(0.3))
                    .foregroundColor(canProceed ? .white : .gray)
                    .cornerRadius(8)
                    .disabled(!canProceed)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .frame(maxWidth: 500) // Limit maximum width
        .frame(maxHeight: UIScreen.main.bounds.height * 0.5) // Half screen height
        .padding(.horizontal, 40) // Add horizontal padding so it doesn't touch edges
        .onAppear {
            // Pre-select ALL definitions from each dictionary by default
            for dictionaryDef in availableDefinitions {
                selectedDefinitions[dictionaryDef.source] = dictionaryDef.definitions
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var canProceed: Bool {
        // Can proceed if we have at least one selection from any dictionary
        return selectedDefinitions.values.contains { !$0.isEmpty }
    }
    
    // MARK: - Helper Functions
    
    private func isDefinitionSelected(for source: String, definition: String) -> Bool {
        return selectedDefinitions[source]?.contains(definition) ?? false
    }
    
    private func isAllSelected(for source: String, totalCount: Int) -> Bool {
        guard let selections = selectedDefinitions[source] else { return false }
        return selections.count == totalCount && totalCount > 0
    }
    
    private func toggleDefinitionSelection(for source: String, definition: String) {
        if selectedDefinitions[source] == nil {
            selectedDefinitions[source] = []
        }
        
        if selectedDefinitions[source]!.contains(definition) {
            selectedDefinitions[source]!.removeAll { $0 == definition }
        } else {
            // Find the source definitions to maintain original order
            if let sourceDefinitions = availableDefinitions.first(where: { $0.source == source })?.definitions {
                // Rebuild the selection array maintaining the original order
                var newSelection: [String] = []
                for originalDef in sourceDefinitions {
                    if originalDef == definition || selectedDefinitions[source]!.contains(originalDef) {
                        newSelection.append(originalDef)
                    }
                }
                selectedDefinitions[source] = newSelection
            } else {
                // Fallback to append if we can't find the source
                selectedDefinitions[source]!.append(definition)
            }
        }
    }
    
    private func toggleAllDefinitions(for source: String, definitions: [String]) {
        if isAllSelected(for: source, totalCount: definitions.count) {
            // Deselect all
            selectedDefinitions[source] = []
        } else {
            // Select all
            selectedDefinitions[source] = definitions
        }
    }
    
    private func isAllDictionariesSelected() -> Bool {
        // Check if all definitions from all dictionaries are selected
        for dictionaryDef in availableDefinitions {
            if selectedDefinitions[dictionaryDef.source]?.count != dictionaryDef.definitions.count {
                return false
            }
        }
        return !availableDefinitions.isEmpty
    }
    
    private func toggleAllDictionaries() {
        if isAllDictionariesSelected() {
            // Deselect all definitions from all dictionaries
            for dictionaryDef in availableDefinitions {
                selectedDefinitions[dictionaryDef.source] = []
            }
        } else {
            // Select all definitions from all dictionaries
            for dictionaryDef in availableDefinitions {
                selectedDefinitions[dictionaryDef.source] = dictionaryDef.definitions
            }
        }
    }
    
    private func dictionarySourceName(_ source: String) -> String {
        switch source {
        case "jmdict":
            return "JMdict"
        case "obunsha":
            return "旺文社"
        default:
            if source.hasPrefix("imported_") {
                // Extract UUID and get display name
                let importedId = source.replacingOccurrences(of: "imported_", with: "")
                if let uuid = UUID(uuidString: importedId) {
                    let importedDictionaries = DictionaryImportManager.shared.getImportedDictionaries()
                    if let dict = importedDictionaries.first(where: { $0.id == uuid }) {
                        return dict.title
                    }
                }
                return "Imported"
            }
            return source.capitalized
        }
    }
    
}

// MARK: - Supporting Data Structures

struct DictionarySourceDefinition {
    let source: String 
    let definitions: [String]
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
        
        DefinitionSelectionPopupView(
            word: "勉強",
            reading: "べんきょう",
            availableDefinitions: [
                DictionarySourceDefinition(
                    source: "jmdict",
                    definitions: [
                        "study; diligence; application",
                        "learning; studying; knowledge",
                        "work; effort; practice",
                        "discount; reduction; bargain"
                    ]
                ),
                DictionarySourceDefinition(
                    source: "obunsha",
                    definitions: [
                        "学問や技芸を学ぶこと。精神を鍛錬すること。学習すること。また、その内容。勉学。学業。修学。習学。学修。学習。ガクシュウ。"
                    ]
                )
            ],
            onDefinitionsSelected: { selections in
                print("Selected definitions: \(selections)")
            },
            onCancel: {
                print("Cancelled")
            }
        )
    }
}
