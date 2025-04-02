//
//  SavedWordDetailView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/21/25.
//


//
//  SavedWordDetailView.swift
//  Shiori Reader
//
//  Created by Claude on 3/20/25.
//

import SwiftUI

struct SavedWordDetailView: View {
    @EnvironmentObject var wordManager: SavedWordsManager
    @State private var editedWord: SavedWord
    @Environment(\.presentationMode) var presentationMode
    @State private var showDeleteConfirmation = false
    @State private var isEditing = false
    
    // Create a date formatter for displaying the date added
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    init(word: SavedWord) {
        self._editedWord = State(initialValue: word)
    }
    
    var body: some View {
        ZStack {
            Color("BackgroundColor").ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Source book and date added info
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Source: \(editedWord.sourceBook)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Added: \(dateFormatter.string(from: editedWord.timeAdded))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            isEditing.toggle()
                        }) {
                            Text(isEditing ? "Done" : "Edit")
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // Word and reading
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Word")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        if isEditing {
                            TextField("Word", text: $editedWord.word)
                                .font(.title)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .disableAutocorrection(true)
                        } else {
                            Text(editedWord.word)
                                .font(.title)
                                .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Reading
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Reading")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        if isEditing {
                            TextField("Reading", text: $editedWord.reading)
                                .font(.title2)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .disableAutocorrection(true)
                        } else {
                            Text(editedWord.reading)
                                .font(.title2)
                                .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Definition
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Definition")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        if isEditing {
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $editedWord.definition)
                                    .padding()
                                    .frame(minHeight: 100)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .disableAutocorrection(true)
                                
                                if editedWord.definition.isEmpty {
                                    Text("Enter definition")
                                        .foregroundColor(.gray)
                                        .padding(25)
                                }
                            }
                        } else {
                            Text(editedWord.definition)
                                .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Example sentence
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Example Sentence")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        if isEditing {
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $editedWord.sentence)
                                    .padding()
                                    .frame(minHeight: 120)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .disableAutocorrection(true)
                                
                                if editedWord.sentence.isEmpty {
                                    Text("Enter example sentence")
                                        .foregroundColor(.gray)
                                        .padding(25)
                                }
                            }
                        } else {
                            Text(editedWord.sentence)
                                .lineSpacing(4)
                                .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal)
                    
                    if isEditing {
                        // Save button when in edit mode
                        Button(action: {
                            saveChanges()
                            isEditing = false
                        }) {
                            Text("Save Changes")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }
                    
                    // Delete button
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Word")
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.top, isEditing ? 10 : 20)
                    .padding(.bottom, 30)
                    .alert(isPresented: $showDeleteConfirmation) {
                        Alert(
                            title: Text("Delete Word"),
                            message: Text("Are you sure you want to delete this word? This action cannot be undone."),
                            primaryButton: .destructive(Text("Delete")) {
                                deleteWord()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
            }
        }
        .navigationTitle("Edit Word")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private func saveChanges() {
        wordManager.updateWord(updated: editedWord)
    }
    
    private func deleteWord() {
        wordManager.deleteWord(with: editedWord.id)
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    NavigationStack {
        SavedWordDetailView(
            word: SavedWord(
                word: "勉強",
                reading: "べんきょう",
                definition: "study",
                sentence: "日本語の勉強は楽しいけど、難しいです。",
                timeAdded: Date(),
                sourceBook: "ReZero"
            )
        )
    }
}
