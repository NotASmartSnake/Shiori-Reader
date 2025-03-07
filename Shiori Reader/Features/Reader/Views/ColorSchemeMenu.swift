////
////  ColorSchemeMenu.swift
////  Shiori Reader
////
////  Created by Russell Graviet on 3/6/25.
////
//
//import SwiftUI
//
//struct ColorSchemeMenu: View {
//    @Environment(\.colorScheme) var colorScheme
//    @ObservedObject var viewModel: BookViewModel
//    @Environment(\.dismiss) private var dismiss
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            Button(action: {
//                viewModel.setColorScheme(.light)
//                dismiss()
//            }) {
//                HStack {
//                    Image(systemName: "sun.max.fill")
//                        .foregroundColor(.orange)
//                    Text("Light Mode")
//                    Spacer()
//                    if viewModel.userColorScheme == .light {
//                        Image(systemName: "checkmark")
//                    }
//                }
//                .padding()
//                .contentShape(Rectangle())
//            }
//            
//            Divider()
//            
//            Button(action: {
//                viewModel.setColorScheme(.dark)
//                dismiss()
//            }) {
//                HStack {
//                    Image(systemName: "moon.fill")
//                        .foregroundColor(.indigo)
//                    Text("Dark Mode")
//                    Spacer()
//                    if viewModel.userColorScheme == .dark {
//                        Image(systemName: "checkmark")
//                    }
//                }
//                .padding()
//                .contentShape(Rectangle())
//            }
//            
//            Divider()
//            
//            Button(action: {
//                viewModel.setColorScheme(.system)
//                dismiss()
//            }) {
//                HStack {
//                    Image(systemName: "gear")
//                        .foregroundColor(.gray)
//                    Text("Use System Setting")
//                    Spacer()
//                    if viewModel.userColorScheme == .system {
//                        Image(systemName: "checkmark")
//                    }
//                }
//                .padding()
//                .contentShape(Rectangle())
//            }
//        }
//        .frame(width: 220)
//        .background(Color(.secondarySystemBackground))
//        .cornerRadius(12)
//        .shadow(radius: 5)
//    }
//}
