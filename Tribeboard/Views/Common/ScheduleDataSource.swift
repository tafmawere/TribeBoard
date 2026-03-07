import Foundation
import Combine

@MainActor
final class ScheduleDataSource: ObservableObject {
    @Published var templates: [SystemDomain.ScheduleTemplate] = []
    @Published var isLoading = false
    @Published var isWorking = false
    @Published var lastError: String? = nil

    private let repository: any ScheduleRepository
    private let householdContext: ActiveHouseholdContext
    private let syncCoordinator: SyncCoordinator?
    private let repositoryTypeName: String

    init(
        repository: any ScheduleRepository = LocalScheduleRepository(),
        householdContext: ActiveHouseholdContext? = nil,
        syncCoordinator: SyncCoordinator? = nil
    ) {
        self.repository = repository
        self.householdContext = householdContext ?? ActiveHouseholdContext()
        self.syncCoordinator = syncCoordinator
        self.repositoryTypeName = String(describing: type(of: repository))
    }

    func refresh() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }
        do {
            templates = try await repository.loadTemplates(for: activeHouseholdId).sorted { lhs, rhs in
                if lhs.hour == rhs.hour {
                    return lhs.minute < rhs.minute
                }
                return lhs.hour < rhs.hour
            }
            lastError = nil
        } catch {
            lastError = "Failed to load schedules."
        }
    }

    func reloadForHouseholdChange() async {
        await refresh()
    }

    func upsert(_ template: SystemDomain.ScheduleTemplate) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        if let validationError = validationError(for: template) {
            lastError = validationError
            return
        }

        do {
            var normalized = template
            if normalized.householdId != activeHouseholdId {
                normalized = SystemDomain.ScheduleTemplate(
                    id: normalized.id,
                    householdId: activeHouseholdId,
                    name: normalized.name,
                    childId: normalized.childId,
                    driverId: normalized.driverId,
                    weekdays: normalized.weekdays,
                    hour: normalized.hour,
                    minute: normalized.minute,
                    stops: normalized.stops,
                    isActive: normalized.isActive,
                    createdAt: normalized.createdAt
                )
            }

            var all = try await repository.loadTemplates(for: activeHouseholdId)
            let isCreate = !all.contains(where: { $0.id == normalized.id })
            if let index = all.firstIndex(where: { $0.id == template.id }) {
                all[index] = normalized
            } else {
                all.append(normalized)
            }
            try await repository.saveTemplates(all, for: activeHouseholdId)
            if let syncCoordinator {
                let change = SyncChangeFactory.makeScheduleChange(
                    householdId: activeHouseholdId,
                    entityId: normalized.id,
                    operation: isCreate ? .create : .update
                )
                await syncCoordinator.enqueue(change)
            }
            lastError = nil
            await refresh()
        } catch {
            lastError = "Failed to save schedule."
        }
    }

    func delete(id: UUID) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let all = try await repository.loadTemplates(for: activeHouseholdId)
            let filtered = all.filter { $0.id != id }
            try await repository.saveTemplates(filtered, for: activeHouseholdId)
            if let syncCoordinator {
                let change = SyncChangeFactory.makeScheduleChange(
                    householdId: activeHouseholdId,
                    entityId: id,
                    operation: .delete
                )
                await syncCoordinator.enqueue(change)
            }
            await refresh()
        } catch {
            lastError = "Failed to delete schedule."
        }
    }

    func toggleEnabled(id: UUID, enabled: Bool) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            var all = try await repository.loadTemplates(for: activeHouseholdId)
            guard let index = all.firstIndex(where: { $0.id == id }) else { return }
            all[index].isActive = enabled
            try await repository.saveTemplates(all, for: activeHouseholdId)
            if let syncCoordinator {
                let change = SyncChangeFactory.makeScheduleChange(
                    householdId: activeHouseholdId,
                    entityId: id,
                    operation: .update
                )
                await syncCoordinator.enqueue(change)
            }
            await refresh()
        } catch {
            lastError = "Failed to update schedule."
        }
    }

    func seedDemoIfNeeded() async {
#if DEBUG
        if AppConfig.isDemoFlowEnabled {
            do {
                let current = try await repository.loadTemplates(for: activeHouseholdId)
                let hasDropoff = current.contains { $0.name == "School Dropoff" }
                let hasPickup = current.contains { $0.name == "School Pickup" }
                guard current.isEmpty || !hasDropoff || !hasPickup else { return }
                try await SystemBootstrap.seedDemoSchedules()
                await refresh()
            } catch {
                lastError = "Failed to seed demo schedules."
            }
        }
#endif
    }

    func generateRuns(daysAhead: Int = 14) async -> Int {
        guard !isWorking else { return 0 }
        isWorking = true
        defer { isWorking = false }
        do {
            lastError = nil
            return try await SystemBootstrap.generateAndPersistRuns(daysAhead: daysAhead)
        } catch {
            lastError = "Failed to generate runs."
            return 0
        }
    }

    var diagnosticsRepositoryType: String {
        repositoryTypeName
    }

    private var activeHouseholdId: UUID {
        householdContext.householdId
    }

    private func validationError(for template: SystemDomain.ScheduleTemplate) -> String? {
        if template.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Schedule title is required."
        }
        if template.weekdays.isEmpty {
            return "Select at least one weekday."
        }
        if template.stops.count < 2 {
            return "At least 2 stops are required."
        }
        for stop in template.stops {
            if stop.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Each stop needs a label."
            }
            if !(-90.0...90.0).contains(stop.latitude) {
                return "Stop latitude must be between -90 and 90."
            }
            if !(-180.0...180.0).contains(stop.longitude) {
                return "Stop longitude must be between -180 and 180."
            }
        }
        return nil
    }
}
