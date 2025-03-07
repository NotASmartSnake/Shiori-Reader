//
//  ThemePanel.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/19/25.
//

import SwiftUI
import UIKit

struct ThemePanel: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("isDarkMode") var isDarkMode: Bool?
    @ObservedObject var viewModel: BookViewModel
    
    var body: some View {
        VStack(spacing: 10) {
            // Handle bar
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
            
            Text("Reading Themes")
                .font(.title2)
                .fontWeight(.bold)
            
            // Font size and dark/light mode customization
            ZStack {
                HStack {
                    HStack {
                        Button(action: {
                            viewModel.decreaseFontSize()
                        }) {
                            Image(systemName: "textformat.size.smaller")
                                .foregroundStyle(.primary)
                                .font(.title)
                                .padding(.horizontal, 40)
                        }
                        .foregroundStyle(.primary)
                        
                        Rectangle()
                            .frame(width: 1, height: 25)
                            .opacity(0.2)
                        
                        Button(action: {
                            viewModel.increaseFontSize()
                        }) {
                            Image(systemName: "textformat.size.larger")
                                .foregroundStyle(.primary)
                                .font(.title)
                                .padding(.horizontal, 40)
                        }
                        .foregroundStyle(.primary)
                        
                    }
                    .frame(height: 40)
                    .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.gray.opacity(0.15)))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Menu {
                        Button(action: {
                            isDarkMode = false
                        }) {
                            HStack {
                                Text("Light Mode")
                                Spacer()
                                if isDarkMode == false {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        
                        Button(action: {
                            isDarkMode = true
                        }) {
                            HStack {
                                Text("Dark Mode")
                                Spacer()
                                if isDarkMode == true {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        
                        Button(action: {
                            isDarkMode = nil
                        }) {
                            HStack {
                                Text("Use System Setting")
                                Spacer()
                                if isDarkMode == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        HStack {
                            AppearanceModeIcon()
                                .font(.title2)
                                .padding(.horizontal, 20)
                            
                        }
                        .frame(height: 40)
                        .background(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.gray.opacity(0.15)))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .foregroundStyle(.primary)
                    
                }
                .padding(.horizontal)
            }
            
            
            // Theme options grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 15) {
                ThemeOption(name: "Original", backgroundColor: .white, textColor: .black)
                ThemeOption(name: "Warm", backgroundColor: Color(red: 245/255, green: 230/255, blue: 211/255), textColor: .black)
                ThemeOption(name: "Sepia", backgroundColor: Color(red: 0.98, green: 0.95, blue: 0.9), textColor: .black)
                ThemeOption(name: "Soft", backgroundColor: Color(red: 250/255, green: 249/255, blue: 246/255), textColor: .black)
                ThemeOption(name: "Paper", backgroundColor: Color(red: 237/255, green: 237/255, blue: 237/255), textColor: .black)
                ThemeOption(name: "Calm", backgroundColor: Color(red: 227/255, green: 242/255, blue: 253/255), textColor: .black)
            }
            .padding(.horizontal)
            
            // Customization bar
            RoundedRectangle(cornerRadius: 15)
                .fill(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.gray.opacity(0.15)))
                .frame(width: 180, height: 40)
                .overlay(
                    HStack {
                        Image(systemName: "gear")
                            .font(.headline)
                        Text("Customize")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 10)
                    }
                        .padding(.horizontal)
                )
                .padding(.top, 5)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: UIScreen.main.bounds.height * 0.5)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
    }
}

struct ThemeOption: View {
    let name: String
    let backgroundColor: Color
    let textColor: Color
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .frame(height: 100)
                .shadow(color: .gray.opacity(0.4), radius: 3)
                .overlay(
                    VStack {
                        Text("あ")
                            .foregroundColor(textColor)
                            .font(.title)
                            .fontWeight(.bold)
                        Text(name)
                            .font(.caption)
                            .foregroundColor(textColor)
                    }
                )
        }
    }
}

struct AppearanceModeIcon: View {
    @AppStorage("isDarkMode") var isDarkMode: Bool?
    
    var body: some View {
        if let isDarkMode = isDarkMode {
            Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
        } else {
            Image(systemName: "circle.lefthalf.filled")
        }
    }
}

#Preview {
    BookReaderView(book: Book(title: "実力至上主義者の教室", coverImage: "COTECover", readingProgress: 0.1, filePath: "konosuba.epub"))
}
