//
//  SettingsView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//


import SwiftUI
import Foundation
import SafariServices

struct SettingsView: View {
    
    var body: some View {
        NavigationStack{
            ZStack {
                
                Color("BackgroundColor").ignoresSafeArea(edges: .all)
                
                VStack {
                    List {
                        
                        NavigationLink(destination: AppAppearanceSettingsView()) {
                            HStack {
                                Image(systemName: "sun.min")
                                Text("App Appearance")
                            }
                        }
                        .listRowBackground(Color(.systemGray6))
                        
                        NavigationLink(destination: DefaultAppearanceSettingsView()) {
                            HStack {
                                Image(systemName: "book")
                                Text("Reader Appearance")
                            }
                        }
                        .listRowBackground(Color(.systemGray6))
                        
                        NavigationLink(destination: DictionarySettingsView()) {
                            HStack {
                                Image(systemName: "text.book.closed")
                                Text("Dictionaries")
                            }
                        }
                        .listRowBackground(Color(.systemGray6))

                        NavigationLink(destination: AnkiSettingsView()) {
                            HStack {
                                Image(systemName: "rectangle.stack.fill")
                                Text("Anki Integration")
                            }
                        }
                        .listRowBackground(Color(.systemGray6))
                        
                        // MARK: - Development/Testing Section                   
                        NavigationLink(destination: AttributionView()) {
                            HStack {
                                Image(systemName: "info.circle")
                                Text("Attributions")
                            }
                        }
                        .listRowBackground(Color(.systemGray6))
                        
                        // MARK: - Support Section
                        Button(action: {
                            openGitHubIssues()
                        }) {
                            HStack {
                                Image(systemName: "exclamationmark.bubble")
                                    .foregroundColor(.primary)
                                Text("Report Issues")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .listRowBackground(Color(.systemGray6))
                        
                        
                    }
                    .listStyle(PlainListStyle())
                    
                    Rectangle()
                        .frame(width: 0, height: 60)
                }
                
            }
            .navigationTitle(
                Text("Settings")
            )
        }
    }
    
    // MARK: - Helper Functions
    
    private func openGitHubIssues() {
        if let url = URL(string: "https://github.com/russgrav/Shiori-Reader/issues") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    SettingsView()
}
