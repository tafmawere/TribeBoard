import SwiftUI

/// Brand styling constants and utilities
struct BrandStyle {
    // MARK: - Corner Radius
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16
    static let cornerRadiusSmall: CGFloat = 8
    
    // MARK: - Shadows
    static let shadowRadius: CGFloat = 4
    static let shadowOffset = CGSize(width: 0, height: 2)
    static let standardShadow = Color.black.opacity(0.1)
    
    // MARK: - Spacing
    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24
    
    // MARK: - Animation
    static let standardAnimation = Animation.easeInOut(duration: 0.3)
    static let quickAnimation = Animation.easeInOut(duration: 0.2)
}

// MARK: - Color Extensions
// Note: Brand colors are defined in BrandColors.swift to avoid conflicts

// MARK: - LinearGradient Extensions
// Note: Brand gradients are defined in BrandColors.swift to avoid conflicts