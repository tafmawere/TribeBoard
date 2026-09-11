import SwiftUI

/// Control-center phase for the Runs map screen (UI-only).
enum RunsTripControlPhase: Equatable {
    case idle
    case scheduled(UIRun)
    case assigned(UIRun)
    case active(UIRun)
}

struct RunsOverviewPermissions: Equatable {
    var canManageSchedules: Bool = true
    /// Organiser-only driver assignment / dispatch-style actions.
    var canAssignDrivers: Bool = true
    var canOpenDriverMode: Bool = true
    var canObserveTracking: Bool = true
    /// Mirrors shell “household scoped” actions for starting the create-run sheet.
    var canCreateRun: Bool = true
    /// Organiser / driver — may arrive, depart, or complete stops on an active run.
    var canPerformRunActions: Bool = true
}

struct RunsTripStatusCard: View {
    let phase: RunsTripControlPhase
    let permissions: RunsOverviewPermissions
    let isDatasourceEmpty: Bool
    let isLoading: Bool
    let isRefreshing: Bool

    let assignedDriverLabel: (UIRun) -> String?

    let onCreateRun: (() -> Void)?
    let onViewCalendar: (() -> Void)?
    let onRefreshRuns: () -> Void

    let onOpenRunDetails: (UIRun) -> Void
    let onOpenObserver: (UIRun) -> Void
    let onOpenDriverMode: (() -> Void)?

    private var mockProgress: CGFloat { 0.40 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch phase {
            case .idle:
                idleContent
            case let .scheduled(run):
                scheduledContent(run)
            case let .assigned(run):
                assignedContent(run)
            case let .active(run):
                activeContent(run)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 10)
    }

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("No active runs")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                Spacer()
                if isLoading || isRefreshing {
                    ProgressView()
                        .scaleEffect(0.9)
                }
            }

            Text("Create a run now or generate runs from your schedules.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(UIRunDesignSystem.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if permissions.canCreateRun, let onCreateRun {
                primaryCapsule(title: "Create Run", icon: "plus.circle.fill") {
                    onCreateRun()
                }
            }

            HStack(spacing: 10) {
                secondaryCapsule(title: "Refresh", icon: "arrow.clockwise") {
                    onRefreshRuns()
                }
                .disabled(isRefreshing)
                .opacity(isRefreshing ? 0.55 : 1)

                if let onViewCalendar {
                    tertiaryCalendarButton(action: onViewCalendar)
                }
            }
        }
    }

    private func tertiaryCalendarButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .semibold))
                Text("Open Calendar")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(UIRunDesignSystem.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func scheduledContent(_ run: UIRun) -> some View {
        runSummaryContent(
            run,
            heading: "Next run",
            badgeText: "SCHEDULED",
            badgeStyle: .info,
            primaryTitle: permissions.canAssignDrivers && (assignedDriverLabel(run) ?? run.driverName) == "Unassigned"
                ? "Assign driver"
                : "Run details",
            primaryIcon: permissions.canAssignDrivers && (assignedDriverLabel(run) ?? run.driverName) == "Unassigned"
                ? "person.badge.plus"
                : "info.circle",
            primaryAction: { onOpenRunDetails(run) }
        )
    }

    private func assignedContent(_ run: UIRun) -> some View {
        runSummaryContent(
            run,
            heading: "Ready to go",
            badgeText: "ASSIGNED",
            badgeStyle: .info,
            primaryTitle: "Start Run",
            primaryIcon: "play.fill",
            primaryAction: { onOpenRunDetails(run) }
        )
    }

    private func runSummaryContent(
        _ run: UIRun,
        heading: String,
        badgeText: String,
        badgeStyle: BadgeStyle,
        primaryTitle: String,
        primaryIcon: String,
        primaryAction: @escaping () -> Void
    ) -> some View {
        let driverTitle = assignedDriverLabel(run) ?? run.driverName
        let unassigned = driverTitle == "Unassigned"

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(heading)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.textSecondary)
                    Text(run.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)
                        .lineLimit(2)
                }
                Spacer()
                AppBadge(text: badgeText, style: badgeStyle)
            }

            HStack(spacing: 8) {
                Label(run.scheduledTime, systemImage: "clock")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                Image(systemName: unassigned ? "person.crop.circle.badge.questionmark" : "person.fill")
                    .foregroundStyle(unassigned ? UIRunDesignSystem.secondary : UIRunDesignSystem.primary)
                Text(unassigned ? "Driver not assigned" : "Driver: \(driverTitle)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
                Spacer()
            }

            HStack(spacing: 10) {
                primaryCapsule(title: primaryTitle, icon: primaryIcon, action: primaryAction)

                if permissions.canObserveTracking {
                    secondaryCapsule(title: "Track", icon: "location.viewfinder") {
                        onOpenObserver(run)
                    }
                }
            }
        }
    }

    private func activeContent(_ run: UIRun) -> some View {
        let driverTitle = assignedDriverLabel(run) ?? run.driverName

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active run")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.textSecondary)
                    Text(run.title)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)
                        .lineLimit(2)
                }
                Spacer()
                AppBadge(text: "LIVE", style: .live)
            }

            Text("In progress")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(UIRunDesignSystem.primary)

            HStack(spacing: 14) {
                Label(run.etaText, systemImage: "clock")
                Label(run.distanceText, systemImage: "location")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(UIRunDesignSystem.textSecondary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(UIRunDesignSystem.primary.opacity(0.14))
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(UIRunDesignSystem.primary)
                        .frame(width: geometry.size.width * mockProgress)
                }
            }
            .frame(height: 5)

            Text("Driver: \(driverTitle)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(UIRunDesignSystem.textSecondary)

            HStack(spacing: 10) {
                if permissions.canOpenDriverMode, let onOpenDriverMode {
                    primaryCapsule(title: "Driver mode", icon: "steeringwheel") {
                        onOpenDriverMode()
                    }
                } else if permissions.canObserveTracking {
                    primaryCapsule(title: "Live tracking", icon: "location.viewfinder") {
                        onOpenObserver(run)
                    }
                } else {
                    primaryCapsule(title: "Run details", icon: "info.circle") {
                        onOpenRunDetails(run)
                    }
                }

                if permissions.canObserveTracking {
                    secondaryCapsule(title: "Observer", icon: "eye") {
                        onOpenObserver(run)
                    }
                }

                secondaryCapsule(title: "Details", icon: "chevron.right") {
                    onOpenRunDetails(run)
                }
            }
        }
    }

    private func primaryCapsule(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(UIRunDesignSystem.primary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func secondaryCapsule(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(UIRunDesignSystem.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
