import SwiftUI

/// Comprehensive design system for TribeBoard app ensuring brand consistency
struct DesignSystem {
    
    // MARK: - Typography System
    
    struct Typography {
        
        // MARK: - Font Styles
        
        /// Display fonts for hero sections and major headings
        static let displayLarge = Font.system(size: 48, weight: .bold, design: .rounded)
        static let displayMedium = Font.system(size: 42, weight: .bold, design: .rounded)
        static let displaySmall = Font.system(size: 36, weight: .bold, design: .rounded)
        
        /// Headline fonts for section titles and important content
        static let headlineLarge = Font.system(size: 32, weight: .semibold, design: .rounded)
        static let headlineMedium = Font.system(size: 28, weight: .semibold, design: .rounded)
        static let headlineSmall = Font.system(size: 24, weight: .semibold, design: .rounded)
        
        /// Title fonts for cards and components
        static let titleLarge = Font.system(size: 22, weight: .semibold, design: .default)
        static let titleMedium = Font.system(size: 20, weight: .semibold, design: .default)
        static let titleSmall = Font.system(size: 18, weight: .semibold, design: .default)
        
        /// Body fonts for main content
        static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 16, weight: .regular, design: .default)
        static let bodySmall = Font.system(size: 15, weight: .regular, design: .default)
        
        /// Label fonts for UI elements
        static let labelLarge = Font.system(size: 14, weight: .medium, design: .default)
        static let labelMedium = Font.system(size: 13, weight: .medium, design: .default)
        static let labelSmall = Font.system(size: 12, weight: .medium, design: .default)
        
        /// Caption fonts for secondary information
        static let captionLarge = Font.system(size: 12, weight: .regular, design: .default)
        static let captionMedium = Font.system(size: 11, weight: .regular, design: .default)
        static let captionSmall = Font.system(size: 10, weight: .regular, design: .default)
        
        /// Button fonts
        static let buttonLarge = Font.system(size: 18, weight: .semibold, design: .default)
        static let buttonMedium = Font.system(size: 16, weight: .semibold, design: .default)
        static let buttonSmall = Font.system(size: 14, weight: .semibold, design: .default)
    }
    
    // MARK: - Spacing System
    
    struct Spacing {
        
        /// Extra small spacing (4pt)
        static let xs: CGFloat = 4
        
        /// Small spacing (8pt)
        static let sm: CGFloat = 8
        
        /// Medium spacing (12pt)
        static let md: CGFloat = 12
        
        /// Large spacing (16pt)
        static let lg: CGFloat = 16
        
        /// Extra large spacing (20pt)
        static let xl: CGFloat = 20
        
        /// Double extra large spacing (24pt)
        static let xxl: CGFloat = 24
        
        /// Triple extra large spacing (32pt)
        static let xxxl: CGFloat = 32
        
        /// Huge spacing (40pt)
        static let huge: CGFloat = 40
        
        /// Massive spacing (48pt)
        static let massive: CGFloat = 48
        
        /// Gigantic spacing (64pt)
        static let gigantic: CGFloat = 64
        
        // MARK: - Semantic Spacing
        
        /// Standard content padding
        static let contentPadding: CGFloat = lg
        
        /// Screen edge padding
        static let screenPadding: CGFloat = xl
        
        /// Card internal padding
        static let cardPadding: CGFloat = lg
        
        /// Section spacing
        static let sectionSpacing: CGFloat = xxxl
        
        /// Component spacing
        static let componentSpacing: CGFloat = xxl
        
        /// Element spacing
        static let elementSpacing: CGFloat = lg
        
        /// Tight spacing for related elements
        static let tightSpacing: CGFloat = sm
    }
    
    // MARK: - Layout System
    
    struct Layout {
        
        /// Maximum content width for readability
        static let maxContentWidth: CGFloat = 600
        
        /// Standard minimum touch target size
        static let minTouchTarget: CGFloat = 44
        
        /// Standard button height
        static let buttonHeight: CGFloat = 56
        
        /// Standard input field height
        static let inputHeight: CGFloat = 48
        
        /// Standard card minimum height
        static let cardMinHeight: CGFloat = 120
        
        /// Standard list row height
        static let listRowHeight: CGFloat = 60
        
        /// Navigation bar height (system standard)
        static let navigationBarHeight: CGFloat = 44
        
        /// Tab bar height (system standard)
        static let tabBarHeight: CGFloat = 49
    }
    
    // MARK: - Animation System
    
    struct Animation {
        
        /// Quick animations for immediate feedback
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        
        /// Standard animations for most UI changes
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        
        /// Smooth animations for page transitions
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.4)
        
        /// Slow animations for emphasis
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.6)
        
        /// Spring animations for playful interactions
        static let spring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.7)
        
        /// Bouncy spring for success states
        static let bouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
        
        /// Button press animation
        static let buttonPress = SwiftUI.Animation.easeInOut(duration: 0.15)
    }
    
    // MARK: - Shadow System
    
    struct Shadow {
        
        /// Light shadow for subtle elevation
        static let light = (
            color: Color.black.opacity(0.05),
            radius: CGFloat(4),
            x: CGFloat(0),
            y: CGFloat(2)
        )
        
        /// Medium shadow for cards and buttons
        static let medium = (
            color: Color.black.opacity(0.1),
            radius: CGFloat(8),
            x: CGFloat(0),
            y: CGFloat(4)
        )
        
        /// Heavy shadow for modals and overlays
        static let heavy = (
            color: Color.black.opacity(0.15),
            radius: CGFloat(16),
            x: CGFloat(0),
            y: CGFloat(8)
        )
        
        /// Brand shadow with brand color tint
        static let brand = (
            color: Color.brandPrimary.opacity(0.2),
            radius: CGFloat(12),
            x: CGFloat(0),
            y: CGFloat(6)
        )
    }
}

