import SwiftUI

/// A footer component that displays instructional text for family sharing
/// Used at the bottom of screens to provide guidance to users
struct InstructionalFooter: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var verticalSpacing: CGFloat {
        BrandStyle.paddingSmall * min(dynamicTypeSize.customScaleFactor, 1.3)
    }
    
    private var horizontalPadding: CGFloat {
        let basePadding = BrandStyle.paddingLarge
        let compactFactor = horizontalSizeClass == .compact ? 0.8 : 1.0
        return basePadding * compactFactor
    }
    
    var body: some View {
        VStack(spacing: verticalSpacing) {
            Text("Ask a family member to share their family code or QR code with you to join their TribeBoard")
                .accessibleFont(size: 13, maxSize: 17, weight: .regular)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, horizontalPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Instructions")
        .accessibilityValue("Ask a family member to share their family code or QR code with you to join their TribeBoard")
        .accessibilityAddTraits(.isStaticText)
        .accessibilityHint("This text provides guidance on how to obtain the necessary information to join a family")
    }
}

// MARK: - Preview

#Preview("InstructionalFooter") {
    VStack(spacing: BrandStyle.paddingLarge) {
        // Example usage in context
        VStack(spacing: BrandStyle.paddingLarge) {
            Text("Main Content Area")
                .font(.title2)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(BrandStyle.cornerRadius)
            
            Spacer()
            
            InstructionalFooter()
        }
        .padding()
        .frame(maxHeight: 400)
        
        Divider()
        
        // Standalone preview
        InstructionalFooter()
            .padding()
        
        // Dark mode preview
        InstructionalFooter()
            .padding()
            .background(Color.black)
            .colorScheme(.dark)
    }
}