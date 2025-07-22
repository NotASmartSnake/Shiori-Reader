import SwiftUI
import UIKit

/// Utility for rendering SwiftUI views as UIImages
struct ViewImageRenderer {
    
    /// Renders a SwiftUI view to a UIImage
    /// - Parameters:
    ///   - view: The SwiftUI view to render
    ///   - size: Optional size for the rendered image. If nil, uses the view's intrinsic size
    /// - Returns: A UIImage representation of the view, or nil if rendering fails
    @MainActor
    static func render<Content: View>(_ view: Content, size: CGSize? = nil) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        
        // Set size if provided
        if let size = size {
            renderer.proposedSize = ProposedViewSize(size)
        }
        
        // Set scale for high-quality rendering
        renderer.scale = UIScreen.main.scale
        
        return renderer.uiImage
    }
    
    /// Renders a pitch accent graph view with custom colors for Anki export
    /// - Parameters:
    ///   - word: The Japanese word
    ///   - reading: The reading (hiragana/katakana)
    ///   - pitchValue: The pitch accent value
    ///   - graphColor: Color for the graph lines and dots
    ///   - textColor: Color for the text (mora characters)
    /// - Returns: A UIImage of the pitch accent graph, or nil if rendering fails
    @MainActor
    static func renderPitchAccentGraph(word: String, reading: String, pitchValue: Int, 
                                     graphColor: String = "black", textColor: String = "black") -> UIImage? {
        // Create a customizable pitch accent graph optimized for Anki cards
        let graphView = CustomizableGraphView(
            word: word,
            reading: reading,
            pitchValue: pitchValue,
            graphColor: colorFromString(graphColor),
            textColor: colorFromString(textColor)
        )
        .background(Color.clear) // Transparent background for better integration
        .padding(4) // Minimal padding
        
        // Calculate appropriate size based on content - small but readable for Anki
        let textToAnalyze = reading.isEmpty ? word : reading
        let moraCount = JapanesePitchAccentUtils.extractMora(from: textToAnalyze).count
        
        // Small but readable dynamic width based on mora count
        let graphWidth = max(min(CGFloat(moraCount) * 8 + 12, 80), 28)
        let graphHeight: CGFloat = 18 // Small but readable height
        
        return render(graphView, size: CGSize(width: graphWidth, height: graphHeight))
    }
    
    // Helper to convert color string to SwiftUI Color
    private static func colorFromString(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "black":
            return .black
        case "white":
            return .white
        case "grey", "gray":
            return .gray
        case "blue":
            return .blue
        default:
            return .black
        }
    }
    
    /// Converts a UIImage to a base64 encoded string for embedding in HTML/URLs
    /// - Parameters:
    ///   - image: The UIImage to convert
    ///   - format: The image format (.png or .jpeg)
    ///   - compressionQuality: Compression quality for JPEG (0.0 to 1.0, ignored for PNG)
    /// - Returns: A base64 encoded string, or nil if conversion fails
    static func imageToBase64(image: UIImage, format: ImageFormat = .png, compressionQuality: CGFloat = 0.8) -> String? {
        let imageData: Data?
        
        switch format {
        case .png:
            imageData = image.pngData()
        case .jpeg:
            imageData = image.jpegData(compressionQuality: compressionQuality)
        }
        
        guard let data = imageData else { return nil }
        return data.base64EncodedString()
    }
    
    /// Creates an HTML img tag with embedded base64 image data
    /// - Parameters:
    ///   - image: The UIImage to embed
    ///   - format: The image format (.png or .jpeg)
    ///   - compressionQuality: Compression quality for JPEG
    ///   - altText: Alt text for the image
    /// - Returns: An HTML img tag string, or nil if conversion fails
    static func imageToHTMLTag(image: UIImage, format: ImageFormat = .png, compressionQuality: CGFloat = 0.8, altText: String = "Pitch Accent Graph") -> String? {
        guard let base64String = imageToBase64(image: image, format: format, compressionQuality: compressionQuality) else {
            return nil
        }
        
        let mimeType = format == .png ? "image/png" : "image/jpeg"
        return "<img src=\"data:\(mimeType);base64,\(base64String)\" alt=\"\(altText)\" style=\"vertical-align: middle; margin: 2px;\">"
    }
}

