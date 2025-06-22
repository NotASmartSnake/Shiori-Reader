//
//  FontSizeButtonControl.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 6/21/25.
//

import SwiftUI

struct FontSizeButtonControl: View {
    @Binding var fontSize: Float
    let fontSizeRange: ClosedRange<Float>
    let fontSizeStep: Float
    let onFontSizeChanged: (Float) -> Void
    
    // State for showing the dots indicator
    @State private var showDots = false
    @State private var dotsOpacity: Double = 0.0
    @State private var hideDotsTask: Task<Void, Never>?
    
    // Constants for dots display
    private let numberOfDots = 8
    private let dotsDisplayDuration: Double = 2.5
    
    var body: some View {
        // Font size button
        HStack {
            Text("Font Size")
            
            Spacer()
            
            // Dots indicator (appears temporarily when font size changes)
            if showDots {
                HStack(spacing: 3) {
                    ForEach(0..<numberOfDots, id: \.self) { index in
                        Circle()
                            .fill(isDotFilled(index: index) ? Color.primary : Color.secondary.opacity(0.4))
                            .frame(width: 5, height: 5)
                    }
                }
                .opacity(dotsOpacity)
                .animation(.easeInOut(duration: 0.2), value: dotsOpacity)
                .animation(.easeInOut(duration: 0.1), value: fontSize)
            }
            
            Spacer()
            
            // Font size button control
            HStack(spacing: 0) {
                // Decrease button (left side with smaller あ)
                Button(action: {
                    decreaseFontSize()
                }) {
                    HStack {
                        Spacer()
                        Text("あ")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(fontSize <= fontSizeRange.lowerBound ? .secondary : .primary)
                        Spacer()
                    }
                    .frame(width: 60, height: 40)
                    .background(Color.secondary.opacity(0.1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                // Separator line
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1, height: 30)
                
                // Increase button (right side with larger あ)
                Button(action: {
                    increaseFontSize()
                }) {
                    HStack {
                        Spacer()
                        Text("あ")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(fontSize >= fontSizeRange.upperBound ? .secondary : .primary)
                        Spacer()
                    }
                    .frame(width: 60, height: 40)
                    .background(Color.secondary.opacity(0.1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func decreaseFontSize() {
        let newSize = max(fontSize - fontSizeStep, fontSizeRange.lowerBound)
        if newSize != fontSize {
            // Provide haptic feedback for successful change
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            updateFontSize(newSize)
        } else {
            // Provide negative haptic feedback when hitting minimum limit
            let selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback.selectionChanged()
            
            // Add a second haptic after a short delay for the "error" feeling
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                selectionFeedback.selectionChanged()
            }
        }
    }
    
    private func increaseFontSize() {
        let newSize = min(fontSize + fontSizeStep, fontSizeRange.upperBound)
        if newSize != fontSize {
            // Provide haptic feedback for successful change
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            updateFontSize(newSize)
        } else {
            // Provide negative haptic feedback when hitting maximum limit
            let selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback.selectionChanged()
            
            // Add a second haptic after a short delay for the "error" feeling
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                selectionFeedback.selectionChanged()
            }
        }
    }
    
    private func updateFontSize(_ newSize: Float) {
        fontSize = newSize
        onFontSizeChanged(newSize)
        showDotsIndicator()
    }
    
    private func showDotsIndicator() {
        // Cancel any existing hide task
        hideDotsTask?.cancel()
        
        // Show dots with animation
        showDots = true
        withAnimation(.easeIn(duration: 0.15)) {
            dotsOpacity = 1.0
        }
        
        // Schedule new hide task
        hideDotsTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(dotsDisplayDuration * 1_000_000_000))
            
            // Check if task was cancelled
            guard !Task.isCancelled else { return }
            
            // Hide dots on main thread
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    dotsOpacity = 0.0
                }
                
                // Remove dots from view hierarchy after fade out
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        showDots = false
                    }
                }
            }
        }
    }
    
    private func isDotFilled(index: Int) -> Bool {
        // Calculate which dots should be filled based on current font size
        let normalizedFontSize = (fontSize - fontSizeRange.lowerBound) / (fontSizeRange.upperBound - fontSizeRange.lowerBound)
        let filledDots = Int(ceil(normalizedFontSize * Float(numberOfDots)))
        return index < max(1, filledDots) // Ensure at least one dot is always filled
    }
}

// MARK: - Preview

struct FontSizeButtonControl_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var fontSize: Float = 1.0
        
        var body: some View {
            VStack(spacing: 20) {
                FontSizeButtonControl(
                    fontSize: $fontSize,
                    fontSizeRange: 0.5...2.0,
                    fontSizeStep: 0.1,
                    onFontSizeChanged: { newSize in
                        print("Font size changed to: \(newSize)")
                    }
                )
                
                Text("Current size: \(fontSize, specifier: "%.1f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
            .previewLayout(.sizeThatFits)
    }
}
