import Foundation
import Combine

@MainActor
final class BackendDriversContext: ObservableObject {
    static let loadFailedUserMessage = "Driver assignment could not be loaded. Please try again."
    static let assignFailedUserMessage = "Driver could not be assigned. Please try again."
    static let syncPendingWarningMessage =
        "Driver assigned on this device. Sync to the server is still pending."

    @Published private(set) var drivers: [BackendDriver] = []
    @Published private(set) var isLoading: Bool = false
    @Published var lastError: String?
    @Published var syncPendingWarning: String?

    private let service: DriverBackendService
    private let backendRunsContext: BackendRunsContext
    private let syncCoordinator: SyncCoordinator?
    private weak var runDataSource: RunDataSource?
    private(set) var activeHouseholdId: UUID?
    private var isRefreshInFlight = false
    private var hasPendingRefresh = false
    private var lastRefreshMemberships: [BackendHouseholdMembership] = []
    private var lastRefreshProfilesByUserId: [UUID: BackendProfile] = [:]
    private var lastRefreshHouseholdPeople: [BackendHouseholdPerson] = []
    private var lastRefreshChildIds: Set<UUID> = []
    private var lastRefreshCurrentUserId: UUID?

    init(
        service: DriverBackendService? = nil,
        backendRunsContext: BackendRunsContext,
        syncCoordinator: SyncCoordinator? = nil,
        runDataSource: RunDataSource? = nil
    ) {
        self.service = service ?? SupabaseDriverBackendService()
        self.backendRunsContext = backendRunsContext
        self.syncCoordinator = syncCoordinator
        self.runDataSource = runDataSource
    }

    func bind(runDataSource: RunDataSource) {
        self.runDataSource = runDataSource
    }

    func refreshDrivers(householdId: UUID) async {
        await refreshDrivers(
            householdId: householdId,
            memberships: [],
            profilesByUserId: [:],
            householdPeople: [],
            childIds: [],
            currentUserId: nil
        )
    }

    func refreshDrivers(
        householdId: UUID,
        householdContext: BackendHouseholdContext,
        peopleContext: BackendHouseholdPeopleContext,
        childrenContext: BackendChildrenContext,
        currentUserId: UUID?
    ) async {
        await refreshDrivers(
            householdId: householdId,
            memberships: householdContext.activeHouseholdMembers,
            profilesByUserId: householdContext.activeHouseholdProfilesByUserId,
            householdPeople: peopleContext.people,
            childIds: Set(childrenContext.children.map(\.id)),
            currentUserId: currentUserId
        )
    }

    func refreshDrivers(
        householdId: UUID,
        memberships: [BackendHouseholdMembership] = [],
        profilesByUserId: [UUID: BackendProfile] = [:],
        householdPeople: [BackendHouseholdPerson] = [],
        childIds: Set<UUID> = [],
        currentUserId: UUID? = nil
    ) async {
        activeHouseholdId = householdId
        lastRefreshMemberships = memberships
        lastRefreshProfilesByUserId = profilesByUserId
        lastRefreshHouseholdPeople = householdPeople
        lastRefreshChildIds = childIds
        lastRefreshCurrentUserId = currentUserId
        if isRefreshInFlight {
            hasPendingRefresh = true
            return
        }
        isRefreshInFlight = true
        isLoading = true
        defer {
            isLoading = false
            isRefreshInFlight = false
        }

        lastError = nil
        NSLog("[AssignDriver] activeHouseholdId=\(householdId.uuidString)")
        NSLog("[AssignDriver] attemptedSource=household_memberships,household_people,profiles")

        let candidates = AssignDriverEligibility.resolve(
            activeHouseholdId: householdId,
            memberships: memberships,
            profilesByUserId: profilesByUserId,
            householdPeople: householdPeople,
            childIds: childIds,
            currentUserId: currentUserId
        )
        drivers = candidates.map { $0.asBackendDriver(householdId: householdId) }

        NSLog("[AssignDriver] candidates count=\(drivers.count)")

        if hasPendingRefresh {
            hasPendingRefresh = false
            await refreshDrivers(
                householdId: householdId,
                memberships: lastRefreshMemberships,
                profilesByUserId: lastRefreshProfilesByUserId,
                householdPeople: lastRefreshHouseholdPeople,
                childIds: lastRefreshChildIds,
                currentUserId: lastRefreshCurrentUserId
            )
        }
    }

