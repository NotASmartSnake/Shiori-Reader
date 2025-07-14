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
    
    @State private var selectedDefinitions: [String: Set<String>] = [:]
    
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
                
                // Word and reading
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
                .frame(maxWidth: .infinity, alignment: .leading)
                
//                Text("Select definitions from each dictionary to add to your Anki card:")
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//                    .multilineTextAlignment(.leading)
//                    .frame(maxWidth: .infinity, alignment: .leading)
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
                                
                                // Dictionary badge
                                Text(dictionarySourceBadge(dictionaryDef.source))
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(dictionarySourceColor(dictionaryDef.source).opacity(0.2))
                                    .foregroundColor(dictionarySourceColor(dictionaryDef.source))
                                    .cornerRadius(4)
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
                        // Convert Set<String> to [String] for each source
                        let definitionsArray = selectedDefinitions.mapValues { Array($0) }
                        onDefinitionsSelected(definitionsArray)
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
                selectedDefinitions[dictionaryDef.source] = Set(dictionaryDef.definitions)
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
            selectedDefinitions[source] = Set<String>()
        }
        
        if selectedDefinitions[source]!.contains(definition) {
            selectedDefinitions[source]!.remove(definition)
        } else {
            selectedDefinitions[source]!.insert(definition)
        }
    }
    
    private func toggleAllDefinitions(for source: String, definitions: [String]) {
        if isAllSelected(for: source, totalCount: definitions.count) {
            // Deselect all
            selectedDefinitions[source] = Set<String>()
        } else {
            // Select all
            selectedDefinitions[source] = Set(definitions)
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
    
    private func dictionarySourceBadge(_ source: String) -> String {
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
    
    private func dictionarySourceColor(_ source: String) -> Color {
        switch source {
        case "jmdict":
            return .blue
        case "obunsha":
            return .orange
        default:
            return .gray
        }
    }
}

// MARK: - Supporting Data Structures

struct DictionarySourceDefinition {
    let source: String // "jmdict" or "obunsha"
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
