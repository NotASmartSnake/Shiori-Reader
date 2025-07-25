import SwiftUI

struct DictionaryDetailView: View {
    let dictionaryId: String
    @ObservedObject var viewModel: DictionarySettingsViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Get the current dictionary info from the view model
    private var dictionary: DictionaryInfo? {
        viewModel.availableDictionaries.first { $0.id == dictionaryId }
    }
    
    // Get additional info for imported dictionaries
    private var importedDictionaryInfo: ImportedDictionaryInfo? {
        guard let dict = dictionary, !dict.isBuiltIn else { return nil }
        
        let importedId = dict.id.replacingOccurrences(of: "imported_", with: "")
        guard let uuid = UUID(uuidString: importedId) else { return nil }
        
        let importedDictionaries = DictionaryImportManager.shared.getImportedDictionaries()
        return importedDictionaries.first(where: { $0.id == uuid })
    }
    
    var body: some View {
        Group {
            if let dictionary = dictionary {
                Form {
                    // MARK: - Basic Information Section
                    Section("Dictionary Information") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(dictionary.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text(dictionary.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                        
                        HStack {
                            Text("Type")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(dictionary.isBuiltIn ? "Built-in" : "Imported")
                                .fontWeight(.medium)
                        }
                        
                        if let imported = importedDictionaryInfo {
                            if let author = imported.author, !author.isEmpty {
                                HStack {
                                    Text("Author")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(author)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            HStack {
                                Text("Import Date")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(imported.importDate, style: .date)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Version")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("v\(imported.version)")
                                    .fontWeight(.medium)
                            }
                            
                            if !imported.revision.isEmpty {
                                HStack {
                                    Text("Revision")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(imported.revision)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                    
                    // MARK: - Tag Color Section
                    Section("Tag Color") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select the color used to identify entries from this dictionary")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                                ForEach(DictionaryTagColor.allCases, id: \.self) { color in
                                    colorSelectionButton(for: color, dictionary: dictionary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // MARK: - Status Section
                    Section("Status") {
                        HStack {
                            Text("Enabled")
                                .foregroundColor(.secondary)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { dictionary.isEnabled },
                                set: { viewModel.toggleDictionary(id: dictionary.id, isEnabled: $0) }
                            ))
                        }
                    }
                }
                .navigationTitle("Dictionary Details")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                Text("Dictionary not found")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Color Selection Button
    
    private func colorSelectionButton(for color: DictionaryTagColor, dictionary: DictionaryInfo) -> some View {
        Button(action: {
            viewModel.updateDictionaryColor(id: dictionary.id, color: color)
        }) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.swiftUIColor.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                dictionary.tagColor == color ? color.swiftUIColor : Color.gray.opacity(0.3),
                                lineWidth: dictionary.tagColor == color ? 3 : 1
                            )
                    )
                    .frame(height: 32)
                    .overlay(
                        dictionary.tagColor == color ?
                        Image(systemName: "checkmark")
                            .foregroundColor(color.swiftUIColor)
                            .fontWeight(.semibold)
                        : nil
                    )
                
                Text(color.displayName)
                    .font(.caption)
                    .foregroundColor(dictionary.tagColor == color ? color.swiftUIColor : .secondary)
                    .fontWeight(dictionary.tagColor == color ? .semibold : .regular)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DictionaryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DictionaryDetailView(
                dictionaryId: "jmdict",
                viewModel: DictionarySettingsViewModel()
            )
        }
    }
}