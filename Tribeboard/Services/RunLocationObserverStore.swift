import Combine
import CoreLocation
import Foundation

@MainActor
final class RunLocationObserverStore: ObservableObject {
    @Published private(set) var remotePositionByRunId: [UUID: RunDriverPositionSnapshot] = [:]

    private let service: RunLocationBackendService
    private var pollTask: Task<Void, Never>?
    private var activeHouseholdId: UUID?

    init(service: RunLocationBackendService = SupabaseRunLocationBackendService()) {
        self.service = service
    }

    func startObserving(householdId: UUID) {
        guard activeHouseholdId != householdId || pollTask == nil else { return }
        activeHouseholdId = householdId
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            await self?.pollLoop(householdId: householdId)
        }
    }

    func stopObserving() {
        pollTask?.cancel()
        pollTask = nil
        activeHouseholdId = nil
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
            await loadPositions(householdId: householdId)
            try? await Task.sleep(nanoseconds: 7_000_000_000)
        }
    }

    private func loadPositions(householdId: UUID) async {
        do {
            let rows = try await service.fetchPositions(householdId: householdId)
            var map: [UUID: RunDriverPositionSnapshot] = [:]
            for row in rows {
                map[row.runId] = RunDriverPositionSnapshot(backend: row)
            }
            remotePositionByRunId = map
        } catch {
            // Keep last known positions when offline.
        }
    }
}
