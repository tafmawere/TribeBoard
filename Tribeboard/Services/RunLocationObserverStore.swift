import Combine
import Foundation

@MainActor
final class RunLocationObserverStore: ObservableObject {
    @Published private(set) var remotePositionByRunId: [UUID: RunDriverPositionSnapshot] = [:]

    private let service: RunLocationBackendService
    private var pollTask: Task<Void, Never>?
    private var activeHouseholdId: UUID?
    private var observedRunIds: Set<UUID> = []

    init(service: RunLocationBackendService = SupabaseRunLocationBackendService()) {
        self.service = service
    }

    func reconcile(
        householdId: UUID?,
        inProgressRunIds: Set<UUID>,
        isSceneActive: Bool
    ) {
        observedRunIds = inProgressRunIds
        let shouldPoll = RunLocationObserverPolicy.shouldPoll(
            hasInProgressRun: !inProgressRunIds.isEmpty,
            isSceneActive: isSceneActive
        )
        guard shouldPoll, let householdId else {
            pauseObserving()
            return
        }
        startObserving(householdId: householdId)
    }

    func startObserving(householdId: UUID) {
        guard activeHouseholdId != householdId || pollTask == nil else { return }
        activeHouseholdId = householdId
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            await self?.pollLoop(householdId: householdId)
        }
    }

    /// Stops the 7s loop but keeps the last known positions for the current scene.
    func pauseObserving() {
        pollTask?.cancel()
        pollTask = nil
    }

    func stopObserving() {
        pauseObserving()
        activeHouseholdId = nil
        observedRunIds = []
        remotePositionByRunId = [:]
    }

    func position(for runId: UUID) -> RunDriverPositionSnapshot? {
        remotePositionByRunId[runId]
    }

    func refreshNow(householdId: UUID) async {
        await loadPositions(householdId: householdId)
    }

    private func pollLoop(householdId: UUID) async {
        while !Task.isCancelled {
            if observedRunIds.isEmpty {
                break
            }
            await loadPositions(householdId: householdId)
            try? await Task.sleep(nanoseconds: RunLocationObserverPolicy.pollIntervalNanoseconds)
        }
    }

    private func loadPositions(householdId: UUID) async {
        let runIds = observedRunIds
        guard !runIds.isEmpty else {
            remotePositionByRunId = [:]
            return
        }
        do {
            let rows = try await service.fetchPositions(householdId: householdId)
            var map: [UUID: RunDriverPositionSnapshot] = [:]
            for row in rows where runIds.contains(row.runId) {
                map[row.runId] = RunDriverPositionSnapshot(backend: row)
            }
            remotePositionByRunId = map
        } catch {
            // Keep last known positions when offline.
        }
    }
}
