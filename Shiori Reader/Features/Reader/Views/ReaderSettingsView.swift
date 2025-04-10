//
//  ReaderSettingsView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/10/25.
//


// ReaderSettingsView.swift
import SwiftUI

struct ReaderSettingsView: View {
    @ObservedObject var viewModel: ReaderSettingsViewModel
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    // Font families available
    private let fontFamilies = ["Default", "Sans Serif", "Serif", "Monospace"]
    
    // Themes available
    private let themes = ["light", "dark", "sepia"]
    
    // Font size range
    private let fontSizeRange: ClosedRange<Float> = 0.5...2.0
    private let fontSizeStep: Float = 0.1
    
    var body: some View {
        NavigationView {
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
                    
                    // Color pickers are only enabled when "custom" theme is selected
                    ColorPicker("Text Color", selection: Binding(
                        get: { viewModel.preferences.getTextColor() },
                        set: { color in
                            viewModel.preferences.textColor = color.toHex() ?? "#000000"
                            // Set theme to custom when manually changing colors
                            viewModel.preferences.theme = "custom"
                            viewModel.savePreferences()
                        }
                    ))
                    .disabled(viewModel.preferences.theme != "custom")
                    .foregroundColor(viewModel.preferences.theme == "custom" ? .primary : .gray)
                    
                    ColorPicker("Background Color", selection: Binding(
                        get: { viewModel.preferences.getBackgroundColor() },
                        set: { color in
                            viewModel.preferences.backgroundColor = color.toHex() ?? "#FFFFFF"
                            // Set theme to custom when manually changing colors
                            viewModel.preferences.theme = "custom"
                            viewModel.savePreferences()
                        }
                    ))
                    .disabled(viewModel.preferences.theme != "custom")
                    .foregroundColor(viewModel.preferences.theme == "custom" ? .primary : .gray)
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
                    
                    // Font size slider
                    HStack {
                        Text("Font Size")
                        Spacer()
                        Text("A").font(.system(size: 12))
                        Slider(
                            value: Binding(
                                get: { viewModel.preferences.fontSize },
                                set: { viewModel.updateFontSize($0) }
                            ),
                            in: fontSizeRange,
                            step: fontSizeStep
                        )
                        .frame(width: 120)
                        Text("A").font(.system(size: 24))
                    }
                }
                
                // MARK: - Layout Section
                Section(header: Text("Layout")) {
                    // Reading direction
                    Picker("Reading Direction", selection: Binding(
                        get: { viewModel.preferences.readingDirection },
                        set: { viewModel.updateReadingDirection($0) }
                    )) {
                        Text("Left to Right").tag("ltr")
                        Text("Right to Left").tag("rtl")
                    }
                    
                    // Vertical text toggle
                    Toggle("Vertical Text", isOn: Binding(
                        get: { viewModel.preferences.isVerticalText },
                        set: { _ in viewModel.toggleVerticalText() }
                    ))
                    
                    // Scroll mode toggle
                    Toggle("Scroll Mode", isOn: Binding(
                        get: { viewModel.preferences.isScrollMode },
                        set: { _ in viewModel.toggleScrollMode() }
                    ))
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
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Reader Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.savePreferences()
                        isPresented = false
                    }
                }
            }
        }
    }
}

// Helper extension for Color to convert to hex
extension Color {
    func toUIColor() -> UIColor {
        let components = self.components()
        return UIColor(red: components.r, green: components.g, blue: components.b, alpha: components.a)
    }
    
    func components() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
    
    func toHex() -> String? {
        let uic = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        uic.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let hex = String(
            format: "#%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255)
        )
        
        return hex
    }
}

