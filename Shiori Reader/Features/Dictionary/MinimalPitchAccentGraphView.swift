//
//  MinimalPitchAccentGraphView.swift
//  Shiori Reader
//
//  Created by Claude on 6/13/25.
//

import SwiftUI

/// Minimal test view to verify compilation
struct MinimalPitchAccentGraphView: View {
    let pitchValue: Int
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
            
            Text("[\(pitchValue)]")
                .font(.caption)
        }
    }
}

/// Test to verify PitchAccentData works
struct TestPitchAccentIntegration: View {
    var body: some View {
        VStack {
            // Test creating PitchAccent
            let testAccent = PitchAccent(term: "test", reading: "test", pitchAccent: 1)
            Text("Test accent: \(testAccent.accentTypeEnglish)")
            
            // Test PitchAccentData
            let testData = PitchAccentData(accents: [testAccent])
            Text("Has data: \(!testData.isEmpty)")
            
            // Test minimal graph
            MinimalPitchAccentGraphView(pitchValue: 1)
        }
    }
}

#Preview {
    TestPitchAccentIntegration()
}
