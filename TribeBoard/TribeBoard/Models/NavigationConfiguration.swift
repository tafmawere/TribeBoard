import Foundation
import SwiftUI

/// Configuration for the floating bottom navigation
struct NavigationConfiguration {
    let tabs: [NavigationTab]
    let appearance: NavigationAppearance
    let animations: NavigationAnimations
    
    /// Default configuration for TribeBoard app
    static let `default` = NavigationConfiguration(
        tabs: NavigationTab.allCases,
        appearance: .default,
        animations: .default
    )
}

/// Appearance settings for the navigation component
struct NavigationAppearance {
    let backgroundColor: Color
    let activeColor: Color
    let inactiveColor: Color
    let shadowStyle: ShadowStyle
    let cornerRadius: CGFloat
    let containerHeight: CGFloat
    let bottomPadding: CGFloat
    let horizontalPadding: CGFloat
    
    /// Default appearance using TribeBoard design system
    static let `default` = NavigationAppearance(
        backgroundColor: Color(.systemBackground).opacity(0.95),
        activeColor: Color.brandPrimary,
        inactiveColor: Color.secondary,
        shadowStyle: ShadowStyle.medium,
        cornerRadius: 24, // Using DesignSystem spacing for large corner radius
        containerHeight: 72,
        bottomPadding: 16,
        horizontalPadding: 20
    )
}

/// Animation settings for navigation interactions
struct NavigationAnimations {
    let tapScale: CGFloat
    let colorTransitionDuration: Double
    let springResponse: Double
    let springDampingFraction: Double
    
    /// Default animation settings
    static let `default` = NavigationAnimations(
        tapScale: 0.95,
        colorTransitionDuration: 0.2,
        springResponse: 0.4,
        springDampingFraction: 0.8
    )
}

/// Shadow style configuration
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    
    /// Medium shadow for floating elements (using DesignSystem values)
    static let medium = ShadowStyle(
        color: Color.black.opacity(0.1),
        radius: 8,
        x: 0,
        y: 4
    )
}