import SwiftUI

/// Reusable empty state view for when there's no content to display
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(.brandPrimary.opacity(0.6))
            
            // Content
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            // Action button
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 200)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Specific empty states for common scenarios
extension EmptyStateView {
    
    /// Empty state for when no family members are found
    static func noMembers(onInvite: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "person.3",
            title: "No Family Members",
            message: "Your family is just getting started. Invite family members to join and start organizing together.",
            actionTitle: "Invite Members",
            action: onInvite
        )
    }
    
    /// Empty state for when no families are found during search
    static func noFamiliesFound(onRetry: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No Families Found",
            message: "We couldn't find any families with that code. Double-check the code and try again.",
            actionTitle: "Try Again",
            action: onRetry
        )
    }
    
    /// Empty state for network connectivity issues
    static func networkError(onRetry: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "wifi.slash",
            title: "Connection Problem",
            message: "Unable to connect to the internet. Check your connection and try again.",
            actionTitle: "Retry",
            action: onRetry
        )
    }
    
    /// Empty state for when user needs to create or join a family
    static func noFamily(onCreate: @escaping () -> Void, onJoin: @escaping () -> Void) -> some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "house")
                .font(.system(size: 64))
                .foregroundColor(.brandPrimary.opacity(0.6))
            
            // Content
            VStack(spacing: 12) {
                Text("Welcome to TribeBoard")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Get started by creating a new family or joining an existing one.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            // Action buttons
            VStack(spacing: 12) {
                Button("Create Family", action: onCreate)
                    .buttonStyle(PrimaryButtonStyle())
                
                Button("Join Family", action: onJoin)
                    .buttonStyle(SecondaryButtonStyle())
            }
            .frame(maxWidth: 200)
        }
        .padding(32)
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