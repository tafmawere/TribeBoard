import SwiftUI

/// Brand colors for TribeBoard app based on the logo design
extension Color {
    
    // MARK: - Semantic Colors
    
    /// Background gradient colors matching the logo
    static let brandGradientStart = brandPrimary
    static let brandGradientEnd = brandSecondary
    
    /// Text color that works well on brand backgrounds
    static let brandText = Color.white
    
    /// Accent color for interactive elements
    static let brandAccent = brandPrimary
}

// MARK: - Brand Gradients

extension LinearGradient {
    
    /// Primary brand gradient matching the logo background
    static let brandGradient = LinearGradient(
        gradient: Gradient(colors: [Color.brandGradientStart, Color.brandGradientEnd]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
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

struct BrandStyle {
    
    /// Standard corner radius matching the logo's rounded corners
    static let cornerRadius: CGFloat = 16
    
    /// Small corner radius for buttons and cards
    static let cornerRadiusSmall: CGFloat = 8
    
    /// Large corner radius for major UI elements
    static let cornerRadiusLarge: CGFloat = 24
    
    /// Standard shadow for elevated elements
    static let standardShadow = Color.black.opacity(0.1)
    
    /// Brand shadow radius
    static let shadowRadius: CGFloat = 8
    
    /// Brand shadow offset
    static let shadowOffset = CGSize(width: 0, height: 4)
}

// MARK: - Preview Helpers

#if DEBUG
struct BrandColors_Previews: PreviewProvider {
    static var previews: some View {
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
        .previewDisplayName("Brand Colors")
    }
}
#endif