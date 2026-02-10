//
//  DesignSystem.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import SwiftUI

/// TribeBoard Design System
/// Single source of truth for colors, spacing, typography, and visual constants
/// Matches the established visual language from reference screens
enum DesignSystem {
    
    // MARK: - Colors
    
    enum Colors {
        // Background
        static let screenBackground = Color(hex: "F9FAFB")
        static let cardBackground = Color.white
        
        // Primary Actions
        static let primaryBlue = Color(hex: "6366F1")
        static let primaryBlueLight = Color(hex: "6366F1").opacity(0.1)
        
        // Status Colors
        static let successGreen = Color(hex: "10B981")
        static let warningOrange = Color(hex: "F59E0B")
        static let infoBlue = Color(hex: "3B82F6")
        
        // Badge Colors
        static let adminBadge = Color(hex: "F59E0B")      // Orange
        static let driverBadge = Color(hex: "6366F1")     // Indigo-blue
        static let observerBadge = Color(hex: "8B5CF6")   // Purple
        static let parentBadge = Color(hex: "EC4899")     // Pink
        static let childBadge = Color(hex: "3B82F6")      // Blue
        static let passengerBadge = Color(hex: "10B981")  // Green
        
        // Text
        static let textPrimary = Color(hex: "1F2937")
        static let textSecondary = Color(hex: "6B7280")
        static let textTertiary = Color(hex: "9CA3AF")
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let spacing4: CGFloat = 4
        static let spacing8: CGFloat = 8
        static let spacing12: CGFloat = 12
        static let spacing16: CGFloat = 16
        static let spacing20: CGFloat = 20
        static let spacing24: CGFloat = 24
        static let spacing32: CGFloat = 32
        
        // Card padding
        static let cardPadding: CGFloat = 20
        
        // Section spacing
        static let sectionSpacing: CGFloat = 16
    }
    
    // MARK: - Corner Radius
    
    enum CornerRadius {
        static let radiusSmall: CGFloat = 8      // Badges, small buttons
        static let radiusMedium: CGFloat = 12    // Buttons
        static let radiusLarge: CGFloat = 20     // Cards
        static let radiusXLarge: CGFloat = 24    // Large cards, modals
        
        // Aliases for backward compatibility
        static let small: CGFloat = radiusSmall
        static let medium: CGFloat = radiusMedium
        static let large: CGFloat = radiusLarge
        static let xLarge: CGFloat = radiusXLarge
    }
    
    // MARK: - Shadows
    
    enum Shadow {
        static let card: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            Color.black.opacity(0.04), 8, 0, 2
        )
        static let cardSecondary: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            Color.black.opacity(0.02), 2, 0, 1
        )
    }
}

// MARK: - Color Extension for Hex Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
