import SwiftUI
import ReadiumShared

struct ReadiumViewModelTestView: View {
    // Use a specific test book instance
    @StateObject private var viewModel = ReadiumBookViewModel(
        book: Book( // Replace with your actual test book details
            title: "COTE",
            coverImage: "",
            readingProgress: 0.0,
            filePath: "Books/cote.epub" // Path relative to Bundle or Documents
        )
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Book: \(viewModel.book.title)")
            Text("Is Loading: \(viewModel.isLoading.description)")
            Text("Error: \(viewModel.errorMessage ?? "None")")
            Text("Publication Loaded: \((viewModel.publication != nil).description)")
            Text("TOC Count: \(viewModel.tableOfContents.count)")
            Text("Initial Location Progression: \(viewModel.initialLocation?.locations.progression?.description ?? "N/A")")
            Text("Current Pref Font Size: \(viewModel.preferences.fontSize?.description ?? "Default")")
            Text("Current Book Progress: \(String(format: "%.1f%%", (viewModel.book.readingProgress ?? 0.0) * 100))")

            Button("Load Publication") {
                Task {
                    await viewModel.loadPublication()
                }
            }
            .disabled(viewModel.isLoading || viewModel.publication != nil)

            // Optional: Button to simulate location update
            Button("Simulate Location Update") {
                // Create a dummy locator for testing
                // Use RelativeURL for href and MediaType for mediaType
                guard let href = RelativeURL(string: "/dummy.xhtml") else {
                    print("Error: Invalid relative URL string for dummy locator")
                    return
                }
                guard let mediaType = MediaType("application/xhtml+xml") else {
                     print("Error: Invalid media type string for dummy locator")
                     return
                }

                let dummyLocator = Locator(
                    href: href, // Use RelativeURL
                    mediaType: mediaType, // Use correct label and MediaType struct
                    // title: nil, // Optional title
                    locations: .init(progression: 0.5) // 50% progress
                    // text: nil // Optional text context
                )

                viewModel.handleLocationUpdate(dummyLocator)
                print("Simulated location update. Check UserDefaults.")
            }

            Spacer()
        }
        .padding()
        .onAppear {
             // Optionally load immediately
             Task { await viewModel.loadPublication() }
        }
    }
}

#Preview {
    ReadiumViewModelTestView()
}
