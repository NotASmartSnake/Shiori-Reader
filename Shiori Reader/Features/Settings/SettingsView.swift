//
//  SettingsView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//


import SwiftUI

struct SettingsView: View {
    
    var body: some View {
        NavigationStack{
            ZStack {
                
                Color("BackgroundColor").ignoresSafeArea(edges: .all)
                
                VStack {
                    List {
                        
                        HStack {
                            Image(systemName: "sun.min")
                            Text("Appearance")
                        }
                        .listRowBackground(Color(.systemGray6))
                        
                        HStack {
                            Image(systemName: "text.book.closed")
                            Text("Dictionaries")
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        print("Settings tapped")
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .toolbarBackground(Color.black, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .navigationTitle(
                Text("Settings")
            )
        }
            
    }
}

#Preview {
    SettingsView()
}