    var assignedRunCount: Int {
        guard let runDataSource, let householdId = activeHouseholdId else { return 0 }
        return runDataSource.runs.filter {
            $0.householdId == householdId && ($0.assignedDriverId ?? $0.driverId) != nil
        }.count
    }

    func reportLoadFailure(error: String, attemptedSource: String) {
        NSLog("[AssignDriver] load failed error=\(error)")
        NSLog("[AssignDriver] attemptedSource=\(attemptedSource)")
        lastError = Self.loadFailedUserMessage
    }

    @discardableResult
    func assignDriver(
        runId: UUID,
        driverId: UUID,
        driverName: String,
        runHouseholdId: UUID?,
        activeHouseholdId: UUID
    ) async -> Bool {
        lastError = nil
        syncPendingWarning = nil

        NSLog("[AssignDriver] runId=\(runId.uuidString)")
        NSLog("[AssignDriver] selectedDriverId=\(driverId.uuidString)")
        NSLog("[AssignDriver] selectedDriverName=\(driverName)")
        NSLog("[AssignDriver] activeHouseholdId=\(activeHouseholdId.uuidString)")
        NSLog("[AssignDriver] target run id=\(runId.uuidString)")

        guard let runHouseholdId else {
            lastError = "This run belongs to another household. Switch household to manage it."
            return false
        }
        guard runHouseholdId == activeHouseholdId else {
            NSLog(
                "[AssignDriver] household mismatch runHouseholdId=\(runHouseholdId.uuidString) " +
                "activeHouseholdId=\(activeHouseholdId.uuidString)"
            )
            lastError = "This run belongs to another household. Switch household to manage it."
            return false
        }

        let runExistsInMemory = runDataSource?.run(withId: runId.uuidString) != nil
        let runExistsInHousehold = runDataSource?.runs.contains {
            $0.id == runId && $0.householdId == activeHouseholdId
        } ?? false
        NSLog(
            "[AssignDriver] run exists in memory=\(runExistsInMemory) " +
            "run exists in active household=\(runExistsInHousehold)"
        )

        guard drivers.contains(where: { $0.id == driverId }) else {
            lastError = "Selected driver is no longer available."
            return false
        }

        isLoading = true
        defer { isLoading = false }

        guard let runDataSource else {
            lastError = Self.assignFailedUserMessage
            return false
        }

        let localAssigned = await runDataSource.assignDriverLocally(
            runId: runId,
            driverId: driverId,
            driverName: driverName
        )
        if !localAssigned {
            if let dataSourceError = runDataSource.lastError, !dataSourceError.isEmpty {
                NSLog("[AssignDriver] run update failed error=\(dataSourceError)")
                lastError = dataSourceError
            } else {
                lastError = Self.assignFailedUserMessage
            }
            return false
        }
        NSLog("[AssignDriver] run update success runId=\(runId.uuidString)")
        await runDataSource.refresh()
        return true
    }

    func removeAssignment(runId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        guard BackendConfig.isBackendConfigured else { return }
        do {
            try await service.clearDriverOnRun(runId: runId)
            if let householdId = activeHouseholdId {
                await backendRunsContext.refreshRuns(householdId: householdId)
            }
            await runDataSource?.refresh()
        } catch {
            NSLog("[AssignDriver] clear driver failed error=\(error.localizedDescription)")
        }
    }

    func reset() {
        drivers = []
        isLoading = false
        lastError = nil
        syncPendingWarning = nil
        activeHouseholdId = nil
        isRefreshInFlight = false
        hasPendingRefresh = false
    }

    func assignedDriverId(forRunId runId: UUID) -> UUID? {
        guard let run = runDataSource?.run(withId: runId.uuidString) else { return nil }
        return run.assignedDriverId ?? run.driverId
    }

    func driverName(forRunId runId: UUID) -> String? {
        if let driverId = assignedDriverId(forRunId: runId),
           let driver = drivers.first(where: { $0.id == driverId }) {
            return driver.displayName
        }
        if let run = runDataSource?.run(withId: runId.uuidString),
           let name = run.assignedDriverName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        return nil
    }
}
