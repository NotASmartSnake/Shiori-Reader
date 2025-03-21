//
//  EntryDetailView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/21/25.
//

import SwiftUI

// Detail view for dictionary entry
struct EntryDetailView: View {
    let entry: DictionaryEntry
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showSavedConfirmation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundColor").ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Word and reading
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Word")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            Text(entry.term)
                                .font(.title)
                                .padding(.leading, 4)
                            
                            if !entry.reading.isEmpty && entry.reading != entry.term {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Reading")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    
                                    Text(entry.reading)
                                        .font(.title2)
                                        .padding(.leading, 4)
                                }
                                .padding(.top, 5)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        // Part of speech / Tags
                        if !entry.termTags.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Word Type")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(entry.termTags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.blue.opacity(0.7))
                                            .cornerRadius(5)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Meanings
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Meanings")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            ForEach(entry.meanings.indices, id: \.self) { index in
                                HStack(alignment: .top) {
                                    Text("\(index + 1).")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    
                                    Text(entry.meanings[index])
                                        .font(.body)
                                }
                                .padding(.leading, 4)
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 30)
                        
                        // Save button
                        Button(action: {
                            onSave()
                            showSavedConfirmation = true
                            
                            // Dismiss after delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                dismiss()
                            }
                        }) {
                            HStack {
                                Image(systemName: "bookmark.fill")
                                Text("Save to Vocabulary List")
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                        .overlay {
                            if showSavedConfirmation {
                                VStack {
                                    Text("Saved!")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.green)
                                        .cornerRadius(8)
                                        .shadow(radius: 3)
                                }
                                .frame(maxWidth: .infinity)
                                .transition(.scale.combined(with: .opacity))
                                .animation(.spring(), value: showSavedConfirmation)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Word Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
