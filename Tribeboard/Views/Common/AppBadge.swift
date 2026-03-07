import SwiftUI

enum BadgeStyle {
    case scheduled
    case pending
    case enRoute
    case completed
    case cancelled
    case overdue
    case info
    case success
    case warning
    case neutral
    case live

    fileprivate var foreground: Color {
        switch self {
        case .scheduled: return Color(red: 0.36, green: 0.22, blue: 0.72) // purple
        case .pending: return Color(red: 0.36, green: 0.39, blue: 0.45) // gray
        case .enRoute: return Color(red: 0.10, green: 0.42, blue: 0.82) // blue
        case .completed: return Color(red: 0.07, green: 0.56, blue: 0.36) // green
        case .cancelled: return Color(red: 0.42, green: 0.44, blue: 0.49) // muted gray
        case .overdue: return Color(red: 0.72, green: 0.15, blue: 0.18) // red
        case .info: return Color(red: 0.286, green: 0.357, blue: 0.769)
        case .success: return Color(red: 0.071, green: 0.557, blue: 0.361)
        case .warning: return Color(red: 0.667, green: 0.467, blue: 0.067)
        case .neutral: return Color(red: 0.345, green: 0.392, blue: 0.478)
        case .live: return Color(red: 0.694, green: 0.102, blue: 0.176)
        }
    }

    fileprivate var background: Color {
        switch self {
        case .scheduled: return Color(red: 0.56, green: 0.42, blue: 0.90).opacity(0.16)
        case .pending: return Color.black.opacity(0.08)
        case .enRoute: return Color(red: 0.17, green: 0.51, blue: 0.96).opacity(0.16)
        case .completed: return Color(red: 0.06, green: 0.73, blue: 0.50).opacity(0.14)
        case .cancelled: return Color.black.opacity(0.07)
        case .overdue: return Color(red: 0.95, green: 0.27, blue: 0.30).opacity(0.16)
        case .info: return Color(red: 0.388, green: 0.400, blue: 0.945).opacity(0.11)
        case .success: return Color(red: 0.063, green: 0.725, blue: 0.506).opacity(0.12)
        case .warning: return Color(red: 0.961, green: 0.620, blue: 0.043).opacity(0.14)
        case .neutral: return Color.black.opacity(0.08)
        case .live: return Color(red: 0.957, green: 0.176, blue: 0.251).opacity(0.14)
        }
    }
}

struct AppBadge: View {
    let text: String
    let style: BadgeStyle
    var icon: String? = nil
    var uppercased: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(uppercased ? text.uppercased() : text)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(style.foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(style.background)
        .clipShape(Capsule())
        .accessibilityLabel(text)
    }
}

extension AppBadge {
    static var setupRequired: AppBadge {
        AppBadge(text: "Setup Required", style: .warning, icon: "exclamationmark.circle.fill", uppercased: false)
    }
}
