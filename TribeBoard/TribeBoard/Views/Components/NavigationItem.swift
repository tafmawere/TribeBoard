import SwiftUI

/// Individual navigation item component for the floating bottom navigation
struct NavigationItem: View {
    // MARK: - Properties
    
    let tab: NavigationTab
    let isActive: Bool
    let onTap: () -> Void
    

    
    // MARK: - Environment
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // MARK: - Body
    
    var body: some View {
        Button(action: handleTap) {
            VStack(spacing: scaledSpacing) {
                Image(systemName: isActive ? tab.activeIcon : tab.icon)
                    .font(.system(size: scaledIconSize, weight: .medium))
                    .foregroundColor(iconColor)
                
                Text(tab.displayName)
                    .font(.system(size: scaledLabelSize, weight: .medium))
                    .foregroundColor(labelColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(minWidth: scaledTouchTarget, minHeight: scaledTouchTarget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityValue(isActive ? "Selected" : "")
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : [.isButton])
    }
    

    
    // MARK: - Computed Properties
    
    private var iconColor: Color {
        if colorSchemeContrast == .increased {
            return isActive ? .brandPrimaryAccessible : .primary
        } else {
            return isActive ? .brandPrimaryDynamic : .secondary
        }
    }
    
    private var labelColor: Color {
        if colorSchemeContrast == .increased {
            return isActive ? .brandPrimaryAccessible : .primary
        } else {
            return isActive ? .brandPrimaryDynamic : .secondary
        }
    }
    
    // MARK: - Dynamic Type Scaling
    
    private var scaledIconSize: CGFloat {
        let baseSize: CGFloat = 24
        let scaleFactor = dynamicTypeSize.scaleFactor
        // Cap icon scaling to prevent overly large icons
        let cappedScaleFactor = min(scaleFactor, 1.5)
        return baseSize * cappedScaleFactor
    }
    
    private var scaledLabelSize: CGFloat {
        let baseSize: CGFloat = 11
        let scaleFactor = dynamicTypeSize.scaleFactor
        // Allow more scaling for text readability
        return baseSize * scaleFactor
    }
    
    private var scaledSpacing: CGFloat {
        let baseSpacing = DesignSystem.Spacing.xs
        let scaleFactor = dynamicTypeSize.scaleFactor
        // Scale spacing proportionally but with a minimum
        return max(baseSpacing * scaleFactor, 2)
    }
    
    private var scaledTouchTarget: CGFloat {
        let baseTarget = DesignSystem.Layout.minTouchTarget
        let scaleFactor = dynamicTypeSize.scaleFactor
        // Ensure touch target grows with text size
        return max(baseTarget * min(scaleFactor, 1.3), baseTarget)
    }
    
    private var accessibilityLabel: String {
        if isActive {
            return "\(tab.displayName), selected"
        } else {
            return tab.displayName
        }
    }
    
    private var accessibilityHint: String {
        if isActive {
            return "Currently viewing \(tab.displayName)"
        } else {
            return "Navigate to \(tab.displayName)"
        }
    }
    
    // MARK: - Actions
    
    private func handleTap() {
        // Enhanced haptic feedback sequence
        if !isActive {
            // Selection feedback for new tab
            HapticManager.shared.selection()
        } else {
            // Light feedback for already active tab
            HapticManager.shared.lightImpact()
        }
        
        // Execute the tap action
        onTap()
    }
    

}



// MARK: - Preview

#Preview("Navigation Item - Inactive") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        NavigationItem(
            tab: .home,
            isActive: false,
            onTap: {}
        )
        
        NavigationItem(
            tab: .schoolRun,
            isActive: false,
            onTap: {}
        )
        
        NavigationItem(
            tab: .shopping,
            isActive: false,
            onTap: {}
        )
        
        NavigationItem(
            tab: .tasks,
            isActive: false,
            onTap: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Navigation Item - Active") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        NavigationItem(
            tab: .home,
            isActive: true,
            onTap: {}
        )
        
        NavigationItem(
            tab: .schoolRun,
            isActive: true,
            onTap: {}
        )
        
        NavigationItem(
            tab: .shopping,
            isActive: true,
            onTap: {}
        )
        
        NavigationItem(
            tab: .tasks,
            isActive: true,
            onTap: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Navigation Item - Mixed States") {
    HStack(spacing: DesignSystem.Spacing.lg) {
        NavigationItem(
            tab: .home,
            isActive: true,
            onTap: {}
        )
        
        NavigationItem(
            tab: .schoolRun,
            isActive: false,
            onTap: {}
        )
        
        NavigationItem(
            tab: .shopping,
            isActive: false,
            onTap: {}
        )
        
        NavigationItem(
            tab: .tasks,
            isActive: false,
            onTap: {}
        )
    }
    .padding()
    .background(
        RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusLarge)
            .fill(Color(.systemBackground))
            .mediumShadow()
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Navigation Item - Large Dynamic Type") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        Text("Large Dynamic Type")
            .headlineSmall()
        
        HStack(spacing: DesignSystem.Spacing.lg) {
            NavigationItem(
                tab: .home,
                isActive: true,
                onTap: {}
            )
            
            NavigationItem(
                tab: .tasks,
                isActive: false,
                onTap: {}
            )
        }
        .environment(\.dynamicTypeSize, .accessibility3)
        
        Text("Standard Size")
            .labelMedium()
        
        HStack(spacing: DesignSystem.Spacing.lg) {
            NavigationItem(
                tab: .home,
                isActive: true,
                onTap: {}
            )
            
            NavigationItem(
                tab: .tasks,
                isActive: false,
                onTap: {}
            )
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Navigation Item - High Contrast") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        Text("High Contrast Mode")
            .headlineSmall()
        
        HStack(spacing: DesignSystem.Spacing.lg) {
            NavigationItem(
                tab: .home,
                isActive: true,
                onTap: {}
            )
            
            NavigationItem(
                tab: .schoolRun,
                isActive: false,
                onTap: {}
            )
            
            NavigationItem(
                tab: .shopping,
                isActive: false,
                onTap: {}
            )
            
            NavigationItem(
                tab: .tasks,
                isActive: false,
                onTap: {}
            )
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}

#Preview("Navigation Item - All Accessibility Features") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        Text("All Accessibility Features")
            .headlineSmall()
        
        HStack(spacing: DesignSystem.Spacing.lg) {
            NavigationItem(
                tab: .home,
                isActive: true,
                onTap: {}
            )
            
            NavigationItem(
                tab: .tasks,
                isActive: false,
                onTap: {}
            )
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .environment(\.dynamicTypeSize, .accessibility2)
}