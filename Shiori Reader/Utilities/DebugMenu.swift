//
//  DebugMenu.swift
//  Shiori Reader
//
//  Created on 4/18/25.
//

import SwiftUI

/// A debug menu that can be conditionally shown in development builds
struct DebugMenu: View {
    @State private var isLoggingEnabled: Bool = Logger.isEnabled
    
    var body: some View {
        #if DEBUG
        VStack(alignment: .leading, spacing: 12) {
            Text("Debug Options")
                .font(.headline)
                .padding(.bottom, 4)
            
            Toggle("Enable Logging", isOn: $isLoggingEnabled)
                .onChange(of: isLoggingEnabled) { oldValue, newValue in
                    Logger.isEnabled = newValue
                    Logger.debug(category: "Debug", "Logging \(newValue ? "enabled" : "disabled")")
                }
            
            Divider()
            
            Button("Force Log Test") {
                Logger.debug(category: "Test", "Debug log test")
                Logger.info(category: "Test", "Info log test")
                Logger.warning(category: "Test", "Warning log test")
                Logger.error(category: "Test", "Error log test")
            }
            
            Button("Test BCCWJ Database") {
                FrequencyManager.shared.testBCCWJDatabaseIntegration()
            }
            
            Button("Test Frequency Integration") {
                DictionaryManager.shared.testFrequencyIntegration()
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding()
        #else
        // No debug menu in release builds
        EmptyView()
        #endif
    }
}

/// A button that shows the debug menu when in DEBUG builds
struct DebugMenuButton: View {
    @State private var showingDebugMenu = false
    
    var body: some View {
        #if DEBUG
        Button(action: {
            showingDebugMenu.toggle()
        }) {
            Image(systemName: "ant.circle")
                .font(.title2)
        }
        .sheet(isPresented: $showingDebugMenu) {
            DebugMenu()
        }
        #else
        // No debug button in release builds
        EmptyView()
        #endif
    }
}

#if DEBUG
// Preview provider for SwiftUI Canvas
struct DebugMenu_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            DebugMenuButton()
            
            Spacer()
            
            DebugMenu()
                .frame(height: 300)
                .padding()
        }
    }
}
#endif
