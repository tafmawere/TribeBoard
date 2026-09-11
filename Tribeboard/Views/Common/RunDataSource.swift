import Foundation
import Combine
import CoreLocation

struct DispatchSummary {
    let total: Int
    let unassigned: Int
    let inProgress: Int
    let completed: Int
}

struct DriverDaySummary {
    let total: Int
    let active: Int
    let scheduled: Int
    let completed: Int
    let cancelled: Int
}

typealias AttentionSummary = (critical: Int, warning: Int)

private enum RunMutationGuardError: LocalizedError {
    case missingAssignedDriver

    var errorDescription: String? {
        switch self {
        case .missingAssignedDriver:
            return "Assign a driver before starting this run."
        }
    }
}

@MainActor
final class RunDataSource: ObservableObject {
    private struct DayCacheKey: Hashable {
        let dayStart: Date
    }

    private struct DriverRunsCacheKey: Hashable {
        let driverId: UUID
        let dayStart: Date
    }

    private struct ETAGateState {
        let lastLocation: CLLocation
        let lastUpdatedAt: Date
        let prediction: ETAPrediction
    }

    struct RunBuckets {
        let todayRuns: [SystemDomain.RunInstance]
        let upcomingRuns: [SystemDomain.RunInstance]
        let historyRuns: [SystemDomain.RunInstance]
        let activeRuns: [SystemDomain.RunInstance]
    }

    @Published private(set) var runs: [SystemDomain.RunInstance] = [] {
        didSet {
            invalidateDerivedCaches()
        }
    }
    @Published var isLoading: Bool = false
    @Published private(set) var isRefreshing: Bool = false
    @Published var lastError: String? = nil

    private let repository: any RunRepository
    private let scheduleRepository: any ScheduleRepository
    private let driverRepository: any DriverRepository
    private let householdContext: ActiveHouseholdContext
    private let backendRunsContext: BackendRunsContext?
    private let authService: AuthService
    private let householdBackendService: HouseholdBackendService
    private let syncCoordinator: SyncCoordinator?
    private let repositoryTypeName: String
    private let scheduleRepositoryTypeName: String
    private let driverRepositoryTypeName: String
    private let dispatchBucketer = DispatchBucketer()
    private let conflictDetector = RunConflictDetector()
    private let attentionEngine = AttentionEngine()
    private let proximityEngine = RunProximityEngine()
    private let etaEngine = ETAEngine()
    private let notificationPlanner = NotificationPlanner()
    private let runAdjustmentService = RunAdjustmentService()
    private let dispatchCalendar = Calendar.current
    private var didBootstrap = false
#if DEBUG
    /// Unit tests set this to skip remote permission checks when Supabase is configured in the host Info.plist.
    var testBypassRunMutationPermission = false
#endif
    private var inFlightCreateKeys: Set<String> = []
    private var inFlightRunMutationIDs: Set<UUID> = []
    private var cachedNextRun: SystemDomain.RunInstance?
    private var cachedActiveRuns: [SystemDomain.RunInstance]?
    private var cachedBucketsByDay: [DayCacheKey: RunBuckets] = [:]
    private var cachedRunsByDay: [DayCacheKey: [SystemDomain.RunInstance]] = [:]
    private var cachedDriverRuns: [DriverRunsCacheKey: [SystemDomain.RunInstance]] = [:]
    private var etaGateByRunID: [UUID: ETAGateState] = [:]
    private let minimumETAUpdateInterval: TimeInterval = 2
    private let minimumETADistanceDeltaMeters: Double = 15

    init(
        repository: (any RunRepository)? = nil,
        scheduleRepository: (any ScheduleRepository)? = nil,
        driverRepository: (any DriverRepository)? = nil,
        householdContext: ActiveHouseholdContext? = nil,
        backendRunsContext: BackendRunsContext? = nil,
        authService: AuthService? = nil,
        householdBackendService: HouseholdBackendService? = nil,
        syncCoordinator: SyncCoordinator? = nil
    ) {
        self.repository = repository ?? LocalRunRepository()
        self.scheduleRepository = scheduleRepository ?? LocalScheduleRepository()
        self.driverRepository = driverRepository ?? LocalDriverRepository()
        self.householdContext = householdContext ?? ActiveHouseholdContext()
        self.backendRunsContext = backendRunsContext
        self.authService = authService ?? SupabaseAuthService()
        self.householdBackendService = householdBackendService ?? SupabaseHouseholdBackendService()
        self.syncCoordinator = syncCoordinator
        self.repositoryTypeName = String(describing: type(of: self.repository))
        self.scheduleRepositoryTypeName = String(describing: type(of: self.scheduleRepository))
        self.driverRepositoryTypeName = String(describing: type(of: self.driverRepository))
    }

