//
//  LibraryView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//


import SwiftUI

struct LibraryView: View {
    
    let books = [
        "DanmachiCover",
        "3DaysCover",
        "86Cover",
        "AOABCover",
        "COTECover",
        "HakomariCover",
        "KonosubaCover",
        "LoveCover",
        "MushokuCover",
        "OregairuCover",
        "ReZeroCover",
        "SlimeCover",
        "OverlordCover",
        "DeathCover",
        "NoGameCover"
    ]
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack{
            ZStack{
                Color("BackgroundColor").ignoresSafeArea(edges: .all)
                ScrollView{
                    VStack {
                        
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(books, id: \.self) { book in
                                Image(book)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100,  height: 150)
                                    .cornerRadius(8)
                                    .shadow(radius: 4)
                            }
                        }
                        .padding(.horizontal, 10)
                        
                        Rectangle()
                            .frame(width:0, height: 85)
                            
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        print("Settings tapped")
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .toolbarBackground(Color.black, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .navigationTitle(
                Text("Library")
            )
        
        }
    }
}

#Preview {
    LibraryView()
}
