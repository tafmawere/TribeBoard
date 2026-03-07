import SwiftUI

enum DemoSheet: Identifiable, Equatable {
    case runCreation
    case scheduleEditor(scheduleId: String?)
    case runScheduledConfirmation(runId: String)

    var id: String {
        switch self {
        case .runCreation:
            return "runCreation"
        case let .scheduleEditor(scheduleId):
            return "scheduleEditor-\(scheduleId ?? "new")"
        case let .runScheduledConfirmation(runId):
            return "runScheduledConfirmation-\(runId)"
        }
    }
}

struct DemoShellView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var tribeStore: TribeStore
    @StateObject private var runDataSource: RunDataSource
    @StateObject private var scheduleDataSource: ScheduleDataSource
    @StateObject private var driverDataSource: DriverDataSource
    @StateObject private var householdContext: ActiveHouseholdContext
    @StateObject private var householdDataSource: HouseholdDataSource
    @StateObject private var locationService: LocationReadinessService
    @StateObject private var notificationService: NotificationService
    @StateObject private var syncCoordinator: SyncCoordinator
    @State private var selectedTab: AppTab
    @State private var runsOverviewTab: RunsOverviewTab = .today
    @State private var runsBoardMode: RunsBoardMode = .runs
    @State private var homePath = NavigationPath()
    @State private var runsPath = NavigationPath()
    @State private var calendarPath = NavigationPath()
    @State private var familyPath = NavigationPath()
    @State private var morePath = NavigationPath()
    @State private var presentedSheet: DemoSheet?
    @State private var lastRemotePullAt: Date?
    private let minimumRemotePullInterval: TimeInterval = 60

    init(store: TribeStore, initialTab: AppTab = .home) {
        let runRepository = LocalRunRepository()
        let scheduleRepository = LocalScheduleRepository()
        let driverRepository = LocalDriverRepository()
        let householdContext = ActiveHouseholdContext()
        let householdRepository = LocalHouseholdRepository()
        let syncCoordinator = SyncCoordinator(
            queueRepository: LocalSyncQueueRepository(),
            auditRepository: LocalSyncAuditRepository(),
            processedChangeRepository: LocalProcessedChangeRepository(),
            remoteDriver: MockRemoteSyncDriver(),
            runRepository: runRepository,
            scheduleRepository: scheduleRepository,
            driverRepository: driverRepository,
            householdRepository: householdRepository
        )
        _tribeStore = StateObject(wrappedValue: store)
        _runDataSource = StateObject(
            wrappedValue: RunDataSource(
                repository: runRepository,
                scheduleRepository: scheduleRepository,
                driverRepository: driverRepository,
                householdContext: householdContext,
                syncCoordinator: syncCoordinator
            )
        )
        _scheduleDataSource = StateObject(
            wrappedValue: ScheduleDataSource(
                repository: scheduleRepository,
                householdContext: householdContext,
                syncCoordinator: syncCoordinator
            )
        )
        _driverDataSource = StateObject(
            wrappedValue: DriverDataSource(
                repository: driverRepository,
                householdContext: householdContext,
                syncCoordinator: syncCoordinator
            )
        )
        _householdContext = StateObject(wrappedValue: householdContext)
        _householdDataSource = StateObject(
            wrappedValue: HouseholdDataSource(
                repository: householdRepository,
                activeContext: householdContext,
                syncCoordinator: syncCoordinator
            )
        )
        _locationService = StateObject(wrappedValue: LocationReadinessService())
        _notificationService = StateObject(wrappedValue: NotificationService())
        _syncCoordinator = StateObject(wrappedValue: syncCoordinator)
        _selectedTab = State(initialValue: initialTab)
    }

    @MainActor
    init() {
        let runRepository = LocalRunRepository()
        let scheduleRepository = LocalScheduleRepository()
        let driverRepository = LocalDriverRepository()
        let householdContext = ActiveHouseholdContext()
        let householdRepository = LocalHouseholdRepository()
        let syncCoordinator = SyncCoordinator(
            queueRepository: LocalSyncQueueRepository(),
            auditRepository: LocalSyncAuditRepository(),
            processedChangeRepository: LocalProcessedChangeRepository(),
            remoteDriver: MockRemoteSyncDriver(),
            runRepository: runRepository,
            scheduleRepository: scheduleRepository,
            driverRepository: driverRepository,
            householdRepository: householdRepository
        )
        _tribeStore = StateObject(wrappedValue: TribeStore(demoFlow: true))
        _runDataSource = StateObject(
            wrappedValue: RunDataSource(
                repository: runRepository,
                scheduleRepository: scheduleRepository,
                driverRepository: driverRepository,
                householdContext: householdContext,
                syncCoordinator: syncCoordinator
            )
        )
        _scheduleDataSource = StateObject(
            wrappedValue: ScheduleDataSource(
                repository: scheduleRepository,
                householdContext: householdContext,
                syncCoordinator: syncCoordinator
            )
        )
        _driverDataSource = StateObject(
            wrappedValue: DriverDataSource(
                repository: driverRepository,
                householdContext: householdContext,
                syncCoordinator: syncCoordinator
            )
        )
        _householdContext = StateObject(wrappedValue: householdContext)
        _householdDataSource = StateObject(
            wrappedValue: HouseholdDataSource(
                repository: householdRepository,
                activeContext: householdContext,
                syncCoordinator: syncCoordinator
            )
        )
        _locationService = StateObject(wrappedValue: LocationReadinessService())
        _notificationService = StateObject(wrappedValue: NotificationService())
        _syncCoordinator = StateObject(wrappedValue: syncCoordinator)
        _selectedTab = State(initialValue: .home)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: pathBinding(for: .home)) {
                HomeView(
                    onOpenRuns: {
                        runsBoardMode = .runs
                        selectedTab = .runs
                    },
                    onOpenDispatch: {
                        runsBoardMode = .dispatch
                        selectedTab = .runs
                    },
                    onOpenCalendar: { selectedTab = .calendar },
                    onOpenFamily: { selectedTab = .family },
                    onCreateRun: {
                        runsBoardMode = .runs
                        selectedTab = .runs
                    },
                    onOpenDriverMode: {
                        homePath.append(Destination.driverModeSelector)
                    },
                    onOpenRunDetails: { runId in
                        homePath.append(Destination.runDetails(runId: runId))
                    },
                    onOpenSettings: {
                        homePath.append(Destination.settings)
                    }
                )
                    .withNavigationRouter()
            }
            .tabItem {
                Label(AppTab.home.title, systemImage: AppTab.home.systemImage)
            }
            .tag(AppTab.home)

            NavigationStack(path: pathBinding(for: .runs)) {
                RunsOverviewView(
                    selectedTab: $runsOverviewTab,
                    boardMode: $runsBoardMode,
                    todayRuns: todayRuns,
                    upcomingRuns: upcomingRuns,
                    historyRuns: historyRuns,
                    activeRun: activeRun,
                    suggestedRuns: tribeStore.generateSuggestedRuns(now: Date()),
                    onOpenRunDetails: { run in
                        runsPath.append(Destination.runDetails(runId: run.backingRunId))
                    },
                    onOpenObserver: { run in
                        // Keep routing simple in shell demo.
                        runsPath.append(Destination.runDetails(runId: run.backingRunId))
                    },
                    onStartSuggestion: { suggestion in
                        _ = tribeStore.createRunInstanceFromSuggestion(suggestion, now: Date())
                    },
                    onSnoozeSuggestion: { suggestion in
                        tribeStore.snoozeSuggestion(suggestion, minutes: 10, now: Date())
                    },
                    onDismissSuggestion: { suggestion in
                        tribeStore.dismissSuggestion(suggestion)
                    },
                    onViewCalendar: {
                        selectedTab = .calendar
                    }
                )
                    .withNavigationRouter()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("New") {
                                presentSheet(.runCreation)
                            }
                        }
                    }
            }
            .tabItem {
                Label(AppTab.runs.title, systemImage: AppTab.runs.systemImage)
            }
            .tag(AppTab.runs)

            NavigationStack(path: pathBinding(for: .calendar)) {
                CalendarView(suggestedRunsProvider: {
                    tribeStore.generateSuggestedRuns(now: selectedDateProxy())
                })
                    .withNavigationRouter()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Schedules") {
                                calendarPath.append(Destination.schedulesList)
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("New") {
                                presentSheet(.scheduleEditor(scheduleId: nil))
                            }
                        }
                    }
            }
            .tabItem {
                Label(AppTab.calendar.title, systemImage: AppTab.calendar.systemImage)
            }
            .tag(AppTab.calendar)

            NavigationStack(path: pathBinding(for: .family)) {
                FamilyRootView(store: tribeStore)
                    .withNavigationRouter()
            }
            .tabItem {
                Label(AppTab.family.title, systemImage: AppTab.family.systemImage)
            }
            .tag(AppTab.family)

            NavigationStack(path: $morePath) {
                MainMenuView(path: $morePath)
                    .withNavigationRouter()
            }
            .tabItem {
                Label(AppTab.more.title, systemImage: AppTab.more.systemImage)
            }
            .tag(AppTab.more)
        }
        .environmentObject(runDataSource)
        .environmentObject(scheduleDataSource)
        .environmentObject(driverDataSource)
        .environmentObject(householdContext)
        .environmentObject(householdDataSource)
        .environmentObject(locationService)
        .environmentObject(notificationService)
        .environmentObject(syncCoordinator)
        .task {
            householdDataSource.setOnHouseholdSwitched {
                async let runReload = runDataSource.reloadForHouseholdChange()
                async let scheduleReload = scheduleDataSource.reloadForHouseholdChange()
                async let driverReload = driverDataSource.reloadForHouseholdChange()
                _ = await (runReload, scheduleReload, driverReload)
                await syncCoordinator.pull(householdId: householdContext.householdId)
                await refreshDataSourcesAfterRemotePull()
                runDataSource.reconcileTrackingState(locationService: locationService)
                await notificationService.refreshAuthorizationState()
                if notificationService.authorizationState == .authorized
                    || notificationService.authorizationState == .provisional
                    || notificationService.authorizationState == .ephemeral {
                    await runDataSource.reconcileNotifications(notificationService: notificationService)
                }
            }

            await householdDataSource.refresh()
            await syncCoordinator.refreshStatus()
            await runDataSource.bootstrapIfNeeded()
            await scheduleDataSource.refresh()
            await driverDataSource.bootstrapIfNeeded()
            await syncCoordinator.pull(householdId: householdContext.householdId)
            await refreshDataSourcesAfterRemotePull()
            lastRemotePullAt = Date()
            runDataSource.reconcileTrackingState(locationService: locationService)
            await notificationService.refreshAuthorizationState()
            if notificationService.authorizationState == .authorized
                || notificationService.authorizationState == .provisional
                || notificationService.authorizationState == .ephemeral {
                await runDataSource.reconcileNotifications(notificationService: notificationService)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await householdDataSource.refresh()
                await syncCoordinator.refreshStatus()
                await runDataSource.refresh()
                await scheduleDataSource.refresh()
                await driverDataSource.refresh()
                if shouldPullRemoteNow {
                    await syncCoordinator.pull(householdId: householdContext.householdId)
                    await refreshDataSourcesAfterRemotePull()
                    lastRemotePullAt = Date()
                }
                runDataSource.reconcileTrackingState(locationService: locationService)
                await notificationService.refreshAuthorizationState()
                if notificationService.authorizationState == .authorized
                    || notificationService.authorizationState == .provisional
                    || notificationService.authorizationState == .ephemeral {
                    await runDataSource.reconcileNotifications(notificationService: notificationService)
                }
            }
        }
        .sheet(item: $presentedSheet, onDismiss: dismissSheet) { sheet in
            sheetView(sheet)
        }
    }

    private var allSystemRuns: [SystemDomain.RunInstance] {
        runDataSource.runs.sorted { $0.date < $1.date }
    }

    private var runBuckets: RunDataSource.RunBuckets {
        runDataSource.bucketedRuns(referenceDate: Date(), calendar: Calendar.current)
    }

    private var uiRuns: [UIRun] {
        allSystemRuns.map(RunUIAdapter.mapToUIRun)
    }

    private var activeRun: UIRun? {
        runBuckets.activeRuns.first.map(RunUIAdapter.mapToUIRun)
    }

    private var todayRuns: [UIRun] {
        runBuckets.todayRuns.map(RunUIAdapter.mapToUIRun)
    }

    private var upcomingRuns: [UIRun] {
        runBuckets.upcomingRuns.map(RunUIAdapter.mapToUIRun)
    }

    private var historyRuns: [UIRun] {
        runBuckets.historyRuns.map(RunUIAdapter.mapToUIRun)
    }

    private func selectedDateProxy() -> Date {
        Date()
    }

    private var shouldPullRemoteNow: Bool {
        guard let lastRemotePullAt else { return true }
        return Date().timeIntervalSince(lastRemotePullAt) >= minimumRemotePullInterval
    }

    private func refreshDataSourcesAfterRemotePull() async {
        await householdDataSource.refresh()
        async let runReload = runDataSource.reloadForHouseholdChange()
        async let scheduleReload = scheduleDataSource.reloadForHouseholdChange()
        async let driverReload = driverDataSource.reloadForHouseholdChange()
        _ = await (runReload, scheduleReload, driverReload)
    }

    private func pathBinding(for tab: AppTab) -> Binding<NavigationPath> {
        switch tab {
        case .home:
            return $homePath
        case .runs:
            return $runsPath
        case .calendar:
            return $calendarPath
        case .family:
            return $familyPath
        case .more:
            return $morePath
        }
    }

    private func presentSheet(_ sheet: DemoSheet) {
        guard presentedSheet == nil else { return }
        presentedSheet = sheet
    }

    private func dismissSheet() {
        presentedSheet = nil
    }

    @ViewBuilder
    private func sheetView(_ sheet: DemoSheet) -> some View {
        switch sheet {
        case .runCreation:
            NavigationStack {
                RunEditRescheduleView(run: RunDetailsData.scheduledRun) { _ in
                    dismissSheet()
                }
            }
        case .scheduleEditor:
            NavigationStack {
                ScheduleEditorView(mode: .create) { _ in
                    dismissSheet()
                }
            }
        case .runScheduledConfirmation:
            RunScheduledConfirmationView()
        }
    }
}

#Preview {
    DemoShellView()
}