    func bootstrapIfNeeded() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        await refresh()
    }

    func refresh() async {
        if isRefreshing || isLoading { return }
        isRefreshing = true
        isLoading = true
        defer {
            isLoading = false
            isRefreshing = false
        }
        do {
            if let backendRunsContext {
                let loadedRuns = await backendRunsContext.refreshRuns(householdId: activeHouseholdId)
                runs = loadedRuns
                if backendRunsContext.lastSyncFailed, let syncError = backendRunsContext.lastError {
                    lastError = syncError
                } else {
                    lastError = nil
                }
            } else {
                let loadedRuns = try await repository.loadRuns(for: activeHouseholdId)
                runs = loadedRuns.sorted { $0.date < $1.date }
                lastError = nil
            }
#if DEBUG
            print("RunDataSource.refresh -> source=supabase loaded runs count: \(runs.count)")
#endif
        } catch {
            lastError = "Failed to load runs."
        }
    }

    func reloadForHouseholdChange() async {
        invalidateDerivedCaches()
        await refresh()
    }

    func clearHouseholdScopedData() {
        runs = []
        lastError = nil
        invalidateDerivedCaches()
    }

    func run(withId id: String) -> SystemDomain.RunInstance? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return runs.first(where: { $0.id == uuid })
    }

    func bucketedRuns(referenceDate: Date = Date(), calendar: Calendar = .current) -> RunBuckets {
        let referenceDay = DayKey.key(for: referenceDate, calendar: calendar)
        let cacheKey = DayCacheKey(dayStart: referenceDay)
        if let cached = cachedBucketsByDay[cacheKey] {
            return cached
        }

        let sorted = runs.sorted { $0.date < $1.date }
        var today: [SystemDomain.RunInstance] = []
        var upcoming: [SystemDomain.RunInstance] = []
        var history: [SystemDomain.RunInstance] = []
        let active: [SystemDomain.RunInstance] = activeRuns()

        for run in sorted {
            let isTerminal = run.status == .completed || run.status == .cancelled
            if isTerminal {
                history.append(run)
                continue
            }

            let runDay = DayKey.key(for: run.date, calendar: calendar)
            if runDay == referenceDay {
                today.append(run)
            } else if run.date > referenceDate {
                upcoming.append(run)
            } else {
                // Overdue non-terminal runs (e.g. past assigned) belong in history, not the active card.
                history.append(run)
            }
        }

        let computed = RunBuckets(
            todayRuns: today,
            upcomingRuns: upcoming,
            historyRuns: history,
            activeRuns: active
        )
        cachedBucketsByDay[cacheKey] = computed
        return computed
    }

    func runsForDay(_ date: Date, calendar: Calendar = .current) -> [SystemDomain.RunInstance] {
        let targetDay = DayKey.key(for: date, calendar: calendar)
        let key = DayCacheKey(dayStart: targetDay)
        if let cached = cachedRunsByDay[key] {
            return cached
        }
        let computed = runs
            .filter { DayKey.key(for: $0.date, calendar: calendar) == targetDay }
            .sorted { $0.date < $1.date }
        cachedRunsByDay[key] = computed
        return computed
    }

    func runsForDay(_ date: Date) -> [SystemDomain.RunInstance] {
        runsForDay(date, calendar: dispatchCalendar)
    }

    func runsForDriver(_ driverId: UUID, on date: Date) -> [SystemDomain.RunInstance] {
        let key = DriverRunsCacheKey(
            driverId: driverId,
            dayStart: DayKey.key(for: date, calendar: dispatchCalendar)
        )
        if let cached = cachedDriverRuns[key] {
            return cached
        }
        let dayRuns = runsForDay(date, calendar: dispatchCalendar)
        let computed = dayRuns
            .filter { $0.assignedDriverId == driverId }
            .sorted { $0.date < $1.date }
        cachedDriverRuns[key] = computed
        return computed
    }

    func activeRunForDriver(_ driverId: UUID, on date: Date) -> SystemDomain.RunInstance? {
        runsForDriver(driverId, on: date).first(where: { $0.status == .inProgress })
    }

    func nextRun(referenceDate: Date = Date(), calendar: Calendar = .current) -> SystemDomain.RunInstance? {
        let result = RunNextRunSelector.select(
            from: runs,
            referenceDate: referenceDate,
            calendar: calendar
        )
        cachedNextRun = result.run
        return result.run
    }

    func activeRuns() -> [SystemDomain.RunInstance] {
        if let cachedActiveRuns {
            return cachedActiveRuns
        }
        let computed = runs
            .filter { $0.status == .inProgress }
            .sorted { $0.date < $1.date }
        cachedActiveRuns = computed
        return computed
    }

    func nextScheduledRunForDriver(
        _ driverId: UUID,
        on date: Date,
        now: Date = Date()
    ) -> SystemDomain.RunInstance? {
        runsForDriver(driverId, on: date)
            .filter { $0.status == .scheduled && $0.date >= now }
            .sorted { $0.date < $1.date }
            .first
    }

    func driverSummary(for driverId: UUID, on date: Date) -> DriverDaySummary {
        let driverRuns = runsForDriver(driverId, on: date)
        return DriverDaySummary(
            total: driverRuns.count,
            active: driverRuns.filter { $0.status == .inProgress }.count,
            scheduled: driverRuns.filter { $0.status == .scheduled }.count,
            completed: driverRuns.filter { $0.status == .completed }.count,
            cancelled: driverRuns.filter { $0.status == .cancelled }.count
        )
    }

    func proximityForRun(
        _ runId: UUID,
        driverLocation: CLLocation
    ) -> RunProximity? {
        guard let run = runs.first(where: { $0.id == runId }) else { return nil }
        return proximityEngine.evaluate(run: run, driverLocation: driverLocation)
    }

    func proximityForDriverRuns(
        driverId: UUID,
        location: CLLocation
    ) -> [RunProximity] {
        runsForDriver(driverId, on: Date())
            .compactMap { proximityEngine.evaluate(run: $0, driverLocation: location) }
            .sorted { $0.distanceMeters < $1.distanceMeters }
    }

    func etaForRun(
        _ runId: UUID,
        currentLocation: CLLocation,
        now: Date = Date(),
        speedMetersPerSecond: Double? = nil,
        sampleCount: Int = 0,
        speedVariance: Double? = nil
    ) -> ETAPrediction? {
        guard let run = runs.first(where: { $0.id == runId }) else { return nil }
        if run.status == .completed || run.status == .cancelled {
            etaGateByRunID.removeValue(forKey: runId)
            return nil
        }
        if let gate = etaGateByRunID[runId] {
            let movedDistance = currentLocation.distance(from: gate.lastLocation)
            let elapsed = now.timeIntervalSince(gate.lastUpdatedAt)
            if movedDistance < minimumETADistanceDeltaMeters && elapsed < minimumETAUpdateInterval {
                return gate.prediction
            }
        }

        return etaEngine.predict(
            run: run,
            currentLocation: currentLocation,
            now: now,
            config: etaConfig(using: speedMetersPerSecond),
            liveSpeedMetersPerSecond: speedMetersPerSecond,
            sampleCount: sampleCount,
            speedVariance: speedVariance
        ).map { prediction in
            etaGateByRunID[runId] = ETAGateState(
                lastLocation: currentLocation,
                lastUpdatedAt: now,
                prediction: prediction
            )
            return prediction
        }
    }

    func etaForDriverRuns(
        driverId: UUID,
        currentLocation: CLLocation,
        now: Date = Date(),
        speedMetersPerSecond: Double? = nil,
        sampleCount: Int = 0,
        speedVariance: Double? = nil
    ) -> [ETAPrediction] {
        return runsForDriver(driverId, on: now)
            .compactMap { run in
                etaForRun(
                    run.id,
                    currentLocation: currentLocation,
                    now: now,
                    speedMetersPerSecond: speedMetersPerSecond,
                    sampleCount: sampleCount,
                    speedVariance: speedVariance
                )
            }
            .sorted { $0.nextStopETA < $1.nextStopETA }
    }

    func smoothedETAForRun(
        _ runId: UUID,
        currentLocation: CLLocation,
        now: Date = Date(),
        liveSpeedMetersPerSecond: Double? = nil,
        sampleCount: Int = 0,
        speedVariance: Double? = nil,
        smoothingService: ETASmoothingService? = nil
    ) -> ETAPrediction? {
        guard let prediction = etaForRun(
            runId,
            currentLocation: currentLocation,
            now: now,
            speedMetersPerSecond: liveSpeedMetersPerSecond,
            sampleCount: sampleCount,
            speedVariance: speedVariance
        ) else {
            if let smoothingService {
                smoothingService.clear(runId: runId)
            }
            return nil
        }

        guard let smoothingService else { return prediction }
        return smoothingService.smoothedETA(for: runId, newPrediction: prediction, now: now)
    }

    func reconcileTrackingState(
        locationService: LocationReadinessService,
        locationPublishService: RunLocationPublishService? = nil,
        currentUserId: UUID? = nil,
        drivers: [BackendDriver] = [],
        now: Date = Date()
    ) {
        let hasInProgressToday = runsForDay(now).contains { $0.status == .inProgress }
        if hasInProgressToday {
            locationService.startRunTracking()
        } else {
            locationService.stopRunTracking()
        }

        guard let locationPublishService else { return }
        if let activeRun = runsForDay(now).first(where: { $0.status == .inProgress }),
           RunDriverIdentityResolver.isCurrentUserDriver(
               run: activeRun,
               drivers: drivers,
               currentUserId: currentUserId
           ) {
            locationPublishService.startPublishing(
                runId: activeRun.id,
                householdId: activeRun.householdId,
                driverId: activeRun.assignedDriverId ?? activeRun.driverId
            )
        } else {
            locationPublishService.stopPublishing()
        }
    }

    func dispatchBuckets(for date: Date) -> DispatchBuckets {
        dispatchBucketer.bucket(runs, for: date, calendar: dispatchCalendar)
    }

    func plannedNotifications(for date: Date, now: Date = Date()) -> [PlannedNotification] {
        let dayRuns = runsForDay(date)
        let dayAttention = attentionItems(for: date, now: now)
        return notificationPlanner.plan(
            runs: dayRuns,
            attentionItems: dayAttention,
            now: now,
            calendar: dispatchCalendar
        )
    }

    func reconcileNotifications(
        notificationService: NotificationService,
        for date: Date = Date(),
        now: Date = Date()
    ) async {
        let planned = plannedNotifications(for: date, now: now)
        let plannedIDs = Set(planned.map(\.id))
        let pendingIDs = Set(await notificationService.pendingRequestIDs())

        let missing = planned.filter { !pendingIDs.contains($0.id) }
        for item in missing {
            await notificationService.schedule(item.request)
        }

        let dayKey = notificationDayKey(for: date, calendar: dispatchCalendar)
        let stale = pendingIDs.filter { id in
            id.hasPrefix("tb-") && id.hasSuffix("-\(dayKey)") && !plannedIDs.contains(id)
        }
        if !stale.isEmpty {
            await notificationService.removePending(withIDs: Array(stale))
        }
    }

    func conflictsForDay(_ date: Date) -> [RunConflict] {
        conflictDetector.detectConflicts(runs, for: date, calendar: dispatchCalendar)
    }

    func dispatchSummary(for date: Date) -> DispatchSummary {
        let buckets = dispatchBuckets(for: date)
        return DispatchSummary(
            total: buckets.unassigned.count + buckets.assigned.count + buckets.inProgress.count + buckets.completed.count + buckets.cancelled.count,
            unassigned: buckets.unassigned.count,
            inProgress: buckets.inProgress.count,
            completed: buckets.completed.count
        )
    }

    func attentionItems(for date: Date, now: Date = Date()) -> [AttentionItem] {
        let dayRuns = runsForDay(date)
        let dayConflicts = conflictsForDay(date)
        return attentionEngine.evaluate(
            runs: dayRuns,
            conflicts: dayConflicts,
            now: now,
            calendar: dispatchCalendar
        )
    }

    func attentionSummary(for date: Date, now: Date = Date()) -> AttentionSummary {
        let items = attentionItems(for: date, now: now)
        let critical = items.filter { $0.severity == .critical }.count
        let warning = items.filter { $0.severity == .warning }.count
        return (critical: critical, warning: warning)
    }

    func createRun(template: SystemDomain.ScheduleTemplate, date: Date) async -> Bool {
        guard await ensureRunMutationPermission(action: "createRun") else {
            return false
        }
        if template.householdId != activeHouseholdId {
            lastError = "This schedule is not fully configured yet."
            return false
        }
        let scopedTemplates: [SystemDomain.ScheduleTemplate]
        do {
            scopedTemplates = try await scheduleRepository.loadTemplates(for: activeHouseholdId)
        } catch {
            lastError = "Unable to validate schedule template right now."
            return false
        }
        guard scopedTemplates.contains(where: { $0.id == template.id }) else {
            lastError = "This schedule is not fully configured yet."
            return false
        }

        let calendar = Calendar.current
        let day = DayKey.key(for: date, calendar: calendar)
        let createKey = "\(template.id.uuidString)-\(Int(day.timeIntervalSince1970))"
        guard !inFlightCreateKeys.contains(createKey) else { return false }
        inFlightCreateKeys.insert(createKey)
        defer { inFlightCreateKeys.remove(createKey) }

        let existingRuns: [SystemDomain.RunInstance]
        do {
            existingRuns = try await repository.loadRuns(for: activeHouseholdId)
        } catch {
            lastError = "Unable to load runs right now."
            return false
        }
        guard let runDate = RunScheduleSnapshot.scheduledDate(on: day, template: template, calendar: calendar) else {
            return false
        }
        let departureTime = RunScheduleSnapshot.departureTime(from: template)

        let duplicate = existingRuns.contains { run in
            run.templateId == template.id && DayKey.key(for: run.date, calendar: calendar) == day
        }
        guard !duplicate else { return false }

        let progressStops = template.stops.sorted { $0.order < $1.order }.map {
            SystemDomain.RunStopProgress(stopId: $0.id, status: .pending, arrivedAt: nil, departedAt: nil)
        }
        let newRun = SystemDomain.RunInstance(
            id: RunGeneratorService.deterministicRunID(templateId: template.id, day: day, calendar: calendar),
            householdId: activeHouseholdId,
            templateId: template.id,
            title: template.name,
            date: runDate,
            departureTime: departureTime,
            status: template.driverId == nil ? .scheduled : .assigned,
            stops: progressStops,
            stopSnapshots: template.stops,
            startedAt: nil,
            completedAt: nil,
            cancelledAt: nil,
            activeStopIndex: nil,
            assignedDriverId: template.driverId,
            driverId: template.driverId,
            childId: template.childId,
            createdAt: Date()
        )
        let updatedRuns = existingRuns + [newRun]
        do {
            try RunCreationValidator.validate(newRun)
            guard let backendRunsContext else {
                lastError = "Backend is not available to create runs."
                return false
            }
            _ = try await backendRunsContext.createRun(from: newRun)
            await refresh()
            lastError = backendRunsContext.lastError
        } catch {
            lastError = error.localizedDescription
            return false
        }
#if DEBUG
        let storage = JSONFileStore.debugStorageDirectory().path
        print("RunDataSource.createRun -> file: run_instances.json, dir: \(storage), saved count: \(updatedRuns.count)")
#endif
        return true
    }

    /// Creates a one-off run from the Create Run editor (not tied to calendar schedule generation).
    /// Persists to `RunRepository` and updates in-memory `runs` after success; may skip remote schedule validation
    /// when the anchor template is local-only.
    func createRunFromManualForm(
        _ uiRun: RunDetailsData.UIRun,
        children: [BackendChild]
    ) async -> Bool {
        await createRunFromManualForm(
            uiRun,
            children: children,
            selectedDriverId: nil,
            selectedDriverSource: nil
        )
    }

    func createRunFromManualForm(
        _ uiRun: RunDetailsData.UIRun,
        children: [BackendChild],
        selectedDriverId: UUID? = nil,
        selectedDriverSource: String? = nil
    ) async -> Bool {
        print("[CreateRun] validation started")
        let householdId = activeHouseholdId
        print("[CreateRun] activeHouseholdId=\(householdId.uuidString)")

        guard await ensureRunMutationPermission(action: "createRunFromManualForm") else {
            print("[CreateRun] save aborted -> \(lastError ?? "permission denied")")
            return false
        }

        guard !children.isEmpty, let childId = ManualRunCreationSupport.resolveChildId(
            passengerNames: uiRun.passengerNames,
            children: children,
            householdId: householdId
        ) else {
            lastError = "Add at least one child in this household and select a passenger."
            print("[CreateRun] save error -> no childId resolved")
            return false
        }

        let driversScoped = (try? await driverRepository.loadDrivers(for: householdId)) ?? []
        let driverNameKey = uiRun.driverName.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchedDriverById = selectedDriverId.flatMap { selectedId in
            driversScoped.first { $0.id == selectedId }
        }
        let matchedDriverByName = driversScoped.first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(driverNameKey) == .orderedSame
        })
        let matchedDriver = matchedDriverById ?? (selectedDriverId == nil ? matchedDriverByName : nil)

        let resolvedDriverId: UUID
        if let matchedDriver {
            resolvedDriverId = matchedDriver.id
        } else {
            resolvedDriverId = selectedDriverId
                ?? ManualRunCreationSupport.stableUUID(namespace: householdId, string: "driver:\(driverNameKey)")
            let synthetic = SystemDomain.Driver(
                id: resolvedDriverId,
                householdId: householdId,
                name: driverNameKey,
                phoneNumber: nil,
                isActive: true,
                createdAt: Date()
            )
            var updatedDrivers = driversScoped.filter { $0.id != resolvedDriverId }
            updatedDrivers.append(synthetic)
            do {
                try await driverRepository.saveDrivers(updatedDrivers, for: householdId)
#if DEBUG
                print("[CreateRun] persisted synthetic driver id=\(resolvedDriverId.uuidString) name=\(driverNameKey)")
#endif
            } catch {
                lastError = "Unable to save driver assignment."
                print("[CreateRun] save error -> driver persistence \(error.localizedDescription)")
                return false
            }
        }
        #if DEBUG
        NSLog(
            "[CreateRunPayload] driver fields selectedDriverId=%@ selectedDriverSource=%@ driver_id=%@ assigned_driver_id=%@ assigned_driver_name=%@",
            selectedDriverId?.uuidString ?? "nil",
            selectedDriverSource ?? "unknown",
            resolvedDriverId.uuidString,
            resolvedDriverId.uuidString,
            driverNameKey
        )
        #endif

        let orderedStops = uiRun.stops
        let stopSnapshots: [SystemDomain.Stop] = orderedStops.enumerated().map { index, ui in
            let lat = ui.latitude ?? 0
            let lng = ui.longitude ?? 0
            let placeLabel = ui.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let selectedPlaceName = ui.placeName.trimmingCharacters(in: .whitespacesAndNewlines)
            let placeName = selectedPlaceName.isEmpty ? placeLabel : selectedPlaceName
            return SystemDomain.Stop(
                id: ui.id,
                name: placeName,
                latitude: lat,
                longitude: lng,
                order: index,
                locationId: ui.locationId,
                kind: ui.type
            )
        }
        let progressStops = stopSnapshots.map {
            SystemDomain.RunStopProgress(stopId: $0.id, status: .pending, arrivedAt: nil, departedAt: nil)
        }

        let templates = (try? await scheduleRepository.loadTemplates(for: householdId)) ?? []
        let templateId: UUID
        if let anchor = templates.first(where: { $0.id == ManualRunCreationSupport.manualRunAnchorTemplateId }) {
            templateId = anchor.id
        } else if let first = templates.first {
            templateId = first.id
        } else {
            let placeholder = ManualRunCreationSupport.placeholderScheduleTemplate(
                householdId: householdId,
                childId: childId,
                anchorDate: uiRun.scheduledTime
            )
            do {
                try await scheduleRepository.saveTemplates([placeholder], for: householdId)
            } catch {
                lastError = "Unable to save a local schedule anchor for this run."
                print("[CreateRun] save error -> schedule placeholder \(error.localizedDescription)")
                return false
            }
            templateId = placeholder.id
#if DEBUG
            print("[CreateRun] created local placeholder schedule template id=\(templateId.uuidString)")
#endif
        }

        let newRunId = uiRun.id
        let runTitle = uiRun.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let createdAt = Date()
        let initialStatus: SystemDomain.RunStatus = resolvedDriverId == nil ? .scheduled : .assigned
        let newRun = SystemDomain.RunInstance(
            id: newRunId,
            householdId: householdId,
            templateId: templateId,
            title: runTitle.isEmpty ? nil : runTitle,
            date: uiRun.scheduledTime,
            departureTime: RunScheduledTime.from(date: uiRun.scheduledTime),
            status: initialStatus,
            stops: progressStops,
            stopSnapshots: stopSnapshots,
            startedAt: nil,
            completedAt: nil,
            cancelledAt: nil,
            activeStopIndex: nil,
            assignedDriverId: resolvedDriverId,
            assignedDriverName: driverNameKey,
            driverId: resolvedDriverId,
            childId: childId,
            createdAt: createdAt
        )

        print("[CreateRun] run object created id=\(newRun.id.uuidString) templateId=\(templateId.uuidString) childId=\(childId.uuidString) driverId=\(resolvedDriverId.uuidString) status=\(newRun.status.rawValue)")

        do {
            try RunCreationValidator.validate(newRun)
            guard let backendRunsContext else {
                lastError = "Backend is not available to create runs."
                print("[CreateRun] save error -> backend unavailable")
                return false
            }
            _ = try await backendRunsContext.createRun(
                from: newRun,
                requireRemoteScheduleValidation: false
            )
            await refresh()
            lastError = backendRunsContext.lastError
            print("[CreateRun] save success id=\(newRun.id.uuidString) refreshedRuns=\(runs.count)")
            return true
        } catch {
            lastError = userFacingCreateRunError(error)
            print("[CreateRun] save error category=\(createRunFailureCategory(error)) detail=\(error.localizedDescription)")
            return false
        }
    }

    func invalidateRuns(templateId: UUID) async {
        do {
            let existingRuns = try await repository.loadRuns(for: activeHouseholdId)
            let removedRuns = existingRuns.filter { $0.templateId == templateId }
            let filteredRuns = existingRuns.filter { $0.templateId != templateId }
            guard !removedRuns.isEmpty else { return }
            if let backendRunsContext {
                for removed in removedRuns {
                    try? await backendRunsContext.deleteRun(id: removed.id, householdId: activeHouseholdId)
                }
            }
            applyPersistedRuns(filteredRuns)
        } catch {
            lastError = "Unable to clean up runs for deleted schedule."
        }
    }

    func startRun(id: UUID, locationService: LocationReadinessService? = nil) async {
        guard await ensureRunMutationPermission(action: "startRun") else {
            return
        }
        if isLoading || isRefreshing {
            lastError = "Run data is still loading. Please try again."
            return
        }
        guard !inFlightRunMutationIDs.contains(id) else {
            lastError = "An update for this run is already in progress."
            return
        }
        guard let sourceRun = runs.first(where: { $0.id == id }) else {
            lastError = "Run not found."
            return
        }
        guard let backendRunsContext else {
            lastError = "Backend is not available to update runs."
            return
        }

        inFlightRunMutationIDs.insert(id)
        defer { inFlightRunMutationIDs.remove(id) }

        do {
            let persisted = try await backendRunsContext.startRun(sourceRun)
            var allRuns = runs
            if let index = allRuns.firstIndex(where: { $0.id == id }) {
                allRuns[index] = persisted
            } else {
                allRuns.append(persisted)
            }
            applyPersistedRuns(allRuns)
            lastError = backendRunsContext.lastError
            if let locationService {
                reconcileTrackingState(locationService: locationService)
            }
        } catch let error as RunTransitionError {
            lastError = readableTransitionError(error)
        } catch let error as RunPersistenceError {
            lastError = error.localizedDescription
        } catch {
            lastError = "Could not start run on server: \(error.localizedDescription)"
        }
    }

    func arriveStop(
        runId: UUID,
        stopIndex: Int,
        locationService: LocationReadinessService? = nil
    ) async {
        await mutateRun(id: runId, locationService: locationService) { run in
            try RunStateMachine().arriveAtStop(run, stopIndex: stopIndex, now: Date())
        }
    }

    func departStop(
        runId: UUID,
        stopIndex: Int,
        locationService: LocationReadinessService? = nil
    ) async {
        await mutateRun(id: runId, locationService: locationService) { run in
            try RunStateMachine().departStop(run, stopIndex: stopIndex, now: Date())
        }
    }

    func skipStop(
        runId: UUID,
        stopIndex: Int,
        locationService: LocationReadinessService? = nil
    ) async {
        await mutateRun(id: runId, locationService: locationService) { run in
            try RunStateMachine().skipStop(run, stopIndex: stopIndex, now: Date())
        }
    }

    func completeRun(id: UUID, locationService: LocationReadinessService? = nil) async {
        await mutateRun(id: id, locationService: locationService) { run in
            try RunStateMachine().complete(run, now: Date())
        }
    }

    func cancelRun(id: UUID, locationService: LocationReadinessService? = nil) async {
        await mutateRun(id: id, locationService: locationService) { run in
            try RunStateMachine().cancel(run, now: Date())
        }
    }

    /// Persists driver assignment locally without backend permission gates (organiser UI path).
    @discardableResult
    func assignDriverLocally(runId: UUID, driverId: UUID, driverName: String) async -> Bool {
        let trimmedName = driverName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            lastError = "Driver name is required."
            return false
        }
        if isLoading || isRefreshing {
            NSLog("[AssignDriver] local assign blocked: run data still loading")
            lastError = "Run data is still loading. Please try again."
            return false
        }
        guard !inFlightRunMutationIDs.contains(runId) else {
            lastError = "An update for this run is already in progress."
            return false
        }
        inFlightRunMutationIDs.insert(runId)
        defer { inFlightRunMutationIDs.remove(runId) }

        let transform: (SystemDomain.RunInstance) throws -> SystemDomain.RunInstance = { run in
            guard run.status != .completed && run.status != .cancelled else {
                throw RunTransitionError.invalidTransition
            }
            var updated = run
            updated.assignedDriverId = driverId
            updated.assignedDriverName = trimmedName
            updated.driverId = driverId
            if updated.status == .scheduled {
                updated.status = .assigned
            }
            return updated
        }

        guard let sourceRun = runs.first(where: { $0.id == runId }) else {
            lastError = "Run not found."
            return false
        }
        guard let backendRunsContext else {
            lastError = "Backend is not available to assign drivers."
            return false
        }

        do {
            let updated = try transform(sourceRun)
            let persisted = try await backendRunsContext.persistRun(updated)
            var allRuns = runs
            if let index = allRuns.firstIndex(where: { $0.id == runId }) {
                allRuns[index] = persisted
            }
            applyPersistedRuns(allRuns)
            lastError = backendRunsContext.lastError
            return true
        } catch let error as RunTransitionError {
            lastError = readableTransitionError(error)
        } catch {
            lastError = "Could not save driver assignment: \(error.localizedDescription)"
        }
        return false
    }

    func hydrateStopCoordinatesIfNeeded(
        runId: UUID,
        placeIndex: [String: StopCoordinateHydrator.PlaceCoordinate]
    ) async {
        guard !placeIndex.isEmpty else { return }
        guard let index = runs.firstIndex(where: { $0.id == runId }) else { return }

        let current = runs[index]
        let hydratedStops = StopCoordinateHydrator.hydrate(stops: current.stopSnapshots, places: placeIndex)
        await persistHydratedStopsIfNeeded(runId: runId, current: current, hydratedStops: hydratedStops)
    }

    func hydrateStopCoordinatesFromHouseholdLocations(
        runId: UUID,
        locations: [BackendHouseholdLocation]
    ) async {
        guard !locations.isEmpty else { return }
        guard let index = runs.firstIndex(where: { $0.id == runId }) else { return }

        let current = runs[index]
        let hydratedStops = StopCoordinateHydrator.hydrate(
            stops: current.stopSnapshots,
            locations: locations,
            legacyPlaces: [:]
        )
        await persistHydratedStopsIfNeeded(runId: runId, current: current, hydratedStops: hydratedStops)
    }

    private func persistHydratedStopsIfNeeded(
        runId: UUID,
        current: SystemDomain.RunInstance,
        hydratedStops: [SystemDomain.Stop]
    ) async {
        let didChange = zip(current.stopSnapshots, hydratedStops).contains { existing, updated in
            existing.latitude != updated.latitude
                || existing.longitude != updated.longitude
                || existing.locationId != updated.locationId
        } || current.stopSnapshots.count != hydratedStops.count
        guard didChange else { return }

        var updated = current
        updated.stopSnapshots = hydratedStops
        if let runIndex = runs.firstIndex(where: { $0.id == runId }) {
            runs[runIndex] = updated
        }

        do {
            var persistedRuns = try await repository.loadRuns(for: activeHouseholdId)
            guard let persistedIndex = persistedRuns.firstIndex(where: { $0.id == runId }) else { return }
            persistedRuns[persistedIndex] = updated
            try await repository.saveRuns(persistedRuns, for: activeHouseholdId)
        } catch {
            NSLog("[RunRoute] failed to persist hydrated stop coordinates error=\(error.localizedDescription)")
        }
    }

    func assignDriver(runId: UUID, driverId: UUID, driverName: String) async {
        let trimmedName = driverName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            lastError = "Driver name is required."
            return
        }
        await mutateRun(id: runId) { run in
            guard run.status != .completed && run.status != .cancelled else {
                throw RunTransitionError.invalidTransition
            }
            var updated = run
            updated.assignedDriverId = driverId
            updated.assignedDriverName = trimmedName
            updated.driverId = driverId
            if updated.status == .scheduled {
                updated.status = .assigned
            }
            return updated
        }
    }

    func assignDriver(runId: UUID, driverId: UUID) async {
        let activeDrivers: [SystemDomain.Driver]
        do {
            let loadedDrivers = try await driverRepository.loadDrivers(for: activeHouseholdId)
            activeDrivers = loadedDrivers.filter { $0.isActive }
        } catch {
            lastError = "Unable to load drivers right now."
            return
        }
        guard let driver = activeDrivers.first(where: { $0.id == driverId }) else {
            lastError = "Selected driver is no longer available."
            return
        }
        await assignDriver(runId: runId, driverId: driver.id, driverName: driver.name)
    }

    func insertStop(
        runId: UUID,
        stopName: String,
        latitude: Double,
        longitude: Double,
        at index: Int? = nil
    ) async {
        let stop = SystemDomain.Stop(
            id: UUID(),
            name: stopName,
            latitude: latitude,
            longitude: longitude,
            order: 0
        )
        await mutateRun(id: runId) { run in
            try runAdjustmentService.insertStop(into: run, stop: stop, at: index)
        }
    }

    func removeStop(runId: UUID, index: Int) async {
        await mutateRun(id: runId) { run in
            try runAdjustmentService.removeStop(from: run, at: index)
        }
    }

    func moveStop(runId: UUID, from sourceIndex: Int, to destinationIndex: Int) async {
        await mutateRun(id: runId) { run in
            try runAdjustmentService.moveStop(in: run, from: sourceIndex, to: destinationIndex)
        }
    }

    func deferStop(runId: UUID, index: Int) async {
        await mutateRun(id: runId) { run in
            try runAdjustmentService.deferStop(in: run, at: index)
        }
    }

    private func backfilledRunsIfNeeded(
        _ runs: [SystemDomain.RunInstance],
        templatesByID: [UUID: SystemDomain.ScheduleTemplate],
        driversByID: [UUID: SystemDomain.Driver]
    ) -> (runs: [SystemDomain.RunInstance], didBackfill: Bool) {
        var didBackfill = false
        let updated = runs.map { run in
            var mutable = run
            let trimmedDriverName = mutable.assignedDriverName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let effectiveDriverId = mutable.assignedDriverId ?? mutable.driverId
            if trimmedDriverName.isEmpty,
               let driverId = effectiveDriverId,
               let driver = driversByID[driverId] {
                mutable.assignedDriverName = driver.name
                mutable.assignedDriverId = driver.id
                didBackfill = true
            }
            return mutable
        }
        return (updated, didBackfill)
    }

    private func mutateRun(
        id: UUID,
        locationService: LocationReadinessService? = nil,
        _ transform: (SystemDomain.RunInstance) throws -> SystemDomain.RunInstance
    ) async {
        guard await ensureRunMutationPermission(action: "updateRun") else {
            return
        }
        if isLoading || isRefreshing {
            lastError = "Run data is still loading. Please try again."
            return
        }
        guard !inFlightRunMutationIDs.contains(id) else {
            lastError = "An update for this run is already in progress."
            return
        }
        inFlightRunMutationIDs.insert(id)
        defer { inFlightRunMutationIDs.remove(id) }

        guard let sourceRun = runs.first(where: { $0.id == id }) else {
            lastError = "Run not found."
            return
        }
        guard let backendRunsContext else {
            lastError = "Backend is not available to update runs."
            return
        }

        do {
            let updated = try transform(sourceRun)
            let persisted = try await backendRunsContext.persistRun(updated)
            var allRuns = runs
            if let index = allRuns.firstIndex(where: { $0.id == id }) {
                allRuns[index] = persisted
            } else {
                allRuns.append(persisted)
            }
            applyPersistedRuns(allRuns)
            lastError = backendRunsContext.lastError
            if let locationService {
                reconcileTrackingState(locationService: locationService)
            }
        } catch let error as RunTransitionError {
            lastError = readableTransitionError(error)
        } catch let error as RunAdjustmentError {
            lastError = readableAdjustmentError(error)
        } catch let error as RunMutationGuardError {
            lastError = error.localizedDescription
        } catch {
            NSLog("[RunMutation] save failed category=%@ detail=%@", createRunFailureCategory(error), error.localizedDescription)
            lastError = userFacingRunMutationError(error)
        }
    }

    private func readableTransitionError(_ error: RunTransitionError) -> String {
        RunUserFacingErrorMapper.readableTransitionError(error)
    }

    private func readableAdjustmentError(_ error: RunAdjustmentError) -> String {
        error.errorDescription ?? "Unable to adjust the route."
    }

    private func userFacingRunMutationError(_ error: Error) -> String {
        RunUserFacingErrorMapper.mutationMessage(for: error)
    }

    private func hasAssignedDriver(_ run: SystemDomain.RunInstance) -> Bool {
        run.assignedDriverId != nil || run.driverId != nil
    }

    private func notificationDayKey(for date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d%02d%02d", y, m, d)
    }

    private func etaConfig(using speedMetersPerSecond: Double?) -> ETAConfig {
        let defaultSpeed = speedMetersPerSecond ?? AppSettings.etaDefaultSpeedMetersPerSecond
        return ETAConfig(
            minimumSpeedMetersPerSecond: ETAConfig.default.minimumSpeedMetersPerSecond,
            defaultSpeedMetersPerSecond: max(ETAConfig.default.minimumSpeedMetersPerSecond, defaultSpeed),
            dwellTimePerStopSeconds: AppSettings.etaDwellTimePerStopSeconds
        )
    }

    private func applyPersistedRuns(_ persistedRuns: [SystemDomain.RunInstance]) {
        // Keep UI state in sync immediately after successful persistence writes.
        runs = persistedRuns.sorted { $0.date < $1.date }
    }

    private func ensureRunMutationPermission(action: String) async -> Bool {
#if DEBUG
        if testBypassRunMutationPermission {
            return true
        }
#endif
        guard BackendConfig.isBackendConfigured else {
            return true
        }
        do {
            guard let session = try await authService.restoreSession() else {
                lastError = Self.expiredSessionMessage
                NSLog("[CreateRun] permission_check auth=session_missing action=%@", action)
                return false
            }
            NSLog(
                "[CreateRun] permission_check auth=session_present tokenPresent=%@ userId=%@ householdId=%@ action=%@",
                session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "no" : "yes",
                session.userId,
                activeHouseholdId.uuidString,
                action
            )
            let memberships = try await householdBackendService.fetchMyMemberships(session: session)
            let membership = BackendPermissionGuard.activeMembership(
                for: activeHouseholdId,
                memberships: memberships
            )
            try BackendPermissionGuard.requireRunOperator(membership, action: action)
            return true
        } catch let error as BackendPermissionError {
            lastError = Self.runPermissionDeniedMessage
            NSLog("[CreateRun] permission_check category=permission error=%@", error.localizedDescription)
            return false
        } catch {
            lastError = userFacingCreateRunError(error)
            NSLog("[CreateRun] permission_check category=%@ error=%@", createRunFailureCategory(error), error.localizedDescription)
            return false
        }
    }

    private static let expiredSessionMessage = RunUserFacingErrorMapper.expiredSessionMessage
    private static let runPermissionDeniedMessage = RunUserFacingErrorMapper.runPermissionDeniedMessage

    private func userFacingCreateRunError(_ error: Error) -> String {
        RunUserFacingErrorMapper.createRunMessage(for: error)
    }

    private func createRunFailureCategory(_ error: Error) -> String {
        if error is RunCreationValidator.ValidationError { return "validation" }
        if error is BackendPermissionError { return "permission" }
        let normalized = error.localizedDescription.lowercased()
        if normalized.contains("session")
            || normalized.contains("jwt")
            || normalized.contains("auth")
            || normalized.contains("unauthorized") {
            return "auth"
        }
        if normalized.contains("permission")
            || normalized.contains("row-level security")
            || normalized.contains("rls")
            || normalized.contains("403") {
            return "permission"
        }
        if normalized.contains("network") || normalized.contains("could not reach") {
            return "network"
        }
        return "backend"
    }

    private func invalidateDerivedCaches() {
        cachedNextRun = nil
        cachedActiveRuns = nil
        cachedBucketsByDay.removeAll()
        cachedRunsByDay.removeAll()
        cachedDriverRuns.removeAll()
        let validRunIDs = Set(runs.map(\.id))
        etaGateByRunID = etaGateByRunID.filter { validRunIDs.contains($0.key) }
    }

