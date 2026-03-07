import SwiftUI

struct UICard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(UIRunDesignSystem.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: UIRunDesignSystem.cardCornerRadius, style: .continuous))
            .shadow(color: UIRunDesignSystem.cardShadow, radius: 10, x: 0, y: 6)
    }
}

struct UIPrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(UIRunDesignSystem.primary)
            .clipShape(Capsule())
        }
    }
}

struct UISecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(UIRunDesignSystem.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.06))
            .clipShape(Capsule())
        }
    }
}

struct UIRunCard: View {
    let run: UIRun
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            UICard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        AppBadge(text: run.status.rawValue, style: statusBadgeStyle(run.status))
                        Spacer()
                        Text(run.scheduledTime)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                    }

                    Text(run.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)

                    HStack(spacing: 14) {
                        Label(run.etaText, systemImage: "clock")
                        Label(run.distanceText, systemImage: "location")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)

                    HStack {
                        Text("Driver: \(run.driverName)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func statusBadgeStyle(_ status: UIRunStatus) -> BadgeStyle {
        switch status {
        case .scheduled:
            return .scheduled
        case .active:
            return .enRoute
        case .completed:
            return .completed
        }
    }
}

struct UIPassengerRow: View {
    let passenger: UIPassenger
    var isSelectable = false
    var isSelected = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(UIRunDesignSystem.primary.opacity(0.14))
                    .frame(width: 42, height: 42)
                    .overlay {
                        Text(initials(passenger.name))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(UIRunDesignSystem.primary)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(passenger.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)
                    Text(passenger.status.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(statusColor(passenger.status))
                }

                Spacer()

                if isSelectable {
                    Circle()
                        .strokeBorder(isSelected ? UIRunDesignSystem.primary : Color.gray.opacity(0.35), lineWidth: 2)
                        .background(Circle().fill(isSelected ? UIRunDesignSystem.primary : Color.clear))
                        .frame(width: 28, height: 28)
                }
            }
            .padding(12)
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? UIRunDesignSystem.primary.opacity(0.35) : Color.black.opacity(0.08), lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isSelectable)
    }

    private func statusColor(_ status: UIPassengerStatus) -> Color {
        switch status {
        case .waiting: return UIRunDesignSystem.secondary
        case .onboard: return UIRunDesignSystem.primary
        case .droppedOff: return UIRunDesignSystem.success
        }
    }

    private func initials(_ fullName: String) -> String {
        fullName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}

struct UIStopRow: View {
    let stop: UIStop
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(isCurrent ? UIRunDesignSystem.primary : Color.gray.opacity(0.30))
                    .frame(width: 14, height: 14)
                Rectangle()
                    .fill(Color.blue.opacity(0.20))
                    .frame(width: 2, height: 46)
                    .opacity(0.8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(stop.label)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                Text(stop.timeText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
                Text("\(stop.type.rawValue) • \(stop.passengerNames.joined(separator: ", "))")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(UIRunDesignSystem.secondary)
            }

            Spacer()
        }
    }
}

struct UITimelineRow: View {
    let item: UITimelineItem
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .strokeBorder(isCurrent ? UIRunDesignSystem.primary : Color.gray.opacity(0.35), lineWidth: 3)
                    .background(Circle().fill(isCurrent ? UIRunDesignSystem.primary.opacity(0.18) : Color.clear))
                    .frame(width: 18, height: 18)

                Rectangle()
                    .fill(Color.blue.opacity(0.25))
                    .frame(width: 2, height: 34)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(isCurrent ? UIRunDesignSystem.primary : UIRunDesignSystem.textPrimary)
                    Spacer()
                    Text(item.timeText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(UIRunDesignSystem.secondary)
                }
                Text(item.subtitle)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
            }
        }
    }
}
