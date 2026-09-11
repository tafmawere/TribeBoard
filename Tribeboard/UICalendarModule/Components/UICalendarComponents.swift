import SwiftUI

struct UICalendarCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(UICalendarDesignSystem.Spacing.medium)
            .background(UICalendarDesignSystem.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: UICalendarDesignSystem.Radius.large, style: .continuous))
            .shadow(
                color: UICalendarDesignSystem.Shadow.color,
                radius: UICalendarDesignSystem.Shadow.radius,
                x: 0,
                y: UICalendarDesignSystem.Shadow.y
            )
    }
}

struct UICalendarPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(UICalendarDesignSystem.Colors.primary)
                .clipShape(Capsule())
        }
    }
}

struct UICalendarSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(UICalendarDesignSystem.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.05))
                .clipShape(Capsule())
        }
    }
}

struct UICalendarChip: View {
    let text: String
    let isSelected: Bool
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
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isSelected ? .white : UICalendarDesignSystem.Colors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? UICalendarDesignSystem.Colors.primary : Color.black.opacity(0.05))
            .clipShape(Capsule())
    }
}

struct UICalendarBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }
}

struct UIDayCell: View {
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
                    .background(isSelected ? UICalendarDesignSystem.Colors.primary : (isToday ? UICalendarDesignSystem.Colors.primary.opacity(0.14) : Color.clear))
                    .clipShape(Circle())

                Circle()
                    .fill(hasOccurrences ? UICalendarDesignSystem.Colors.warning : Color.clear)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .disabled(dayNumber == nil)
    }

    private var textColor: Color {
        if dayNumber == nil { return .clear }
        if isSelected { return .white }
        if isToday { return UICalendarDesignSystem.Colors.primary }
        return UICalendarDesignSystem.Colors.textPrimary
    }
}

struct UIOccurrenceCard: View {
    let occurrence: UIScheduleOccurrence
    let onCreateRunNow: () -> Void
    let onViewSchedule: () -> Void

    @EnvironmentObject private var authSession: AuthSessionContext

    var body: some View {
        UICalendarCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(occurrence.title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(UICalendarDesignSystem.Colors.textPrimary)
                    Spacer()
                    statusBadge
                }

                Text(timeText(occurrence.dateTime))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(UICalendarDesignSystem.Colors.textSecondary)

                Text("Driver: \(occurrence.driver.name)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(UICalendarDesignSystem.Colors.textSecondary)

                HStack(spacing: 6) {
                    Text("\(occurrence.passengers.count) passengers")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(UICalendarDesignSystem.Colors.textTertiary)
                    HStack(spacing: -6) {
                        ForEach(occurrence.passengers) { user in
                            TribeAvatarView(
                                identity: TribeAvatarIdentity(displayName: user.name),
                                size: .compact,
                                accessToken: authSession.currentAccessToken
                            )
                        }
                    }
                }

                HStack(spacing: 10) {
                    UICalendarPrimaryButton(title: "Create Run Now", action: onCreateRunNow)
                    UICalendarSecondaryButton(title: "View Schedule", action: onViewSchedule)
                }
            }
        }
    }

    private var statusBadge: some View {
        UICalendarBadge(
            text: occurrence.hasMaterializedRun ? "Run Created" : "Scheduled Template",
            color: occurrence.hasMaterializedRun ? UICalendarDesignSystem.Colors.success : UICalendarDesignSystem.Colors.primary
        )
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

struct UIScheduleRow: View {
    let schedule: UISchedule
    @Binding var isEnabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            UICalendarCard {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(schedule.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(UICalendarDesignSystem.Colors.textPrimary)
                        Text(recurrenceText(schedule.recurrence))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(UICalendarDesignSystem.Colors.textSecondary)
                        Text(timeText(schedule.timeOfDay))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(UICalendarDesignSystem.Colors.textTertiary)
                        Text("Driver: \(schedule.driver.name)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(UICalendarDesignSystem.Colors.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: $isEnabled)
                        .labelsHidden()
                        .tint(UICalendarDesignSystem.Colors.primary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func timeText(_ components: DateComponents) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }

    private func recurrenceText(_ recurrence: UICalendarRecurrence) -> String {
        switch recurrence {
        case .daily: return "Daily"
        case let .oneOff(date):
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "One-off • \(formatter.string(from: date))"
        case let .weekly(days):
            if days == [2, 3, 4, 5, 6] {
                return "Weekdays"
            }
            return "Weekly"
        }
    }
}
