import Foundation
import Combine

@MainActor
final class BackendRunsContext: ObservableObject {
    @Published private(set) var runs: [BackendRun] = []
    @Published private(set) var isLoading: Bool = false
    @Published var lastError: String?
    @Published private(set) var lastSyncFailed: Bool = false
    @Published private(set) var lastLoadedHouseholdId: UUID?

    private let service: RunBackendService
    private let scheduleBackendService: ScheduleBackendService
    private let runRepository: any RunRepository
    private let scheduleRepository: any ScheduleRepository
    private let driverRepository: any DriverRepository
    private var isRefreshInFlight = false
    private var hasPendingRefresh = false

    init(
        service: RunBackendService? = nil,
        scheduleBackendService: ScheduleBackendService? = nil,
        runRepository: (any RunRepository)? = nil,
        scheduleRepository: (any ScheduleRepository)? = nil,
        driverRepository: (any DriverRepository)? = nil
    ) {
        self.service = service ?? SupabaseRunBackendService()
        self.scheduleBackendService = scheduleBackendService ?? SupabaseScheduleBackendService()
        self.runRepository = runRepository ?? LocalRunRepository()
        self.scheduleRepository = scheduleRepository ?? LocalScheduleRepository()
        self.driverRepository = driverRepository ?? LocalDriverRepository()
    }

    /// Loads runs from Supabase (source of truth) and writes them to the offline cache.
    @discardableResult
    func refreshRuns(householdId: UUID) async -> [SystemDomain.RunInstance] {
        if isRefreshInFlight {
            hasPendingRefresh = true
            return await cachedRuns(householdId: householdId)
        }
        isRefreshInFlight = true
        isLoading = true
        defer {
            isLoading = false
            isRefreshInFlight = false
        }

        guard BackendConfig.isBackendConfigured else {
            lastSyncFailed = true
            lastError = "Backend is not configured. Showing cached runs only."
            do {
                return try await runRepository.loadRuns(for: householdId).sorted { $0.date < $1.date }
            } catch {
                return []
            }
        }

        do {
            let packages = try await service.fetchRunPackages(householdId: householdId)
            runs = packages.map(\.run)
            let templates = (try? await scheduleRepository.loadTemplates(for: householdId)) ?? []
            let drivers = (try? await driverRepository.loadDrivers(for: householdId)) ?? []
            let templateById = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
            let driversById = Dictionary(uniqueKeysWithValues: drivers.map { ($0.id, $0) })

            let mapped = packages.map { package -> SystemDomain.RunInstance in
                let template = templateById[package.run.scheduleId]
                let driverName = package.run.driverId.flatMap { driversById[$0]?.name }
                return RunPersistenceMapper.runInstance(
                    from: package,
                    template: template,
                    driverName: driverName,
                    childId: package.run.childId ?? template?.childId
                )
            }.sorted { $0.date < $1.date }

            try await runRepository.saveRuns(mapped, for: householdId)
            lastLoadedHouseholdId = householdId
            lastError = nil
            lastSyncFailed = false

            if hasPendingRefresh {
                hasPendingRefresh = false
                return await refreshRuns(householdId: householdId)
            }
            return mapped
        } catch {
            lastSyncFailed = true
            lastError = "Could not load runs from server: \(error.localizedDescription)"
            do {
                return try await runRepository.loadRuns(for: householdId).sorted { $0.date < $1.date }
            } catch {
                return []
            }
        }
    }

    /// Creates a run and its stops in Supabase, then caches locally.
    func createRun(
        from run: SystemDomain.RunInstance,
        requireRemoteScheduleValidation: Bool = true
    ) async throws -> SystemDomain.RunInstance {
        guard BackendConfig.isBackendConfigured else {
            throw RunPersistenceError.backendNotConfigured
        }

        if requireRemoteScheduleValidation {
            let exists = await validateScheduleTemplateForRunCreation(
                scheduleId: run.templateId,
                householdId: run.householdId
            )
            guard exists else {
                throw RunPersistenceError.scheduleTemplateMissing
            }
        }

        try RunCreationValidator.validate(run)

        let package = RunPersistenceMapper.package(from: run)
        _ = try await service.createRunPackage(package)
        let refreshed = await refreshRuns(householdId: run.householdId)
        if let mapped = refreshed.first(where: { $0.id == run.id }) {
            return mapped
        }
        let templates = (try? await scheduleRepository.loadTemplates(for: run.householdId)) ?? []
        let template = templates.first(where: { $0.id == run.templateId })
        let fallback = RunPersistenceMapper.runInstance(
            from: package,
            template: template,
            driverName: run.assignedDriverName,
            childId: run.childId
        )
        try await upsertCachedRun(fallback, householdId: run.householdId)
        lastError = nil
        lastSyncFailed = false
        return fallback
    }

