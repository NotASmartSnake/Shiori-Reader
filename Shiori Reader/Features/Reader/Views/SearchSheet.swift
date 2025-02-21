//
//  SearchSheet.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/20/25.
//

import SwiftUI

struct SearchSheet: View {
    @Binding var showSearch: Bool
    
    var body: some View {
        VStack {
                
            HStack (spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search", text: .constant(""))
                        .foregroundStyle(.secondary)
                    
                }
                .padding(10)
                .background(.tertiary)
                .cornerRadius(10)
                .padding()
                
                Button(action: {
                    showSearch.toggle()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .padding(.trailing, 25)
                }
                .foregroundStyle(.tertiary)
                
                
            }
            
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
    }
    
}
