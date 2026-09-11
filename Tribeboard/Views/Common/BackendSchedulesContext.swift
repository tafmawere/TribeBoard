import Foundation
import Combine

@MainActor
final class BackendSchedulesContext: ObservableObject {
    @Published private(set) var schedules: [BackendScheduleTemplate] = []
    @Published private(set) var isLoading: Bool = false
    @Published var lastError: String?

    private let service: ScheduleBackendService
    private let scheduleDataSource: ScheduleDataSource
    private let syncCoordinator: SyncCoordinator?
    private let householdLocationsContext: BackendHouseholdLocationsContext?
    private var activeHouseholdId: UUID?
    private var isRefreshInFlight = false
    private var hasPendingRefresh = false

    init(
        service: ScheduleBackendService? = nil,
        scheduleDataSource: ScheduleDataSource,
        syncCoordinator: SyncCoordinator? = nil,
        householdLocationsContext: BackendHouseholdLocationsContext? = nil
    ) {
        self.service = service ?? SupabaseScheduleBackendService()
        self.scheduleDataSource = scheduleDataSource
        self.syncCoordinator = syncCoordinator
        self.householdLocationsContext = householdLocationsContext
    }

    func refreshSchedules(householdId: UUID) async {
        activeHouseholdId = householdId
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
        do {
            let fetched = try await service.fetchSchedules(householdId: householdId)
#if DEBUG
            print(
                "[BackendSchedulesContext] fetch returned rows=\(fetched.count), " +
                "activeHouseholdId=\(householdId.uuidString)"
            )
#endif
            let stops = try await service.fetchScheduleStops(scheduleIds: fetched.map(\.id))
            let stopsByScheduleId = Dictionary(grouping: stops, by: \.scheduleId)
            let merged = mergeBackendSchedules(current: schedules, fetched: fetched)
            await MainActor.run {
                schedules = merged
            }
            if shouldReplaceLocalSchedulesFromBackend(householdId: householdId) {
                await scheduleDataSource.replaceSchedulesFromBackend(
                    fetched,
                    stopsByScheduleId: stopsByScheduleId,
                    householdId: householdId
                )
            }
            await MainActor.run {
                lastError = nil
            }
#if DEBUG
            print(
                "[BackendSchedulesContext] published schedules_count=\(schedules.count), " +
                "activeHouseholdId=\(householdId.uuidString)"
            )
#endif
        } catch {
            lastError = error.localizedDescription
        }
        if hasPendingRefresh {
            hasPendingRefresh = false
            await refreshSchedules(householdId: householdId)
        }
    }

    @discardableResult
    func createSchedule(from template: SystemDomain.ScheduleTemplate) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
#if DEBUG
            print("[BackendSchedulesContext] createSchedule start household_id=\(template.householdId.uuidString), child_id=\(template.childId.uuidString), title=\(template.name)")
#endif
            let weekdays = template.weekdays.sorted()
            guard !weekdays.isEmpty else {
                lastError = "Select at least one weekday."
                return false
            }
            try validateStops(template.stops)
            for (index, weekdayValue) in weekdays.enumerated() {
                let payload = mapToBackend(
                    template,
                    weekdayValue: weekdayValue,
                    explicitId: index == 0 ? template.id : UUID()
                )
#if DEBUG
                print(
                    "[BackendSchedulesContext] schedule_templates insert payload: " +
                    "household_id=\(payload.householdId.uuidString), " +
                    "child_id=\(payload.childId.uuidString), " +
                    "title=\(payload.title), " +
                    "weekday=\(payload.weekday), " +
                    "departure_time=\(payload.departureTime)"
                )
#endif
                let createdTemplate = try await service.createSchedule(payload)
                let backendStops = try mapStopsToBackend(
                    template.stops,
                    scheduleId: createdTemplate.id,
                    childId: template.childId
                )
                let createdStops = try await service.replaceScheduleStops(scheduleId: createdTemplate.id, stops: backendStops)
                schedules.removeAll { $0.id == createdTemplate.id }
                schedules.append(createdTemplate)
                await scheduleDataSource.upsertScheduleFromBackend(
                    createdTemplate,
                    backendStops: createdStops,
                    fallbackDriverId: template.driverId
                )
            }
#if DEBUG
            print("[BackendSchedulesContext] createSchedule success title=\(template.name) weekday_count=\(weekdays.count)")
#endif
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
#if DEBUG
            print("[BackendSchedulesContext] createSchedule failed household_id=\(template.householdId.uuidString), child_id=\(template.childId.uuidString), title=\(template.name), error=\(error.localizedDescription)")
#endif
            return false
        }
    }

    @discardableResult
    func updateSchedule(from template: SystemDomain.ScheduleTemplate) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            try validateStops(template.stops)
            let weekdayValue = template.weekdays.sorted().first ?? 2
            let payload = mapToBackend(template, weekdayValue: weekdayValue)
#if DEBUG
            print("[BackendSchedulesContext] updateSchedule start household_id=\(template.householdId.uuidString), child_id=\(template.childId.uuidString), title=\(template.name)")
            print(
                "[BackendSchedulesContext] schedule_templates update payload: " +
                "household_id=\(payload.householdId.uuidString), " +
                "child_id=\(payload.childId.uuidString), " +
                "title=\(payload.title), " +
                "weekday=\(payload.weekday), " +
                "departure_time=\(payload.departureTime)"
            )
