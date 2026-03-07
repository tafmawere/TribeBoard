import SwiftUI

enum RunsOverviewTab: String, CaseIterable, Identifiable {
    case today = "Today"
    case upcoming = "Upcoming"
    case history = "History"

    var id: String { rawValue }
}

enum RunsBoardMode: String, CaseIterable, Identifiable {
    case runs = "Runs"
    case dispatch = "Dispatch"

    var id: String { rawValue }
}

struct RunsOverviewView: View {
    @EnvironmentObject private var runDataSource: RunDataSource
    @EnvironmentObject private var driverDataSource: DriverDataSource
    @Binding var selectedTab: RunsOverviewTab
    @Binding var boardMode: RunsBoardMode
    let todayRuns: [UIRun]
    let upcomingRuns: [UIRun]
    let historyRuns: [UIRun]
    let activeRun: UIRun?
    let suggestedRuns: [RunSuggestion]
    let onOpenRunDetails: (UIRun) -> Void
    let onOpenObserver: (UIRun) -> Void
    let onStartSuggestion: (RunSuggestion) -> Void
    let onSnoozeSuggestion: (RunSuggestion) -> Void
    let onDismissSuggestion: (RunSuggestion) -> Void
    let onViewCalendar: (() -> Void)?

    init(
        selectedTab: Binding<RunsOverviewTab>,
        boardMode: Binding<RunsBoardMode> = .constant(.runs),
        todayRuns: [UIRun],
        upcomingRuns: [UIRun],
        historyRuns: [UIRun],
        activeRun: UIRun?,
        suggestedRuns: [RunSuggestion],
        onOpenRunDetails: @escaping (UIRun) -> Void,
        onOpenObserver: @escaping (UIRun) -> Void,
        onStartSuggestion: @escaping (RunSuggestion) -> Void,
        onSnoozeSuggestion: @escaping (RunSuggestion) -> Void,
        onDismissSuggestion: @escaping (RunSuggestion) -> Void,
        onViewCalendar: (() -> Void)? = nil
    ) {
        self._selectedTab = selectedTab
        self._boardMode = boardMode
        self.todayRuns = todayRuns
        self.upcomingRuns = upcomingRuns
        self.historyRuns = historyRuns
        self.activeRun = activeRun
        self.suggestedRuns = suggestedRuns
        self.onOpenRunDetails = onOpenRunDetails
        self.onOpenObserver = onOpenObserver
        self.onStartSuggestion = onStartSuggestion
        self.onSnoozeSuggestion = onSnoozeSuggestion
        self.onDismissSuggestion = onDismissSuggestion
        self.onViewCalendar = onViewCalendar
    }

    private var currentRuns: [UIRun] {
        switch selectedTab {
        case .today: return todayRuns
        case .upcoming: return upcomingRuns
        case .history: return historyRuns
        }
    }

    private var runsForCurrentSection: [UIRun] {
        if selectedTab == .today {
            return todayRuns.filter { $0.status != .active }
        }
        return currentRuns
    }

    private var situationalSummaryText: String {
        let activeCount = (activeRun == nil ? 0 : 1)
        let scheduledCount = todayRuns.filter { $0.status == .scheduled }.count
        // Keep the weekly bucket mock-friendly while still data-driven.
        let thisWeekCount = todayRuns.count + upcomingRuns.count
        return "\(activeCount) Active • \(scheduledCount) Scheduled • \(thisWeekCount) This Week"
    }

    private var quickActionRun: UIRun? {
        if let activeRun {
            return activeRun
        }
        return todayRuns.first(where: { $0.status == .scheduled }) ?? upcomingRuns.first
    }

    private var nextScheduledRun: UIRun? {
        todayRuns.first(where: { $0.status == .scheduled }) ?? upcomingRuns.first
    }

    private var hasNoRunData: Bool {
        activeRun == nil && todayRuns.isEmpty && upcomingRuns.isEmpty && suggestedRuns.isEmpty
    }

    private var shouldShowGlobalEmptyState: Bool {
        runDataSource.runs.isEmpty && !runDataSource.isLoading
    }

    private var isRefreshInProgress: Bool {
        runDataSource.isRefreshing || runDataSource.isLoading
    }