    /// Persists the full run header and all stop rows to Supabase, then caches locally.
    func persistRun(_ run: SystemDomain.RunInstance) async throws -> SystemDomain.RunInstance {
        guard BackendConfig.isBackendConfigured else {
            throw RunPersistenceError.backendNotConfigured
        }

        let package = RunPersistenceMapper.package(from: run)
        _ = try await service.updateRunHeader(package.run)
        _ = try await service.replaceRunStops(runId: run.id, stops: package.stops)

        let templates = (try? await scheduleRepository.loadTemplates(for: run.householdId)) ?? []
        let template = templates.first(where: { $0.id == run.templateId })
        let refreshedPackage = BackendRunPackage(run: package.run, stops: package.stops)
        let mapped = RunPersistenceMapper.runInstance(
            from: refreshedPackage,
            template: template,
            driverName: run.assignedDriverName,
            childId: run.childId
        )
        try await upsertCachedRun(mapped, householdId: run.householdId)
        runs.removeAll { $0.id == mapped.id }
        runs.append(package.run)
        lastError = nil
        lastSyncFailed = false
        return mapped
    }

    /// Starts a run: `runs.status = in_progress`, first stop `en_route`.
    func startRun(_ run: SystemDomain.RunInstance) async throws -> SystemDomain.RunInstance {
        guard run.assignedDriverId != nil || run.driverId != nil else {
            throw RunPersistenceError.missingAssignedDriver
        }
        let updated = try RunStateMachine().start(run, now: Date())
        let firstStopStatus = updated.stops.first?.status.rawValue ?? "none"
        NSLog(
            "[StartRun] run_id=%@ status=in_progress first_stop_status=%@ stop_count=%d",
            updated.id.uuidString,
            firstStopStatus,
            updated.stops.count
        )
        return try await persistRun(updated)
    }

    func deleteRun(id: UUID, householdId: UUID) async throws {
        guard BackendConfig.isBackendConfigured else {
            throw RunPersistenceError.backendNotConfigured
        }
        try await service.deleteRun(id: id)
        try await removeCachedRun(id: id, householdId: householdId)
        runs.removeAll { $0.id == id }
        lastError = nil
        lastSyncFailed = false
    }

    func reset() {
        runs = []
        isLoading = false
        lastError = nil
        lastSyncFailed = false
        lastLoadedHouseholdId = nil
        isRefreshInFlight = false
        hasPendingRefresh = false
    }

    private func upsertCachedRun(_ run: SystemDomain.RunInstance, householdId: UUID) async throws {
        var existing = try await runRepository.loadRuns(for: householdId)
        if let index = existing.firstIndex(where: { $0.id == run.id }) {
            existing[index] = run
        } else {
            existing.append(run)
        }
        try await runRepository.saveRuns(existing.sorted { $0.date < $1.date }, for: householdId)
    }

    private func cachedRuns(householdId: UUID) async -> [SystemDomain.RunInstance] {
        (try? await runRepository.loadRuns(for: householdId))?.sorted { $0.date < $1.date } ?? []
    }

    private func removeCachedRun(id: UUID, householdId: UUID) async throws {
        let existing = try await runRepository.loadRuns(for: householdId)
        let filtered = existing.filter { $0.id != id }
        try await runRepository.saveRuns(filtered.sorted { $0.date < $1.date }, for: householdId)
    }

    private func validateScheduleTemplateForRunCreation(scheduleId: UUID, householdId: UUID) async -> Bool {
        do {
            let loadedTemplates = try await scheduleBackendService.fetchSchedules(householdId: householdId)
            let templateExists = loadedTemplates.contains { $0.id == scheduleId }
            if !templateExists {
                lastError = "Cannot create run because the selected schedule template is not available in backend."
            }
            return templateExists
        } catch {
            lastError = "Unable to validate schedule template before creating run."
            return false
        }
    }
}

enum RunPersistenceError: LocalizedError {
    case backendNotConfigured
    case scheduleTemplateMissing
    case missingAssignedDriver
    case invalidRunPayload(RunCreationValidator.ValidationError)

    var errorDescription: String? {
        switch self {
        case .backendNotConfigured:
            return "Backend is not configured."
        case .scheduleTemplateMissing:
            return "Schedule template is missing in backend."
        case .missingAssignedDriver:
            return "Assign a driver before starting this run."
        case .invalidRunPayload(let error):
            return error.localizedDescription
        }
    }
}
