//
//  AttributionView.swift
//  Shiori Reader
//
//  Created on 4/18/25.
//

import SwiftUI
import SafariServices

struct AttributionView: View {
    @State private var showingSafariView = false
    @State private var currentURL: URL?
    
    // Attribution data structure
    struct Attribution {
        let name: String
        let description: String
        let url: URL
    }
    
    let attributions: [Attribution] = [
        // Core Libraries
        Attribution(name: "Readium Swift Toolkit", description: "EPUB rendering and navigation", url: URL(string: "https://github.com/readium/swift-toolkit")!),
        
        // Inspiration
        Attribution(name: "Yomitan", description: "Japanese pop-up dictionary", url: URL(string: "https://github.com/yomidevs/yomitan")!),
        Attribution(name: "Immersion Reader", description: "iOS Japanese ebook reader", url: URL(string: "https://github.com/mathewthe2/immersion_reader/tree/main")!),
        
        
        // Japanese Language
        Attribution(name: "MeCab-Swift", description: "Japanese text tokenization", url: URL(string: "https://github.com/shinjukunian/Mecab-Swift")!),
        Attribution(name: "IPADic", description: "Japanese dictionary data for MeCab", url: URL(string: "https://github.com/taku910/mecab/tree/master/mecab-ipadic")!),
        Attribution(name: "JMdict", description: "Japanese-English dictionary database", url: URL(string: "https://www.edrdg.org/jmdict/j_jmdict.html")!),
        
        // Database
        Attribution(name: "GRDB.swift", description: "SQL database toolkit", url: URL(string: "https://github.com/groue/GRDB.swift")!),
        Attribution(name: "SQLite.swift", description: "SQLite wrapper", url: URL(string: "https://github.com/stephencelis/SQLite.swift")!),
        
        // Other
        Attribution(name: "AnkiMobile API", description: "Vocabulary export to Anki", url: URL(string: "https://docs.ankimobile.net/")!)
    ]
    
    var body: some View {
        ZStack {
            Color("BackgroundColor").ignoresSafeArea(edges: .all)
            
            List {
                ForEach(attributions, id: \.name) { attribution in
                    Button(action: {
                        self.currentURL = attribution.url
                        self.showingSafariView = true
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(attribution.name)
                                    .foregroundColor(.primary)
                                Text(attribution.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .listRowBackground(Color(.systemGray6))
                }
            }
            .listStyle(PlainListStyle())
        }
        .navigationTitle("Attributions")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSafariView) {
            if let url = currentURL {
                SafariView(url: url)
            }
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {
        // No update needed
    }
}

#Preview {
    NavigationStack {
        AttributionView()
    }
}
