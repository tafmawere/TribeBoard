import SwiftUI

/// A divider component that displays "or" text centered between two horizontal lines
/// Used to separate different sections or options in the UI
struct OrDivider: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private var spacing: CGFloat {
        BrandStyle.paddingMedium * min(dynamicTypeSize.customScaleFactor, 1.3)
    }
    
    private var textPadding: CGFloat {
        BrandStyle.paddingSmall * min(dynamicTypeSize.customScaleFactor, 1.2)
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            // Left divider line
            Rectangle()
                .fill(Color.secondary.opacity(0.4))
                .frame(height: 1)
            
            // "or" text
            Text("or")
                .accessibleFont(size: 15, maxSize: 18, weight: .medium)
                .foregroundColor(.secondary)
                .padding(.horizontal, textPadding)
            
            // Right divider line
            Rectangle()
                .fill(Color.secondary.opacity(0.4))
                .frame(height: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Alternative option separator")
        .accessibilityHint("Separates the family code entry option from the QR code scanning option")
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Preview

#Preview("OrDivider") {
    VStack(spacing: BrandStyle.paddingLarge) {
        // Example usage in context
        VStack(spacing: BrandStyle.paddingMedium) {
            Text("Option 1")
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(BrandStyle.cornerRadius)
            
            OrDivider()
            
            Text("Option 2")
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(BrandStyle.cornerRadius)
        }
        .padding()
        
        Divider()
        
        // Standalone preview
        OrDivider()
            .padding()
    }
}