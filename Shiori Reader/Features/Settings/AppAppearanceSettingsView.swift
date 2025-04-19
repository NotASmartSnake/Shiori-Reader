//
//  AppAppearanceSettingsView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/18/25.
//

import SwiftUI

struct AppAppearanceSettingsView: View {
    // State to track the current appearance mode
    @State private var appearanceMode: String
    
    // Initialize with the current mode from AppearanceManager
    init() {
        self._appearanceMode = State(initialValue: AppearanceManager.shared.getCurrentAppearanceMode())
    }
    
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
                    AppearanceManager.shared.setAppearanceMode(newValue)
                }
                
                Text("This setting controls the appearance of the app's interface (light or dark mode), not the reader content.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // MARK: - Reset Section
            Section {
                Button(action: {
                    appearanceMode = "system"
                    AppearanceManager.shared.setAppearanceMode("system")
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
