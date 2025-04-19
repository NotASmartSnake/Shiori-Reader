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
                        
                        NavigationLink(destination: AttributionView()) {
                            HStack {
                                Image(systemName: "info.circle")
                                Text("Attributions")
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
}

#Preview {
    SettingsView()
}