// MARK: - View Extensions for Design System

extension View {
    
    // MARK: - Typography Modifiers
    
    func displayLarge() -> some View {
        self.font(DesignSystem.Typography.displayLarge)
    }
    
    func displayMedium() -> some View {
        self.font(DesignSystem.Typography.displayMedium)
    }
    
    func displaySmall() -> some View {
        self.font(DesignSystem.Typography.displaySmall)
    }
    
    func headlineLarge() -> some View {
        self.font(DesignSystem.Typography.headlineLarge)
    }
    
    func headlineMedium() -> some View {
        self.font(DesignSystem.Typography.headlineMedium)
    }
    
    func headlineSmall() -> some View {
        self.font(DesignSystem.Typography.headlineSmall)
    }
    
    func titleLarge() -> some View {
        self.font(DesignSystem.Typography.titleLarge)
    }
    
    func titleMedium() -> some View {
        self.font(DesignSystem.Typography.titleMedium)
    }
    
    func titleSmall() -> some View {
        self.font(DesignSystem.Typography.titleSmall)
    }
    
    func bodyLarge() -> some View {
        self.font(DesignSystem.Typography.bodyLarge)
    }
    
    func bodyMedium() -> some View {
        self.font(DesignSystem.Typography.bodyMedium)
    }
    
    func bodySmall() -> some View {
        self.font(DesignSystem.Typography.bodySmall)
    }
    
    func labelLarge() -> some View {
        self.font(DesignSystem.Typography.labelLarge)
    }
    
    func labelMedium() -> some View {
        self.font(DesignSystem.Typography.labelMedium)
    }
    
    func labelSmall() -> some View {
        self.font(DesignSystem.Typography.labelSmall)
    }
    
    func captionLarge() -> some View {
        self.font(DesignSystem.Typography.captionLarge)
    }
    
    func captionMedium() -> some View {
        self.font(DesignSystem.Typography.captionMedium)
    }
    
    func captionSmall() -> some View {
        self.font(DesignSystem.Typography.captionSmall)
    }
    
    // MARK: - Spacing Modifiers
    
    func contentPadding() -> some View {
        self.padding(DesignSystem.Spacing.contentPadding)
    }
    
    func screenPadding() -> some View {
        self.padding(.horizontal, DesignSystem.Spacing.screenPadding)
    }
    
    func cardPadding() -> some View {
        self.padding(DesignSystem.Spacing.cardPadding)
    }
    
    func sectionSpacing() -> some View {
        self.padding(.vertical, DesignSystem.Spacing.sectionSpacing)
    }
    
    func componentSpacing() -> some View {
        self.padding(.vertical, DesignSystem.Spacing.componentSpacing)
    }
    
    func elementSpacing() -> some View {
        self.padding(.vertical, DesignSystem.Spacing.elementSpacing)
    }
    
    // MARK: - Shadow Modifiers
    
