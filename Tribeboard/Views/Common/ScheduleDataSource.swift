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
    private let authService: AuthService
    private let householdBackendService: HouseholdBackendService
    private let syncCoordinator: SyncCoordinator?
    private let backendRunsContext: BackendRunsContext?
    private let repositoryTypeName: String

    init(
        repository: (any ScheduleRepository)? = nil,
        householdContext: ActiveHouseholdContext? = nil,
        authService: AuthService? = nil,
        householdBackendService: HouseholdBackendService? = nil,
        syncCoordinator: SyncCoordinator? = nil,
        backendRunsContext: BackendRunsContext? = nil
    ) {
        self.repository = repository ?? LocalScheduleRepository()
        self.householdContext = householdContext ?? ActiveHouseholdContext()
        self.authService = authService ?? SupabaseAuthService()
        self.householdBackendService = householdBackendService ?? SupabaseHouseholdBackendService()
        self.syncCoordinator = syncCoordinator
        self.backendRunsContext = backendRunsContext
        self.repositoryTypeName = String(describing: type(of: self.repository))
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

    func clearHouseholdScopedData() {
        templates = []
        lastError = nil
    }

    func upsert(_ template: SystemDomain.ScheduleTemplate) async {
        guard await ensureScheduleMutationPermission(action: "upsertSchedule") else {
            return
        }
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
        guard await ensureScheduleMutationPermission(action: "deleteSchedule") else {
            return
        }
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
        guard await ensureScheduleMutationPermission(action: "toggleScheduleEnabled") else {
            return
        }
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
        // Sprint 40: disable schedule fallback/demo seeding to prevent phantom templates.
        lastError = "Demo schedule seeding is disabled."
    }

    func generateRuns(daysAhead: Int = 14) async -> Int {
        guard !isWorking else { return 0 }
        isWorking = true
        defer { isWorking = false }
        do {
            lastError = nil
            let templates = try await repository.loadTemplates(for: activeHouseholdId)
                .filter { $0.householdId == activeHouseholdId && !$0.weekdays.isEmpty }
            let runRepository = LocalRunRepository()
            let existingRuns = try await runRepository.loadRuns(for: activeHouseholdId)
            let generated = RunGeneratorService().generateRuns(
                from: templates,
                existingRuns: existingRuns,
                daysAhead: daysAhead
            )
            guard !generated.isEmpty else { return 0 }
            guard let backendRunsContext else {
                lastError = "Backend is not available to generate runs."
                return 0
            }
            var createdCount = 0
            for run in generated {
                do {
                    _ = try await backendRunsContext.createRun(from: run)
                    createdCount += 1
                } catch {
                    lastError = "Failed to save generated run: \(error.localizedDescription)"
                }
            }
            return createdCount
        } catch {
            lastError = "Failed to generate runs."
            return 0
        }
    }

    var diagnosticsRepositoryType: String {
        repositoryTypeName
    }

    var templatesLoadedCount: Int {
        templates.count
    }

    var templatesForActiveHouseholdCount: Int {
        templates.filter { $0.householdId == activeHouseholdId }.count
    }

    func templateExists(id: UUID, in householdId: UUID? = nil) -> Bool {
        let scopedHouseholdId = householdId ?? activeHouseholdId
        return templates.contains { $0.id == id && $0.householdId == scopedHouseholdId }
    }

    func upsertScheduleFromBackend(
        _ backendSchedule: BackendScheduleTemplate,
        backendStops: [BackendScheduleStop] = [],
        fallbackDriverId: UUID? = nil
    ) async {
        do {
            let householdId = backendSchedule.householdId
            var scoped = try await repository.loadTemplates(for: householdId)
            let existing = scoped.first(where: { $0.id == backendSchedule.id })
            let mapped = mapBackendSchedule(
                backendSchedule,
                backendStops: backendStops,
                existingTemplate: existing,
                fallbackDriverId: fallbackDriverId
            )
            if let index = scoped.firstIndex(where: { $0.id == mapped.id }) {
                scoped[index] = mapped
            } else {
                scoped.append(mapped)
            }
            try await repository.saveTemplates(scoped, for: householdId)
            await refresh()
            lastError = nil
        } catch {
            lastError = "Failed to upsert backend schedule."
        }
    }

    func replaceSchedulesFromBackend(
        _ backendSchedules: [BackendScheduleTemplate],
        stopsByScheduleId: [UUID: [BackendScheduleStop]] = [:],
        householdId: UUID
    ) async {
        do {
            let existing = try await repository.loadTemplates(for: householdId)
            let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
            let mapped = backendSchedules.map {
                mapBackendSchedule(
                    $0,
                    backendStops: stopsByScheduleId[$0.id] ?? [],
                    existingTemplate: existingById[$0.id]
                )
            }
            try await repository.saveTemplates(mapped, for: householdId)
            await refresh()
            lastError = nil
        } catch {
            lastError = "Failed to replace schedules from backend."
        }
    }

    func removeScheduleFromBackend(id: UUID, householdId: UUID) async {
        do {
            let scoped = try await repository.loadTemplates(for: householdId)
            let filtered = scoped.filter { $0.id != id }
            try await repository.saveTemplates(filtered, for: householdId)
            await refresh()
            lastError = nil
        } catch {
            lastError = "Failed to remove backend schedule."
        }
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
            if !HouseholdLocationCoordinateValidator.isValid(latitude: stop.latitude, longitude: stop.longitude) {
                return "Stop \"\(stop.name)\" needs a saved location with valid coordinates."
            }
        }
        return nil
    }

    private func ensureScheduleMutationPermission(action: String) async -> Bool {
        guard BackendConfig.isBackendConfigured else {
            return true
        }
        do {
            guard let session = try await authService.restoreSession() else {
                return true
            }
            let memberships = try await householdBackendService.fetchMyMemberships(session: session)
            let membership = BackendPermissionGuard.activeMembership(
                for: activeHouseholdId,
                memberships: memberships
            )
            try BackendPermissionGuard.requireOrganiser(membership, action: action)
            return true
        } catch let error as BackendPermissionError {
            lastError = error.localizedDescription
            return false
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func mapBackendSchedule(
        _ schedule: BackendScheduleTemplate,
        backendStops: [BackendScheduleStop],
        existingTemplate: SystemDomain.ScheduleTemplate?,
        fallbackDriverId: UUID? = nil
    ) -> SystemDomain.ScheduleTemplate {
        let start = parseTime(schedule.departureTime) ?? DateComponents(hour: 6, minute: 45)
        let weekday = weekdayValue(from: schedule.weekday)
        let stops = mappedStops(backendStops, fallbackStops: existingTemplate?.stops)
        return SystemDomain.ScheduleTemplate(
            id: schedule.id,
            householdId: schedule.householdId,
            name: schedule.title.trimmingCharacters(in: .whitespacesAndNewlines),
            childId: schedule.childId,
            driverId: existingTemplate?.driverId ?? fallbackDriverId,
            weekdays: [weekday],
            hour: start.hour ?? 6,
            minute: start.minute ?? 45,
            stops: stops,
            isActive: true,
            createdAt: schedule.createdAtDate ?? Date()
        )
    }

    private func parseTime(_ value: String) -> DateComponents? {
        let parts = value.split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else {
            return nil
        }
        return DateComponents(hour: hour, minute: minute)
    }

    private func weekdayValue(from name: String) -> Int {
        switch name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "sunday": return 1
        case "monday": return 2
        case "tuesday": return 3
        case "wednesday": return 4
        case "thursday": return 5
        case "friday": return 6
        case "saturday": return 7
        default: return 2
        }
    }

    private var quickPlaceIndex: [String: StopCoordinateHydrator.PlaceCoordinate] = [:]

    func updateQuickPlaceIndex(
        slotPlaces: [String: ResolvedFamilyPlace],
        namedPlaces: [ResolvedFamilyPlace] = [],
        recentPlaces: [ResolvedFamilyPlace] = [],
        homeLocation: BackendHouseholdLocation? = nil,
        householdLocations: [BackendHouseholdLocation] = []
    ) {
        quickPlaceIndex = StopCoordinateHydrator.buildPlaceIndex(
            slotPlaces: slotPlaces,
            namedPlaces: namedPlaces,
            recentPlaces: recentPlaces,
            homeLocation: homeLocation,
            householdLocations: householdLocations
        )
    }

    private func defaultStops() -> [SystemDomain.Stop] {
        [
            SystemDomain.Stop(id: UUID(), name: "Start", latitude: 0, longitude: 0, order: 0),
            SystemDomain.Stop(id: UUID(), name: "End", latitude: 0, longitude: 0, order: 1)
        ]
    }

    private func mappedStops(
        _ backendStops: [BackendScheduleStop],
        fallbackStops: [SystemDomain.Stop]?
    ) -> [SystemDomain.Stop] {
        if !backendStops.isEmpty {
            return backendStops
                .sorted { $0.stopOrder < $1.stopOrder }
                .map { stop in
                    let mapped = SystemDomain.Stop(
                        id: stop.id,
                        name: stop.label,
                        latitude: stop.latitude,
                        longitude: stop.longitude,
                        order: stop.stopOrder,
                        locationId: stop.locationId
                    )
                    return StopCoordinateHydrator.hydrate(mapped, places: quickPlaceIndex)
                }
        }
        if let fallbackStops, !fallbackStops.isEmpty {
            return fallbackStops
        }
        return defaultStops()
    }
}
