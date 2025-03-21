//
//  NoteTypePickerView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/21/25.
//

import SwiftUI

struct DeckPickerView: View {
    @Binding var selectedDeck: String
    @Binding var isPresented: Bool
    let availableDecks: [String]
    
    var body: some View {
        NavigationView {
            List(availableDecks, id: \.self) { deck in
                Button(action: {
                    selectedDeck = deck
                    isPresented = false
                }) {
                    HStack {
                        Text(deck)
                        Spacer()
                        if deck == selectedDeck {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Select Deck")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
    
