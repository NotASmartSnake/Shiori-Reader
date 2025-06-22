//
//  DefaultAppearanceSettingsView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/16/25.
//

import SwiftUI

struct DefaultAppearanceSettingsView: View {
    @StateObject var viewModel = DefaultAppearanceSettingsViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showSaveThemeAlert = false
    @State private var newThemeName = ""
    
    // Font families available
    private let fontFamilies = ["Default", "Sans Serif", "Serif", "Monospace"]
    
    // Themes available
    private let themes = ["light", "dark", "sepia"]
    
    // Font size range
    private let fontSizeRange: ClosedRange<Float> = 0.5...2.0
    private let fontSizeStep: Float = 0.1
    
    var body: some View {
        ZStack {
            VStack {
                    List {
                    // MARK: - Theme Section
                    Section(header: Text("Theme")) {
                        Picker("Theme", selection: Binding(
                            get: { viewModel.preferences.theme },
                            set: { viewModel.setTheme($0) }
                        )) {
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                            Text("Sepia").tag("sepia")
                            Text("Custom").tag("custom")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        // Only show custom theme options when "custom" is selected
                        if viewModel.preferences.theme == "custom" {
                            // Custom theme selection
                            HStack {
                                Text("Current Theme")
                                Spacer()
                                CustomThemePickerView(
                                    customThemes: $viewModel.customThemes,
                                    selectedThemeId: $viewModel.selectedCustomThemeId,
                                    onThemeSelected: { theme in
                                        viewModel.applyCustomTheme(theme)
                                    },
                                    onDelete: { _ in } // We'll handle delete separately
                                )
                            }
                            
                            // Color pickers
                            ColorPicker("Text Color", selection: Binding(
                                get: { viewModel.preferences.getTextColor() },
                                set: { color in
                                    viewModel.preferences.textColor = color.toHex() ?? "#000000"
                                    // Reset selected custom theme when colors change
                                    viewModel.selectedCustomThemeId = nil
                                    viewModel.savePreferences()
                                }
                            ))
                            
                            ColorPicker("Background Color", selection: Binding(
                                get: { viewModel.preferences.getBackgroundColor() },
                                set: { color in
                                    viewModel.preferences.backgroundColor = color.toHex() ?? "#FFFFFF"
                                    // Reset selected custom theme when colors change
                                    viewModel.selectedCustomThemeId = nil
                                    viewModel.savePreferences()
                                }
                            ))
                            
                            // Save current theme button
                            Button(action: {
                                newThemeName = ""
                                showSaveThemeAlert = true
                            }) {
                                Text("Save Current Theme")
                            }
                            
                            // Delete theme button - only show when a theme is selected
                            if let selectedThemeId = viewModel.selectedCustomThemeId,
                               let selectedTheme = viewModel.customThemes.first(where: { $0.id == selectedThemeId }) {
                                Button(action: {
                                    viewModel.deleteCustomTheme(selectedTheme)
                                }) {
                                    Text("Delete \(selectedTheme.name)")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    // MARK: - Text Section
                    Section(header: Text("Text")) {
                        // Font family picker
                        Picker("Font", selection: Binding(
                            get: { viewModel.preferences.fontFamily },
                            set: { viewModel.updateFontFamily($0) }
                        )) {
                            ForEach(fontFamilies, id: \.self) { family in
                                Text(family).tag(family)
                            }
                        }
                        
                        // Font size button control
                        FontSizeButtonControl(
                            fontSize: Binding(
                                get: { viewModel.preferences.fontSize },
                                set: { viewModel.updateFontSize($0) }
                            ),
                            fontSizeRange: fontSizeRange,
                            fontSizeStep: fontSizeStep,
                            onFontSizeChanged: { newSize in
                                viewModel.updateFontSize(newSize)
                            }
                        )
                    }
                    
                    // MARK: - Layout Section
                    Section(header: Text("Layout")) {
                        // Scroll mode toggle
                        Toggle("Scroll Mode", isOn: Binding(
                            get: { viewModel.preferences.isScrollMode },
                            set: { _ in viewModel.toggleScrollMode() }
                        ))
                    }
                    
                    // MARK: - Animation Section
                    Section(header: Text("Dictionary Popup")) {
                        // Animation toggle
                        Toggle("Animate Dictionary Popup", isOn: Binding(
                            get: { viewModel.preferences.isDictionaryAnimationEnabled },
                            set: { _ in viewModel.toggleDictionaryAnimation() }
                        ))
                        
                        // Animation speed picker (only show when animation is enabled)
                        if viewModel.preferences.isDictionaryAnimationEnabled {
                            Picker("Animation Speed", selection: Binding(
                                get: { viewModel.preferences.dictionaryAnimationSpeed },
                                set: { viewModel.updateDictionaryAnimationSpeed($0) }
                            )) {
                                Text("Slow").tag("slow")
                                Text("Normal").tag("normal")
                                Text("Fast").tag("fast")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                    
                    // MARK: - Reset Section
                    Section {
                        Button(action: {
                            viewModel.resetToDefaults()
                        }) {
                            HStack {
                                Spacer()
                                Text("Reset to Defaults")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                    
                    // MARK: - Info Section
                    Section {
                        Text("These settings apply to all new books you open. You can also set different appearance preferences for each individual book when reading.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    }
                    .listStyle(InsetGroupedListStyle())
                    
                    // Bottom spacer to prevent overlap with tab bar
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 60)
            }
            .navigationTitle("Reader Appearance")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Save Current Theme", isPresented: $showSaveThemeAlert, actions: {
            TextField("Theme Name", text: $newThemeName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if !newThemeName.isEmpty {
                    viewModel.saveCurrentThemeAs(name: newThemeName)
                }
            }
        }, message: {
            Text("Enter a name for this theme.")
        })
    }
}
