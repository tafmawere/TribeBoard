import SwiftUI

enum CalendarUITheme {
    static let offWhite = Color(red: 0.976, green: 0.980, blue: 0.984) // #F9FAFB
    static let cardWhite = Color.white
    static let indigo = Color(red: 0.388, green: 0.400, blue: 0.945) // #6366F1
    static let textPrimary = Color(red: 0.122, green: 0.161, blue: 0.216) // #1F2937
    static let textSecondary = Color(red: 0.420, green: 0.447, blue: 0.502) // #6B7280
    static let success = Color(red: 0.063, green: 0.725, blue: 0.506) // #10B981
    static let warning = Color(red: 0.961, green: 0.620, blue: 0.043) // #F59E0B
}

struct CalendarCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(CalendarUITheme.cardWhite)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
    }
}

struct CalendarBadge: View {
    let text: String
    let color: Color

    var body: some View {
        AppBadge(text: text, style: badgeStyle)
    }

    private var badgeStyle: BadgeStyle {
        text.lowercased().contains("created") ? .success : .info
    }
}

struct CalendarChip: View {
    let text: String
    let selected: Bool
    let action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) { chipBody }
                    .buttonStyle(.plain)
            } else {
                chipBody
            }
        }
    }

    private var chipBody: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(selected ? .white : CalendarUITheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(selected ? CalendarUITheme.indigo : Color.gray.opacity(0.12))
            .clipShape(Capsule())
            .frame(minHeight: 28)
    }
}

struct CalendarDayCell: View {
    let dayNumber: Int?
    let isToday: Bool
    let isSelected: Bool
    let hasOccurrences: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(dayNumber.map(String.init) ?? "")
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(textColor)
                    .frame(width: 30, height: 30)
                    .background(isSelected ? CalendarUITheme.indigo.opacity(0.20) : .clear)
                    .overlay {
                        Circle()
                            .stroke(
                                isToday ? CalendarUITheme.indigo.opacity(0.5) : .clear,
                                lineWidth: isToday ? 1.2 : 0
                            )
                    }
                    .clipShape(Circle())

                Circle()
                    .fill(hasOccurrences ? CalendarUITheme.warning : Color.clear)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(dayNumber == nil)
        .accessibilityLabel(accessibilityLabel)
    }

    private var textColor: Color {
        if dayNumber == nil { return .clear }
        if isSelected { return CalendarUITheme.indigo }
        if isToday { return CalendarUITheme.indigo }
        return CalendarUITheme.textPrimary
    }

    private var accessibilityLabel: String {
        guard let dayNumber else { return "Empty day" }
        return hasOccurrences ? "Day \(dayNumber), has schedules" : "Day \(dayNumber)"
    }
}

struct CalendarOccurrenceCard: View {
    let title: String
    let time: String
    let driver: String
    let passengers: [String]
    let isCreated: Bool
    let subtitle: String
    let onTap: () -> Void
    let onCreateRunNow: () -> Void
    var showsCreateAction = true
    var isCompact = false

    var body: some View {
        Button(action: onTap) {
            CalendarCard {
                VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
                    HStack {
                        Text(title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(CalendarUITheme.textPrimary)
                        Spacer()
                        CalendarBadge(
                            text: isCreated ? "Created" : "Scheduled",
                            color: isCreated ? CalendarUITheme.success : CalendarUITheme.indigo
                        )
                    }

                    Text(time)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CalendarUITheme.textSecondary)

                    Text("Driver: \(driver)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(CalendarUITheme.textSecondary)

                    if !isCompact {
                        HStack(spacing: 6) {
                            ForEach(passengers, id: \.self) { passenger in
                                CalendarChip(text: initials(passenger), selected: false, action: nil)
                            }
                        }
                    }

                    if !isCompact {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(CalendarUITheme.textSecondary)
                    }

                    if showsCreateAction {
                        Button {
                            onCreateRunNow()
                        } label: {
                            Text(isCreated ? "Run Created" : "Create Run Now")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(isCreated ? CalendarUITheme.success : CalendarUITheme.indigo)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Create Run Now")
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}
