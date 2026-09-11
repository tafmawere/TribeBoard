import Foundation
import Combine

@MainActor
final class DriverDataSource: ObservableObject {
    @Published private(set) var drivers: [SystemDomain.Driver] = []
    @Published private(set) var activeDriversCount: Int = 0
    @Published private(set) var totalDriversCount: Int = 0
    @Published var isLoading = false
    @Published var isWorking = false
    @Published var lastError: String?

    private let repository: any DriverRepository
    private let householdContext: ActiveHouseholdContext
    private let syncCoordinator: SyncCoordinator?
    private let repositoryTypeName: String

    init(
        repository: (any DriverRepository)? = nil,
        householdContext: ActiveHouseholdContext? = nil,
        syncCoordinator: SyncCoordinator? = nil
    ) {
        self.repository = repository ?? LocalDriverRepository()
        self.householdContext = householdContext ?? ActiveHouseholdContext()
        self.syncCoordinator = syncCoordinator
        self.repositoryTypeName = String(describing: type(of: self.repository))
    }

    func refresh() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await repository.loadDrivers(for: activeHouseholdId)
            totalDriversCount = loaded.count
            let active = loaded.filter(\.isActive)
            activeDriversCount = active.count
            drivers = active
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            lastError = nil
        } catch {
            lastError = "Failed to load drivers."
        }
    }

    func reloadForHouseholdChange() async {
        await refresh()
    }

    func bootstrapIfNeeded() async {
        await refresh()
    }

    func upsert(_ driver: SystemDomain.Driver) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        let trimmed = driver.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = "Driver name is required."
            return
        }
        var normalized = driver
        normalized.name = trimmed
        do {
            if normalized.householdId != activeHouseholdId {
                normalized = SystemDomain.Driver(
                    id: normalized.id,
                    householdId: activeHouseholdId,
                    name: normalized.name,
                    phoneNumber: normalized.phoneNumber,
                    isActive: normalized.isActive,
                    createdAt: normalized.createdAt
                )
            }

            var all = try await repository.loadDrivers(for: activeHouseholdId)
            let isCreate = !all.contains(where: { $0.id == normalized.id })
            if let index = all.firstIndex(where: { $0.id == normalized.id }) {
                all[index] = normalized
            } else {
                all.append(normalized)
            }
            try await repository.saveDrivers(all, for: activeHouseholdId)
            if let syncCoordinator {
                let change = SyncChangeFactory.makeDriverChange(
                    householdId: activeHouseholdId,
                    entityId: normalized.id,
                    operation: isCreate ? .create : .update
                )
                await syncCoordinator.enqueue(change)
            }
            lastError = nil
            await refresh()
        } catch {
            lastError = "Failed to save driver."
        }
    }

    func seedDemoDrivers() async {
        guard AppConfig.isDemoFlowEnabled else { return }
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            var all = try await repository.loadDrivers(for: activeHouseholdId)
            let existingIDs = Set(all.map(\.id))
            let now = Date()
            for demo in demoDriverSeeds {
                if all.contains(where: { $0.id == demo.id }) {
                    continue
                }
                all.append(
                    SystemDomain.Driver(
                        id: demo.id,
                        householdId: activeHouseholdId,
                        name: demo.name,
                        phoneNumber: demo.phoneNumber,
                        isActive: true,
                        createdAt: now
                    )
                )
            }
            try await repository.saveDrivers(all, for: activeHouseholdId)
            if let syncCoordinator {
                let createdChanges = demoDriverSeeds
                    .map(\.id)
                    .filter { !existingIDs.contains($0) }
                    .map {
                        SyncChangeFactory.makeDriverChange(
                            householdId: activeHouseholdId,
                            entityId: $0,
                            operation: .create
                        )
                    }
                await syncCoordinator.enqueue(changes: createdChanges)
            }
            lastError = nil
            await refresh()
        } catch {
            lastError = "Failed to seed demo drivers."
        }
    }

    func clearDrivers() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let existing = try await repository.loadDrivers(for: activeHouseholdId)
            try await repository.saveDrivers([], for: activeHouseholdId)
            if let syncCoordinator {
                let deleteChanges = existing.map {
                    SyncChangeFactory.makeDriverChange(
                        householdId: activeHouseholdId,
                        entityId: $0.id,
                        operation: .delete
                    )
                }
                await syncCoordinator.enqueue(changes: deleteChanges)
            }
            lastError = nil
            await refresh()
        } catch {
            lastError = "Failed to clear drivers."
        }
    }

    var diagnosticsRepositoryType: String {
        repositoryTypeName
    }

    private var activeHouseholdId: UUID {
        householdContext.householdId
    }

    private let demoDriverSeeds: [(id: UUID, name: String, phoneNumber: String?)] = [
        (UUID(uuidString: "A1000000-0000-0000-0000-000000000001")!, "Tafadzwa", "+263771000001"),
        (UUID(uuidString: "A1000000-0000-0000-0000-000000000002")!, "Rue", "+263771000002"),
        (UUID(uuidString: "A1000000-0000-0000-0000-000000000003")!, "Alex", "+263771000003"),
        (UUID(uuidString: "A1000000-0000-0000-0000-000000000004")!, "Nyasha", "+263771000004")
    ]
}
