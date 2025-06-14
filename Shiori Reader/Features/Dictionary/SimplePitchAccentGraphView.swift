//
//  SimplePitchAccentGraphView.swift
//  Shiori Reader
//
//  Created by Claude on 6/13/25.
//

import SwiftUI

/// A simple pitch accent graph that shows just the visual pattern without badges or numbers
struct SimplePitchAccentGraphView: View {
    let word: String
    let reading: String
    let pitchValue: Int
    
    // Drawing constants - smaller for popup use
    private let stepWidth: CGFloat = 18
    private let marginLR: CGFloat = 8
    private let dotRadius: CGFloat = 2.5
    private let highY: CGFloat = 6
    private let lowY: CGFloat = 18
    private let lineWidth: CGFloat = 1.5
    
    var body: some View {
        pitchGraphView
    }
    
    private var pitchGraphView: some View {
        let textToAnalyze = reading.isEmpty ? word : reading
        let mora = JapanesePitchAccentUtils.extractMora(from: textToAnalyze)
        let pattern = JapanesePitchAccentUtils.generatePitchPattern(moraCount: mora.count, pitchValue: pitchValue)
        
        // Ensure width includes the last circle properly
        let graphWidth = max(CGFloat(max(mora.count, pattern.count) - 1) * stepWidth + marginLR * 2, 60)
        
        return ZStack(alignment: .topLeading) {
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
                            
                            context.stroke(path, with: .color(.blue), lineWidth: lineWidth)
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
                            with: .color(.blue),
                            lineWidth: 1
                        )
                    } else {
                        context.fill(
                            Circle().path(in: dotRect),
                            with: .color(.blue)
                        )
                    }
                    
                    previousPoint = currentPoint
                }
            }
            
            // Overlay Text views for reliable Japanese character rendering
            ForEach(Array(mora.enumerated()), id: \.offset) { index, moraChar in
                let xCenter = marginLR + CGFloat(index) * stepWidth
                
                Text(moraChar)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .position(x: xCenter, y: lowY + 12)
            }
        }
        .frame(width: graphWidth, height: 35)
    }
}

#Preview {
    VStack(spacing: 10) {
        SimplePitchAccentGraphView(word: "はし", reading: "はし", pitchValue: 0)
        SimplePitchAccentGraphView(word: "はし", reading: "はし", pitchValue: 1) 
        SimplePitchAccentGraphView(word: "はし", reading: "はし", pitchValue: 2)
        SimplePitchAccentGraphView(word: "がっこう", reading: "がっこう", pitchValue: 0)
        
        // FIXED: Test compound Japanese characters that were previously failing
        Group {
            Text("Compound Characters (Fixed):")
                .font(.caption)
                .foregroundColor(.green)
            
            SimplePitchAccentGraphView(word: "じゃあく", reading: "じゃあく", pitchValue: 0) // じゃ should display
            SimplePitchAccentGraphView(word: "しゃしん", reading: "しゃしん", pitchValue: 1) // しゃ should display
            SimplePitchAccentGraphView(word: "きょう", reading: "きょう", pitchValue: 2) // きょ should display
            SimplePitchAccentGraphView(word: "シャワー", reading: "シャワー", pitchValue: 0) // シャ should display
        }
    }
    .padding()
}
