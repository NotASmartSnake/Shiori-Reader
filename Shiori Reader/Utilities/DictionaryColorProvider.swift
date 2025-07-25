import SwiftUI
import Foundation

class DictionaryColorProvider: ObservableObject {
    static let shared = DictionaryColorProvider()
    
    @Published private var colorMap: [String: DictionaryTagColor] = [:]
    private var dictionaryOrder: [String] = []
    private let userDefaults = UserDefaults.standard
    private let dictionarySettingsKey = "dictionarySettings"
    
    init() {
        loadColors()
        
        // Listen for settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: UserDefaults.didChangeNotification,
            object: userDefaults
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func loadColors() {
        if let data = userDefaults.data(forKey: dictionarySettingsKey),
           let settings = try? JSONDecoder().decode(DictionarySettings.self, from: data) {
            colorMap = settings.dictionaryColors
            dictionaryOrder = settings.dictionaryOrder
        } else {
            // Use default colors and order
            colorMap = [
                "jmdict": .blue,
                "obunsha": .orange,
                "bccwj": .green
            ]
            dictionaryOrder = ["jmdict", "obunsha"]
        }
    }
    
    @objc private func settingsChanged() {
        loadColors()
    }
    
    func getColor(for source: String) -> Color {
        if let tagColor = colorMap[source] {
            return tagColor.swiftUIColor
        }
        
        // Fallback colors for backward compatibility
        switch source {
        case "jmdict":
            return .blue
        case "obunsha":
            return .orange
        case "bccwj":
            return .green
        default:
            if source.hasPrefix("imported_") {
                return getImportedDictionaryFallbackColor(for: source)
            }
            return .cyan
        }
    }
    
    private func getImportedDictionaryFallbackColor(for source: String) -> Color {
        let availableColors: [Color] = [.purple, .pink, .indigo, .teal, .cyan, .mint, .brown]
        let hash = abs(source.hashValue)
        return availableColors[hash % availableColors.count]
    }
    
    // Fast lookup without SwiftUI Color conversion for performance-critical paths
    func getTagColor(for source: String) -> DictionaryTagColor {
        return colorMap[source] ?? .cyan
    }
    
    func getOrderedDictionarySources() -> [String] {
        return dictionaryOrder
    }
}