    var body: some View {
        ZStack {
            UIRunDesignSystem.background.ignoresSafeArea()

            VStack(spacing: 0) {
                boardModeToggle
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                if boardMode == .dispatch {
                    DailyDispatchView(onOpenRunDetails: onOpenRunDetails)
                        .environmentObject(runDataSource)
                        .environmentObject(driverDataSource)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            header
                            Text(situationalSummaryText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                            tabs
                            if shouldShowGlobalEmptyState {
                                runsDataEmptyStateCard
                            }

                            if selectedTab == .today {
                                todayAtAGlanceCard
                                quickActionsCard

                                if hasNoRunData && !shouldShowGlobalEmptyState {
                                    emptyRunsCard
                                }

                                if let activeRun {
                                    Text("Active Run")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(UIRunDesignSystem.textPrimary)
                                    activeRunCard(activeRun)
                                }

                                if !suggestedRuns.isEmpty {
                                    Text("Suggested Runs")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(UIRunDesignSystem.textPrimary)

                                    LazyVStack(spacing: 10) {
                                        ForEach(suggestedRuns) { suggestion in
                                            suggestedRunCard(suggestion)
                                        }
                                    }
                                }
                            }

                            Text(
                                selectedTab == .history
                                ? "Past Runs"
                                : (selectedTab == .today ? "Up Next" : "Runs")
                            )
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(UIRunDesignSystem.textPrimary)

                            if runsForCurrentSection.isEmpty {
                                if shouldShowGlobalEmptyState {
                                    EmptyView()
                                } else
                                if selectedTab == .today {
                                    if !hasNoRunData {
                                        UICard {
                                            Text("No upcoming runs today.")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.vertical, 8)
                                        }
                                    }
                                } else if selectedTab == .upcoming {
                                    upcomingEmptyState
                                } else {
                                    UICard {
                                        VStack(spacing: 10) {
                                            Image(systemName: "car.fill")
                                                .font(.system(size: 28, weight: .semibold))
                                                .foregroundStyle(UIRunDesignSystem.primary)
                                            Text("No runs in \(selectedTab.rawValue.lowercased())")
                                                .font(.system(size: 17, weight: .semibold))
                                                .foregroundStyle(UIRunDesignSystem.textPrimary)
                                            Text("Create a run to coordinate pickups and dropoffs.")
                                                .font(.system(size: 14, weight: .regular))
                                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                    }
                                }
                            } else {
                                LazyVStack(spacing: 10) {
                                    ForEach(runsForCurrentSection) { run in
                                        UIRunCard(run: run) {
                                            onOpenRunDetails(run)
                                        }
                                        .saturation(selectedTab == .history ? 0.72 : 1.0)
                                        .opacity(selectedTab == .history ? 0.84 : 1.0)
                                        .shadow(
                                            color: selectedTab == .history ? Color.black.opacity(0.025) : Color.clear,
                                            radius: selectedTab == .history ? 6 : 0,
                                            x: 0,
                                            y: selectedTab == .history ? 3 : 0
                                        )
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                    .refreshable {
                        await runDataSource.refresh()
                        await driverDataSource.refresh()
                    }
                }
            }
        }
        .navigationTitle("Runs")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack {
            Text("Runs")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(UIRunDesignSystem.textPrimary)
            Spacer()
        }
    }

    private var tabs: some View {
        HStack(spacing: 6) {
            ForEach(RunsOverviewTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selectedTab == tab ? .white : UIRunDesignSystem.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 2)
                        .background(selectedTab == tab ? UIRunDesignSystem.primary : Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var boardModeToggle: some View {
        HStack(spacing: 6) {
            ForEach(RunsBoardMode.allCases) { mode in
                Button {
                    boardMode = mode
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(boardMode == mode ? .white : UIRunDesignSystem.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 2)
                        .background(boardMode == mode ? UIRunDesignSystem.primary : Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var todayAtAGlanceCard: some View {
        UICard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Today at a glance")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                HStack(alignment: .firstTextBaseline) {
                    Text(nextScheduledRun?.scheduledTime ?? "No runs yet")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)
                    Spacer()
                    AppBadge(
                        text: activeRun != nil ? "LIVE" : (nextScheduledRun != nil ? "UPCOMING" : "NONE"),
                        style: activeRun != nil ? .live : (nextScheduledRun != nil ? .info : .neutral)
                    )
                }
                Text(activeRun != nil ? "A run is in progress." : "Next scheduled departure")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
            }
        }
    }

    private var quickActionsCard: some View {
        UICard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Quick Actions")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                quickActionRow(
                    icon: "steeringwheel",
                    title: "Driver Mode",
                    subtitle: quickActionRun == nil ? "No active or upcoming run yet" : "Open driver controls for your next run",
                    action: { run in onOpenRunDetails(run) }
                )
                quickActionRow(
                    icon: "location.viewfinder",
                    title: "Observer Tracking",
                    subtitle: quickActionRun == nil ? "No run to track right now" : "Track live progress as an observer",
                    action: { run in onOpenObserver(run) }
                )
            }
        }
    }

    private var emptyRunsCard: some View {
        UICard {
            VStack(alignment: .leading, spacing: 12) {
                Text("No runs yet")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                Text("Create a run to get started, or build recurring schedules from Calendar.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
                HStack(spacing: 8) {
                    subtleCreateRunButton
                    if let onViewCalendar {
                        Button {
                            onViewCalendar()
                        } label: {
                            Text("View Calendar")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(UIRunDesignSystem.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.06))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
        }
    }

    private var runsDataEmptyStateCard: some View {
        UICard {
            VStack(alignment: .leading, spacing: 12) {
                Text("No runs yet")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                Text("Runs come from schedules. Add schedules next, or refresh demo runs.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
                HStack(spacing: 10) {
                    if let onViewCalendar {
                        Button {
                            onViewCalendar()
                        } label: {
                            Text("Open Calendar")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(UIRunDesignSystem.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                                .background(Color.black.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("Calendar coming next")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background(Color.black.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Button {
                        Task { await runDataSource.refresh() }
                    } label: {
                        Group {
                            if isRefreshInProgress {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Refreshing...")
                                }
                            } else {
                                Text("Refresh")
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(UIRunDesignSystem.primary.opacity(isRefreshInProgress ? 0.7 : 1.0))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isRefreshInProgress)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func quickActionRow(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping (UIRun) -> Void
    ) -> some View {
        let run = quickActionRun
        return Button {
            guard let run else { return }
            action(run)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.primary)
                    .frame(width: 34, height: 34)
                    .background(UIRunDesignSystem.primary.opacity(0.10))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(UIRunDesignSystem.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                if let run {
                    quickActionAvatarCluster(run: run)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.07), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(run == nil)
        .opacity(run == nil ? 0.72 : 1)
    }

    private func quickActionAvatarCluster(run: UIRun) -> some View {
        let names = [run.driverName] + run.passengers.map(\.name)
        let visible = Array(names.prefix(3))
        return HStack(spacing: -8) {
            ForEach(Array(visible.enumerated()), id: \.offset) { index, name in
                AvatarView(
                    name: name,
                    identity: "\(run.id.uuidString)-quick-\(index)",
                    size: 24
                )
            }
        }
    }

    private var upcomingEmptyState: some View {
        UICard {
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.secondary)
                Text("No upcoming runs scheduled.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                Button {
                    selectedTab = .today
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Create Run")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(UIRunDesignSystem.primary.opacity(0.90))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(UIRunDesignSystem.primary.opacity(0.09))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }

    private var subtleCreateRunButton: some View {
        Button {
            selectedTab = .today
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text("Create Run")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(UIRunDesignSystem.primary.opacity(0.90))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(UIRunDesignSystem.primary.opacity(0.09))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func activeRunCard(_ run: UIRun) -> some View {
        let mockProgress: CGFloat = 0.40
        return Button {
            onOpenRunDetails(run)
        } label: {
            UICard {
                VStack(alignment: .leading, spacing: 11) {
                    Text(run.status.rawValue.uppercased())
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(UIRunDesignSystem.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(UIRunDesignSystem.primary.opacity(0.24))
                        .clipShape(Capsule())

                    Text(run.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)

                    Text("En route to pickup")
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

                    HStack {
                        Text("Driver: \(run.driverName)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 10)
            }
            .background(UIRunDesignSystem.primary.opacity(0.17))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(UIRunDesignSystem.primary.opacity(0.18), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: UIRunDesignSystem.primary.opacity(0.16), radius: 11, x: 0, y: 7)
        }
        .buttonStyle(.plain)
    }

    private func suggestedRunCard(_ suggestion: RunSuggestion) -> some View {
        UICard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(suggestion.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)
                    Spacer()
                    Text(timeText(suggestion.proposedStart))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.primary)
                }

                Text("\(suggestion.originName) → \(suggestion.destinationName)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)

                HStack(spacing: 6) {
                    ForEach(Array(suggestion.childNames.enumerated()), id: \.offset) { index, childName in
                        AvatarView(
                            name: childName,
                            identity: "\(suggestion.id.uuidString)-\(index)",
                            imageName: index < suggestion.childAvatarImageNames.count ? suggestion.childAvatarImageNames[index] : nil,
                            size: 24
                        )
                    }
                    Spacer()
                    Text(driverLabel(for: suggestion))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.textSecondary)
                }

                HStack(spacing: 8) {
                    miniAction("Start", tint: UIRunDesignSystem.primary) {
                        onStartSuggestion(suggestion)
                    }
                    miniAction("Snooze 10m", tint: UIRunDesignSystem.secondary) {
                        onSnoozeSuggestion(suggestion)
                    }
                    miniAction("Dismiss", tint: .red.opacity(0.8)) {
                        onDismissSuggestion(suggestion)
                    }
                }
            }
        }
    }

    private func miniAction(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(tint.opacity(0.10))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func driverLabel(for suggestion: RunSuggestion) -> String {
        guard let driverName = suggestion.driverName, !driverName.isEmpty else { return "No driver set" }
        return "Driver: \(driverName)"
    }

}

#Preview {
    NavigationStack {
        RunsOverviewView(
            selectedTab: .constant(.today),
            boardMode: .constant(.runs),
            todayRuns: [UIRunMockData.scheduledRun],
            upcomingRuns: [UIRunMockData.scheduledRun],
            historyRuns: UIRunMockData.historyRuns,
            activeRun: UIRunMockData.activeRun,
            suggestedRuns: [],
            onOpenRunDetails: { _ in },
            onOpenObserver: { _ in },
            onStartSuggestion: { _ in },
            onSnoozeSuggestion: { _ in },
            onDismissSuggestion: { _ in }
        )
        .environmentObject(RunDataSource())
        .environmentObject(DriverDataSource())
    }
}
