import SwiftUI

enum NotificationTheme {
    static let background = Color(red: 0.972, green: 0.980, blue: 0.988)
    static let card = Color.white
    static let primary = Color(red: 0.388, green: 0.400, blue: 0.945)
    static let textPrimary = Color(red: 0.122, green: 0.161, blue: 0.216)
    static let textSecondary = Color(red: 0.420, green: 0.447, blue: 0.502)
    static let success = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let warning = Color(red: 0.961, green: 0.620, blue: 0.043)
    static let danger = Color(red: 0.880, green: 0.160, blue: 0.240)
}

enum NotificationType: String, CaseIterable, Identifiable {
    case runStarting
    case driverArrived
    case late
    case runCreated
    case runCancelled

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .runStarting:
            return "Run starting"
        case .driverArrived:
            return "Driver arrived"
        case .late:
            return "Late"
        case .runCreated:
            return "Run created"
        case .runCancelled:
            return "Run cancelled"
        }
    }

    var iconName: String {
        switch self {
        case .runStarting:
            return "play.circle.fill"
        case .driverArrived:
            return "car.fill"
        case .late:
            return "clock.badge.exclamationmark.fill"
        case .runCreated:
            return "calendar.badge.plus"
        case .runCancelled:
            return "xmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .runStarting, .runCreated:
            return NotificationTheme.primary
        case .driverArrived:
            return NotificationTheme.success
        case .late:
            return NotificationTheme.warning
        case .runCancelled:
            return NotificationTheme.danger
        }
    }
}

enum NotificationsFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case unread = "Unread"

    var id: String { rawValue }
}

struct NotificationInboxItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let time: String
    let type: NotificationType
    var isUnread: Bool
}

struct ContactShortcut: Identifiable {
    let id: UUID
    let role: String
    let name: String
    let phone: String

    var telURL: URL? {
        let digits = phone.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://\(digits)")
    }
}

enum NotificationMockData {
    static let inboxItems: [NotificationInboxItem] = [
        NotificationInboxItem(
            id: UUID(),
            title: "Run starting",
            subtitle: "Morning school run starts in 15 minutes.",
            time: "7:10 AM",
            type: .runStarting,
            isUnread: true
        ),
        NotificationInboxItem(
            id: UUID(),
            title: "Driver arrived",
            subtitle: "Alex is waiting at the front gate.",
            time: "7:28 AM",
            type: .driverArrived,
            isUnread: true
        ),
        NotificationInboxItem(
            id: UUID(),
            title: "Late",
            subtitle: "Traffic delay detected. ETA +12 minutes.",
            time: "8:02 AM",
            type: .late,
            isUnread: false
        ),
        NotificationInboxItem(
            id: UUID(),
            title: "Run created",
            subtitle: "New pickup run added for Thursday.",
            time: "Yesterday",
            type: .runCreated,
            isUnread: false
        ),
        NotificationInboxItem(
            id: UUID(),
            title: "Run cancelled",
            subtitle: "Evening run cancelled by organizer.",
            time: "Yesterday",
            type: .runCancelled,
            isUnread: false
        )
    ]

    static let driverContacts: [ContactShortcut] = [
        ContactShortcut(id: UUID(), role: "Driver", name: "Alex Rivera", phone: "+1 (555) 010-2333")
    ]

    static let parentContacts: [ContactShortcut] = [
        ContactShortcut(id: UUID(), role: "Parent", name: "Jordan Lee", phone: "+1 (555) 010-8452"),
        ContactShortcut(id: UUID(), role: "Parent", name: "Sam Patel", phone: "+1 (555) 010-7841")
    ]
}

struct NotificationStitchCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(NotificationTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 6)
    }
}

struct NotificationSectionHeading: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(NotificationTheme.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(NotificationTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NotificationInboxCard: View {
    let item: NotificationInboxItem

    var body: some View {
        NotificationStitchCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.type.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(item.type.tint)
                    .frame(width: 34, height: 34)
                    .background(item.type.tint.opacity(0.14))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NotificationTheme.textPrimary)
                            .lineLimit(1)

                        if item.isUnread {
                            Circle()
                                .fill(NotificationTheme.primary)
                                .frame(width: 8, height: 8)
                                .accessibilityLabel("Unread")
                        }

                        Spacer(minLength: 8)

                        Text(item.time)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(NotificationTheme.textSecondary)
                    }

                    Text(item.subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(NotificationTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct NotificationToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NotificationTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(NotificationTheme.textSecondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(NotificationTheme.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            isOn.toggle()
        }
    }
}

struct QuickContactButton: View {
    let contact: ContactShortcut
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(NotificationTheme.primary)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.role)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NotificationTheme.textSecondary)
                    Text(contact.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(NotificationTheme.textPrimary)
                    Text(contact.phone)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(NotificationTheme.textSecondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NotificationTheme.textSecondary.opacity(0.7))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NotificationTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Call \(contact.role) \(contact.name)")
    }
}
