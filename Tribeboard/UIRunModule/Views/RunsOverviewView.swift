import CoreLocation
import SwiftUI

enum RunsOverviewTab: String, CaseIterable, Identifiable {
    case today = "Today"
    case upcoming = "Upcoming"
    case history = "History"

    var id: String { rawValue }
}

struct RunsOverviewView: View {
    @EnvironmentObject private var activeHouseholdStore: ActiveHouseholdStore
    @EnvironmentObject private var runDataSource: RunDataSource
    @EnvironmentObject private var driverDataSource: DriverDataSource
    @EnvironmentObject private var backendDriversContext: BackendDriversContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext
    @EnvironmentObject private var locationService: LocationReadinessService
    @EnvironmentObject private var activeRunDriverSessionStore: ActiveRunDriverSessionStore

    @Binding var selectedTab: RunsOverviewTab
    @Binding var isDispatchPresented: Bool

    let permissions: RunsOverviewPermissions

    let todayRuns: [UIRun]
    let upcomingRuns: [UIRun]
    let historyRuns: [UIRun]
    let activeRun: UIRun?
    let suggestedRuns: [RunSuggestion]

    let onCreateRun: (() -> Void)?
    let onOpenDriverMode: (() -> Void)?
    let onDispatchCreateRun: (() -> Void)?
    let onDispatchOpenCalendar: (() -> Void)?

    let onOpenRunDetails: (UIRun) -> Void
    let onOpenObserver: (UIRun) -> Void
    let onStartSuggestion: (RunSuggestion) -> Void
    let onSnoozeSuggestion: (RunSuggestion) -> Void
    let onDismissSuggestion: (RunSuggestion) -> Void
    let onViewCalendar: (() -> Void)?

    @State private var runsOverviewCamera = GoogleMapCameraState.southAfricaJohannesburgDefault
    /// After the first GPS fix, pin the Runs map to a neighborhood-scale region (avoids `.automatic` world/continent zoom).
    @State private var didApplyRunsOverviewStreetZoom = false
    @State private var isAllRunsPresented = false

