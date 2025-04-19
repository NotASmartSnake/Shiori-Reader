//
//  ImportStatusOverlay.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/9/25.
//


import SwiftUI

/// A simple overlay view to show import status
struct ImportStatusOverlay: View {
    let status: ImportStatus
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack {
            VStack(spacing: 20) {
                // Status icon
                statusIcon
                
                // Status text
                Text(title)
                    .font(.headline)
                
                Text(status.message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                // Only show dismiss button for failure cases since that's the only one we'll display
                Button(action: {
                    isPresented = false
                }) {
                    Text("OK")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top, 10)
            }
            .padding(25)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
            .padding(40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.4))
        .ignoresSafeArea()
        .transition(.opacity)
    }
    
    // Dynamic status icon based on the current status
    private var statusIcon: some View {
        Group {
            switch status {
            case .importing:
                ProgressView()
                    .scaleEffect(1.5)
                    .padding(8)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
            case .failure:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
            case .cancelled:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
            default:
                EmptyView()
            }
        }
    }
    
    // Dynamic title based on the current status
    private var title: String {
        switch status {
        case .importing:
            return "Importing Book"
        case .success:
            return "Import Successful"
        case .failure:
            return "Import Failed"
        case .cancelled:
            return "Import Cancelled"
        default:
            return ""
        }
    }
}

/// Extension to add more descriptive messages to ImportStatus
extension ImportStatus {
    var detailedMessage: String {
        switch self {
        case .idle:
            return ""
        case .importing:
            return "Please wait while your book is being processed..."
        case .success:
            return "Your book has been successfully imported and is ready to read."
        case .failure(let message):
            return "There was a problem importing your book: \(message)"
        case .cancelled:
            return "Book import was cancelled."
        }
    }
}

/// Preview for ImportStatusOverlay
#Preview {
    ZStack {
        Color.white.edgesIgnoringSafeArea(.all)
        
        VStack(spacing: 20) {
            Text("Preview States").font(.headline)
            
            Button("Show Importing") {
                // Preview action
            }
            
            Button("Show Success") {
                // Preview action
            }
            
            Button("Show Failure") {
                // Preview action
            }
        }
        
        // Preview with a status
        ImportStatusOverlay(status: .importing, isPresented: .constant(true))
    }
}
