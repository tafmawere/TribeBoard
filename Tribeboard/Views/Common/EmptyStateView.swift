import SwiftUI

enum GeneralUXTheme {
    static let background = Color(red: 0.976, green: 0.980, blue: 0.984)
    static let card = Color.white
    static let primary = Color(red: 0.388, green: 0.400, blue: 0.945)
    static let textPrimary = Color(red: 0.122, green: 0.161, blue: 0.216)
    static let textSecondary = Color(red: 0.420, green: 0.447, blue: 0.502)
    static let border = Color.black.opacity(0.08)
    static let shadow = Color.black.opacity(0.06)
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let primaryButtonTitle: String
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(GeneralUXTheme.primary.opacity(0.14))
                .frame(width: 76, height: 76)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(GeneralUXTheme.primary)
                }

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(GeneralUXTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(GeneralUXTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 320)

            if let action {
                Button(primaryButtonTitle, action: action)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(GeneralUXTheme.primary)
                    .clipShape(Capsule())
                    .shadow(color: GeneralUXTheme.primary.opacity(0.20), radius: 8, x: 0, y: 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GeneralUXTheme.background)
    }
}

#Preview("Empty State") {
    EmptyStateView(
        icon: "magnifyingglass",
        title: "Nothing to show yet",
        message: "Once your family creates runs, they will appear here.",
        primaryButtonTitle: "Create Demo Run"
    ) {
        // UI-only action
    }
}
