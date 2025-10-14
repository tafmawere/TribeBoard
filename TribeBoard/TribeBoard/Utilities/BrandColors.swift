import SwiftUI

/// Brand colors for TribeBoard app based on the logo design
extension Color {
    
    // MARK: - Primary Brand Colors
    
    // Note: brandPrimary is auto-generated from asset catalog
    
    // Note: brandSecondary is auto-generated from asset catalog
    
    // MARK: - Semantic Colors
    
    /// Background gradient colors matching the logo
    static let brandGradientStart = brandPrimary
    static let brandGradientEnd = brandSecondary
    
    /// Text color that works well on brand backgrounds
    static let brandText = Color.white
    
    /// Accent color for interactive elements
    static let brandAccent = brandPrimary
    
    /// Green accent color for QR scanning and success states
    static let brandGreen = Color(red: 0.2, green: 0.7, blue: 0.3) // Accessible green
    
    /// Green accent color with accessibility support
    static let brandGreenAccessible = Color(red: 0.15, green: 0.6, blue: 0.25) // Darker green for better contrast
    
    // MARK: - Accessibility Colors
    
    /// High contrast versions for accessibility
    static let brandPrimaryAccessible = Color(red: 0.2, green: 0.4, blue: 0.8) // Darker blue for better contrast
    static let brandSecondaryAccessible = Color(red: 0.15, green: 0.3, blue: 0.6) // Darker secondary
    
    /// Dynamic colors that adapt to accessibility settings
    static var brandPrimaryDynamic: Color {
        Color(UIColor { traitCollection in
            if traitCollection.accessibilityContrast == .high {
                return UIColor(Color.brandPrimaryAccessible)
            } else {
                return UIColor(Color.brandPrimary)
            }
        })
    }
    
    static var brandSecondaryDynamic: Color {
        Color(UIColor { traitCollection in
            if traitCollection.accessibilityContrast == .high {
                return UIColor(Color.brandSecondaryAccessible)
            } else {
                return UIColor(Color.brandSecondary)
            }
        })
    }
    
    /// Dynamic green color that adapts to accessibility settings
    static var brandGreenDynamic: Color {
        Color(UIColor { traitCollection in
            if traitCollection.accessibilityContrast == .high {
                return UIColor(Color.brandGreenAccessible)
            } else {
                return UIColor(Color.brandGreen)
            }
        })
    }
}

// MARK: - Brand Gradients

extension LinearGradient {
    
    /// Primary brand gradient matching the logo background
    static let brandGradient = LinearGradient(
        gradient: Gradient(colors: [Color.brandGradientStart, Color.brandGradientEnd]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Accessible brand gradient with higher contrast
    static let brandGradientAccessible = LinearGradient(
        gradient: Gradient(colors: [Color.brandPrimaryAccessible, Color.brandSecondaryAccessible]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Dynamic gradient that adapts to accessibility settings
    static var brandGradientDynamic: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [Color.brandPrimaryDynamic, Color.brandSecondaryDynamic]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Subtle brand gradient for backgrounds
    static let brandGradientSubtle = LinearGradient(
        gradient: Gradient(colors: [
            Color.brandPrimary.opacity(0.1),
            Color.brandSecondary.opacity(0.05)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Brand Styling Helpers
// Note: BrandStyle struct is defined in BrandStyle.swift to avoid conflicts

// MARK: - Preview Helpers

#Preview("Brand Colors") {
    VStack(spacing: 20) {
        // Brand colors showcase
        HStack(spacing: 16) {
            Rectangle()
                .fill(Color.brandPrimary)
                .frame(width: 80, height: 80)
                .cornerRadius(BrandStyle.cornerRadius)
                .overlay(
                    Text("Primary")
                        .foregroundColor(.white)
                        .font(.caption)
                )
            
            Rectangle()
                .fill(Color.brandSecondary)
                .frame(width: 80, height: 80)
                .cornerRadius(BrandStyle.cornerRadius)
                .overlay(
                    Text("Secondary")
                        .foregroundColor(.white)
                        .font(.caption)
                )
            
            Rectangle()
                .fill(Color.brandGreen)
                .frame(width: 80, height: 80)
                .cornerRadius(BrandStyle.cornerRadius)
                .overlay(
                    Text("Green")
                        .foregroundColor(.white)
                        .font(.caption)
                )
        }
        
        // Brand gradient showcase
        Rectangle()
            .fill(LinearGradient.brandGradient)
            .frame(height: 100)
            .cornerRadius(BrandStyle.cornerRadius)
            .overlay(
                Text("Brand Gradient")
                    .foregroundColor(.white)
                    .font(.headline)
            )
        
        // Subtle gradient showcase
        Rectangle()
            .fill(LinearGradient.brandGradientSubtle)
            .frame(height: 60)
            .cornerRadius(BrandStyle.cornerRadius)
            .overlay(
                Text("Subtle Gradient")
                    .foregroundColor(.primary)
                    .font(.subheadline)
            )
    }
    .padding()
}