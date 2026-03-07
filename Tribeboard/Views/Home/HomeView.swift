import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var flow: AppFlowState
    @EnvironmentObject private var runDataSource: RunDataSource
    @EnvironmentObject private var locationService: LocationReadinessService
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var syncCoordinator: SyncCoordinator
    var onOpenRuns: () -> Void = {}
    var onOpenDispatch: () -> Void = {}
    var onOpenCalendar: () -> Void = {}
    var onOpenFamily: () -> Void = {}
    var onCreateRun: () -> Void = {}
    var onOpenDriverMode: () -> Void = {}
    var onOpenRunDetails: (String) -> Void = { _ in }
    var onOpenSettings: () -> Void = {}
    @State private var showProfileSheet = false
    @State private var isActivePulseOn = false
    @StateObject private var etaSmoothingService = ETASmoothingService()

    private var isRefreshInProgress: Bool {
        runDataSource.isRefreshing || runDataSource.isLoading
    }

    private var attentionItems: [AttentionItem] {
        runDataSource.attentionItems(for: Date())
    }

    private var showNotificationHint: Bool {
        notificationService.authorizationState == .notDetermined
            || notificationService.authorizationState == .denied
    }

    private var showSyncWarningHint: Bool {
        syncCoordinator.recentSyncWarning != nil
    }

    private var activeRun: SystemDomain.RunInstance? {
        runDataSource.runs
            .filter { $0.status == .inProgress }
            .sorted { $0.date < $1.date }
            .first
    }

    private var activeRunETA: ETAPrediction? {
        guard let activeRun, let location = locationService.currentLocation else {
            if let activeRun {
                etaSmoothingService.clear(runId: activeRun.id)
            }
            return nil
        }
        return runDataSource.smoothedETAForRun(
            activeRun.id,
            currentLocation: location,
            liveSpeedMetersPerSecond: locationService.estimatedSpeedMetersPerSecond,
            sampleCount: locationService.speedSampleCount,
            speedVariance: locationService.speedVariance,
            smoothingService: etaSmoothingService
        )
    }

    private var viewModel: HomeViewModel {
        let calendar = Calendar.current
        let now = Date()
        let activeRunCount = runDataSource.runs.filter { $0.status == .inProgress }.count
        let todayRuns = runDataSource.runs
            .filter { calendar.isDate($0.date, inSameDayAs: now) }
            .sorted { $0.date < $1.date }
            .map { run in
                HomeRunItem(
                    title: run.stopSnapshots.last?.name ?? "Scheduled Run",
                    subtitle: homeRunSubtitle(for: run),
                    status: run.status == .completed ? .completed : .pending
                )
            }
        let upcoming = runDataSource.runs
            .filter { $0.date > now && $0.status == .scheduled }
            .sorted { $0.date < $1.date }
            .first

        return HomeViewModel(
            activeRunCount: activeRunCount,
            syncStatusText: syncStatusText,
            upcomingEvent: mapUpcomingEvent(upcoming),
            todaysRuns: todayRuns
        )
    }

    private var syncStatusText: String {
        let status = syncCoordinator.status
        switch status.state {
        case .syncing:
            return "SYNCING..."
        case .pending:
            return "PENDING (\(status.pendingCount))"
        case .failed:
            return "FAILED"
        case .succeeded:
            if let lastSyncAt = status.lastSyncAt {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .short
                return formatter.localizedString(for: lastSyncAt, relativeTo: Date()).uppercased()
            }
            return "JUST NOW"
        case .idle:
            return status.pendingCount > 0 ? "PENDING (\(status.pendingCount))" : "JUST NOW"
        }
    }

    var body: some View {
        ZStack {
            HomeTheme.background
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerRow
                    dateStatusRow
                    notificationHint
                    syncWarningHint
                    attentionPanel
                    liveETACard
                    upNextSection
                    quickActionsSection
                    runsSummarySection
                    upcomingEventsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .refreshable {
                await runDataSource.refresh()
            }
        }
        .task {
            await runDataSource.bootstrapIfNeeded()
            await syncCoordinator.refreshStatus()
            await notificationService.refreshAuthorizationState()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isActivePulseOn = true
            }
        }
        .sheet(isPresented: $showProfileSheet) {
            NavigationStack {
                ProfileView()
                    .environmentObject(flow)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var headerRow: some View {
        HStack {
            Button {
                print("Avatar tapped")
                showProfileSheet = true
            } label: {
                Circle()
                    .fill(HomeTheme.primary.opacity(0.14))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text("TM")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(HomeTheme.primary)
                    }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .frame(width: 44, height: 44)

            Spacer()

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [HomeTheme.primary, HomeTheme.primary.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 20, height: 20)
                    .overlay {
                        Image(systemName: "house.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }

                Text("TribeBoard")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(HomeTheme.textPrimary)
            }

            Spacer()

            Button {
                print("Settings tapped")
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HomeTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .frame(width: 44, height: 44)
        }
    }

    private var dateStatusRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MONDAY, OCTOBER 23RD")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(HomeTheme.textSecondary)
                .tracking(0.8)

            HStack(spacing: 10) {
                StatusChip(
                    title: "\(viewModel.activeRunCount) ACTIVE RUN",
                    hasDot: true
                )
                StatusChip(title: "SYNC: \(viewModel.syncStatusText)")
                Spacer(minLength: 0)
            }
            Rectangle()
                .fill(Color.black.opacity(0.05))
                .frame(height: 1)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private var notificationHint: some View {
        if showNotificationHint {
            HomeCard {
                HStack(spacing: 8) {
                    Text("Enable notifications for run reminders")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HomeTheme.textSecondary)
                    Spacer()
                    Button("Enable") {
                        Task {
                            let granted = await notificationService.requestAuthorization()
                            if granted {
                                await runDataSource.reconcileNotifications(notificationService: notificationService)
                            }
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HomeTheme.primary)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var syncWarningHint: some View {
        if showSyncWarningHint, let warning = syncCoordinator.recentSyncWarning {
            HomeCard {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text(warning)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HomeTheme.textSecondary)
                    Spacer()
                }
            }
        }
    }

    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Up Next")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(HomeTheme.textPrimary)
                Spacer()
                Button {
                    onOpenRuns()
                } label: {
                    HStack(spacing: 4) {
                        Text("Open Runs")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HomeTheme.textSecondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if runDataSource.runs.isEmpty && !runDataSource.isLoading {
                homeRunsEmptyStateCard
            } else if viewModel.activeRunCount > 0 {
                Button {
                    onOpenRuns()
                } label: {
                    HomeCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(HomeTheme.primary)
                                        .frame(width: 8, height: 8)
                                        .opacity(isActivePulseOn ? 0.4 : 1.0)
                                    Text("Active Run")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(HomeTheme.primary)
                                }
                                Spacer()
                                AppBadge(text: "LIVE", style: .live)
                            }
                            Text("School Pick-up is in progress")
                                .font(.system(size: 21, weight: .bold))
                                .foregroundStyle(HomeTheme.textPrimary)
                            Text("Tap to view live progress.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(HomeTheme.textSecondary)
                        }
                    }
                }
                .buttonStyle(HomePressableCardButtonStyle())
                .background(HomeTheme.primary.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(HomeTheme.primary.opacity(0.14), lineWidth: 1)
                }
                .shadow(color: HomeCardStyle.activeShadow, radius: 18, x: 0, y: 10)
            } else {
                HomeCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Next Scheduled Run")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(HomeTheme.primary)
                        Text(viewModel.upcomingEvent?.title ?? "No run scheduled")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(HomeTheme.textPrimary)
                        Text(viewModel.upcomingEvent?.timeRange ?? "Set up your next run")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(HomeTheme.textSecondary)
                    }
                }
                .background(HomeTheme.primary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
        .padding(.top, -4)
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Actions")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(HomeTheme.textPrimary)

            HStack(spacing: 10) {
                quickActionButton(title: "Driver Mode", icon: "steeringwheel", action: onOpenDriverMode)
                quickActionButton(title: "Observer Tracking", icon: "location.viewfinder", action: onOpenDispatch)
                quickActionButton(title: "Create Run", icon: "plus", action: onCreateRun)
            }
        }
    }

    private var runsSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Runs Summary")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(HomeTheme.textPrimary)
                Spacer()
            }

            if viewModel.todaysRuns.isEmpty {
                homeRunsEmptyStateCard
            } else {
                ForEach(viewModel.todaysRuns) { run in
                    TodayRunCard(run: run)
                }
            }
        }
    }

    @ViewBuilder
    private var attentionPanel: some View {
        let visible = Array(attentionItems.prefix(3))
        let remaining = max(0, attentionItems.count - visible.count)
        if !visible.isEmpty {
            HomeCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Attention")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(HomeTheme.textPrimary)

                    ForEach(visible) { item in
                        Button {
                            if let runId = item.runId?.uuidString {
                                onOpenRunDetails(runId)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(attentionColor(item.severity))
                                Text(item.message)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(HomeTheme.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(item.runId == nil)
                    }

                    if remaining > 0 {
                        Text("+\(remaining) more")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(HomeTheme.textSecondary)
                    }

                    Button {
                        onOpenDispatch()
                    } label: {
                        Text("Open Dispatch")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(HomeTheme.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var liveETACard: some View {
        if let activeRunETA, let activeRun {
            HomeCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Live ETA")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(HomeTheme.primary)
                    Text(runTitle(activeRun))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(HomeTheme.textPrimary)
                    Text("Next stop: \(activeRunETA.nextStopName)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(HomeTheme.textSecondary)
                    Text("ETA \(formattedTime(activeRunETA.nextStopETA)) • Arriving in \(activeRunETA.estimatedMinutesRemaining) min")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(HomeTheme.textPrimary)
                    Text(activeRunETA.quality.reason)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(HomeTheme.textSecondary)
                }
            }
        }
    }

    private var homeRunsEmptyStateCard: some View {
        HomeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("No runs yet")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(HomeTheme.textPrimary)
                Text("Runs come from schedules. Add schedules next, or refresh demo runs.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(HomeTheme.textSecondary)
                HStack(spacing: 10) {
                    Button {
                        onOpenCalendar()
                    } label: {
                        Text("Open Calendar")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(HomeTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background(Color.black.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

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
                        .background(HomeTheme.primary.opacity(isRefreshInProgress ? 0.7 : 1.0))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isRefreshInProgress)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var upcomingEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Events")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(HomeTheme.textPrimary)
                Spacer()
                Button("See Calendar") {
                    onOpenCalendar()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HomeTheme.primary)
            }
            HomeHeroCard(event: viewModel.upcomingEvent, isSecondary: true)
        }
    }

    private func quickActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(HomeTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func homeRunSubtitle(for run: SystemDomain.RunInstance) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let timeText = formatter.string(from: run.date)
        if run.status == .completed {
            return "Completed at \(timeText)"
        }
        return "Starts at \(timeText)"
    }

    private func mapUpcomingEvent(_ run: SystemDomain.RunInstance?) -> HomeUpcomingEvent? {
        guard let run else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let timeText = formatter.string(from: run.date)
        return HomeUpcomingEvent(
            category: "RUN",
            label: "UPCOMING EVENT",
            title: run.stopSnapshots.last?.name ?? "Scheduled Run",
            timeRange: timeText,
            location: run.stopSnapshots.first?.name ?? "Route",
            passengerInitials: ["TB"]
        )
    }

    private func attentionColor(_ severity: AttentionSeverity) -> Color {
        switch severity {
        case .critical:
            return Color.red
        case .warning:
            return Color.orange
        case .info:
            return HomeTheme.primary
        }
    }

    private func runTitle(_ run: SystemDomain.RunInstance) -> String {
        let trimmed = run.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Scheduled Run" : trimmed
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    HomeView()
        .environmentObject(RunDataSource())
        .environmentObject(LocationReadinessService())
        .environmentObject(NotificationService())
        .environmentObject(SyncCoordinator(queueRepository: LocalSyncQueueRepository()))
}
