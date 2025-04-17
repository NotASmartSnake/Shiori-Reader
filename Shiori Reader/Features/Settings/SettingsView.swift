//
//  SettingsView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//


import SwiftUI
import Foundation

struct SettingsView: View {
    
    var body: some View {
        NavigationStack{
            ZStack {
                
                Color("BackgroundColor").ignoresSafeArea(edges: .all)
                
                VStack {
                    List {
                        
                        NavigationLink(destination: DefaultAppearanceSettingsView()) {
                            HStack {
                                Image(systemName: "sun.min")
                                Text("Default Appearance")
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
