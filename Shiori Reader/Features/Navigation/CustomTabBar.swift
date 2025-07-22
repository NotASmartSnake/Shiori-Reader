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
                    
                    VStack(spacing: 2) {
                        Image(systemName: tabBarItems[index].0)
                            .font(.system(size: 24))
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
            .background(
                (colorScheme == .light ? Color.white : Color.black)
                    .opacity(colorScheme == .light ? 0.85 : 0.2)
                    .background(.ultraThinMaterial)
            )
            
        }
    }

}

#Preview {
    MainView()
        .environmentObject(IsReadingBook())
        .environmentObject(LibraryManager())
        .environmentObject(SavedWordsManager())
}

