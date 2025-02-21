//
//  CustomTabBar.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/20/25.
//

import SwiftUI

struct CustomTabBar: View {
    
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedIndex: Int
    
    let tabBarItems = [
        ("books.vertical.fill", "Library"),
        ("bookmark.fill", "Saved Words"),
        ("magnifyingglass", "Search"),
        ("gearshape.fill", "Settings")
    ]

    var body: some View {
        
        VStack(spacing:0) {
            if (colorScheme == .light) {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.3))
            }

            HStack {
                ForEach(0..<tabBarItems.count, id: \.self) { index in
                    VStack(spacing: 5) { // Adjust spacing here
                        Image(systemName: tabBarItems[index].0)
                            .imageScale(.large)
                        Text(tabBarItems[index].1)
                            .font(.caption)
                    }
                    .foregroundColor(selectedIndex == index ? .blue : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 3) // Add top padding
                    .onTapGesture {
                        selectedIndex = index
                    }
                }
            }
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }

}
