//
//  DictionaryPopupView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/13/25.
//


import SwiftUI

struct DictionaryPopupView: View {
    let matches: [DictionaryMatch]
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Dictionary")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Button(action: {
                    onDismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            .padding(0)
            
            if matches.isEmpty {
                Text("No definitions found.")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    ForEach(matches, id: \.word) { match in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(match.word)
                                .font(.headline)
                                .padding(.vertical, 4)
                                .foregroundColor(.blue)
                            
                            ForEach(match.entries) { entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    if !entry.reading.isEmpty && entry.reading != entry.term {
                                        Text(entry.reading)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    ForEach(entry.meanings.indices, id: \.self) { index in
                                        Text("\(entry.meanings[index])")
                                            .font(.body)
                                            .padding(.leading, 8)
                                    }
                                }
                                .padding(.leading, 8)
                            }
                            
                            Divider()
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(height: UIScreen.main.bounds.height * 0.5)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        .shadow(radius: 5)
    }
}

#Preview {
    let isReadingBook = IsReadingBook()
    return BookReaderView(book: Book(
        title: "実力至上主義者の教室",
        coverImage: "COTECover",
        readingProgress: 0.1,
        filePath: "hakomari.epub"
    ))
    .environmentObject(isReadingBook)
}

