//
//  AppAppearanceSettingsView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/18/25.
//

import SwiftUI

struct AppAppearanceSettingsView: View {
    // Use @AppStorage to automatically sync with UserDefaults
    // This will automatically update when the value changes in UserDefaults
    @AppStorage(kAppearanceModeKey) private var appearanceMode: String = "system"
    
    var body: some View {
        List {
            // MARK: - App Appearance Section
            Section(header: Text("App Interface Mode")) {
                Picker("Mode", selection: $appearanceMode) {
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                    Text("Follow System").tag("system")
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: appearanceMode) { oldValue, newValue in
                    // Apply the appearance mode when changed
                    // No need to call setAppearanceMode since @AppStorage handles UserDefaults
                    AppearanceManager.shared.applyAppearanceMode()
                }
                
                Text("This setting controls the appearance of the app's interface (light or dark mode), not the reader content.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // MARK: - Reset Section
            Section {
                Button(action: {
                    appearanceMode = "system"
                    // No need to call setAppearanceMode since @AppStorage handles UserDefaults
                    AppearanceManager.shared.applyAppearanceMode()
                }) {
                    HStack {
                        Spacer()
                        Text("Reset to System Default")
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("App Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        AppAppearanceSettingsView()
    }
}
