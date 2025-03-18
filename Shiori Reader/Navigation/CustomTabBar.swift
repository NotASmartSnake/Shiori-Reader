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
            Divider()
                .background(Color.gray.opacity(0.5))
            HStack {
                ForEach(0..<tabBarItems.count, id: \.self) { index in
                    Spacer()
                    
                    VStack(spacing: 4) { // Adjust spacing here
                        Image(systemName: tabBarItems[index].0)
                            .imageScale(.medium)
                            .font(.system(size: 21))
                        Text(tabBarItems[index].1)
                            .font(.system(size: 10))
                    }
                    .foregroundColor(selectedIndex == index ? .accentColor : .gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 49)
                    .onTapGesture {
                        selectedIndex = index
                    }
                }
            }
            .background(.ultraThinMaterial)
            
        }
    }

}

#Preview {
    MainView()
}

