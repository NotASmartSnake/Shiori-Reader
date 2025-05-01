//
//  UIColor+Hex.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/16/25.
//

import UIKit

extension UIColor {
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        let success = Scanner(string: hex).scanHexInt64(&int)
        
        // Return nil if scan fails or if string is empty
        if !success || hex.isEmpty {
            return nil
        }
        
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        // Make sure values are within valid range
        let red = min(CGFloat(r), 255) / 255.0
        let green = min(CGFloat(g), 255) / 255.0
        let blue = min(CGFloat(b), 255) / 255.0
        let alpha = min(CGFloat(a), 255) / 255.0
        
        self.init(
            red: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }
    
    func toHexString() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // Clamp values between 0 and 1
        r = max(0, min(1, r))
        g = max(0, min(1, g))
        b = max(0, min(1, b)) 
        
        return String(
            format: "#%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255)
        )
    }
}
