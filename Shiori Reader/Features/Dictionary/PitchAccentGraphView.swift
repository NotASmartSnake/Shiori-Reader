//
//  PitchAccentGraphView.swift
//  Shiori Reader
//
//  Created by Claude on 6/13/25.
//

import SwiftUI

/// A visual representation of Japanese pitch accent patterns using dots and lines
struct PitchAccentGraphView: View {
    let word: String
    let reading: String
    let pitchValue: Int
    
    // Drawing constants
    private let stepWidth: CGFloat = 25
    private let marginLR: CGFloat = 12
    private let dotRadius: CGFloat = 3
    private let highY: CGFloat = 8
    private let lowY: CGFloat = 24
    private let lineWidth: CGFloat = 2
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Create the pitch pattern graph
            pitchGraphView
        }
    }
    
    private var pitchGraphView: some View {
        let textToAnalyze = reading.isEmpty ? word : reading
        let mora = JapanesePitchAccentUtils.extractMora(from: textToAnalyze)
        let pattern = JapanesePitchAccentUtils.generatePitchPattern(moraCount: mora.count, pitchValue: pitchValue)
        
        // Ensure width includes the last circle properly
        let graphWidth = max(CGFloat(max(mora.count, pattern.count) - 1) * stepWidth + marginLR * 2, 80)
        
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
                            
                            context.stroke(path, with: .color(.primary), lineWidth: lineWidth)
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
                            with: .color(.primary),
                            lineWidth: 1.5
                        )
                    } else {
                        context.fill(
                            Circle().path(in: dotRect),
                            with: .color(.primary)
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
                    .foregroundColor(.primary)
                    .position(x: xCenter, y: lowY + 15)
            }
        }
        .frame(width: graphWidth, height: 50)
    }
    

}

/// Container view for multiple pitch accent graphs
struct PitchAccentGraphsView: View {
    let pitchAccents: PitchAccentData
    let term: String
    let reading: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(pitchAccents.accents.prefix(3)), id: \.id) { accent in
                HStack(spacing: 8) {
                    // Pitch accent number badge
                    Text("[\(accent.pitchAccent)]")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(pitchAccentColor(for: accent.pitchAccent))
                        .cornerRadius(4)
                    
                    // Pitch accent graph
                    PitchAccentGraphView(
                        word: accent.term,
                        reading: accent.reading,
                        pitchValue: accent.pitchAccent
                    )
                    
                    Spacer()
                }
            }
            
            // Show additional patterns if any
            if pitchAccents.accents.count > 3 {
                Text("+ \(pitchAccents.accents.count - 3) more")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func pitchAccentColor(for pattern: Int) -> Color {
        switch pattern {
        case 0:
            return .green  // Heiban (flat)
        case 1:
            return .orange // Atamadaka (head-high)
        default:
            return .blue   // Nakadaka (middle-high)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Test various pitch accent patterns
        PitchAccentGraphView(word: "はし", reading: "はし", pitchValue: 0) // Flat
        PitchAccentGraphView(word: "はし", reading: "はし", pitchValue: 1) // Head-high
        PitchAccentGraphView(word: "はし", reading: "はし", pitchValue: 2) // Middle-high
        
        PitchAccentGraphView(word: "がっこう", reading: "がっこう", pitchValue: 0) // Flat
        PitchAccentGraphView(word: "がっこう", reading: "がっこう", pitchValue: 3) // Drop after 3rd mora
        
        // FIXED: Test compound Japanese characters (yōon) - these should now display correctly
        Group {
            Text("Compound Characters Test (Fixed):")
                .font(.headline)
                .foregroundColor(.green)
            
            PitchAccentGraphView(word: "じゃあく", reading: "じゃあく", pitchValue: 0) // じゃあく - 'じゃ' should display
            PitchAccentGraphView(word: "しゃしん", reading: "しゃしん", pitchValue: 1) // しゃしん - 'しゃ' should display
            PitchAccentGraphView(word: "きょう", reading: "きょう", pitchValue: 2) // きょう - 'きょ' should display
            PitchAccentGraphView(word: "ちゅうい", reading: "ちゅうい", pitchValue: 0) // ちゅうい - 'ちゅ' should display
            PitchAccentGraphView(word: "にゃんこ", reading: "にゃんこ", pitchValue: 1) // にゃんこ - 'にゃ' should display
            
            // Katakana compound characters
            PitchAccentGraphView(word: "シャワー", reading: "シャワー", pitchValue: 0) // シャワー - 'シャ' should display
            PitchAccentGraphView(word: "ジュース", reading: "ジュース", pitchValue: 2) // ジュース - 'ジュ' should display
        }
        
        // Test with PitchAccentData
        let testAccents = PitchAccentData(accents: [
            PitchAccent(term: "猫", reading: "ねこ", pitchAccent: 1),
            PitchAccent(term: "猫", reading: "ねこ", pitchAccent: 0)
        ])
        
        PitchAccentGraphsView(pitchAccents: testAccents, term: "猫", reading: "ねこ")
    }
    .padding()
}
