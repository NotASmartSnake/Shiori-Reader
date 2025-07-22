import SwiftUI
import ReadiumShared
import ReadiumNavigator

struct SearchResultRow: View {
    let locator: Locator
    let index: Int
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void // Action to perform on tap

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Chapter title if available
            if let chapter = locator.title {
                Text(chapter)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Text with highlighted search term
            HStack {
                // Use locator.text which contains before/highlight/after
                Text(locator.text.before ?? "") +
                Text(locator.text.highlight ?? "")
                    .foregroundColor(.orange) // Or another highlight color
                    .bold() +
                Text(locator.text.after ?? "")

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ?
                      (colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.1)) :
                      Color.clear)
        )
        .contentShape(Rectangle()) // Ensure the whole row area is tappable
        .onTapGesture {
            action() // Call the provided action on tap
        }
    }
}
