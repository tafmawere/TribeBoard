import SwiftUI

/// Shopping view placeholder for shopping navigation
struct ShoppingView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                // Header section
                VStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.brandPrimary)
                        .accessibilityHidden(true)
                    
                    Text("Shopping")
                        .headlineLarge()
                        .foregroundColor(.primary)
                    
                    Text("Family shopping lists and coordination")
                        .bodyMedium()
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DesignSystem.Spacing.xl)
                
                Spacer()
                
                // Placeholder content
                VStack(spacing: DesignSystem.Spacing.lg) {
                    EmptyStateView(
                        icon: "cart.badge.plus",
                        title: "Shopping Lists Coming Soon",
                        message: "Create and share shopping lists with your family members.",
                        actionTitle: "Learn More",
                        action: {
                            // Placeholder action
                        }
                    )
                }
                
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .navigationTitle("Shopping")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Shopping view")
        .accessibilityHint("View and manage family shopping lists")
    }
}

// MARK: - Preview

#Preview("Shopping View") {
    ShoppingView()
        .environmentObject(AppState())
}

#Preview("Shopping View - Dark Mode") {
    ShoppingView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}

#Preview("Shopping View - Large Text") {
    ShoppingView()
        .environmentObject(AppState())
        .environment(\.sizeCategory, .extraExtraExtraLarge)
}