
import Foundation
import ReadiumNavigator
import ReadiumShared

// Add default implementations for the new method to avoid breaking existing code
extension EPUBNavigatorDelegate {
    // Default empty implementation for the resource loading completion method
    // This ensures backward compatibility with existing code
    func navigator(_ navigator: Navigator, didLoadResourceAt href: RelativeURL) {
        // Default empty implementation
    }
}
