import Foundation
import Combine

@MainActor
final class HouseholdDataSource: ObservableObject {
    @Published private(set) var households: [Household] = []
    @Published var lastError: String?

    private let repository: HouseholdRepository
    private let activeContext: ActiveHouseholdContext
    private let syncCoordinator: SyncCoordinator?
    private var onHouseholdSwitched: (() async -> Void)?
    private var isSwitchingHousehold = false

    init(
        repository: HouseholdRepository,
        activeContext: ActiveHouseholdContext,
        syncCoordinator: SyncCoordinator? = nil
    ) {
        self.repository = repository
        self.activeContext = activeContext
        self.syncCoordinator = syncCoordinator
    }

    func setOnHouseholdSwitched(_ callback: @escaping () async -> Void) {
        self.onHouseholdSwitched = callback
    }

    func refresh() async {
        do {
            let loaded = try await repository.loadHouseholds()
                .sorted { $0.createdAt < $1.createdAt }

            households = loaded
            alignActiveContextToLoadedHouseholds()
            lastError = nil
        } catch {
            if isCancellationError(error) {
#if DEBUG
                print("[HouseholdDataSource] ignored cancellation during refresh")
#endif
                return
            }
            lastError = "Failed to load households."
        }
    }

    func createHousehold(name: String) async {
        let trimmed = HouseholdCreateName.normalized(name)
        guard HouseholdCreateName.isUsable(trimmed) else {
            lastError = "Household name is required."
            return
        }

        var updated = households
        let newHousehold = Household(id: UUID(), name: trimmed, createdAt: Date())
        updated.append(newHousehold)
        updated.sort { $0.createdAt < $1.createdAt }

        do {
            try await repository.saveHouseholds(updated)
            households = updated
            if let syncCoordinator {
                let change = SyncChangeFactory.makeHouseholdChange(
                    householdId: newHousehold.id,
                    entityId: newHousehold.id,
                    operation: .create
                )
                await syncCoordinator.enqueue(change)
            }
            lastError = nil
            await switchHousehold(id: newHousehold.id)
        } catch {
            if isCancellationError(error) {
#if DEBUG
                print("[HouseholdDataSource] ignored cancellation during create")
#endif
                return
            }
            lastError = "Failed to create household."
        }
    }

    func deleteHousehold(id: UUID) async {
        guard households.count > 1 else {
            lastError = "At least one household is required."
            return
        }

        var updated = households.filter { $0.id != id }
        guard !updated.isEmpty else {
            lastError = "At least one household is required."
            return
        }
        updated.sort { $0.createdAt < $1.createdAt }

        do {
            try await repository.saveHouseholds(updated)
            households = updated
            if let syncCoordinator {
                let change = SyncChangeFactory.makeHouseholdChange(
                    householdId: id,
                    entityId: id,
                    operation: .delete
                )
                await syncCoordinator.enqueue(change)
            }
            lastError = nil

            if activeContext.householdId == id, let fallback = updated.first {
                await switchHousehold(id: fallback.id)
            } else {
                alignActiveContextToLoadedHouseholds()
            }
        } catch {
            lastError = "Failed to delete household."
        }
    }

    func switchHousehold(id: UUID) async {
        guard !isSwitchingHousehold else { return }
        guard let household = households.first(where: { $0.id == id }) else {
            lastError = "Selected household not found."
            return
        }
        guard activeContext.householdId != household.id else {
            activeContext.householdName = household.name
            lastError = nil
            return
        }
        isSwitchingHousehold = true
        defer { isSwitchingHousehold = false }
        activeContext.householdId = household.id
        activeContext.householdName = household.name
        lastError = nil
        if let onHouseholdSwitched {
            await onHouseholdSwitched()
        }
    }

    func adoptBackendHousehold(id: UUID, name: String) async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = trimmedName.isEmpty ? "Shared Household" : trimmedName
        var updated = households

        if let index = updated.firstIndex(where: { $0.id == id }) {
            updated[index].name = fallbackName
        } else {
            updated.append(Household(id: id, name: fallbackName, createdAt: Date()))
            updated.sort { $0.createdAt < $1.createdAt }
        }

        do {
            try await repository.saveHouseholds(updated)
            households = updated
            await switchHousehold(id: id)
        } catch {
            lastError = "Failed to adopt backend household."
        }
    }

    private func alignActiveContextToLoadedHouseholds() {
        guard !households.isEmpty else { return }
        if let current = households.first(where: { $0.id == activeContext.householdId }) {
            activeContext.householdName = current.name
            return
        }
        guard let first = households.first else { return }
        activeContext.householdId = first.id
        activeContext.householdName = first.name
    }
}
