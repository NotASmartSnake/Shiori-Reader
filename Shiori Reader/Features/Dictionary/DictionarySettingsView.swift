//
//  DictionarySettingsView.swift
//  Shiori Reader
//
//  Created by Claude on 4/16/25.
//

import SwiftUI

struct DictionarySettingsView: View {
    @StateObject private var viewModel = DictionarySettingsViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Form {
                // MARK: - Dictionary List Section
                Section(header: Text("Dictionaries")) {
                    ForEach(viewModel.availableDictionaries) { dictionary in
                        dictionaryRow(dictionary)
                    }
                }
                
                // MARK: - Future Features Section
                Section(footer: customFooter) {
                    // Future: Add button to import custom dictionaries
                    HStack {
                        Text("Import Custom Dictionary")
                        Spacer()
                        Image(systemName: "plus.circle")
                            .foregroundColor(.gray)
                    }
                    .disabled(true) // Disabled for now
                }
            }
            .navigationTitle("Dictionary Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $viewModel.showAlert) {
                Alert(
                    title: Text(viewModel.alertTitle),
                    message: Text(viewModel.alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            
            // Spacer at the bottom for tab bar
            Rectangle()
                .frame(width: 0, height: 40)
                .foregroundStyle(Color.clear)
        }
    }
    
    // MARK: - UI Components
    
    private func dictionaryRow(_ dictionary: DictionaryInfo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dictionary.name)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { dictionary.isEnabled },
                set: { viewModel.toggleDictionary(id: dictionary.id, isEnabled: $0) }
            ))
            .disabled(!dictionary.canDisable) // Can't disable if it's the only enabled dictionary
        }
    }
    
    private var customFooter: some View {
        Text("Support for additional dictionaries will be added in future updates. Stay tuned for the ability to import custom dictionaries to enhance your reading experience.")
            .font(.footnote)
            .foregroundColor(.secondary)
            .padding(.top, 4)
    }
}

struct DictionarySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DictionarySettingsView()
        }
    }
}
