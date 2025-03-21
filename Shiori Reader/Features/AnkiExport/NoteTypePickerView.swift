//
//  NoteTypePickerView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/21/25.
//

import SwiftUI

struct NoteTypePickerView: View {
    @Binding var selectedNoteType: String
    @Binding var isPresented: Bool
    let availableNoteTypes: [String: [String]]
    var onNoteTypeSelected: (String, [String]) -> Void
    
    var body: some View {
        NavigationView {
            List(Array(availableNoteTypes.keys.sorted()), id: \.self) { type in
                Button(action: {
                    selectedNoteType = type
                    onNoteTypeSelected(type, availableNoteTypes[type] ?? [])
                    isPresented = false
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(type)
                            Text("\(availableNoteTypes[type]?.count ?? 0) fields")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if type == selectedNoteType {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Select Note Type")
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