    func lightShadow() -> some View {
        let shadow = DesignSystem.Shadow.light
        return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    func mediumShadow() -> some View {
        let shadow = DesignSystem.Shadow.medium
        return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    func heavyShadow() -> some View {
        let shadow = DesignSystem.Shadow.heavy
        return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    func brandShadow() -> some View {
        let shadow = DesignSystem.Shadow.brand
        return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    // MARK: - Layout Modifiers
    
    func standardButtonHeight() -> some View {
        self.frame(height: DesignSystem.Layout.buttonHeight)
    }
    
    func standardInputHeight() -> some View {
        self.frame(height: DesignSystem.Layout.inputHeight)
    }
    
    func maxContentWidth() -> some View {
        self.frame(maxWidth: DesignSystem.Layout.maxContentWidth)
    }
    
    func minTouchTarget() -> some View {
        self.frame(minWidth: DesignSystem.Layout.minTouchTarget, minHeight: DesignSystem.Layout.minTouchTarget)
    }
}

// MARK: - Preview

#Preview("Design System Typography") {
    ScrollView {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Group {
                Text("Display Large")
                    .displayLarge()
                    .foregroundColor(.brandPrimary)
                
                Text("Display Medium")
                    .displayMedium()
                    .foregroundColor(.brandPrimary)
                
                Text("Display Small")
                    .displaySmall()
                    .foregroundColor(.brandPrimary)
            }
            
            Divider()
            
            Group {
                Text("Headline Large")
                    .headlineLarge()
                
                Text("Headline Medium")
                    .headlineMedium()
                
                Text("Headline Small")
                    .headlineSmall()
            }
            
            Divider()
            
            Group {
                Text("Title Large")
                    .titleLarge()
                
                Text("Title Medium")
                    .titleMedium()
                
                Text("Title Small")
                    .titleSmall()
            }
            
            Divider()
            
            Group {
                Text("Body Large - Lorem ipsum dolor sit amet, consectetur adipiscing elit.")
                    .bodyLarge()
                
                Text("Body Medium - Lorem ipsum dolor sit amet, consectetur adipiscing elit.")
                    .bodyMedium()
                
                Text("Body Small - Lorem ipsum dolor sit amet, consectetur adipiscing elit.")
                    .bodySmall()
            }
            
            Divider()
            
            Group {
                Text("Label Large")
                    .labelLarge()
                
                Text("Label Medium")
                    .labelMedium()
                
                Text("Label Small")
                    .labelSmall()
            }
            
            Divider()
            
            Group {
                Text("Caption Large")
                    .captionLarge()
                    .foregroundColor(.secondary)
                
                Text("Caption Medium")
                    .captionMedium()
                    .foregroundColor(.secondary)
                
                Text("Caption Small")
                    .captionSmall()
                    .foregroundColor(.secondary)
            }
        }
        .screenPadding()
    }
}

#Preview("Design System Spacing") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        Text("Spacing System")
            .headlineMedium()
        
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Rectangle()
                    .fill(Color.brandPrimary)
                    .frame(width: DesignSystem.Spacing.xs, height: 20)
                Text("XS - \(Int(DesignSystem.Spacing.xs))pt")
                    .labelMedium()
            }
            
            HStack {
                Rectangle()
                    .fill(Color.brandPrimary)
                    .frame(width: DesignSystem.Spacing.sm, height: 20)
                Text("SM - \(Int(DesignSystem.Spacing.sm))pt")
                    .labelMedium()
            }
            
            HStack {
                Rectangle()
                    .fill(Color.brandPrimary)
                    .frame(width: DesignSystem.Spacing.md, height: 20)
                Text("MD - \(Int(DesignSystem.Spacing.md))pt")
                    .labelMedium()
            }
            
            HStack {
                Rectangle()
                    .fill(Color.brandPrimary)
                    .frame(width: DesignSystem.Spacing.lg, height: 20)
                Text("LG - \(Int(DesignSystem.Spacing.lg))pt")
                    .labelMedium()
            }
            
            HStack {
                Rectangle()
                    .fill(Color.brandPrimary)
                    .frame(width: DesignSystem.Spacing.xl, height: 20)
                Text("XL - \(Int(DesignSystem.Spacing.xl))pt")
                    .labelMedium()
            }
            
            HStack {
                Rectangle()
                    .fill(Color.brandPrimary)
                    .frame(width: DesignSystem.Spacing.xxl, height: 20)
                Text("XXL - \(Int(DesignSystem.Spacing.xxl))pt")
                    .labelMedium()
            }
        }
    }
    .screenPadding()
}

#Preview("Design System Shadows") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        Text("Shadow System")
            .headlineMedium()
        
        HStack(spacing: DesignSystem.Spacing.lg) {
            VStack {
                Rectangle()
                    .fill(Color(.systemBackground))
                    .frame(width: 80, height: 80)
                    .cornerRadius(BrandStyle.cornerRadius)
                    .lightShadow()
                
                Text("Light")
                    .labelMedium()
            }
            
            VStack {
                Rectangle()
                    .fill(Color(.systemBackground))
                    .frame(width: 80, height: 80)
                    .cornerRadius(BrandStyle.cornerRadius)
                    .mediumShadow()
                
                Text("Medium")
                    .labelMedium()
            }
            
            VStack {
                Rectangle()
                    .fill(Color(.systemBackground))
                    .frame(width: 80, height: 80)
                    .cornerRadius(BrandStyle.cornerRadius)
                    .heavyShadow()
                
                Text("Heavy")
                    .labelMedium()
            }
            
            VStack {
                Rectangle()
                    .fill(Color(.systemBackground))
                    .frame(width: 80, height: 80)
                    .cornerRadius(BrandStyle.cornerRadius)
                    .brandShadow()
                
                Text("Brand")
                    .labelMedium()
            }
        }
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
}