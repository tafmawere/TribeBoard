import SwiftUI

/// Reusable badge component for displaying run status with color coding
struct RunStatusBadge: View {
    let status: RunStatus
    let style: BadgeStyle
    
    enum BadgeStyle {
        case standard
        case compact
        case large
        case minimal
    }
    
    init(status: RunStatus, style: BadgeStyle = .standard) {
        self.status = status
        self.style = style
    }
    
    var body: some View {
        HStack(spacing: spacingForStyle) {
            // Status icon
            if showIcon {
                Image(systemName: status.icon)
                    .font(iconFontForStyle)
                    .foregroundColor(status.foregroundColor)
            }
            
            // Status text
            if showText {
                Text(status.displayText)
                    .font(textFontForStyle)
                    .foregroundColor(status.foregroundColor)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, horizontalPaddingForStyle)
        .padding(.vertical, verticalPaddingForStyle)
        .background(backgroundForStyle)
        .cornerRadius(cornerRadiusForStyle)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadiusForStyle)
                .stroke(borderColorForStyle, lineWidth: borderWidthForStyle)
        )
        // Enhanced accessibility support
        .statusBadgeAccessibility(status: status)
        .highContrastSupport(
            normalColor: status.foregroundColor,
            highContrastColor: status.foregroundColor
        )
        .dynamicTypeSupport(minSize: 8, maxSize: 24)
    }
    
    // MARK: - Style Properties
    
    private var showIcon: Bool {
        switch style {
        case .minimal:
            return false
        default:
            return true
        }
    }
    
    private var showText: Bool {
        true
    }
    
    private var spacingForStyle: CGFloat {
        switch style {
        case .compact, .minimal:
            return DesignSystem.Spacing.xs
        case .standard:
            return DesignSystem.Spacing.sm
        case .large:
            return DesignSystem.Spacing.md
        }
    }
    
    private var iconFontForStyle: Font {
        switch style {
        case .compact, .minimal:
            return DesignSystem.Typography.captionLarge
        case .standard:
            return DesignSystem.Typography.labelMedium
        case .large:
            return DesignSystem.Typography.labelLarge
        }
    }
    
    private var textFontForStyle: Font {
        switch style {
        case .compact, .minimal:
            return DesignSystem.Typography.captionMedium
        case .standard:
            return DesignSystem.Typography.labelMedium
        case .large:
            return DesignSystem.Typography.labelLarge
        }
    }
    
    private var horizontalPaddingForStyle: CGFloat {
        switch style {
        case .compact, .minimal:
            return DesignSystem.Spacing.sm
        case .standard:
            return DesignSystem.Spacing.md
        case .large:
            return DesignSystem.Spacing.lg
        }
    }
    
    private var verticalPaddingForStyle: CGFloat {
        switch style {
        case .compact, .minimal:
            return DesignSystem.Spacing.xs
        case .standard:
            return DesignSystem.Spacing.sm
        case .large:
            return DesignSystem.Spacing.md
        }
    }
    
    private var cornerRadiusForStyle: CGFloat {
        switch style {
        case .compact, .minimal:
            return BrandStyle.cornerRadiusSmall
        case .standard:
            return BrandStyle.cornerRadiusSmall
        case .large:
            return BrandStyle.cornerRadius
        }
    }
    
    private var backgroundForStyle: Color {
        switch style {
        case .minimal:
            return Color.clear
        default:
            return status.backgroundColor
        }
    }
    
    private var borderColorForStyle: Color {
        switch style {
        case .minimal:
            return status.foregroundColor.opacity(0.3)
        default:
            return Color.clear
        }
    }
    
    private var borderWidthForStyle: CGFloat {
        switch style {
        case .minimal:
            return 1
        default:
            return 0
        }
    }
}

// MARK: - Animated Status Badge

struct AnimatedRunStatusBadge: View {
    let status: RunStatus
    let style: RunStatusBadge.BadgeStyle
    
    @State private var isAnimating = false
    
    init(status: RunStatus, style: RunStatusBadge.BadgeStyle = .standard) {
        self.status = status
        self.style = style
    }
    
    var body: some View {
        RunStatusBadge(status: status, style: style)
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .animation(
                status == .inProgress ? 
                    Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                    Animation.easeInOut(duration: 0.3),
                value: isAnimating
            )
            .onAppear {
                if status == .inProgress {
                    isAnimating = true
                }
            }
            .onChange(of: status) { _, newStatus in
                if newStatus == .inProgress {
                    isAnimating = true
                } else {
                    isAnimating = false
                }
            }
    }
}

// MARK: - Status Progress Badge

struct StatusProgressBadge: View {
    let status: RunStatus
    let progress: Double
    let style: RunStatusBadge.BadgeStyle
    
    init(status: RunStatus, progress: Double = 0.0, style: RunStatusBadge.BadgeStyle = .standard) {
        self.status = status
        self.progress = progress
        self.style = style
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            RunStatusBadge(status: status, style: style)
            
            if status == .inProgress && progress > 0 {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: status.color))
                        .frame(width: 60)
                        .scaleEffect(y: 0.8)
                    
                    Text("\(Int(progress * 100))%")
                        .captionSmall()
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Status Badge Variants") {
    ScrollView {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Standard badges for all statuses
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Standard Badges")
                    .headlineSmall()
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    ForEach(RunStatus.allCases, id: \.self) { status in
                        HStack {
                            RunStatusBadge(status: status, style: .standard)
                            Spacer()
                        }
                    }
                }
            }
            
            Divider()
            
            // Different styles for scheduled status
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Style Variants (Scheduled)")
                    .headlineSmall()
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("Large:")
                        RunStatusBadge(status: .scheduled, style: .large)
                        Spacer()
                    }
                    
                    HStack {
                        Text("Standard:")
                        RunStatusBadge(status: .scheduled, style: .standard)
                        Spacer()
                    }
                    
                    HStack {
                        Text("Compact:")
                        RunStatusBadge(status: .scheduled, style: .compact)
                        Spacer()
                    }
                    
                    HStack {
                        Text("Minimal:")
                        RunStatusBadge(status: .scheduled, style: .minimal)
                        Spacer()
                    }
                }
            }
            
            Divider()
            
            // Animated badges
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Animated Badges")
                    .headlineSmall()
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("In Progress (Animated):")
                        AnimatedRunStatusBadge(status: .inProgress, style: .standard)
                        Spacer()
                    }
                    
                    HStack {
                        Text("Completed (Static):")
                        AnimatedRunStatusBadge(status: .completed, style: .standard)
                        Spacer()
                    }
                }
            }
            
            Divider()
            
            // Progress badges
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Progress Badges")
                    .headlineSmall()
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    StatusProgressBadge(status: .inProgress, progress: 0.3, style: .standard)
                    StatusProgressBadge(status: .inProgress, progress: 0.7, style: .compact)
                    StatusProgressBadge(status: .completed, progress: 1.0, style: .standard)
                }
            }
        }
        .screenPadding()
    }
}