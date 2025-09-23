import SwiftUI

/// Floating bottom navigation component providing quick access to main app sections
struct FloatingBottomNavigation: View {
    // MARK: - Properties
    
    @Binding var selectedTab: NavigationTab
    let onTabSelected: (NavigationTab) -> Void
    
    // MARK: - Animation State
    
    @State private var containerScale: CGFloat = 1.0
    @State private var backgroundOpacity: Double = 0.95
    
    // MARK: - Environment
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: scaledItemSpacing) {
            ForEach(NavigationTab.allCases) { tab in
                NavigationItem(
                    tab: tab,
                    isActive: selectedTab == tab,
                    onTap: {
                        handleTabSelection(tab)
                    }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: scaledContainerHeight)
        .padding(.horizontal, scaledHorizontalPadding)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusLarge)
                .fill(.regularMaterial)
                .background(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusLarge)
                        .fill(containerBackgroundColor.opacity(backgroundOpacity))
                        .animation(reduceMotion ? .none : DesignSystem.Animation.smooth, value: backgroundOpacity)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusLarge)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
                .mediumShadow()
        )
        .scaleEffect(containerScale)
        .animation(reduceMotion ? .none : DesignSystem.Animation.spring, value: containerScale)
        .padding(.horizontal, scaledEdgePadding)
        .padding(.bottom, DesignSystem.Spacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
        .accessibilityHint("Four tab navigation bar. Swipe right or left to navigate between sections")
        .accessibilityRotor("Navigation Tabs") {
            ForEach(NavigationTab.allCases) { tab in
                AccessibilityRotorEntry(tab.displayName, id: tab.rawValue) {
                    // This will focus on the specific tab
                    handleTabSelection(tab)
                }
            }
        }
        .onAppear {
            // Entrance animation (respect reduce motion)
            if !reduceMotion {
                withAnimation(DesignSystem.Animation.spring.delay(0.1)) {
                    containerScale = 1.0
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var scaledContainerHeight: CGFloat {
        let baseHeight: CGFloat = 72
        let scaleFactor = dynamicTypeSize.scaleFactor
        // Scale container height to accommodate larger text
        return max(baseHeight * min(scaleFactor, 1.4), baseHeight)
    }
    
    private var scaledHorizontalPadding: CGFloat {
        let basePadding = DesignSystem.Spacing.lg
        let scaleFactor = dynamicTypeSize.scaleFactor
        return basePadding * min(scaleFactor, 1.2)
    }
    
    private var scaledEdgePadding: CGFloat {
        let basePadding = DesignSystem.Spacing.xl
        let scaleFactor = dynamicTypeSize.scaleFactor
        return basePadding * min(scaleFactor, 1.2)
    }
    
    private var scaledItemSpacing: CGFloat {
        let scaleFactor = dynamicTypeSize.scaleFactor
        // Reduce spacing slightly for larger text sizes to maintain layout
        return max(0, 4 - (scaleFactor - 1.0) * 2)
    }
    
    private var containerBackgroundColor: Color {
        if colorSchemeContrast == .increased {
            return Color(.systemBackground)
        } else {
            return Color(.systemBackground)
        }
    }
    
    private var borderColor: Color {
        if colorSchemeContrast == .increased {
            return Color(.separator).opacity(0.6)
        } else {
            return Color(.separator).opacity(0.2)
        }
    }
    
    private var borderWidth: CGFloat {
        colorSchemeContrast == .increased ? 2 : 1
    }
    
    // MARK: - Private Methods
    
    /// Enhanced tab selection with coordinated animations
    private func handleTabSelection(_ tab: NavigationTab) {
        // Don't animate if already selected
        guard selectedTab != tab else {
            onTabSelected(tab)
            return
        }
        
        // Container pulse animation for feedback (respect reduce motion)
        if !reduceMotion {
            withAnimation(DesignSystem.Animation.quick) {
                containerScale = 1.02
                backgroundOpacity = 1.0
            }
            
            // Return to normal state
            withAnimation(DesignSystem.Animation.spring.delay(0.1)) {
                containerScale = 1.0
                backgroundOpacity = 0.95
            }
        }
        
        // Execute the selection with a slight delay for visual coordination
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            onTabSelected(tab)
        }
    }
}

// MARK: - Preview

#Preview("Floating Bottom Navigation - Home Selected") {
    VStack {
        Spacer()
        
        FloatingBottomNavigation(
            selectedTab: .constant(.home),
            onTabSelected: { _ in }
        )
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Floating Bottom Navigation - School Run Selected") {
    VStack {
        Spacer()
        
        FloatingBottomNavigation(
            selectedTab: .constant(.schoolRun),
            onTabSelected: { _ in }
        )
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Floating Bottom Navigation - Shopping Selected") {
    VStack {
        Spacer()
        
        FloatingBottomNavigation(
            selectedTab: .constant(.shopping),
            onTabSelected: { _ in }
        )
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Floating Bottom Navigation - Tasks Selected") {
    VStack {
        Spacer()
        
        FloatingBottomNavigation(
            selectedTab: .constant(.tasks),
            onTabSelected: { _ in }
        )
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Floating Bottom Navigation - Interactive") {
    struct InteractivePreview: View {
        @State private var selectedTab: NavigationTab = .home
        
        var body: some View {
            VStack {
                Spacer()
                
                Text("Selected: \(selectedTab.displayName)")
                    .headlineSmall()
                    .padding()
                
                Spacer()
                
                FloatingBottomNavigation(
                    selectedTab: $selectedTab,
                    onTabSelected: { tab in
                        selectedTab = tab
                    }
                )
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    return InteractivePreview()
}

#Preview("Floating Bottom Navigation - Dark Mode") {
    VStack {
        Spacer()
        
        FloatingBottomNavigation(
            selectedTab: .constant(.home),
            onTabSelected: { _ in }
        )
    }
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}

#Preview("Floating Bottom Navigation - Accessibility Large Text") {
    VStack {
        Spacer()
        
        Text("Extra Large Text Size")
            .headlineSmall()
            .padding()
        
        FloatingBottomNavigation(
            selectedTab: .constant(.tasks),
            onTabSelected: { _ in }
        )
    }
    .background(Color(.systemGroupedBackground))
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Floating Bottom Navigation - High Contrast") {
    VStack {
        Spacer()
        
        Text("High Contrast Mode")
            .headlineSmall()
            .padding()
        
        FloatingBottomNavigation(
            selectedTab: .constant(.home),
            onTabSelected: { _ in }
        )
    }
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}

#Preview("Floating Bottom Navigation - Reduce Motion") {
    VStack {
        Spacer()
        
        Text("Reduce Motion Enabled")
            .headlineSmall()
            .padding()
        
        FloatingBottomNavigation(
            selectedTab: .constant(.schoolRun),
            onTabSelected: { _ in }
        )
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Floating Bottom Navigation - All Accessibility Features") {
    VStack {
        Spacer()
        
        Text("All Accessibility Features")
            .headlineSmall()
            .padding()
        
        FloatingBottomNavigation(
            selectedTab: .constant(.shopping),
            onTabSelected: { _ in }
        )
    }
    .background(Color(.systemGroupedBackground))
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Floating Bottom Navigation - Layout Test") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        // Show different screen widths
        Text("iPhone SE Width")
            .labelMedium()
        
        FloatingBottomNavigation(
            selectedTab: .constant(.home),
            onTabSelected: { _ in }
        )
        .frame(width: 320) // iPhone SE width
        
        Text("iPhone Pro Width")
            .labelMedium()
        
        FloatingBottomNavigation(
            selectedTab: .constant(.schoolRun),
            onTabSelected: { _ in }
        )
        .frame(width: 393) // iPhone 14 Pro width
        
        Text("iPhone Pro Max Width")
            .labelMedium()
        
        FloatingBottomNavigation(
            selectedTab: .constant(.shopping),
            onTabSelected: { _ in }
        )
        .frame(width: 430) // iPhone 14 Pro Max width
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}