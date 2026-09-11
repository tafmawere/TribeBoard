import SwiftUI

private enum HouseholdBootstrapPhase: Equatable {
    case idle
    case loading
    case resolved(hasHousehold: Bool)
    case loadFailed(message: String)
}

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
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var backendProfileContext: BackendProfileContext
    @StateObject private var tribeStore: TribeStore
    @StateObject private var runDataSource: RunDataSource
    @StateObject private var scheduleDataSource: ScheduleDataSource
    @StateObject private var driverDataSource: DriverDataSource
    @StateObject private var householdContext: ActiveHouseholdContext
    @StateObject private var activeHouseholdStore: ActiveHouseholdStore
    @StateObject private var householdDataSource: HouseholdDataSource
    @StateObject private var backendHouseholdContext: BackendHouseholdContext
    @StateObject private var backendHouseholdPeopleContext: BackendHouseholdPeopleContext
    @StateObject private var backendEmergencyContactsContext: BackendEmergencyContactsContext
    @StateObject private var backendChildrenContext: BackendChildrenContext
    @StateObject private var backendHouseholdLocationsContext: BackendHouseholdLocationsContext
    @StateObject private var backendSchedulesContext: BackendSchedulesContext
    @StateObject private var backendRunsContext: BackendRunsContext
    @StateObject private var backendDriversContext: BackendDriversContext
    @StateObject private var realtimeService: SupabaseRealtimeService
    @StateObject private var networkMonitor: NetworkMonitor
    @StateObject private var locationService: LocationReadinessService
    @StateObject private var familyQuickPlacesStore: FamilyQuickPlacesStore
    @StateObject private var notificationService: NotificationService
    @StateObject private var syncCoordinator: SyncCoordinator
    @StateObject private var backendWriteDiagnostics = BackendWriteDiagnosticsStore.shared
    @State private var selectedTab: AppTab
    @State private var runsOverviewTab: RunsOverviewTab = .today
    @State private var showRunsDispatchSheet = false
    @State private var homePath = NavigationPath()
    @State private var runsPath = NavigationPath()
    @State private var calendarPath = NavigationPath()
    @State private var familyPath = NavigationPath()
    @State private var morePath = NavigationPath()
    @State private var presentedSheet: DemoSheet?
    @State private var lastRemotePullAt: Date?
    @State private var initializedForAuthUserId: String?
    @State private var childrenLoadedHouseholdId: UUID?
    @State private var isShowingJoinHouseholdSheet = false
    @State private var isShowingCreateHouseholdSheet = false
    @State private var householdBootstrapPhase: HouseholdBootstrapPhase = .idle
    @State private var isDependentHouseholdDataLoading = false
    @State private var dependentDataLoadedHouseholdId: UUID?
    @State private var lastHandledActiveHouseholdId: UUID?
    @State private var syncDebounceTask: Task<Void, Never>?
    @State private var isRealtimeRunRefreshInFlight = false
    @State private var hasPendingRealtimeRunRefresh = false
    @StateObject private var activeRunDriverSessionStore = ActiveRunDriverSessionStore()
    @StateObject private var runLocationObserverStore = RunLocationObserverStore()
    @State private var locationPublishService: RunLocationPublishService?
    private let minimumRemotePullInterval: TimeInterval = 60

    init(store: TribeStore, initialTab: AppTab = .home) {
        let runRepository = LocalRunRepository()
        let scheduleRepository = LocalScheduleRepository()
        let driverRepository = LocalDriverRepository()
        let householdContext = ActiveHouseholdContext()
        let activeHouseholdStore = ActiveHouseholdStore()
        let householdRepository = LocalHouseholdRepository()
        let syncCoordinator = SyncCoordinator(
            queueRepository: LocalSyncQueueRepository(),
            auditRepository: LocalSyncAuditRepository(),
            processedChangeRepository: LocalProcessedChangeRepository(),
            remoteDriver: nil,
            runRepository: runRepository,
            scheduleRepository: scheduleRepository,
            driverRepository: driverRepository,
            householdRepository: householdRepository
        )
        let backendRunsContext = BackendRunsContext(
            runRepository: runRepository,
            scheduleRepository: scheduleRepository,
            driverRepository: driverRepository
        )
        _tribeStore = StateObject(wrappedValue: store)
        let runDataSource = RunDataSource(
            repository: runRepository,
            scheduleRepository: scheduleRepository,
            driverRepository: driverRepository,
            householdContext: householdContext,
            backendRunsContext: backendRunsContext,
            syncCoordinator: syncCoordinator
        )
        _runDataSource = StateObject(wrappedValue: runDataSource)
        let scheduleDataSource = ScheduleDataSource(
            repository: scheduleRepository,
            householdContext: householdContext,
            syncCoordinator: syncCoordinator,
            backendRunsContext: backendRunsContext
        )
        _scheduleDataSource = StateObject(wrappedValue: scheduleDataSource)
        _driverDataSource = StateObject(
            wrappedValue: DriverDataSource(
                repository: driverRepository,
                householdContext: householdContext,
                syncCoordinator: syncCoordinator
            )
        )
        _householdContext = StateObject(wrappedValue: householdContext)
        _activeHouseholdStore = StateObject(wrappedValue: activeHouseholdStore)
        let householdDataSource = HouseholdDataSource(
            repository: householdRepository,
            activeContext: householdContext,
            syncCoordinator: syncCoordinator
        )
        _householdDataSource = StateObject(wrappedValue: householdDataSource)
        let backendHouseholdContext = BackendHouseholdContext(
            localHouseholdContext: householdContext,
            localHouseholdDataSource: householdDataSource,
            activeHouseholdStore: activeHouseholdStore
        )
        _backendHouseholdContext = StateObject(wrappedValue: backendHouseholdContext)
        _backendHouseholdPeopleContext = StateObject(
            wrappedValue: BackendHouseholdPeopleContext(activeHouseholdStore: activeHouseholdStore)
        )
        _backendEmergencyContactsContext = StateObject(
            wrappedValue: BackendEmergencyContactsContext(activeHouseholdStore: activeHouseholdStore)
        )
        let backendHouseholdLocationsContext = BackendHouseholdLocationsContext(
            householdContext: backendHouseholdContext
        )
        _backendHouseholdLocationsContext = StateObject(wrappedValue: backendHouseholdLocationsContext)
        _backendChildrenContext = StateObject(
            wrappedValue: BackendChildrenContext(
                householdContext: backendHouseholdContext,
                store: store,
                householdLocationsContext: backendHouseholdLocationsContext
            )
        )
        _backendSchedulesContext = StateObject(
            wrappedValue: BackendSchedulesContext(
                scheduleDataSource: scheduleDataSource,
                syncCoordinator: syncCoordinator,
                householdLocationsContext: backendHouseholdLocationsContext
            )
        )
        _backendRunsContext = StateObject(wrappedValue: backendRunsContext)
        _backendDriversContext = StateObject(
            wrappedValue: BackendDriversContext(
                backendRunsContext: backendRunsContext,
                syncCoordinator: syncCoordinator,
                runDataSource: runDataSource
            )
        )
        _realtimeService = StateObject(wrappedValue: SupabaseRealtimeService())
        _networkMonitor = StateObject(wrappedValue: NetworkMonitor())
        let locationService = LocationReadinessService()
        _locationService = StateObject(wrappedValue: locationService)
        _locationPublishService = State(initialValue: RunLocationPublishService(locationService: locationService))
        _familyQuickPlacesStore = StateObject(wrappedValue: FamilyQuickPlacesStore())
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
        let activeHouseholdStore = ActiveHouseholdStore()
        let householdRepository = LocalHouseholdRepository()
        let syncCoordinator = SyncCoordinator(
            queueRepository: LocalSyncQueueRepository(),
            auditRepository: LocalSyncAuditRepository(),
            processedChangeRepository: LocalProcessedChangeRepository(),
            remoteDriver: nil,
            runRepository: runRepository,
            scheduleRepository: scheduleRepository,
            driverRepository: driverRepository,
            householdRepository: householdRepository
        )
        let backendRunsContext = BackendRunsContext(
            runRepository: runRepository,
            scheduleRepository: scheduleRepository,
            driverRepository: driverRepository
        )
        let store = TribeStore(demoFlow: true)
        _tribeStore = StateObject(wrappedValue: store)
        let runDataSource = RunDataSource(
            repository: runRepository,
            scheduleRepository: scheduleRepository,
            driverRepository: driverRepository,
            householdContext: householdContext,
            backendRunsContext: backendRunsContext,
            syncCoordinator: syncCoordinator
        )
        _runDataSource = StateObject(wrappedValue: runDataSource)
        let scheduleDataSource = ScheduleDataSource(
            repository: scheduleRepository,
            householdContext: householdContext,
            syncCoordinator: syncCoordinator,
            backendRunsContext: backendRunsContext
        )
        _scheduleDataSource = StateObject(wrappedValue: scheduleDataSource)
        _driverDataSource = StateObject(
            wrappedValue: DriverDataSource(
                repository: driverRepository,
                householdContext: householdContext,
                syncCoordinator: syncCoordinator
            )
        )
        _householdContext = StateObject(wrappedValue: householdContext)
        _activeHouseholdStore = StateObject(wrappedValue: activeHouseholdStore)
        let householdDataSource = HouseholdDataSource(
            repository: householdRepository,
            activeContext: householdContext,
            syncCoordinator: syncCoordinator
        )
        _householdDataSource = StateObject(wrappedValue: householdDataSource)
        let backendHouseholdContext = BackendHouseholdContext(
            localHouseholdContext: householdContext,
            localHouseholdDataSource: householdDataSource,
            activeHouseholdStore: activeHouseholdStore
        )
        _backendHouseholdContext = StateObject(wrappedValue: backendHouseholdContext)
        _backendHouseholdPeopleContext = StateObject(
            wrappedValue: BackendHouseholdPeopleContext(activeHouseholdStore: activeHouseholdStore)
        )
        _backendEmergencyContactsContext = StateObject(
            wrappedValue: BackendEmergencyContactsContext(activeHouseholdStore: activeHouseholdStore)
        )
        let backendHouseholdLocationsContext = BackendHouseholdLocationsContext(
            householdContext: backendHouseholdContext
        )
        _backendHouseholdLocationsContext = StateObject(wrappedValue: backendHouseholdLocationsContext)
        _backendChildrenContext = StateObject(
            wrappedValue: BackendChildrenContext(
                householdContext: backendHouseholdContext,
                store: store,
                householdLocationsContext: backendHouseholdLocationsContext
            )
        )
        _backendSchedulesContext = StateObject(
            wrappedValue: BackendSchedulesContext(
                scheduleDataSource: scheduleDataSource,
                syncCoordinator: syncCoordinator,
                householdLocationsContext: backendHouseholdLocationsContext
            )
        )
        _backendRunsContext = StateObject(wrappedValue: backendRunsContext)
        _backendDriversContext = StateObject(
            wrappedValue: BackendDriversContext(
                backendRunsContext: backendRunsContext,
                syncCoordinator: syncCoordinator,
                runDataSource: runDataSource
            )
        )
        _realtimeService = StateObject(wrappedValue: SupabaseRealtimeService())
        _networkMonitor = StateObject(wrappedValue: NetworkMonitor())
        let locationService = LocationReadinessService()
        _locationService = StateObject(wrappedValue: locationService)
        _locationPublishService = State(initialValue: RunLocationPublishService(locationService: locationService))
        _familyQuickPlacesStore = StateObject(wrappedValue: FamilyQuickPlacesStore())
        _notificationService = StateObject(wrappedValue: NotificationService())
        _syncCoordinator = StateObject(wrappedValue: syncCoordinator)
        _selectedTab = State(initialValue: .home)
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            homeTab
            runsTab
            calendarTab
            familyTab
            moreTab
        }
        .onReceive(NotificationCenter.default.publisher(for: .tribeboardOpenFamilyForDriverSetup)) { _ in
            selectedTab = .family
        }
    }

    private var homeTab: some View {
        NavigationStack(path: pathBinding(for: .home)) {
            Group {
                if shouldShowHouseholdLoadFailure {
                    householdLoadFailedCard
                } else if shouldShowNoHouseholdOnboarding {
                    noHouseholdOnboardingCard
                } else {
                    homeTabContent
                }
            }
            .onAppear { logTabState(tab: "Home") }
        }
        .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.systemImage) }
        .tag(AppTab.home)
    }

    private var homeTabContent: some View {
        HomeView(
            onOpenRuns: { selectedTab = .runs },
            onOpenDispatch: {
                selectedTab = .runs
                showRunsDispatchSheet = true
            },
            onOpenCalendar: { selectedTab = .calendar },
            onOpenFamily: { selectedTab = .family },
            onCreateRun: { selectedTab = .runs },
            onOpenDriverMode: { homePath.append(Destination.driverModeSelector) },
            onOpenRunDetails: { runId in homePath.append(Destination.runDetails(runId: runId)) },
            onOpenProfile: { homePath.append(Destination.profile) },
            onOpenNotifications: { homePath.append(Destination.notificationsInbox) },
            isContentLoading: isHouseholdContentLoading
        )
        .withNavigationRouter()
    }

    private var runsTab: some View {
        NavigationStack(path: pathBinding(for: .runs)) {
            runsTabContent
        }
        .tabItem { Label(AppTab.runs.title, systemImage: AppTab.runs.systemImage) }
        .tag(AppTab.runs)
    }

    @ViewBuilder
    private var runsTabContent: some View {
        if shouldShowHouseholdLoadFailure {
            householdLoadFailedCard
        } else if shouldShowNoHouseholdOnboarding {
            noHouseholdOnboardingCard
        } else if shouldShowPendingApprovalState {
            pendingApprovalAccessCard
        } else if isHouseholdContentLoading {
            HouseholdTabSkeletonView(showsSyncingStatus: true)
        } else {
            RunsOverviewView(
                selectedTab: $runsOverviewTab,
                isDispatchPresented: $showRunsDispatchSheet,
                permissions: RunsOverviewPermissions(
                    canManageSchedules: backendHouseholdContext.canManageSchedules,
                    canAssignDrivers: backendHouseholdContext.canManageMembers,
                    canOpenDriverMode: backendHouseholdContext.canStartRuns,
                    canObserveTracking: backendHouseholdContext.canViewRunTracking,
                    canCreateRun: canPerformHouseholdScopedActions,
                    canPerformRunActions: backendHouseholdContext.canUpdateRuns
                ),
                todayRuns: todayRuns,
                upcomingRuns: upcomingRuns,
                historyRuns: historyRuns,
                activeRun: activeRun,
                suggestedRuns: tribeStore.generateSuggestedRuns(now: Date()),
                onCreateRun: { presentSheet(.runCreation) },
                onOpenDriverMode: { runsPath.append(Destination.driverModeSelector) },
                onDispatchCreateRun: { presentSheet(.runCreation) },
                onDispatchOpenCalendar: { selectedTab = .calendar },
                onOpenRunDetails: { run in runsPath.append(Destination.runDetails(runId: run.backingRunId)) },
                onOpenObserver: { run in runsPath.append(Destination.runDetails(runId: run.backingRunId)) },
                onStartSuggestion: { suggestion in _ = tribeStore.createRunInstanceFromSuggestion(suggestion, now: Date()) },
                onSnoozeSuggestion: { suggestion in tribeStore.snoozeSuggestion(suggestion, minutes: 10, now: Date()) },
                onDismissSuggestion: { suggestion in tribeStore.dismissSuggestion(suggestion) },
                onViewCalendar: { selectedTab = .calendar }
            )
            .withNavigationRouter()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New") { presentSheet(.runCreation) }
                        .disabled(!canPerformHouseholdScopedActions)
                }
            }
        }
    }

    private var calendarTab: some View {
        NavigationStack(path: pathBinding(for: .calendar)) {
            calendarTabContent
        }
        .tabItem { Label(AppTab.calendar.title, systemImage: AppTab.calendar.systemImage) }
        .tag(AppTab.calendar)
    }

    @ViewBuilder
    private var calendarTabContent: some View {
        if shouldShowHouseholdLoadFailure {
            householdLoadFailedCard
        } else if shouldShowNoHouseholdOnboarding {
            noHouseholdOnboardingCard
        } else if shouldShowPendingApprovalState {
            pendingApprovalAccessCard
        } else if isHouseholdContentLoading {
            HouseholdTabSkeletonView(showsSyncingStatus: true)
        } else {
            CalendarView(
                suggestedRunsProvider: { tribeStore.generateSuggestedRuns(now: selectedDateProxy()) },
                childMembersProvider: { tribeStore.children() },
                driverNameProvider: { driverId in driverDataSource.drivers.first(where: { $0.id == driverId })?.name }
            )
            .withNavigationRouter()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schedules") { calendarPath.append(Destination.schedulesList) }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New") { presentSheet(.scheduleEditor(scheduleId: nil)) }
                        .disabled(!canPerformHouseholdScopedActions)
                }
            }
        }
    }

    private var familyTab: some View {
        NavigationStack(path: pathBinding(for: .family)) {
            familyTabContent
                .onAppear { logTabState(tab: "Tribe") }
        }
        .tabItem { Label(AppTab.family.title, systemImage: AppTab.family.systemImage) }
        .tag(AppTab.family)
    }

    @ViewBuilder
    private var familyTabContent: some View {
        if shouldShowHouseholdLoadFailure {
            householdLoadFailedCard
        } else if shouldShowNoHouseholdOnboarding {
            noHouseholdOnboardingCard
        } else if shouldShowPendingApprovalState {
            pendingApprovalAccessCard
        } else if isHouseholdContentLoading {
            HouseholdTabSkeletonView(showsSyncingStatus: true)
        } else {
            FamilyRootView(store: tribeStore)
                .withNavigationRouter()
        }
    }

    private var moreTab: some View {
        NavigationStack(path: $morePath) {
            moreTabContent
                .onAppear { logTabState(tab: "More") }
        }
        .tabItem { Label(AppTab.more.title, systemImage: AppTab.more.systemImage) }
        .tag(AppTab.more)
    }

    @ViewBuilder
    private var moreTabContent: some View {
        if shouldShowHouseholdLoadFailure {
            householdLoadFailedCard
        } else if shouldShowNoHouseholdOnboarding {
            noHouseholdOnboardingCard
        } else if isHouseholdContentLoading {
            HouseholdTabSkeletonView(showsSyncingStatus: true)
        } else {
            MainMenuView(path: $morePath)
                .withNavigationRouter()
        }
    }

    var body: some View {
        mainTabView
        .environmentObject(runDataSource)
        .environmentObject(scheduleDataSource)
        .environmentObject(driverDataSource)
        .environmentObject(backendProfileContext)
        .environmentObject(householdContext)
        .environmentObject(activeHouseholdStore)
        .environmentObject(householdDataSource)
        .environmentObject(backendHouseholdContext)
        .environmentObject(backendHouseholdPeopleContext)
        .environmentObject(backendEmergencyContactsContext)
        .environmentObject(backendChildrenContext)
        .environmentObject(backendHouseholdLocationsContext)
        .environmentObject(backendSchedulesContext)
        .environmentObject(backendRunsContext)
        .environmentObject(backendDriversContext)
        .environmentObject(realtimeService)
        .environmentObject(networkMonitor)
        .environmentObject(locationService)
        .environmentObject(familyQuickPlacesStore)
        .environmentObject(notificationService)
        .environmentObject(syncCoordinator)
        .environmentObject(backendWriteDiagnostics)
        .environmentObject(activeRunDriverSessionStore)
        .environmentObject(runLocationObserverStore)
        .fullScreenCover(item: $activeRunDriverSessionStore.presentation) { session in
            ActiveRunDriverView(runId: session.id)
                .environmentObject(runDataSource)
                .environmentObject(locationService)
                .environmentObject(backendDriversContext)
                .environmentObject(backendHouseholdContext)
                .environmentObject(backendHouseholdLocationsContext)
                .environmentObject(familyQuickPlacesStore)
                .environmentObject(activeRunDriverSessionStore)
        }
        .task {
            if activeHouseholdStore.restoredActiveHouseholdId != nil {
                householdBootstrapPhase = .resolved(hasHousehold: true)
            }
            locationService.prepareMapsAndLocation()
            networkMonitor.onReconnect = {
                requestSync(reason: "network_reconnect")
            }
            realtimeService.onEvent = { event in
                Task {
                    await backendChildrenContext.handleRealtimeEvent(event)
                    await backendHouseholdContext.handleRealtimeEvent(event)
                    updateFamilySummary()
                    if event.entityType == .run || event.entityType == .runAssignment,
                       let householdId = event.householdId {
                        await runSafeRealtimeRunRefresh(householdId: householdId)
                    }
                    if event.entityType == .runDriverPosition,
                       let householdId = event.householdId {
                        await runLocationObserverStore.refreshNow(householdId: householdId)
                    }
                }
            }
            householdDataSource.setOnHouseholdSwitched {
                async let runReload: Void = runDataSource.reloadForHouseholdChange()
                async let scheduleReload: Void = scheduleDataSource.reloadForHouseholdChange()
                async let driverReload: Void = driverDataSource.reloadForHouseholdChange()
                _ = await (runReload, scheduleReload, driverReload)
                if let scopedHouseholdId {
                    await refreshDriverCandidates(householdId: scopedHouseholdId)
                    await backendHouseholdPeopleContext.refreshPeople(householdId: scopedHouseholdId)
                    await backendEmergencyContactsContext.refreshContacts(householdId: scopedHouseholdId)
                    updateFamilySummary()
                    await syncCoordinator.pull(householdId: scopedHouseholdId)
                    requestSync(reason: "household_switched")
                }
                await refreshDataSourcesAfterRemotePull()
                reconcileLiveRunSystems()
                await notificationService.refreshAuthorizationState()
                if notificationService.authorizationState == .authorized
                    || notificationService.authorizationState == .provisional
                    || notificationService.authorizationState == .ephemeral {
                    await runDataSource.reconcileNotifications(notificationService: notificationService)
                }
            }
            await runInitializationPipeline()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await runInitializationPipeline(forceRemotePull: shouldPullRemoteNow)
            }
        }
        .sheet(item: $presentedSheet, onDismiss: dismissSheet) { sheet in
            sheetView(sheet)
        }
        .sheet(isPresented: $isShowingJoinHouseholdSheet) {
            NavigationStack {
                JoinHouseholdView(onJoined: {
                    await runInitializationPipeline()
                })
                .environmentObject(backendHouseholdContext)
                .environmentObject(backendChildrenContext)
                .environmentObject(realtimeService)
            }
        }
        .sheet(isPresented: $isShowingCreateHouseholdSheet) {
            NavigationStack {
                CreateHouseholdSheet {
                    await runInitializationPipeline()
                }
                .environmentObject(backendHouseholdContext)
            }
        }
        .onChange(of: activeHouseholdStore.activeHouseholdId) { _, householdId in
            Task {
                await handleActiveHouseholdChanged(to: householdId)
            }
        }
        .onChange(of: runDataSource.runs.map { "\($0.id.uuidString):\($0.status.rawValue)" }.joined()) { _, _ in
            reconcileLiveRunSystems()
        }
        .onChange(of: authSession.isAuthenticated) { _, authenticated in
            Task {
                if authenticated {
                    if activeHouseholdStore.restoredActiveHouseholdId == nil {
                        householdBootstrapPhase = .loading
                    }
                    dependentDataLoadedHouseholdId = nil
                    await runInitializationPipeline()
                    requestSync(reason: "auth_signin")
                } else {
                    await handleSignedOutStateCleanup()
                }
            }
        }
        .onChange(of: shouldShowNoHouseholdOnboarding) { _, isShowing in
#if DEBUG
            let selected = activeHouseholdStore.activeHouseholdId?.uuidString ?? "nil"
            print(
                "[Bootstrap] no-household-ui shown=\(isShowing), auth.uid=\(authSession.currentUserId ?? "nil"), " +
                "bootstrap_phase=\(bootstrapPhaseDebugLabel), memberships.count=\(backendHouseholdContext.memberships.count), " +
                "selected_active_household_id=\(selected)"
            )
#endif
        }
        .onChange(of: backendHouseholdContext.activeHouseholdMembers) { _, _ in
            updateFamilySummary()
        }
        .onChange(of: backendHouseholdPeopleContext.people) { _, _ in
            updateFamilySummary()
        }
        .onChange(of: backendChildrenContext.children) { _, _ in
            updateFamilySummary()
        }
        .onDisappear {
            Task {
                await realtimeService.unsubscribe()
            }
        }
    }

    private var allSystemRuns: [SystemDomain.RunInstance] {
        runDataSource.runs.sorted { $0.date < $1.date }
    }

    private var runBuckets: RunDataSource.RunBuckets {
        runDataSource.bucketedRuns(referenceDate: Date(), calendar: Calendar.current)
    }

    private var uiRuns: [UIRun] {
        allSystemRuns.map(mapToUIRun)
    }

    private var activeRun: UIRun? {
        runBuckets.activeRuns.first.map(mapToUIRun)
    }

    private var todayRuns: [UIRun] {
        runBuckets.todayRuns.map(mapToUIRun)
    }

    private var upcomingRuns: [UIRun] {
        runBuckets.upcomingRuns.map(mapToUIRun)
    }

    private var historyRuns: [UIRun] {
        runBuckets.historyRuns.map(mapToUIRun)
    }

    private func mapToUIRun(_ run: SystemDomain.RunInstance) -> UIRun {
        RunUIAdapter.mapToUIRun(
            run,
            childName: RunDisplayStrings.childName(for: run, children: backendChildrenContext.children)
        )
    }

    private func selectedDateProxy() -> Date {
        Date()
    }

    private var shouldPullRemoteNow: Bool {
        guard let lastRemotePullAt else { return true }
        return Date().timeIntervalSince(lastRemotePullAt) >= minimumRemotePullInterval
    }

    private var isHouseholdContentLoading: Bool {
        guard authSession.isAuthenticated, authSession.didRestoreSession else { return false }
        if shouldShowNoHouseholdOnboarding { return false }
        switch householdBootstrapPhase {
        case .idle:
            return true
        case .loading:
            return activeHouseholdStore.restoredActiveHouseholdId == nil
        case .loadFailed:
            return false
        case .resolved(let hasHousehold):
            guard hasHousehold else { return false }
            guard let activeHouseholdId = activeHouseholdStore.activeHouseholdId else { return true }
            return isDependentHouseholdDataLoading || dependentDataLoadedHouseholdId != activeHouseholdId
        }
    }

    private var shouldShowHouseholdLoadFailure: Bool {
        guard authSession.isAuthenticated, authSession.didRestoreSession else { return false }
        if case .loadFailed = householdBootstrapPhase {
            return true
        }
        return false
    }

    private var householdLoadFailureMessage: String {
        if case .loadFailed(let message) = householdBootstrapPhase {
            return message
        }
        return BackendUserFacingErrorMapper.genericLoadFailure
    }

    private var shouldShowNoHouseholdOnboarding: Bool {
        guard authSession.isAuthenticated, authSession.didRestoreSession else { return false }
        if case .resolved(let hasHousehold) = householdBootstrapPhase {
            return !hasHousehold || !backendHouseholdContext.hasActiveMembership
        }
        return false
    }

    private var currentUserMembershipStatusForActiveHousehold: HouseholdMembershipStatus? {
        backendHouseholdContext.currentUserMembershipStatusForActiveHousehold()
    }

    private var shouldShowPendingApprovalState: Bool {
        guard authSession.isAuthenticated, authSession.didRestoreSession else { return false }
        guard activeHouseholdStore.activeHouseholdId != nil else { return false }
        return currentUserMembershipStatusForActiveHousehold == .pending
    }

    private var bootstrapPhaseDebugLabel: String {
        switch householdBootstrapPhase {
        case .idle: return "idle"
        case .loading: return "loading"
        case .loadFailed: return "load_failed"
        case .resolved(let hasHousehold): return hasHousehold ? "resolved_with_household" : "resolved_no_household"
        }
    }

    private var resolvedActiveHouseholdName: String {
        guard let activeHouseholdId = activeHouseholdStore.activeHouseholdId else {
            return backendHouseholdContext.memberships.isEmpty ? "None" : "Loading household..."
        }
        if let name = backendHouseholdContext.households.first(where: { $0.id == activeHouseholdId })?.name,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        return backendHouseholdContext.memberships.isEmpty ? "None" : "Loading household..."
    }

    private var resolvedProfileDisplayName: String {
        backendProfileContext.currentUserProfile?.resolvedDisplayName(
            providerDisplayName: authSession.currentUserProviderDisplayName,
            fallbackEmail: authSession.currentUserEmail
        ).value ?? "User"
    }

    private func reconcileLiveRunSystems() {
        runDataSource.reconcileTrackingState(
            locationService: locationService,
            locationPublishService: locationPublishService,
            currentUserId: authSession.currentUserId.flatMap(UUID.init(uuidString:)),
            drivers: backendDriversContext.drivers
        )
        let householdId = activeHouseholdStore.activeHouseholdId ?? householdContext.householdId
        runLocationObserverStore.startObserving(householdId: householdId)
    }

    private func logTabState(tab: String) {
#if DEBUG
        let activeHouseholdId = activeHouseholdStore.activeHouseholdId?.uuidString ?? "nil"
        let profileDisplay = backendProfileContext.currentUserProfile?.display_name ?? resolvedProfileDisplayName
        let homeHousehold = resolvedActiveHouseholdName
        let moreHousehold = resolvedActiveHouseholdName
        let tribeMode = shouldShowNoHouseholdOnboarding ? "create_flow" : "active_household_flow"
        print(
            "[TabState] tab=\(tab), auth.uid=\(authSession.currentUserId ?? "nil"), " +
            "currentUserProfile.displayName=\(profileDisplay), memberships.count=\(backendHouseholdContext.memberships.count), " +
            "households.count=\(backendHouseholdContext.households.count), activeHouseholdId=\(activeHouseholdId), " +
            "home_household_name=\(homeHousehold), more_household_name=\(moreHousehold), tribe_mode=\(tribeMode)"
        )
#endif
    }

    private var pendingApprovalAccessCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "hourglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.indigo)
            Text("Waiting for approval")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
            Text("The household admin must approve your access before runs, calendar, and family data become available.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func refreshDataSourcesAfterRemotePull() async {
        if !authSession.isAuthenticated {
            await householdDataSource.refresh()
        }
        async let runReload: Void = runDataSource.reloadForHouseholdChange()
        async let scheduleReload: Void = scheduleDataSource.reloadForHouseholdChange()
        async let driverReload: Void = driverDataSource.reloadForHouseholdChange()
        _ = await (runReload, scheduleReload, driverReload)
    }

    private func updateRealtimeSubscription() async {
        guard authSession.isAuthenticated else {
            await realtimeService.unsubscribe()
            return
        }
        guard let householdId = activeHouseholdStore.activeHouseholdId else {
            await realtimeService.unsubscribe()
            return
        }
        guard childrenLoadedHouseholdId == householdId else {
            await realtimeService.unsubscribe()
            return
        }
        await realtimeService.reconnectForHousehold(householdId: householdId)
    }

    private var canPerformHouseholdScopedActions: Bool {
        if !authSession.isAuthenticated {
            return true
        }
        return backendHouseholdContext.hasActiveMembership && activeHouseholdStore.activeHouseholdId != nil
    }

    private var scopedHouseholdId: UUID? {
        if authSession.isAuthenticated {
            return activeHouseholdStore.activeHouseholdId
        }
        return householdContext.householdId
    }

    private func runInitializationPipeline(forceRemotePull: Bool = true) async {
        await authSession.restoreSession()
        guard authSession.isAuthenticated else {
            await handleSignedOutStateCleanup()
            return
        }

#if DEBUG
        print("[Bootstrap] auth.uid=\(authSession.currentUserId ?? "nil"), stage=session_confirmed")
#endif

        if initializedForAuthUserId != authSession.currentUserId {
            childrenLoadedHouseholdId = nil
            dependentDataLoadedHouseholdId = nil
        }

        let cachedHouseholdId = activeHouseholdStore.restoredActiveHouseholdId
        if cachedHouseholdId != nil {
            // Hide stale persisted selection until membership refresh validates it.
            activeHouseholdStore.clear()
        }
        householdBootstrapPhase = .loading

        await backendProfileContext.ensureProfileExists(
            email: authSession.currentUserEmail,
            providerDisplayName: authSession.currentUserProviderDisplayName
        )
        await backendProfileContext.refreshProfile(
            authEmail: authSession.currentUserEmail,
            providerDisplayName: authSession.currentUserProviderDisplayName
        )
        if backendProfileContext.currentUserProfile == nil && backendProfileContext.lastError == nil {
            await backendProfileContext.refreshProfile(
                authEmail: authSession.currentUserEmail,
                providerDisplayName: authSession.currentUserProviderDisplayName
            )
        }
#if DEBUG
        let profile = backendProfileContext.currentUserProfile
        print(
            "[Bootstrap] auth.uid=\(authSession.currentUserId ?? "nil"), profile_fetch_result=" +
            "\(profile?.id.uuidString ?? "nil"), display_name=\(profile?.display_name ?? "nil"), first_name=\(profile?.first_name ?? "nil")"
        )
#endif
        await backendHouseholdContext.refresh()
#if DEBUG
        let beforeSelection = activeHouseholdStore.activeHouseholdId?.uuidString ?? "nil"
        print(
            "[Bootstrap] auth.uid=\(authSession.currentUserId ?? "nil"), " +
            "membership_count=\(backendHouseholdContext.memberships.count), household_count=\(backendHouseholdContext.households.count), " +
            "activeHouseholdId.before=\(beforeSelection)"
        )
        print("[Bootstrap] MEMBERSHIPS COUNT=\(backendHouseholdContext.memberships.count)")
#endif
        if backendHouseholdContext.memberships.isEmpty,
           let loadError = backendHouseholdContext.lastError,
           !loadError.isEmpty,
           !isCancellationMessage(loadError) {
            householdBootstrapPhase = .loadFailed(message: loadError)
#if DEBUG
            print("[Bootstrap] household refresh failed error=\(loadError)")
#endif
            return
        }
        if backendHouseholdContext.memberships.isEmpty {
            activeHouseholdStore.clear()
            childrenLoadedHouseholdId = nil
            dependentDataLoadedHouseholdId = nil
            await realtimeService.unsubscribe()
            runDataSource.clearHouseholdScopedData()
            scheduleDataSource.clearHouseholdScopedData()
            householdBootstrapPhase = .resolved(hasHousehold: false)
#if DEBUG
            print(
                "[Bootstrap] auth.uid=\(authSession.currentUserId ?? "nil"), selected_active_household_id=nil, " +
                "activeHouseholdId.after=nil, no-household-ui=true"
            )
#endif
            return
        }

        let resolvedActiveHouseholdId = backendHouseholdContext.ensureActiveHouseholdSelectionFromMemberships()

        guard let activeHouseholdId = resolvedActiveHouseholdId else {
            childrenLoadedHouseholdId = nil
            dependentDataLoadedHouseholdId = nil
            await realtimeService.unsubscribe()
            runDataSource.clearHouseholdScopedData()
            scheduleDataSource.clearHouseholdScopedData()
            householdBootstrapPhase = .resolved(hasHousehold: false)
#if DEBUG
            print(
                "[Bootstrap] auth.uid=\(authSession.currentUserId ?? "nil"), selected_active_household_id=nil, " +
                "activeHouseholdId.after=nil, no-household-ui=\(backendHouseholdContext.memberships.isEmpty)"
            )
#endif
            return
        }
        activeHouseholdStore.setActiveHousehold(id: activeHouseholdId)
#if DEBUG
        let afterSelection = activeHouseholdStore.activeHouseholdId?.uuidString ?? "nil"
        print(
            "[Bootstrap] auth.uid=\(authSession.currentUserId ?? "nil"), selected_active_household_id=\(activeHouseholdId.uuidString), " +
            "activeHouseholdId.after=\(afterSelection)"
        )
        print("[Bootstrap] ACTIVE HOUSEHOLD RESOLVED activeHouseholdId=\(afterSelection)")
#endif

        if cachedHouseholdId == activeHouseholdId {
            await preloadCachedHouseholdData(householdId: activeHouseholdId)
        }

        if let activeHousehold = backendHouseholdContext.households.first(where: { $0.id == activeHouseholdId }) {
            await householdDataSource.adoptBackendHousehold(
                id: activeHousehold.id,
                name: activeHousehold.name
            )

            if tribeStore.tribe == nil {
                tribeStore.createTribe(
                    name: activeHousehold.name,
                    tribeCode: formatHouseholdJoinCode(householdId: activeHousehold.id)
                )
            }
        }

        await refreshDependentHouseholdData(householdId: activeHouseholdId, source: "bootstrap")
        await refreshDriverCandidates(householdId: activeHouseholdId)

        await updateRealtimeSubscription()
        await syncCoordinator.refreshStatus()
        await runDataSource.bootstrapIfNeeded()
        await scheduleDataSource.refresh()
        await driverDataSource.bootstrapIfNeeded()

        if forceRemotePull, let scopedHouseholdId {
            await syncCoordinator.pull(householdId: scopedHouseholdId)
            await refreshDataSourcesAfterRemotePull()
            lastRemotePullAt = Date()
        }
        householdBootstrapPhase = .resolved(hasHousehold: true)
        requestSync(reason: "initialization_pipeline")

        reconcileLiveRunSystems()
        await notificationService.refreshAuthorizationState()
        if notificationService.authorizationState == .authorized
            || notificationService.authorizationState == .provisional
            || notificationService.authorizationState == .ephemeral {
            await runDataSource.reconcileNotifications(notificationService: notificationService)
        }

        initializedForAuthUserId = authSession.currentUserId
#if DEBUG
        print(
            "[Bootstrap] auth.uid=\(authSession.currentUserId ?? "nil"), bootstrap_complete=true, no-household-ui=false"
        )
#endif
    }

    private func preloadCachedHouseholdData(householdId: UUID) async {
        await householdDataSource.refresh()
        await runDataSource.bootstrapIfNeeded()
        await scheduleDataSource.refresh()
        await driverDataSource.bootstrapIfNeeded()
        if let cachedHousehold = householdDataSource.households.first(where: { $0.id == householdId }) {
            await householdDataSource.switchHousehold(id: cachedHousehold.id)
            if tribeStore.tribe == nil {
                tribeStore.createTribe(
                    name: cachedHousehold.name,
                    tribeCode: formatHouseholdJoinCode(householdId: cachedHousehold.id)
                )
            }
        }
#if DEBUG
        print(
            "[Bootstrap] cache-first preload householdId=\(householdId.uuidString), " +
            "local_runs=\(runDataSource.runs.count)"
        )
#endif
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

    private var householdLoadFailedCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.indigo)
            Text("Couldn't load your tribe")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
            Text(householdLoadFailureMessage)
                .font(.system(size: 15, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320)
            Button("Try again") {
                Task { await runInitializationPipeline() }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.indigo)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var noHouseholdOnboardingCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.indigo)
            Text("No active tribe selected")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
            Text("Join or create a tribe to see schedules and runs.")
                .font(.system(size: 15, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320)
            VStack(spacing: 10) {
                Button("Join a tribe") {
                    isShowingJoinHouseholdSheet = true
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.indigo)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button("Set up a tribe") {
                    isShowingCreateHouseholdSheet = true
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.indigo)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.indigo.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
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
                RunEditRescheduleView(mode: .create) { _ in
                    true
                }
                .environmentObject(locationService)
                .environmentObject(familyQuickPlacesStore)
                .environmentObject(runDataSource)
                .environmentObject(householdContext)
                .environmentObject(backendChildrenContext)
                .environmentObject(backendDriversContext)
                .environmentObject(backendHouseholdLocationsContext)
                .environmentObject(backendProfileContext)
                .environmentObject(backendHouseholdContext)
                .environmentObject(backendSchedulesContext)
                .environmentObject(backendHouseholdPeopleContext)
                .environmentObject(authSession)
            }
        case .scheduleEditor:
            NavigationStack {
                ScheduleCreatorView()
                    .environmentObject(backendProfileContext)
                    .environmentObject(backendHouseholdContext)
                    .environmentObject(backendChildrenContext)
                    .environmentObject(backendSchedulesContext)
                    .environmentObject(backendHouseholdPeopleContext)
            }
        case .runScheduledConfirmation:
            RunScheduledConfirmationView()
        }
    }
    
    private func requestSync(reason: String) {
#if DEBUG
        print("DemoShellView.requestSync -> \(reason)")
#endif
        syncDebounceTask?.cancel()
        syncDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            await syncCoordinator.startSync()
        }
    }
    
    private func runSafeRealtimeRunRefresh(householdId: UUID) async {
        if isRealtimeRunRefreshInFlight {
            hasPendingRealtimeRunRefresh = true
            return
        }
        isRealtimeRunRefreshInFlight = true
        defer { isRealtimeRunRefreshInFlight = false }
        await refreshDriverCandidates(householdId: householdId)
        await backendRunsContext.refreshRuns(householdId: householdId)
        if hasPendingRealtimeRunRefresh {
            hasPendingRealtimeRunRefresh = false
            await refreshDriverCandidates(householdId: householdId)
            await backendRunsContext.refreshRuns(householdId: householdId)
        }
    }

    private func handleActiveHouseholdChanged(to householdId: UUID?) async {
        if householdId == lastHandledActiveHouseholdId {
#if DEBUG
            print("[DemoShellView] active household change ignored (no-op) id=\(householdId?.uuidString ?? "nil")")
#endif
            return
        }
        lastHandledActiveHouseholdId = householdId
        childrenLoadedHouseholdId = nil
        dependentDataLoadedHouseholdId = nil
        guard let householdId else {
            backendHouseholdPeopleContext.reset()
            backendEmergencyContactsContext.reset()
            backendChildrenContext.reset()
            backendHouseholdLocationsContext.reset()
            updateFamilySummary()
            backendRunsContext.reset()
            backendSchedulesContext.reset()
            backendDriversContext.reset()
            householdContext.householdId = HouseholdDefaults.defaultHouseholdId
            householdContext.householdName = HouseholdDefaults.defaultHouseholdName
            runDataSource.clearHouseholdScopedData()
            scheduleDataSource.clearHouseholdScopedData()
            await driverDataSource.reloadForHouseholdChange()
            await realtimeService.unsubscribe()
            if case .resolved = householdBootstrapPhase {
                householdBootstrapPhase = .resolved(hasHousehold: false)
            }
            return
        }

        if backendHouseholdContext.activeHouseholdId != householdId {
            backendHouseholdContext.selectHousehold(householdId)
        }

        // Clear stale state before loading the newly selected household.
        backendHouseholdPeopleContext.reset()
        backendEmergencyContactsContext.reset()
        backendChildrenContext.reset()
        backendHouseholdLocationsContext.reset()
        backendRunsContext.reset()
        backendSchedulesContext.reset()
        backendDriversContext.reset()

        await refreshDependentHouseholdData(householdId: householdId, source: "household_change")
        updateFamilySummary()
        await refreshDriverCandidates(householdId: householdId)
        requestSync(reason: "active_household_changed")
        await updateRealtimeSubscription()
    }

    private func refreshDependentHouseholdData(householdId: UUID, source: String) async {
        isDependentHouseholdDataLoading = true
        defer { isDependentHouseholdDataLoading = false }

#if DEBUG
        print("[HouseholdContent] source=\(source), activeHouseholdId=\(householdId.uuidString), stage=people:start")
#endif
        await backendHouseholdPeopleContext.refreshPeople(householdId: householdId)
#if DEBUG
        print(
            "[HouseholdContent] source=\(source), activeHouseholdId=\(householdId.uuidString), stage=people:done, " +
            "people_count=\(backendHouseholdPeopleContext.people.count)"
        )
#endif

#if DEBUG
        print("[HouseholdContent] source=\(source), activeHouseholdId=\(householdId.uuidString), stage=emergency_contacts:start")
#endif
        await backendEmergencyContactsContext.refreshContacts(householdId: householdId)
#if DEBUG
        print(
            "[HouseholdContent] source=\(source), activeHouseholdId=\(householdId.uuidString), stage=emergency_contacts:done, " +
            "emergency_contacts_count=\(backendEmergencyContactsContext.contactCount)"
        )
#endif

#if DEBUG
        print("[HouseholdContent] source=\(source), activeHouseholdId=\(householdId.uuidString), stage=children:start")
#endif
        await backendChildrenContext.refreshChildren(householdId: householdId)
        if backendChildrenContext.lastError == nil {
            childrenLoadedHouseholdId = householdId
        }
#if DEBUG
        print(
            "[HouseholdContent] source=\(source), activeHouseholdId=\(householdId.uuidString), stage=children:done, " +
            "children_count=\(backendChildrenContext.children.count)"
        )
#endif

#if DEBUG
        print("[HouseholdContent] source=\(source), activeHouseholdId=\(householdId.uuidString), stage=locations:start")
#endif
        await backendHouseholdLocationsContext.refresh(householdId: householdId)
        let (backfilledChildren, linkedSchoolCount) = HouseholdLocationBackfillService.backfillChildrenSchoolLinks(
            children: backendChildrenContext.children,
            locations: backendHouseholdLocationsContext.locations
        )
        if linkedSchoolCount > 0 {
            for child in backfilledChildren where child.schoolLocationId != nil {
                await backendChildrenContext.updateChildSchoolLocation(child)
            }
        }
        await backendSchedulesContext.repairPlaceholderScheduleStops(householdId: householdId)
#if DEBUG
        print(
            "[HouseholdContent] source=\(source), activeHouseholdId=\(householdId.uuidString), stage=locations:done, " +
            "locations_count=\(backendHouseholdLocationsContext.locations.count), linked_schools=\(linkedSchoolCount)"
        )
#endif

#if DEBUG
        print("[HouseholdContent] source=\(source), activeHouseholdId=\(householdId.uuidString), stage=schedules:start")
#endif
        scheduleDataSource.updateQuickPlaceIndex(
            slotPlaces: familyQuickPlacesStore.slotPlaces,
            namedPlaces: familyQuickPlacesStore.namedPlaces,
            recentPlaces: familyQuickPlacesStore.recentPlaces,
            homeLocation: backendHouseholdLocationsContext.homeLocation,
            householdLocations: backendHouseholdLocationsContext.locations
        )
        await backendSchedulesContext.refreshSchedules(householdId: householdId)
#if DEBUG
        print(
            "[HouseholdContent] source=\(source), activeHouseholdId=\(householdId.uuidString), stage=schedules:done, " +
            "schedules_count=\(backendSchedulesContext.schedules.count)"
        )
#endif

#if DEBUG
        print("[HouseholdContent] source=\(source), activeHouseholdId=\(householdId.uuidString), stage=runs:start")
#endif
        await backendRunsContext.refreshRuns(householdId: householdId)
#if DEBUG
        print(
            "[HouseholdContent] source=\(source), activeHouseholdId=\(householdId.uuidString), stage=runs:done, " +
            "runs_count=\(backendRunsContext.runs.count)"
        )
#endif

        dependentDataLoadedHouseholdId = householdId
        updateFamilySummary()
    }
    
    private func handleSignedOutStateCleanup() async {
        initializedForAuthUserId = nil
        childrenLoadedHouseholdId = nil
        dependentDataLoadedHouseholdId = nil
        lastHandledActiveHouseholdId = nil
        isDependentHouseholdDataLoading = false
        householdBootstrapPhase = .idle
        syncDebounceTask?.cancel()
        await realtimeService.unsubscribe()
        backendProfileContext.reset()
        backendHouseholdContext.reset()
        activeHouseholdStore.clear()
        backendHouseholdPeopleContext.reset()
        backendEmergencyContactsContext.reset()
        backendChildrenContext.reset()
        updateFamilySummary()
        backendSchedulesContext.reset()
        backendRunsContext.reset()
        backendDriversContext.reset()
        householdContext.householdId = HouseholdDefaults.defaultHouseholdId
        householdContext.householdName = HouseholdDefaults.defaultHouseholdName
        await syncCoordinator.resetUserScopedState(clearPendingOperations: true)
    }

    private func refreshDriverCandidates(householdId: UUID) async {
        await backendHouseholdPeopleContext.refreshPeople(householdId: householdId)
        await backendDriversContext.refreshDrivers(
            householdId: householdId,
            householdContext: backendHouseholdContext,
            peopleContext: backendHouseholdPeopleContext,
            childrenContext: backendChildrenContext,
            currentUserId: authSession.currentUserId.flatMap(UUID.init(uuidString:))
        )
    }

    private func updateFamilySummary() {
        tribeStore.updateFamilySummary(
            activeMemberships: backendHouseholdContext.activeHouseholdMembers.filter {
                $0.normalizedStatus == .active || $0.status == nil
            },
            householdPeople: backendHouseholdPeopleContext.people,
            children: backendChildrenContext.children
        )
    }
}

private struct CreateHouseholdSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @State private var name = ""
    let onCreated: () async -> Void

    var body: some View {
        Form {
            Section("Create a Family") {
                TextField("Family name", text: $name)
            }
            Section {
                Button("Create Family") {
                    Task {
                        await backendHouseholdContext.createHousehold(name: name)
                        if backendHouseholdContext.householdAlertError == nil {
                            await onCreated()
                            dismiss()
                        }
                    }
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Create Family")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}

#Preview {
    DemoShellView()
}
