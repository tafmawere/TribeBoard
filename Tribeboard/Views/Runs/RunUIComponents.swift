import SwiftUI

enum RunStitchTheme {
    static let background = Color(red: 0.976, green: 0.980, blue: 0.984)
    static let card = Color.white
    static let indigo = Color(red: 0.388, green: 0.400, blue: 0.945)
    static let textPrimary = Color(red: 0.122, green: 0.161, blue: 0.216)
    static let textSecondary = Color(red: 0.420, green: 0.447, blue: 0.502)
    static let success = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let warning = Color(red: 0.961, green: 0.620, blue: 0.043)
    static let danger = Color(red: 0.880, green: 0.160, blue: 0.240)
}

struct StitchCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(RunStitchTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
    }
}

struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(RunStitchTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        AppBadge(text: text, style: badgeStyle)
            .accessibilityLabel("Status \(text)")
    }

    private var badgeStyle: BadgeStyle {
        let normalized = text.lowercased()
        if normalized.contains("complete") || normalized.contains("done") {
            return .success
        }
        if normalized.contains("cancel") || normalized.contains("fail") {
            return .warning
        }
        if normalized.contains("live") || normalized.contains("active") {
            return .live
        }
        return .info
    }
}

struct RoleChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(RunStitchTheme.indigo)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(minHeight: 44)
        .accessibilityLabel(title)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(RunStitchTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.gray.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(minHeight: 44)
        .accessibilityLabel(title)
    }
}

struct DestructiveButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(RunStitchTheme.danger)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(RunStitchTheme.danger.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(minHeight: 44)
        .accessibilityLabel(title)
    }
}

struct TimelineRow: View {
    let event: RunDetailsData.UITimelineEvent
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Image(systemName: event.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colorForSeverity(event.severity))
                    .frame(width: 24, height: 24)
                    .background(colorForSeverity(event.severity).opacity(0.14))
                    .clipShape(Circle())

                if !isLast {
                    Rectangle()
                        .fill(Color.gray.opacity(0.30))
                        .frame(width: 2, height: 24)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RunStitchTheme.textPrimary)
                    Spacer()
                    Text(event.timeString)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RunStitchTheme.textSecondary)
                }
                Text(event.detail)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(RunStitchTheme.textSecondary)
            }
        }
    }

    private func colorForSeverity(_ severity: RunDetailsData.EventSeverity) -> Color {
        switch severity {
        case .normal:
            return RunStitchTheme.indigo
        case .warn:
            return RunStitchTheme.warning
        case .success:
            return RunStitchTheme.success
        }
    }
}
