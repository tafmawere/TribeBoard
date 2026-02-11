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
        // Background - Semantic colors that adapt to dark mode
        static let screenBackground = Color(.systemBackground)
        static let cardBackground = Color(.systemBackground)
        static let cardBackgroundSecondary = Color(.secondarySystemBackground)
        
        // Primary Actions - Fixed brand color that works in both modes
        static let primaryBrand = Color(hex: "6B81F1")  // Periwinkle Blue - Primary brand color
        static let primaryBlue = Color(hex: "6366F1")
        static let primaryBlueLight = Color(hex: "6366F1").opacity(0.1)
        
        // Status Colors - Fixed colors that work in both modes
        static let successGreen = Color(hex: "10B981")
        static let warningOrange = Color(hex: "F59E0B")
        static let infoBlue = Color(hex: "3B82F6")
        
        // Badge Colors - Fixed colors that work in both modes
        static let adminBadge = Color(hex: "F59E0B")      // Orange
        static let driverBadge = Color(hex: "6366F1")     // Indigo-blue
        static let observerBadge = Color(hex: "8B5CF6")   // Purple
        static let parentBadge = Color(hex: "EC4899")     // Pink
        static let childBadge = Color(hex: "3B82F6")      // Blue
        static let passengerBadge = Color(hex: "10B981")  // Green
        
        // Text - Semantic colors that adapt to dark mode
        static let textPrimary = Color(.label)
        static let textSecondary = Color(.secondaryLabel)
        static let textTertiary = Color(.tertiaryLabel)
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
        // Card shadows for home dashboard redesign
        // Note: Shadow opacity adapts automatically in dark mode via Color(.systemGray)
        static let card: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            Color.black.opacity(0.1), 8, 0, 2
        )
        static let cardSecondary: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            Color.black.opacity(0.02), 2, 0, 1
        )
        
        // Floating button shadow
        static let floating: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            Color.black.opacity(0.3), 8, 0, 4
        )
        
        // Dark mode aware shadow color
        static var adaptiveShadow: Color {
            Color(.systemGray).opacity(0.3)
        }
    }
    
    // MARK: - Typography
    
    enum Typography {
        // Font sizes for home dashboard with Dynamic Type support
        static let title: Font = .title2
        static let heading: Font = .headline
        static let body: Font = .body
        static let caption: Font = .caption
        static let captionBold: Font = .caption.bold()
        
        // Custom scalable fonts for specific use cases
        static func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            return .system(size: size, weight: weight)
        }
    }
    
    // MARK: - Accessibility
    
    enum Accessibility {
        /// Minimum touch target size (44x44pt per Apple HIG)
        static let minimumTouchTarget: CGFloat = 44
        
        /// Recommended touch target size for primary actions
        static let recommendedTouchTarget: CGFloat = 48
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

// MARK: - StatusBadgeView Component

/// Reusable badge component for displaying status information
/// Supports primary, secondary, success, and warning styles
struct StatusBadgeView: View {
    let text: String
    let style: BadgeStyle
    
    enum BadgeStyle {
        case primary
        case secondary
        case success
        case warning
        
        var backgroundColor: Color {
            switch self {
            case .primary:
                return DesignSystem.Colors.primaryBrand
            case .secondary:
                // Use semantic color that adapts to dark mode
                return Color(.secondarySystemFill)
            case .success:
                return DesignSystem.Colors.successGreen
            case .warning:
                return DesignSystem.Colors.warningOrange
            }
        }
        
        var textColor: Color {
            switch self {
            case .primary, .success, .warning:
                return .white
            case .secondary:
                // Use semantic text color that adapts to dark mode
                return Color(.label)
            }
        }
    }
    
    var body: some View {
        Text(text.uppercased())
            .font(DesignSystem.Typography.captionBold)
            .foregroundColor(style.textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(style.backgroundColor)
            )
    }
}

// MARK: - StatusBadgeView Previews

#Preview("Primary Badge") {
    StatusBadgeView(text: "1 Active Run", style: .primary)
        .padding()
}

#Preview("Secondary Badge") {
    StatusBadgeView(text: "Sync: Just Now", style: .secondary)
        .padding()
}

#Preview("Success Badge") {
    StatusBadgeView(text: "Completed", style: .success)
        .padding()
}

#Preview("Warning Badge") {
    StatusBadgeView(text: "Delayed", style: .warning)
        .padding()
}

#Preview("All Badge Styles") {
    VStack(spacing: 16) {
        StatusBadgeView(text: "Primary", style: .primary)
        StatusBadgeView(text: "Secondary", style: .secondary)
        StatusBadgeView(text: "Success", style: .success)
        StatusBadgeView(text: "Warning", style: .warning)
    }
    .padding()
}
