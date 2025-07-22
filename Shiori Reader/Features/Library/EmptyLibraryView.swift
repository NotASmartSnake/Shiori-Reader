
import SwiftUI

struct EmptyLibraryView: View {
    @Binding var showDocumentPicker: Bool
    
    var body: some View {
        VStack(spacing: 25) {
            // Icon
            Image(systemName: "books.vertical")
                .font(.system(size: 70))
                .foregroundColor(.gray.opacity(0.7))
                .padding(.bottom, 10)
            
            // Title
            Text("Your Library is empty")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Description
            Text("Import your EPUB files to start reading and building your Japanese vocabulary")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Add book button
            Button(action: {
                showDocumentPicker = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add your first book")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.top, 10)
            
            // Tips section
            VStack(alignment: .leading, spacing: 12) {
                Text("Tips:")
                    .font(.headline)
                    .padding(.bottom, 5)
                
                tipRow(icon: "hand.tap", text: "Tap on words to look them up")
                tipRow(icon: "bookmark", text: "Save words to your vocabulary list")
                tipRow(icon: "plus.rectangle.on.rectangle", text: "Export words to Anki for review")
            }
            .padding(20)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.top, 10)
            .padding(.horizontal, 20)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.blue)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    EmptyLibraryView(showDocumentPicker: .constant(false))
}
