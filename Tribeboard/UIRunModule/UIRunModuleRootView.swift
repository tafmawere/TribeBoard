import SwiftUI

private enum UIRunRoute: Hashable {
    case runDetails(String)
    case runFocus(UIRun)
    case driverMode(UIRun)
    case observer(UIRun)
    case completion(UIRun)
}

/// Standalone Runs module preview host — mirrors shell wiring so `DailyDispatchView` and `RunDataSource` behave consistently.
struct UIRunModuleRootView: View {
    @State private var path: [UIRunRoute] = []
    @State private var selectedTab: RunsOverviewTab = .today
    @State private var isDispatchPresented = false

    @StateObject private var activeHouseholdStore: ActiveHouseholdStore
    @StateObject private var householdDataSource: HouseholdDataSource
    @StateObject private var backendHouseholdContext: BackendHouseholdContext
    @StateObject private var backendRunsContext: BackendRunsContext
    @StateObject private var backendDriversContext: BackendDriversContext
    @StateObject private var runDataSource: RunDataSource
    @StateObject private var driverDataSource: DriverDataSource
    @StateObject private var locationService: LocationReadinessService
    @StateObject private var notificationService: NotificationService
    @StateObject private var familyQuickPlacesStore: FamilyQuickPlacesStore
    @StateObject private var householdContext: ActiveHouseholdContext
    @StateObject private var tribeStore: TribeStore
    @StateObject private var backendChildrenContext: BackendChildrenContext

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
        let runDataSource = RunDataSource(
            repository: runRepository,
            scheduleRepository: scheduleRepository,
            driverRepository: driverRepository,
            householdContext: householdContext,
            backendRunsContext: backendRunsContext,
            syncCoordinator: syncCoordinator
        )
        let driverDataSource = DriverDataSource(
            repository: driverRepository,
            householdContext: householdContext,
            syncCoordinator: syncCoordinator
        )
        let householdDataSource = HouseholdDataSource(
            repository: householdRepository,
            activeContext: householdContext,
            syncCoordinator: syncCoordinator
        )
        let backendHouseholdContext = BackendHouseholdContext(
            localHouseholdContext: householdContext,
            localHouseholdDataSource: householdDataSource,
            activeHouseholdStore: activeHouseholdStore
        )
        let backendDriversContext = BackendDriversContext(
            backendRunsContext: backendRunsContext,
            syncCoordinator: syncCoordinator
        )
        let tribeStore = TribeStore()
        let backendChildrenContext = BackendChildrenContext(
            householdContext: backendHouseholdContext,
            store: tribeStore
        )

