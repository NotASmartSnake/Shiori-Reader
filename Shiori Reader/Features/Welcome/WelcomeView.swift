
import SwiftUI

struct WelcomeView: View {
    @Binding var isFirstLaunch: Bool
    @State private var currentPage = 0
    
    private let pages: [WelcomePage] = [
        WelcomePage(
            title: "Welcome to Shiori Reader",
            description: "Your personal Japanese e-book reader designed for language learners",
            imageName: "book.closed.fill",
            backgroundColor: Color.blue
        ),
        WelcomePage(
            title: "Tap to Look Up Words",
            description: "Simply tap on any Japanese word to instantly see its meaning and reading",
            imageName: "hand.tap.fill",
            backgroundColor: Color.purple
        ),
        WelcomePage(
            title: "Save Words",
            description: "Save words you want to remember to your vocabulary list for later review",
            imageName: "bookmark.fill",
            backgroundColor: Color.green
        ),
        WelcomePage(
            title: "Export to Anki",
            description: "Send words directly to AnkiMobile for spaced repetition practice",
            imageName: "square.and.arrow.up.fill",
            backgroundColor: Color.orange
        ),
        WelcomePage(
            title: "Let's Get Started!",
            description: "Import your first EPUB book and begin your Japanese reading journey!",
            imageName: "arrow.right.circle.fill",
            backgroundColor: Color.red
        )
    ]
    
    var body: some View {
        ZStack {
            // Background that animates between page colors
            pages[currentPage].backgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut, value: currentPage)
            
            VStack {
                Spacer()
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        VStack(spacing: 30) {
                            // Icon
                            Image(systemName: pages[index].imageName)
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                            
                            // Title
                            Text(pages[index].title)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                            
                            // Description
                            Text(pages[index].description)
                                .font(.title3)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 40)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                Spacer()
                
                // Page indicator and continue button
                VStack(spacing: 30) {
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == currentPage ? 1.2 : 1.0)
                                .animation(.spring(), value: currentPage)
                        }
                    }
                    
                    // Continue or Get Started button
                    Button(action: {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            isFirstLaunch = false
                        }
                    }) {
                        HStack {
                            Group {
                                if currentPage < pages.count - 1 {
                                    Text("Continue")
                                } else {
                                    Text("Get Started")
                                }
                            }
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                            .fontWeight(.semibold)

                            Image(systemName: "arrow.right")
                                .font(.headline)
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .foregroundColor(pages[currentPage].backgroundColor)
                        .cornerRadius(12)
                    }
                    
                    // Skip button (only show if not on last page)
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            isFirstLaunch = false
                        }
                        .foregroundColor(.white)
                        .padding(.top, 8)
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }
}

// Model for welcome page data
struct WelcomePage {
    let title: String
    let description: String
    let imageName: String
    let backgroundColor: Color
}

// Preview
#Preview {
    WelcomeView(isFirstLaunch: .constant(true))
}
