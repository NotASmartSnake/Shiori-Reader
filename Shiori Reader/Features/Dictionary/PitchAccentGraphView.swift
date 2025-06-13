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
        let graphWidth = max(CGFloat((mora.count - 1)) * stepWidth + marginLR * 2, 80)
        
        return Canvas { context, size in
            // Draw mora text
            for (index, moraChar) in mora.enumerated() {
                let xCenter = marginLR + CGFloat(index) * stepWidth
                let textRect = CGRect(x: xCenter - 10, y: lowY + 8, width: 20, height: 12)
                
                context.draw(
                    Text(moraChar)
                        .font(.caption2)
                        .foregroundColor(.primary),
                    in: textRect
                )
            }
            
            // Draw connecting lines and dots
            var previousPoint: CGPoint?
            
            for (index, accent) in pattern.enumerated() {
                let xCenter = marginLR + CGFloat(index) * stepWidth
                let yCenter: CGFloat = (accent == "H") ? highY : lowY
                let currentPoint = CGPoint(x: xCenter, y: yCenter)
                
                // Draw connecting line from previous point
                if let prevPoint = previousPoint {
                    var path = Path()
                    path.move(to: prevPoint)
                    path.addLine(to: currentPoint)
                    
                    context.stroke(path, with: .color(.primary), lineWidth: lineWidth)
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
        
        // Test with PitchAccentData
        let testAccents = PitchAccentData(accents: [
            PitchAccent(term: "猫", reading: "ねこ", pitchAccent: 1),
            PitchAccent(term: "猫", reading: "ねこ", pitchAccent: 0)
        ])
        
        PitchAccentGraphsView(pitchAccents: testAccents, term: "猫", reading: "ねこ")
    }
    .padding()
}