#endif
            let updatedTemplate = try await service.updateSchedule(payload)
            let backendStops = try mapStopsToBackend(
                template.stops,
                scheduleId: updatedTemplate.id,
                childId: template.childId
            )
            let updatedStops = try await service.replaceScheduleStops(scheduleId: updatedTemplate.id, stops: backendStops)
            schedules.removeAll { $0.id == updatedTemplate.id }
            schedules.append(updatedTemplate)
            await scheduleDataSource.upsertScheduleFromBackend(
                updatedTemplate,
                backendStops: updatedStops,
                fallbackDriverId: template.driverId
            )
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func deleteSchedule(id: UUID, householdId: UUID) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.deleteSchedule(id: id)
            schedules.removeAll { $0.id == id }
            await scheduleDataSource.removeScheduleFromBackend(id: id, householdId: householdId)
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
    
    func reset() {
        schedules = []
        isLoading = false
        lastError = nil
        activeHouseholdId = nil
        isRefreshInFlight = false
        hasPendingRefresh = false
    }
    
    private func shouldReplaceLocalSchedulesFromBackend(householdId: UUID) -> Bool {
        guard let syncCoordinator else { return true }
        let pending = syncCoordinator.pendingOperations(for: householdId, entityType: .schedule)
        return pending.isEmpty
    }
    
    private func mergeBackendSchedules(
        current: [BackendScheduleTemplate],
        fetched: [BackendScheduleTemplate]
    ) -> [BackendScheduleTemplate] {
        var mergedById = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        for schedule in fetched {
            mergedById[schedule.id] = schedule
        }
        return Array(mergedById.values)
    }

    private func mapToBackend(
        _ template: SystemDomain.ScheduleTemplate,
        weekdayValue: Int,
        explicitId: UUID? = nil
    ) -> BackendScheduleTemplate {
        let departureTime = String(format: "%02d:%02d:00", template.hour, template.minute)
        return BackendScheduleTemplate(
            id: explicitId ?? template.id,
            householdId: template.householdId,
            childId: template.childId,
            title: template.name,
            weekday: weekdayName(for: weekdayValue),
            departureTime: departureTime,
            createdAt: nil
        )
    }

    private func weekdayName(for value: Int) -> String {
        switch value {
        case 1: return "sunday"
        case 2: return "monday"
        case 3: return "tuesday"
        case 4: return "wednesday"
        case 5: return "thursday"
        case 6: return "friday"
        case 7: return "saturday"
        default: return "monday"
        }
    }

    private func mapStopsToBackend(
        _ stops: [SystemDomain.Stop],
        scheduleId: UUID,
        childId: UUID
    ) throws -> [BackendScheduleStop] {
        let resolvedStops = try resolveStopsForBackend(stops)
        return try resolvedStops.sorted { $0.order < $1.order }.enumerated().map { index, stop in
            try HouseholdLocationCoordinateValidator.validate(
                latitude: stop.latitude,
                longitude: stop.longitude
            )
            guard stop.locationId != nil else {
                throw HouseholdLocationValidationError.missingCoordinates
            }
            return BackendScheduleStop(
                id: stop.id,
                scheduleId: scheduleId,
                childId: childId,
                label: stop.name,
                latitude: stop.latitude,
                longitude: stop.longitude,
                stopOrder: index,
                locationId: stop.locationId
            )
        }
    }

    private func validateStops(_ stops: [SystemDomain.Stop]) throws {
        guard stops.count >= 2 else {
            throw HouseholdLocationValidationError.missingCoordinates
        }
        let resolved = try resolveStopsForBackend(stops)
        for stop in resolved.sorted(by: { $0.order < $1.order }) {
            try HouseholdLocationCoordinateValidator.validate(
                latitude: stop.latitude,
                longitude: stop.longitude
            )
            guard stop.locationId != nil else {
                throw HouseholdLocationValidationError.missingCoordinates
            }
        }
    }

    private func resolveStopsForBackend(_ stops: [SystemDomain.Stop]) throws -> [SystemDomain.Stop] {
        let locations = householdLocationsContext?.locations ?? []
        let (backfilled, _) = HouseholdLocationBackfillService.backfillScheduleStops(stops, locations: locations)
        return backfilled.map { stop in
            guard !HouseholdLocationCoordinateValidator.isValid(latitude: stop.latitude, longitude: stop.longitude),
                  let match = householdLocationsContext?.findLocationByNameOrLabel(stop.name) else {
                return stop
            }
            var updated = stop
            updated.locationId = match.id
            updated.name = match.displayName
            updated.latitude = match.latitude
            updated.longitude = match.longitude
            return updated
        }
    }

    func repairPlaceholderScheduleStops(householdId: UUID) async {
        guard let householdLocationsContext else { return }
        let locations = householdLocationsContext.locations
        guard !locations.isEmpty else { return }
        do {
            let templates = try await service.fetchSchedules(householdId: householdId)
            let stops = try await service.fetchScheduleStops(scheduleIds: templates.map(\.id))
            let grouped = Dictionary(grouping: stops, by: \.scheduleId)
            for template in templates {
                guard let scheduleStops = grouped[template.id], !scheduleStops.isEmpty else { continue }
                let localStops = scheduleStops.sorted { $0.stopOrder < $1.stopOrder }.map {
                    SystemDomain.Stop(
                        id: $0.id,
                        name: $0.label,
                        latitude: $0.latitude,
                        longitude: $0.longitude,
                        order: $0.stopOrder,
                        locationId: $0.locationId
                    )
                }
                let (repaired, result) = HouseholdLocationBackfillService.backfillScheduleStops(
                    localStops,
                    locations: locations
                )
                guard result.repairedStopCount > 0 else { continue }
                let backendStops = try mapStopsToBackend(
                    repaired,
                    scheduleId: template.id,
                    childId: template.childId
                )
                _ = try await service.replaceScheduleStops(scheduleId: template.id, stops: backendStops)
            }
            await refreshSchedules(householdId: householdId)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