    init(
        selectedTab: Binding<RunsOverviewTab>,
        isDispatchPresented: Binding<Bool>,
        permissions: RunsOverviewPermissions = RunsOverviewPermissions(),
        todayRuns: [UIRun],
        upcomingRuns: [UIRun],
        historyRuns: [UIRun],
        activeRun: UIRun?,
        suggestedRuns: [RunSuggestion],
        onCreateRun: (() -> Void)? = nil,
        onOpenDriverMode: (() -> Void)? = nil,
        onDispatchCreateRun: (() -> Void)? = nil,
        onDispatchOpenCalendar: (() -> Void)? = nil,
        onOpenRunDetails: @escaping (UIRun) -> Void,
        onOpenObserver: @escaping (UIRun) -> Void,
        onStartSuggestion: @escaping (RunSuggestion) -> Void,
        onSnoozeSuggestion: @escaping (RunSuggestion) -> Void,
        onDismissSuggestion: @escaping (RunSuggestion) -> Void,
        onViewCalendar: (() -> Void)? = nil
    ) {
        self._selectedTab = selectedTab
        self._isDispatchPresented = isDispatchPresented
        self.permissions = permissions
        self.todayRuns = todayRuns
        self.upcomingRuns = upcomingRuns
        self.historyRuns = historyRuns
        self.activeRun = activeRun
        self.suggestedRuns = suggestedRuns
        self.onCreateRun = onCreateRun
        self.onOpenDriverMode = onOpenDriverMode
        self.onDispatchCreateRun = onDispatchCreateRun
        self.onDispatchOpenCalendar = onDispatchOpenCalendar
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

    /// Changes when any run id or status changes (even if `runs.count` stays the same).
    private var runStatusFingerprint: String {
        runDataSource.runs.map { "\($0.id.uuidString):\($0.status.rawValue)" }.joined(separator: "|")
    }

    private var hasAnyRuns: Bool {
        !runDataSource.runs.isEmpty
    }

    /// Runs that should surface on the Runs control center (matches `nextRun` eligibility).
    private var hasActiveRuns: Bool {
        !runDataSource.activeRuns().isEmpty || runDataSource.nextRun(referenceDate: Date()) != nil
    }

    private var primaryInProgressSystemRun: SystemDomain.RunInstance? {
        runDataSource.activeRuns().first
    }

    private var controlPhase: RunsTripControlPhase {
        if let sys = primaryInProgressSystemRun {
            return .active(mapToUIRun(sys))
        }
        if let sys = runDataSource.nextRun(referenceDate: Date()) {
            let uiRun = mapToUIRun(sys)
            switch sys.status {
            case .assigned:
                return .assigned(uiRun)
            case .scheduled:
                return .scheduled(uiRun)
            default:
                break
            }
        }
        return .idle
    }

    private var emptyStateReason: String {
        switch controlPhase {
        case .idle:
            if !hasAnyRuns { return "idle_no_runs_loaded" }
            if !hasActiveRuns { return "idle_only_terminal_runs" }
            return "idle_no_eligible_next_run"
        case .scheduled:
            return "overlay_next_scheduled"
        case .assigned:
            return "overlay_next_assigned"
        case .active:
            return showInProgressActiveExperience ? "overlay_in_progress_experience" : "overlay_active_summary_card"
        }
    }

    private var shouldShowDatasourceEmpty: Bool {
        runDataSource.runs.isEmpty && !runDataSource.isLoading
    }

    private var isRefreshInProgress: Bool {
        runDataSource.isRefreshing || runDataSource.isLoading
    }

    private var resolvedSystemActiveRun: SystemDomain.RunInstance? {
        primaryInProgressSystemRun
    }

    private var showInProgressActiveExperience: Bool {
        primaryInProgressSystemRun?.status == .inProgress
    }

    #if DEBUG
    /// When `true`, Runs is only a full-screen `TribeGoogleMapView` (no cards, gradients, or toolbar). Toggle to `true` to isolate rendering.
    private static let runsOverviewBareMapOnlyForDebug = false
    /// When `true`, shows only `RunsTripMapBackground` + "MAP TEST" pill to isolate SwiftUI layers.
    private static let isolateRunsMapLayerForDebug = false
    /// When `true`, tints root (blue), map (red), and floating chrome (green) to reveal cover-up layers.
    private static let paintRunsMapDebugLayerColors = false
    #endif

    private var runsOverviewBareMapOnlyBody: some View {
        ZStack {
            TribeGoogleMapView(
                markers: [],
                polylineCoordinates: [],
                strokeUIColor: .clear,
                lineWidth: 0,
                cameraHint: nil,
                externalCamera: runsOverviewCamera,
                showsUserLocation: true,
                padding: .zero,
                onMarkerIdTap: nil
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
    }

    private var runsMapDebugBody: some View {
        ZStack {
            RunsTripMapBackground(camera: $runsOverviewCamera)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                #if DEBUG
                .background(Self.paintRunsMapDebugLayerColors ? Color.red.opacity(0.22) : Color.clear)
                #endif

            VStack {
                Spacer()

                Text("MAP TEST")
                    .padding()
                    .background(.black.opacity(0.7))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(.bottom, 120)
            }
            #if DEBUG
            .background(Self.paintRunsMapDebugLayerColors ? Color.green.opacity(0.18) : Color.clear)
            #endif
        }
        #if DEBUG
        .background(Self.paintRunsMapDebugLayerColors ? Color.blue.opacity(0.15) : Color.clear)
        #endif
    }

    private var runsMapProductionZStack: some View {
        ZStack(alignment: .bottom) {
            if !(showInProgressActiveExperience && resolvedSystemActiveRun != nil) {
                RunsTripMapBackground(camera: $runsOverviewCamera)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .zIndex(0)
                    #if DEBUG
                    .background(Self.paintRunsMapDebugLayerColors ? Color.red.opacity(0.22) : Color.clear)
                    #endif
            }

            LinearGradient(
                colors: [Color.black.opacity(0.38), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 130)
            .frame(maxWidth: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
            .zIndex(1)

            if showInProgressActiveExperience, let sys = resolvedSystemActiveRun {
                RunsActiveRunExperienceView(
                    systemRun: sys,
                    uiRun: mapToUIRun(sys),
                    permissions: permissions,
                    embedRouteMap: true,
                    onEnterDriverMode: {
                        activeRunDriverSessionStore.present(runId: sys.id)
                    },
                    onOpenAllRuns: { isAllRunsPresented = true }
                )
                .zIndex(2)
                #if DEBUG
                .background(Self.paintRunsMapDebugLayerColors ? Color.green.opacity(0.18) : Color.clear)
                #endif
            } else {
                VStack(spacing: 20) {
                    RunsTripStatusCard(
                        phase: controlPhase,
                        permissions: permissions,
                        isDatasourceEmpty: shouldShowDatasourceEmpty,
                        isLoading: runDataSource.isLoading,
                        isRefreshing: isRefreshInProgress,
                        assignedDriverLabel: { run in
                            assignedDriverName(for: run)
                        },
                        onCreateRun: onCreateRun,
                        onViewCalendar: onViewCalendar,
                        onRefreshRuns: {
                            Task {
                                await runDataSource.refresh()
                                await driverDataSource.refresh()
                            }
                        },
                        onOpenRunDetails: onOpenRunDetails,
                        onOpenObserver: onOpenObserver,
                        onOpenDriverMode: onOpenDriverMode
                    )
                    .padding(.horizontal, 16)

                    Button {
                        isAllRunsPresented = true
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                                .font(.system(size: 14, weight: .semibold))
                            Text("All runs")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
                .background(Color.clear)
                .zIndex(2)
                #if DEBUG
                .background(Self.paintRunsMapDebugLayerColors ? Color.green.opacity(0.18) : Color.clear)
                #endif
            }
        }
        #if DEBUG
        .background(Self.paintRunsMapDebugLayerColors ? Color.blue.opacity(0.15) : Color.clear)
        #endif
    }

    var body: some View {
        Group {
            #if DEBUG
            if Self.runsOverviewBareMapOnlyForDebug {
                runsOverviewBareMapOnlyBody
            } else if Self.isolateRunsMapLayerForDebug {
                runsMapDebugBody
            } else {
                runsMapProductionZStack
            }
            #else
            runsMapProductionZStack
            #endif
        }
        #if DEBUG
        .navigationTitle(Self.runsOverviewBareMapOnlyForDebug ? "" : "Runs")
        #else
        .navigationTitle("Runs")
        #endif
        .navigationBarTitleDisplayMode(.inline)
        #if DEBUG
        .toolbar(Self.runsOverviewBareMapOnlyForDebug ? .hidden : .automatic, for: .navigationBar)
        #endif
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            #if DEBUG
            if !Self.runsOverviewBareMapOnlyForDebug {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            isDispatchPresented = true
                        } label: {
                            Label("Dispatch board", systemImage: "square.grid.2x2")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .accessibilityLabel("Runs menu")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await runDataSource.refresh()
                            await driverDataSource.refresh()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .disabled(isRefreshInProgress)
                    .accessibilityLabel("Refresh runs")
                }
            }
            #else
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button {
                        isDispatchPresented = true
                    } label: {
                        Label("Dispatch board", systemImage: "square.grid.2x2")
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 17, weight: .medium))
                }
                .accessibilityLabel("Runs menu")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await runDataSource.refresh()
                        await driverDataSource.refresh()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                }
                .disabled(isRefreshInProgress)
                .accessibilityLabel("Refresh runs")
            }
            #endif
        }
        .sheet(isPresented: $isDispatchPresented) {
            NavigationStack {
                DailyDispatchView(
                    onOpenRunDetails: onOpenRunDetails,
                    onCreateRun: onDispatchCreateRun,
                    onOpenCalendar: onDispatchOpenCalendar
                )
                    .navigationTitle("Dispatch")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                isDispatchPresented = false
                            }
                        }
                    }
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isAllRunsPresented) {
            NavigationStack {
                allRunsSheet
                    .navigationTitle("All runs")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                isAllRunsPresented = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: activeHouseholdStore.activeHouseholdId) { _, _ in
            Task {
                await runDataSource.refresh()
                await driverDataSource.refresh()
            }
        }
        .onAppear {
            logRunsOverviewMapDebug(reason: "onAppear")
            applyRunsOverviewStreetLevelMapIfNeeded()
        }
        .onChange(of: runDataSource.runs.count) { _, _ in
            logRunsOverviewMapDebug(reason: "runsCountChanged")
        }
        .onChange(of: runStatusFingerprint) { _, _ in
            logRunsOverviewMapDebug(reason: "runStatusesChanged")
        }
        .onChange(of: activeRun?.backingRunId) { _, _ in
            logRunsOverviewMapDebug(reason: "activeRunChanged")
        }
        .onChange(of: locationService.lastLocationTimestamp) { _, _ in
            applyRunsOverviewStreetLevelMapIfNeeded()
        }
    }

