import SwiftUI

/// Shared Xcode preview wiring for run editor screens (matches shell `DependencyContainer` layout enough to render).
struct RunFormPreviewShell<Content: View>: View {
    @StateObject private var activeHouseholdContext: ActiveHouseholdContext
    @StateObject private var runDataSource: RunDataSource
    @StateObject private var backendChildrenContext: BackendChildrenContext
    @StateObject private var backendHouseholdContext: BackendHouseholdContext
    @StateObject private var backendHouseholdPeopleContext: BackendHouseholdPeopleContext
    @StateObject private var backendDriversContext: BackendDriversContext
    @StateObject private var backendHouseholdLocationsContext: BackendHouseholdLocationsContext
    @StateObject private var authSession = AuthSessionContext()
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
        let activeHouseholdContext = ActiveHouseholdContext()
        let householdRepository = LocalHouseholdRepository()
        let householdDataSource = HouseholdDataSource(
            repository: householdRepository,
            activeContext: activeHouseholdContext,
            syncCoordinator: nil
        )
        let backendHouseholdContext = BackendHouseholdContext(
            localHouseholdContext: activeHouseholdContext,
            localHouseholdDataSource: householdDataSource,
            activeHouseholdStore: nil
        )
        let tribeStore = TribeStore()
        let backendChildrenContext = BackendChildrenContext(
            householdContext: backendHouseholdContext,
            store: tribeStore
        )
        let runRepository = LocalRunRepository()
        let scheduleRepository = LocalScheduleRepository()
        let driverRepository = LocalDriverRepository()
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
            householdContext: activeHouseholdContext,
            backendRunsContext: backendRunsContext,
            syncCoordinator: syncCoordinator
        )
        _activeHouseholdContext = StateObject(wrappedValue: activeHouseholdContext)
        _runDataSource = StateObject(wrappedValue: runDataSource)
        _backendChildrenContext = StateObject(wrappedValue: backendChildrenContext)
        _backendHouseholdContext = StateObject(wrappedValue: backendHouseholdContext)
        _backendHouseholdPeopleContext = StateObject(
            wrappedValue: BackendHouseholdPeopleContext(activeHouseholdStore: ActiveHouseholdStore())
        )
        _backendDriversContext = StateObject(
            wrappedValue: BackendDriversContext(backendRunsContext: backendRunsContext)
        )
        _backendHouseholdLocationsContext = StateObject(
            wrappedValue: BackendHouseholdLocationsContext(householdContext: backendHouseholdContext)
        )
    }

    var body: some View {
        content()
            .environmentObject(LocationReadinessService())
            .environmentObject(FamilyQuickPlacesStore())
            .environmentObject(runDataSource)
            .environmentObject(activeHouseholdContext)
            .environmentObject(backendChildrenContext)
            .environmentObject(backendHouseholdContext)
            .environmentObject(backendHouseholdPeopleContext)
            .environmentObject(backendDriversContext)
            .environmentObject(backendHouseholdLocationsContext)
            .environmentObject(authSession)
    }
}
