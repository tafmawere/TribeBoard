import SwiftUI

enum SafetyTheme {
    static let background = Color(red: 0.976, green: 0.980, blue: 0.984)
    static let card = Color.white
    static let tint = Color(red: 0.388, green: 0.400, blue: 0.945)
    static let textPrimary = Color(red: 0.122, green: 0.161, blue: 0.216)
    static let textSecondary = Color(red: 0.420, green: 0.447, blue: 0.502)
    static let success = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let warning = Color(red: 0.961, green: 0.620, blue: 0.043)
    static let danger = Color(red: 0.880, green: 0.160, blue: 0.240)
}

struct SafetyCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(SafetyTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
    }
}

struct SafetySectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(SafetyTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SafetyInfoCard: View {
    let iconName: String
    let title: String
    let detail: String
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 30, height: 30)
                .background(accent.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SafetyTheme.textPrimary)
                Text(detail)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(SafetyTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct SafetyBadge: View {
    let text: String
    let color: Color

    var body: some View {
        AppBadge(text: text, style: badgeStyle)
    }

    private var badgeStyle: BadgeStyle {
        let normalized = text.lowercased()
        if normalized.contains("alert") || normalized.contains("warning") {
            return .warning
        }
        if normalized.contains("ok") || normalized.contains("enabled") {
            return .success
        }
        return .info
    }
}

struct SafetyChip: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : SafetyTheme.tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isSelected ? SafetyTheme.tint : SafetyTheme.tint.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct SafetyPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(SafetyTheme.tint)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SafetySecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SafetyTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.gray.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