    private var allRunsSheet: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                sheetTabs

                if shouldShowDatasourceEmpty {
                    UICard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No runs loaded")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(UIRunDesignSystem.textPrimary)
                            Text("Runs appear when schedules generate them. Open Calendar or refresh.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                            Button {
                                Task { await runDataSource.refresh() }
                            } label: {
                                Text("Refresh")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(UIRunDesignSystem.primary.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if selectedTab == .today, !suggestedRuns.isEmpty {
                    Text("Suggested")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)

                    LazyVStack(spacing: 10) {
                        ForEach(suggestedRuns) { suggestion in
                            suggestedRunCard(suggestion)
                        }
                    }
                }

                Text(
                    selectedTab == .history
                        ? "Past runs"
                        : (selectedTab == .today ? "Today" : "Upcoming")
                )
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(UIRunDesignSystem.textPrimary)

                if runsForCurrentSection.isEmpty, !shouldShowDatasourceEmpty {
                    emptySectionPlaceholder
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(runsForCurrentSection) { run in
                            UIRunCard(run: run, driverNameOverride: assignedDriverName(for: run)) {
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
        .background(UIRunDesignSystem.background)
        .refreshable {
            await runDataSource.refresh()
            await driverDataSource.refresh()
        }
    }

    private var sheetTabs: some View {
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
                        .background(selectedTab == tab ? UIRunDesignSystem.primary : Color(uiColor: .secondarySystemBackground))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var emptySectionPlaceholder: some View {
        switch selectedTab {
        case .today:
            UICard {
                Text("No other runs today.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
        case .upcoming:
            UICard {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.secondary)
                    Text("No upcoming runs scheduled.")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
        case .history:
            UICard {
                VStack(spacing: 10) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.primary)
                    Text("No past runs in this list yet.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
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

    private func mapToUIRun(_ run: SystemDomain.RunInstance) -> UIRun {
        RunUIAdapter.mapToUIRun(
            run,
            childName: RunDisplayStrings.childName(for: run, children: backendChildrenContext.children)
        )
    }

    private func assignedDriverName(for run: UIRun) -> String? {
        guard let runId = UUID(uuidString: run.backingRunId) else { return nil }
        if let backendName = backendDriversContext.driverName(forRunId: runId)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !backendName.isEmpty {
            return backendName
        }
        let uiName = run.driverName.trimmingCharacters(in: .whitespacesAndNewlines)
        return uiName.isEmpty || uiName == "Unassigned" ? nil : uiName
    }

    private func logRunsOverviewMapDebug(reason: String) {
        #if DEBUG
        let runsCount = runDataSource.runs.count
        let statusSummary = runDataSource.runs
            .map { "\($0.id.uuidString.prefix(8)):\($0.status.rawValue)" }
            .joined(separator: ", ")
        let phaseLabel: String = {
            switch controlPhase {
            case .idle: return "idle"
            case .scheduled: return "scheduled"
            case .assigned: return "assigned"
            case .active: return "active"
            }
        }()
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        for run in runDataSource.runs {
            let stopCount = run.stopSnapshots.count
            let runDate = dateFormatter.string(from: run.date)
            NSLog(
                "[RunsScreen] run_id=%@ title=%@ status=%@ household_id=%@ run_date=%@ driver_id=%@ stops=%d source=RunDataSource.supabase",
                run.id.uuidString,
                run.title ?? "(nil)",
                run.status.rawValue,
                run.householdId.uuidString,
                runDate,
                (run.assignedDriverId ?? run.driverId)?.uuidString ?? "(nil)",
                stopCount
            )
        }
        for run in runDataSource.runs where run.status == .completed || run.status == .cancelled {
            NSLog(
                "[RunsScreen] filtered_out run_id=%@ reason=terminal_status status=%@",
                run.id.uuidString,
                run.status.rawValue
            )
        }
        if hasAnyRuns && !hasActiveRuns {
            NSLog("[RunsScreen] filtered_out all_runs reason=only_completed_or_cancelled_in_control_center")
        }
        if hasActiveRuns, runDataSource.nextRun(referenceDate: Date()) == nil {
            NSLog("[RunsScreen] filtered_out active_runs reason=nextRun_returned_nil_despite_active_statuses")
        }
        let tripStatusCardVisible = !showInProgressActiveExperience
        NSLog("[RunsMap] debug trigger=%@", reason)
        NSLog("[RunsMap] runs_count=%d statuses=[%@]", runsCount, statusSummary)
        NSLog(
            "[RunsMap] hasAnyRuns=%@ hasActiveRuns=%@ controlPhase=%@ emptyStateReason=%@",
            hasAnyRuns ? "true" : "false",
            hasActiveRuns ? "true" : "false",
            phaseLabel,
            emptyStateReason
        )
        NSLog(
            "[RunsMap] mapLayerVisible=true tripStatusCardVisible=%@ inProgressExperience=%@ googleMapsConfigured=%@",
            tripStatusCardVisible ? "true" : "false",
            showInProgressActiveExperience ? "true" : "false",
            GoogleMapsBootstrap.isConfigured ? "true" : "false"
        )
        #endif
    }

    private func applyRunsOverviewStreetLevelMapIfNeeded() {
        guard !didApplyRunsOverviewStreetZoom else { return }
        guard let coordinate = locationService.currentLocation?.coordinate else { return }
        didApplyRunsOverviewStreetZoom = true
        let target = coordinate
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            runsOverviewCamera = GoogleMapCameraState(
                target: target,
                zoom: 15.2
            )
        }
    }
}

#Preview {
    NavigationStack {
        RunsOverviewView(
            selectedTab: .constant(.today),
            isDispatchPresented: .constant(false),
            permissions: RunsOverviewPermissions(),
            todayRuns: [UIRunMockData.scheduledRun],
            upcomingRuns: [UIRunMockData.scheduledRun],
            historyRuns: UIRunMockData.historyRuns,
            activeRun: UIRunMockData.activeRun,
            suggestedRuns: [],
            onCreateRun: {},
            onOpenDriverMode: {},
            onDispatchCreateRun: nil,
            onDispatchOpenCalendar: nil,
            onOpenRunDetails: { _ in },
            onOpenObserver: { _ in },
            onStartSuggestion: { _ in },
            onSnoozeSuggestion: { _ in },
            onDismissSuggestion: { _ in }
        )
        .environmentObject(RunDataSource())
        .environmentObject(DriverDataSource())
        .environmentObject(BackendDriversContext(backendRunsContext: BackendRunsContext()))
        .environmentObject(ActiveHouseholdStore())
        .environmentObject(LocationReadinessService())
    }
}
