import SwiftUI

// FlowLayout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let containerWidth = proposal.width ?? .infinity
        
        var origin = CGPoint.zero
        var maxHeight: CGFloat = 0
        
        for view in subviews {
            let viewSize = view.sizeThatFits(.unspecified)
            
            // Check if we need to move to next row
            if origin.x + viewSize.width > containerWidth && origin.x > 0 {
                origin.x = 0
                origin.y += viewSize.height + spacing
            }
            
            // Position view
            origin.x += viewSize.width + spacing
            maxHeight = max(maxHeight, origin.y + viewSize.height)
        }
        
        return CGSize(width: containerWidth, height: maxHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let containerWidth = bounds.width
        
        var origin = CGPoint(x: bounds.minX, y: bounds.minY)
        var maxHeight: CGFloat = 0
        
        for view in subviews {
            let viewSize = view.sizeThatFits(.unspecified)
            
            // Check if we need to move to next row
            if origin.x + viewSize.width > containerWidth + bounds.minX && origin.x > bounds.minX {
                origin.x = bounds.minX
                origin.y += viewSize.height + spacing
            }
            
            // Place view
            view.place(at: origin, proposal: ProposedViewSize(width: viewSize.width, height: viewSize.height))
            origin.x += viewSize.width + spacing
            maxHeight = max(maxHeight, origin.y + viewSize.height - bounds.minY)
        }
    }
}
