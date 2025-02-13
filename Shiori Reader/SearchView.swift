//
//  SearchView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//


import SwiftUI

struct SearchView: View {
    var body: some View {
        VStack {
                
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search", text: .constant(""))
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding()
            
            Spacer()
        }
    }
}

#Preview {
    SearchView()
}