#if DEBUG
    @discardableResult
    func simulateMissingDriverAlerts(now: Date = Date()) async -> String {
        let loaded: [SystemDomain.RunInstance]
        do {
            loaded = try await repository.loadRuns(for: activeHouseholdId)
        } catch {
            return "Unable to load runs for simulation."
        }
        var allRuns = loaded.sorted { $0.date < $1.date }
        let upcomingScheduled = allRuns.indices.filter { index in
            allRuns[index].status == .scheduled && allRuns[index].date > now
        }
        guard !upcomingScheduled.isEmpty else {
            return "No upcoming scheduled runs available."
        }

        var updated = 0
        for (offset, index) in upcomingScheduled.prefix(2).enumerated() {
            allRuns[index].assignedDriverId = nil
            allRuns[index].assignedDriverName = nil
            allRuns[index].driverId = nil
            allRuns[index].date = now.addingTimeInterval(TimeInterval((offset + 1) * 20 * 60))
            updated += 1
        }
        do {
            try await repository.saveRuns(allRuns, for: activeHouseholdId)
        } catch {
            return "Unable to save simulated runs."
        }
        await refresh()
        return "Simulated missing-driver alerts on \(updated) runs."
    }

    @discardableResult
    func simulateOverdueAlerts(now: Date = Date()) async -> String {
        let loaded: [SystemDomain.RunInstance]
        do {
            loaded = try await repository.loadRuns(for: activeHouseholdId)
        } catch {
            return "Unable to load runs for simulation."
        }
        var allRuns = loaded.sorted { $0.date < $1.date }
        guard let index = allRuns.firstIndex(where: { $0.status == .scheduled }) else {
            return "No scheduled run available for overdue simulation."
        }
        allRuns[index].date = now.addingTimeInterval(-20 * 60)
        do {
            try await repository.saveRuns(allRuns, for: activeHouseholdId)
        } catch {
            return "Unable to save simulated runs."
        }
        await refresh()
        return "Simulated overdue alert on run \(allRuns[index].id.uuidString.prefix(8))."
    }

    @discardableResult
    func simulateConflictAlerts(now: Date = Date()) async -> String {
        let loaded: [SystemDomain.RunInstance]
        do {
            loaded = try await repository.loadRuns(for: activeHouseholdId)
        } catch {
            return "Unable to load runs for simulation."
        }
        var allRuns = loaded.sorted { $0.date < $1.date }
        let candidateIndexes = allRuns.indices.filter { allRuns[$0].status == .scheduled }
        guard candidateIndexes.count >= 2 else {
            return "Need at least 2 scheduled runs to simulate conflict."
        }

        let driverId = allRuns[candidateIndexes[0]].assignedDriverId
            ?? UUID(uuidString: "A1000000-0000-0000-0000-000000000001")
            ?? UUID()
        let driverName = "Tafadzwa"
        let baseDate = now.addingTimeInterval(30 * 60)

        allRuns[candidateIndexes[0]].assignedDriverId = driverId
        allRuns[candidateIndexes[0]].assignedDriverName = driverName
        allRuns[candidateIndexes[0]].driverId = driverId
        allRuns[candidateIndexes[0]].date = baseDate

        allRuns[candidateIndexes[1]].assignedDriverId = driverId
        allRuns[candidateIndexes[1]].assignedDriverName = driverName
        allRuns[candidateIndexes[1]].driverId = driverId
        allRuns[candidateIndexes[1]].date = baseDate.addingTimeInterval(30 * 60)

        do {
            try await repository.saveRuns(allRuns, for: activeHouseholdId)
        } catch {
            return "Unable to save simulated runs."
        }
        await refresh()
        return "Simulated same-driver timing conflict on 2 runs."
    }
#endif

    var diagnosticsRepositoryType: String {
        repositoryTypeName
    }

    var diagnosticsScheduleRepositoryType: String {
        scheduleRepositoryTypeName
    }

    var diagnosticsDriverRepositoryType: String {
        driverRepositoryTypeName
    }

    var diagnosticsActiveETAComputations: Int {
        etaGateByRunID.count
    }

    private var activeHouseholdId: UUID {
        householdContext.householdId
    }
}
