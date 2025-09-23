import SwiftUI

/// Reusable empty state view for when there's no content to display
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    let style: EmptyStateStyle
    
    enum EmptyStateStyle {
        case standard
        case branded
        case minimal
        case illustrated
    }
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        style: EmptyStateStyle = .branded
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.style = style
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxl) {
            // Illustration section
            illustrationSection
            
            // Content section
            contentSection
            
            // Action section
            actionSection
        }
        .maxContentWidth()
        .screenPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Illustration Section
    
    @ViewBuilder
    private var illustrationSection: some View {
        switch style {
        case .standard:
            standardIllustration
        case .branded:
            brandedIllustration
        case .minimal:
            minimalIllustration
        case .illustrated:
            enhancedIllustration
        }
    }
    
    private var standardIllustration: some View {
        Image(systemName: icon)
            .font(.system(size: 64, weight: .light))
            .foregroundColor(.brandPrimary.opacity(0.6))
    }
    
    private var brandedIllustration: some View {
        ZStack {
            // Background circle with gradient
            Circle()
                .fill(LinearGradient.brandGradientSubtle)
                .frame(width: 120, height: 120)
            
            // Icon with brand styling
            Image(systemName: icon)
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(.brandPrimary)
        }
        .lightShadow()
    }
    
    private var minimalIllustration: some View {
        Image(systemName: icon)
            .font(.system(size: 40, weight: .regular))
            .foregroundColor(.secondary)
    }
    
    private var enhancedIllustration: some View {
        ZStack {
            // Animated background elements
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.brandPrimary.opacity(0.1 - Double(index) * 0.03))
                    .frame(width: CGFloat(140 + index * 20), height: CGFloat(140 + index * 20))
            }
            
            // Main illustration container
            ZStack {
                // Gradient background
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusLarge)
                    .fill(LinearGradient.brandGradient)
                    .frame(width: 100, height: 100)
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundColor(.white)
            }
            .mediumShadow()
        }
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text(title)
                .headlineSmall()
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text(message)
                .bodyMedium()
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
    }
    
    // MARK: - Action Section
    
    @ViewBuilder
    private var actionSection: some View {
        if let action = action, let actionTitle = actionTitle {
            Button(action: action) {
                Text(actionTitle)
                    .font(DesignSystem.Typography.buttonMedium)
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 280)
        }
    }
}

/// Specific empty states for common scenarios
extension EmptyStateView {
    
    /// Empty state for when no family members are found
    static func noMembers(onInvite: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "person.3.fill",
            title: "No Family Members Yet",
            message: "Your family is just getting started! Invite family members to join and start organizing together.",
            actionTitle: "Invite Members",
            action: onInvite,
            style: .branded
        )
    }
    
    /// Empty state for when no families are found during search
    static func noFamiliesFound(onRetry: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass.circle",
            title: "No Families Found",
            message: "We couldn't find any families with that code. Double-check the code and try again.",
            actionTitle: "Try Again",
            action: onRetry,
            style: .illustrated
        )
    }
    
    /// Empty state for network connectivity issues
    static func networkError(onRetry: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "wifi.slash",
            title: "Connection Problem",
            message: "Unable to connect to the internet. Check your connection and try again.",
            actionTitle: "Retry",
            action: onRetry,
            style: .standard
        )
    }
    
    /// Empty state for calendar with no events
    static func noEvents(onAddEvent: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "calendar.badge.plus",
            title: "No Events Scheduled",
            message: "Your family calendar is empty. Add events, birthdays, and activities to keep everyone organized.",
            actionTitle: "Add Event",
            action: onAddEvent,
            style: .branded
        )
    }
    
    /// Empty state for tasks with no assignments
    static func noTasks(onAddTask: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "checklist",
            title: "No Tasks Assigned",
            message: "No tasks or chores have been assigned yet. Create tasks to help organize family responsibilities.",
            actionTitle: "Add Task",
            action: onAddTask,
            style: .branded
        )
    }
    
    /// Empty state for messages with no conversations
    static func noMessages(onStartChat: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "message.fill",
            title: "No Messages Yet",
            message: "Start conversations with your family members to stay connected and share updates.",
            actionTitle: "Start Chatting",
            action: onStartChat,
            style: .branded
        )
    }
    
    /// Empty state for school runs with no schedules
    static func noSchoolRuns(onAddRun: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "car.fill",
            title: "No School Runs Scheduled",
            message: "Set up pickup and drop-off schedules to coordinate school transportation with your family.",
            actionTitle: "Add School Run",
            action: onAddRun,
            style: .branded
        )
    }
    
    /// Empty state for when user needs to create or join a family
    static func noFamily(onCreate: @escaping () -> Void, onJoin: @escaping () -> Void) -> some View {
        VStack(spacing: DesignSystem.Spacing.xxl) {
            // Enhanced illustration
            ZStack {
                // Background gradient circle
                Circle()
                    .fill(LinearGradient.brandGradientSubtle)
                    .frame(width: 140, height: 140)
                
                // House icon with family context
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(.brandPrimary)
                    
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle()
                                .fill(Color.brandSecondary)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .lightShadow()
            
            // Content
            VStack(spacing: DesignSystem.Spacing.md) {
                Text("Welcome to TribeBoard")
                    .headlineSmall()
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Get started by creating a new family or joining an existing one to begin organizing together.")
                    .bodyMedium()
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            .maxContentWidth()
            
            // Action buttons
            VStack(spacing: DesignSystem.Spacing.md) {
                Button("Create Family", action: onCreate)
                    .buttonStyle(PrimaryButtonStyle())
                
                Button("Join Family", action: onJoin)
                    .buttonStyle(SecondaryButtonStyle())
            }
            .frame(maxWidth: 280)
        }
        .screenPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("Empty Members") {
    EmptyStateView.noMembers(onInvite: {})
}

#Preview("No Families Found") {
    EmptyStateView.noFamiliesFound(onRetry: {})
}

#Preview("Network Error") {
    EmptyStateView.networkError(onRetry: {})
}

#Preview("No Family") {
    EmptyStateView.noFamily(onCreate: {}, onJoin: {})
}