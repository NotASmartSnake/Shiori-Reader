//
//  DictionaryEntryView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/13/25.
//

import SwiftUI

struct DictionaryEntryView: View {
    let entry: DictionaryEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.term)
                    .font(.headline)
                    .fontWeight(.bold)
                
                if !entry.reading.isEmpty && entry.reading != entry.term {
                    Text("「\(entry.reading)」")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            if !entry.termTags.isEmpty {
                Text(entry.termTags.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.vertical, 2)
            }
            
            ForEach(0..<entry.meanings.count, id: \.self) { index in
                HStack(alignment: .top) {
                    Text("\(index + 1).")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text(entry.meanings[index])
                        .font(.body)
                }
            }
            
            Divider()
        }
        .padding(.vertical, 4)
    }
}
