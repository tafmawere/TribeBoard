import SwiftUI

enum HomeTheme {
    static let background = Color(red: 0.969, green: 0.976, blue: 0.984) // #F6F7FB
    static let card = Color.white
    static let primary = Color(red: 0.388, green: 0.400, blue: 0.945) // #6366F1
    static let textPrimary = Color(red: 0.098, green: 0.110, blue: 0.145)
    static let textSecondary = Color(red: 0.420, green: 0.471, blue: 0.580)
}

struct HomeCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(HomeTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
    }
}

struct StatusChip: View {
    let title: String
    var hasDot = false

    var body: some View {
        HStack(spacing: 8) {
            if hasDot {
                Circle()
                    .fill(HomeTheme.primary)
                    .frame(width: 7, height: 7)
            }

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(HomeTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white)
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .clipShape(Capsule(style: .continuous))
    }
}

struct PassengerAvatarStack: View {
    let initials: [String]

    var body: some View {
        let visible = Array(initials.prefix(3))
        let overflow = max(0, initials.count - visible.count)

        return HStack(spacing: -5) {
            ForEach(Array(visible.enumerated()), id: \.offset) { index, item in
                Circle()
                    .fill(index.isMultiple(of: 2) ? HomeTheme.primary.opacity(0.20) : Color.orange.opacity(0.20))
                    .frame(width: 30, height: 30)
                    .overlay {
                        Text(item)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(HomeTheme.textPrimary)
                    }
                    .overlay {
                        Circle().stroke(Color.white, lineWidth: 1.5)
                    }
            }

            if overflow > 0 {
                Circle()
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 30, height: 30)
                    .overlay {
                        Text("+\(overflow)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(HomeTheme.textSecondary)
                    }
                    .overlay {
                        Circle().stroke(Color.white, lineWidth: 1.5)
                    }
            }
        }
    }
}

struct HomeHeroCard: View {
    let event: HomeUpcomingEvent?
    var isSecondary = false

    var body: some View {
        Group {
            if isSecondary {
                secondaryCard
            } else {
                primaryCard
            }
        }
    }

    private var primaryCard: some View {
        HomeCard {
            VStack(alignment: .leading, spacing: 12) {
                if let event {
                    HStack {
                        Text(event.category)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(HomeTheme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(HomeTheme.primary.opacity(0.12))
                            .clipShape(Capsule())
                        Spacer()
                    }

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [HomeTheme.primary.opacity(0.75), Color.blue.opacity(0.40)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 130)
                        .overlay {
                            Image(systemName: "figure.run")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.85))
                        }

                    Text(event.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(HomeTheme.textSecondary)

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(event.title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(HomeTheme.textPrimary)

                            Label(event.timeRange, systemImage: "clock")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(HomeTheme.textSecondary)

                            Label(event.location, systemImage: "mappin.and.ellipse")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(HomeTheme.textSecondary)
                        }
                        Spacer()
                        PassengerAvatarStack(initials: event.passengerInitials)
                    }
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.gray.opacity(0.10))
                        .frame(height: 120)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundStyle(HomeTheme.primary)
                                Text("No upcoming events yet")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(HomeTheme.textPrimary)
                                Text("Your next event will appear here.")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(HomeTheme.textSecondary)
                            }
                        }
                }

                HStack(spacing: 10) {
                    Button {
                        // UI-only action.
                    } label: {
                        Text("View Details")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(HomeTheme.primary)
                            .clipShape(Capsule())
                    }

                    Button {
                        // UI-only action.
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(HomeTheme.primary)
                            .frame(width: 44, height: 44)
                            .background(HomeTheme.primary.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var secondaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let event {
                HStack {
                    Text(event.category)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(HomeTheme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(HomeTheme.primary.opacity(0.10))
                        .clipShape(Capsule())
                    Spacer()
                }

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [HomeTheme.primary.opacity(0.35), Color.blue.opacity(0.20)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 52)
                    .overlay {
                        Image(systemName: "calendar")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }

                Text(event.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(HomeTheme.textSecondary)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(HomeTheme.textPrimary)

                        Label(event.timeRange, systemImage: "clock")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(HomeTheme.textSecondary)
                    }
                    Spacer()
                    PassengerAvatarStack(initials: event.passengerInitials)
                }
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.gray.opacity(0.10))
                    .frame(height: 90)
                    .overlay {
                        Text("No upcoming events yet")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(HomeTheme.textSecondary)
                    }
            }
        }
        .padding(14)
        .background(HomeTheme.card.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
    }
}

struct TodayRunCard: View {
    let run: HomeRunItem

    var body: some View {
        HomeCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(run.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(HomeTheme.textPrimary)
                    Text(run.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(HomeTheme.textSecondary)
                }
                Spacer()
                if run.status == .pending {
                    Text(run.status.rawValue)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(HomeTheme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(HomeTheme.primary.opacity(0.12))
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green.opacity(0.72))
                        .font(.system(size: 20, weight: .semibold))
                }
            }
        }
    }
}

struct HomeTabBarMock: View {
    var body: some View {
        HStack {
            tabItem(icon: "house.fill", title: "Today", active: true)
            Spacer()
            tabItem(icon: "car.fill", title: "Runs", active: false)
            Spacer()
            tabItem(icon: "calendar", title: "Calendar", active: false)
            Spacer()
            tabItem(icon: "dot.radiowaves.left.and.right", title: "Feed", active: false)
            Spacer()
            tabItem(icon: "person.3.fill", title: "Tribe", active: false)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color.white)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1)
        }
    }

    private func tabItem(icon: String, title: String, active: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(active ? HomeTheme.primary : HomeTheme.textSecondary)
    }
}