/// Image format options for rendering
enum ImageFormat {
    case png
    case jpeg
}

// MARK: - Private Components

/// A customizable pitch accent graph for internal use in ViewImageRenderer
private struct CustomizableGraphView: View {
    let word: String
    let reading: String
    let pitchValue: Int
    let graphColor: Color
    let textColor: Color
    
    // Drawing constants - small but readable for Anki export
    private let stepWidth: CGFloat = 8
    private let marginLR: CGFloat = 4
    private let dotRadius: CGFloat = 1.2
    private let highY: CGFloat = 2
    private let lowY: CGFloat = 7
    private let lineWidth: CGFloat = 0.8
    
    var body: some View {
        let textToAnalyze = reading.isEmpty ? word : reading
        let mora = JapanesePitchAccentUtils.extractMora(from: textToAnalyze)
        let pattern = JapanesePitchAccentUtils.generatePitchPattern(moraCount: mora.count, pitchValue: pitchValue)
        
        // Ensure width includes the last circle properly
        let graphWidth = max(CGFloat(max(mora.count, pattern.count) - 1) * stepWidth + marginLR * 2, 28)
        
        ZStack(alignment: .topLeading) {
            // Background canvas for lines and dots only (no text)
            Canvas { context, size in
                // Draw connecting lines and dots
                var previousPoint: CGPoint?
                
                for (index, accent) in pattern.enumerated() {
                    let xCenter = marginLR + CGFloat(index) * stepWidth
                    let yCenter: CGFloat = (accent == "H") ? highY : lowY
                    let currentPoint = CGPoint(x: xCenter, y: yCenter)
                    
                    // Draw connecting line from previous point
                    if let prevPoint = previousPoint {
                        // Calculate line endpoints to stop at circle borders
                        let dx = currentPoint.x - prevPoint.x
                        let dy = currentPoint.y - prevPoint.y
                        let distance = sqrt(dx * dx + dy * dy)
                        
                        if distance > 0 {
                            // Normalize direction vector
                            let unitX = dx / distance
                            let unitY = dy / distance
                            
                            // Calculate start and end points at circle borders
                            let startPoint = CGPoint(
                                x: prevPoint.x + unitX * dotRadius,
                                y: prevPoint.y + unitY * dotRadius
                            )
                            let endPoint = CGPoint(
                                x: currentPoint.x - unitX * dotRadius,
                                y: currentPoint.y - unitY * dotRadius
                            )
                            
                            var path = Path()
                            path.move(to: startPoint)
                            path.addLine(to: endPoint)
                            
                            context.stroke(path, with: .color(graphColor), lineWidth: lineWidth)
                        }
                    }
                    
                    // Draw dot
                    let dotRect = CGRect(
                        x: currentPoint.x - dotRadius,
                        y: currentPoint.y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    )
                    
                    // Use hollow circle for points beyond mora count
                    if index >= mora.count {
                        context.stroke(
                            Circle().path(in: dotRect),
                            with: .color(graphColor),
                            lineWidth: 1
                        )
                    } else {
                        context.fill(
                            Circle().path(in: dotRect),
                            with: .color(graphColor)
                        )
                    }
                    
                    previousPoint = currentPoint
                }
            }
            
            // Overlay Text views for reliable Japanese character rendering
            ForEach(Array(mora.enumerated()), id: \.offset) { index, moraChar in
                let xCenter = marginLR + CGFloat(index) * stepWidth
                
                Text(moraChar)
                    .font(.system(size: 6)) // Small but readable font
                    .foregroundColor(textColor)
                    .position(x: xCenter, y: lowY + 5)
            }
        }
        .frame(width: graphWidth, height: 18)
    }
}