        _householdContext = StateObject(wrappedValue: householdContext)
        _tribeStore = StateObject(wrappedValue: tribeStore)
        _backendChildrenContext = StateObject(wrappedValue: backendChildrenContext)
        _activeHouseholdStore = StateObject(wrappedValue: activeHouseholdStore)
        _householdDataSource = StateObject(wrappedValue: householdDataSource)
        _backendHouseholdContext = StateObject(wrappedValue: backendHouseholdContext)
        _backendRunsContext = StateObject(wrappedValue: backendRunsContext)
        _backendDriversContext = StateObject(wrappedValue: backendDriversContext)
        _runDataSource = StateObject(wrappedValue: runDataSource)
        _driverDataSource = StateObject(wrappedValue: driverDataSource)
        _locationService = StateObject(wrappedValue: LocationReadinessService())
        _notificationService = StateObject(wrappedValue: NotificationService())
        _familyQuickPlacesStore = StateObject(wrappedValue: FamilyQuickPlacesStore())
    }

    var body: some View {
        NavigationStack(path: $path) {
            RunsOverviewView(
                selectedTab: $selectedTab,
                isDispatchPresented: $isDispatchPresented,
                permissions: RunsOverviewPermissions(canPerformRunActions: true),
                todayRuns: todayRuns,
                upcomingRuns: upcomingRuns,
                historyRuns: historyRuns,
                activeRun: activeRun,
                suggestedRuns: [],
                onCreateRun: nil,
                onOpenDriverMode: {
                    guard let run = activeRun else { return }
                    path.append(.driverMode(run))
                },
                onDispatchCreateRun: nil,
                onDispatchOpenCalendar: nil,
                onOpenRunDetails: { run in
                    path.append(.runDetails(run.backingRunId))
                },
                onOpenObserver: { run in
                    path.append(.observer(run))
                },
                onStartSuggestion: { _ in },
                onSnoozeSuggestion: { _ in },
                onDismissSuggestion: { _ in },
                onViewCalendar: nil
            )
            .environmentObject(runDataSource)
            .environmentObject(driverDataSource)
            .environmentObject(activeHouseholdStore)
            .environmentObject(backendDriversContext)
            .environmentObject(backendHouseholdContext)
            .environmentObject(locationService)
            .environmentObject(notificationService)
            .environmentObject(familyQuickPlacesStore)
            .environmentObject(householdContext)
            .environmentObject(backendChildrenContext)
            .navigationDestination(for: UIRunRoute.self) { route in
                switch route {
                case let .runDetails(runId):
                    runDetailsDestination(runId: runId)
                case let .runFocus(run):
                    RunFocusUIScreen(run: run, isDriver: true) {
                        path.append(.driverMode(run))
                    }
                case let .driverMode(run):
                    DriverModeUIScreen(run: run) {
                        path.append(.completion(run))
                    }
                case let .observer(run):
                    ObserverTrackingUIScreen(run: run, timeline: UIRunMockData.timeline)
                case let .completion(run):
                    RunCompletionUIScreen(
                        run: run,
                        timeline: UIRunMockData.timeline,
                        onBackToDashboard: { path.removeAll() },
                        onViewHistory: {
                            selectedTab = .history
                            path.removeAll()
                        }
                    )
                }
            }
        }
        .task {
            await runDataSource.bootstrapIfNeeded()
            await driverDataSource.bootstrapIfNeeded()
        }
    }

    private var allSystemRuns: [SystemDomain.RunInstance] {
        runDataSource.runs.sorted { $0.date < $1.date }
    }

    private var allUIRuns: [UIRun] {
        allSystemRuns.map(mapToUIRun)
    }

    private var activeRun: UIRun? {
        allUIRuns.first(where: { $0.status == .active })
    }

    private var todayRuns: [UIRun] {
        let calendar = Calendar.current
        let today = Date()
        return allSystemRuns.filter { run in
            let isTerminal = run.status == .completed || run.status == .cancelled
            return calendar.isDate(run.date, inSameDayAs: today) && !isTerminal
        }.map(mapToUIRun)
    }

    private var upcomingRuns: [UIRun] {
        let calendar = Calendar.current
        let today = Date()
        return allSystemRuns.filter { run in
            run.status == .scheduled && !calendar.isDate(run.date, inSameDayAs: today) && run.date > today
        }.map(mapToUIRun)
    }

    private var historyRuns: [UIRun] {
        allSystemRuns.filter { run in
            run.status == .completed || run.status == .cancelled
        }.map(mapToUIRun)
    }

    private func mapToUIRun(_ run: SystemDomain.RunInstance) -> UIRun {
        RunUIAdapter.mapToUIRun(
            run,
            childName: RunDisplayStrings.childName(for: run, children: backendChildrenContext.children)
        )
    }

    private func runForRunId(_ runId: String) -> UIRun? {
        allUIRuns.first { $0.backingRunId == runId }
    }

    private func runDetailsDestination(runId: String) -> some View {
        RunExecutionDetailView(runId: runId)
            .environmentObject(runDataSource)
            .environmentObject(driverDataSource)
            .environmentObject(householdContext)
            .environmentObject(backendHouseholdContext)
            .environmentObject(backendDriversContext)
            .environmentObject(backendChildrenContext)
            .environmentObject(locationService)
            .environmentObject(familyQuickPlacesStore)
    }

    private func mapUIRunToRunDetails(_ run: UIRun?) -> RunDetailsData.UIRun {
        guard let run else { return RunDetailsData.scheduledRun }
        let now = Date()
        let timeline: [RunDetailsData.UITimelineEvent] = [
            .init(time: now.addingTimeInterval(-1800), title: "Scheduled", detail: "Run prepared", iconName: "calendar", severity: .normal),
            .init(time: now.addingTimeInterval(-900), title: "Reminder", detail: "Family notified", iconName: "bell", severity: .normal)
        ]
        let statusLabel: String = {
            switch run.status {
            case .scheduled: return "Scheduled"
            case .assigned: return "Assigned"
            case .active: return "Active"
            case .completed: return "Completed"
            }
        }()

        return RunDetailsData.UIRun(
            title: run.title,
            scheduledTime: now,
            status: statusLabel,
            driverName: run.driverName,
            passengerNames: run.passengers.map(\.name),
            passengerStatuses: run.passengers.map { $0.status.rawValue.capitalized },
            stops: run.stops.map {
                .init(
                    type: $0.type.rawValue.capitalized,
                    label: $0.label,
                    placeName: "",
                    address: $0.passengerNames.joined(separator: ", "),
                    latitude: nil,
                    longitude: nil,
                    timeEstimate: run.etaText
                )
            },
            timeline: timeline,
            canEdit: run.status == .scheduled,
            canCancel: run.status == .scheduled,
            isHistory: run.status == .completed
        )
    }
}

#Preview {
    UIRunModuleRootView()
}
