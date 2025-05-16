//
//  CustomThemePickerView.swift
//  Shiori Reader
//
//  Created by Claude on 5/16/25.
//

import SwiftUI

struct CustomThemePickerView: View {
    @Binding var customThemes: [CustomTheme]
    @Binding var selectedThemeId: UUID?
    var onThemeSelected: (CustomTheme) -> Void
    var onDelete: (CustomTheme) -> Void
    
    var body: some View {
        Menu {
            if customThemes.isEmpty {
                Text("No saved themes")
                    .foregroundColor(.secondary)
            } else {
                ForEach(customThemes) { theme in
                Button(action: {
                        onThemeSelected(theme)
                    }) {
                        HStack {
                            if selectedThemeId == theme.id {
                                Image(systemName: "checkmark")
                            }
                            Text(theme.name)
                            
                            // Color preview
                            Circle()
                                .fill(theme.getTextColor())
                                .frame(width: 12, height: 12)
                            
                            Circle()
                                .fill(theme.getBackgroundColor())
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                            
                            Spacer()
                        }
                    }
                }
            }
        } label: {
            // If a custom theme is selected, show its name
            if let selectedId = selectedThemeId,
               let selectedTheme = customThemes.first(where: { $0.id == selectedId }) {
                Text(selectedTheme.name)
            } else {
                Text("Select Theme")
            }
        }
    }
}

struct SaveThemeView: View {
    @State private var themeName: String = ""
    @Binding var isPresented: Bool
    var onSave: (String) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Save Current Theme")
                .font(.headline)
            
            TextField("Theme Name", text: $themeName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disableAutocorrection(true)
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                
                Spacer()
                
                Button("Save") {
                    guard !themeName.isEmpty else { return }
                    onSave(themeName)
                    isPresented = false
                }
                .disabled(themeName.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}
