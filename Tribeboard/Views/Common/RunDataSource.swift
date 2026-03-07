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
        repository: any RunRepository = LocalRunRepository(),
        scheduleRepository: any ScheduleRepository = LocalScheduleRepository(),
        driverRepository: any DriverRepository = LocalDriverRepository(),
        householdContext: ActiveHouseholdContext? = nil,
        syncCoordinator: SyncCoordinator? = nil
    ) {
        self.repository = repository
        self.scheduleRepository = scheduleRepository
        self.driverRepository = driverRepository
        self.householdContext = householdContext ?? ActiveHouseholdContext()
        self.syncCoordinator = syncCoordinator
        self.repositoryTypeName = String(describing: type(of: repository))
        self.scheduleRepositoryTypeName = String(describing: type(of: scheduleRepository))
        self.driverRepositoryTypeName = String(describing: type(of: driverRepository))
    }

    func bootstrapIfNeeded() async {
        guard !didBootstrap else { return }
        didBootstrap = true
#if DEBUG
        if AppConfig.isDemoFlowEnabled {
            let result = SystemBootstrap.debugSeedAndGenerate(daysAhead: 14)
            print("RunDataSource.bootstrapIfNeeded -> seeded: \(result.seeded), generated: \(result.newRuns)")
        }
#endif
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
            let loadedRuns = try await repository.loadRuns(for: activeHouseholdId)
            let templates = try await scheduleRepository.loadTemplates(for: activeHouseholdId)
            let drivers = try await driverRepository.loadDrivers(for: activeHouseholdId)
            let templatesByID = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
            let driversByID = Dictionary(uniqueKeysWithValues: drivers.map { ($0.id, $0) })
            let backfillResult = backfilledRunsIfNeeded(
                loadedRuns,
                templatesByID: templatesByID,
                driversByID: driversByID
            )
            if backfillResult.didBackfill {
                try await repository.saveRuns(backfillResult.runs, for: activeHouseholdId)
            }
            runs = backfillResult.runs.sorted { $0.date < $1.date }
#if DEBUG
            print("RunDataSource.refresh -> loaded runs count: \(runs.count)")
#endif
            lastError = nil
        } catch {
            lastError = "Failed to load runs."
        }
    }

    func reloadForHouseholdChange() async {
        invalidateDerivedCaches()
        await refresh()
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
        var active: [SystemDomain.RunInstance] = activeRuns()

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
                // Treat newly created/scheduled future runs as upcoming.
                upcoming.append(run)
            } else {
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

    func nextRun(referenceDate: Date = Date()) -> SystemDomain.RunInstance? {
        if let cachedNextRun, cachedNextRun.date >= referenceDate {
            return cachedNextRun
        }
        if let cachedNextRun, cachedNextRun.status == .inProgress {
            return cachedNextRun
        }
        let computed = runs
            .filter { $0.status == .inProgress || ($0.status == .scheduled && $0.date >= referenceDate) }
            .sorted { lhs, rhs in
                if lhs.status == .inProgress && rhs.status != .inProgress { return true }
                if rhs.status == .inProgress && lhs.status != .inProgress { return false }
                return lhs.date < rhs.date
            }
            .first
        cachedNextRun = computed
        return computed
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
        now: Date = Date()
    ) {
        let hasInProgressToday = runsForDay(now).contains { $0.status == .inProgress }
        if hasInProgressToday {
            locationService.startRunTracking()
        } else {
            locationService.stopRunTracking()
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
        guard let runDate = calendar.date(
            bySettingHour: template.hour,
            minute: template.minute,
            second: 0,
            of: day
        ) else {
            return false
        }

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
            status: .scheduled,
            stops: progressStops,
            stopSnapshots: template.stops,
            startedAt: nil,
            completedAt: nil,
            cancelledAt: nil,
            activeStopIndex: nil,
            assignedDriverId: nil,
            driverId: template.driverId,
            childId: template.childId,
            createdAt: Date()
        )
        let updatedRuns = existingRuns + [newRun]
        do {
            try await repository.saveRuns(updatedRuns, for: activeHouseholdId)
            if let syncCoordinator {
                let change = SyncChangeFactory.makeRunChange(
                    householdId: activeHouseholdId,
                    entityId: newRun.id,
                    operation: .create
                )
                await syncCoordinator.enqueue(change)
            }
            applyPersistedRuns(updatedRuns)
            lastError = nil
        } catch {
            lastError = "Unable to save run right now."
            return false
        }
#if DEBUG
        let storage = JSONFileStore.debugStorageDirectory().path
        print("RunDataSource.createRun -> file: run_instances.json, dir: \(storage), saved count: \(updatedRuns.count)")
#endif
        return true
    }

    func startRun(id: UUID, locationService: LocationReadinessService? = nil) async {
        await mutateRun(id: id, locationService: locationService) { run in
            try RunStateMachine().start(run, now: Date())
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

    func assignDriver(runId: UUID, driverId: UUID) async {
        let activeDrivers: [SystemDomain.Driver]
        do {
            let loadedDrivers = try await driverRepository.loadDrivers(for: activeHouseholdId)
            activeDrivers = loadedDrivers.filter { $0.isActive }
        } catch {
            lastError = "Unable to load drivers right now."
            return
        }
        await mutateRun(id: runId) { run in
            guard run.status != .completed && run.status != .cancelled else {
                throw RunTransitionError.invalidTransition
            }
            guard let driver = activeDrivers.first(where: { $0.id == driverId }) else {
                throw RunTransitionError.invalidTransition
            }
            var updated = run
            updated.assignedDriverId = driver.id
            updated.assignedDriverName = driver.name
            updated.driverId = driver.id
            return updated
        }
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
            let trimmedTitle = mutable.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmedTitle.isEmpty, let template = templatesByID[mutable.templateId] {
                mutable.title = template.name
                didBackfill = true
            }

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

        if let inMemoryRun = runs.first(where: { $0.id == id }) {
            do {
                let updatedInMemory = try transform(inMemoryRun)
                var persistedRuns = try await repository.loadRuns(for: activeHouseholdId)
                guard let persistedIndex = persistedRuns.firstIndex(where: { $0.id == id }) else {
                    lastError = "Run not found."
                    return
                }
                persistedRuns[persistedIndex] = updatedInMemory
                try await repository.saveRuns(persistedRuns, for: activeHouseholdId)
                if let syncCoordinator {
                    let change = SyncChangeFactory.makeRunChange(
                        householdId: activeHouseholdId,
                        entityId: updatedInMemory.id,
                        operation: .update
                    )
                    await syncCoordinator.enqueue(change)
                }
                applyPersistedRuns(persistedRuns)
                lastError = nil
                if let locationService {
                    reconcileTrackingState(locationService: locationService)
                }
            } catch let error as RunTransitionError {
                lastError = readableTransitionError(error)
            } catch let error as RunAdjustmentError {
                lastError = readableAdjustmentError(error)
            } catch {
                lastError = "Unable to update run right now."
            }
            return
        }

        var allRuns: [SystemDomain.RunInstance]
        do {
            allRuns = try await repository.loadRuns(for: activeHouseholdId)
        } catch {
            lastError = "Unable to update run right now."
            return
        }
        guard let index = allRuns.firstIndex(where: { $0.id == id }) else {
            lastError = "Run not found."
            return
        }

        do {
            let updated = try transform(allRuns[index])
            allRuns[index] = updated
            try await repository.saveRuns(allRuns, for: activeHouseholdId)
            if let syncCoordinator {
                let change = SyncChangeFactory.makeRunChange(
                    householdId: activeHouseholdId,
                    entityId: updated.id,
                    operation: .update
                )
                await syncCoordinator.enqueue(change)
            }
            applyPersistedRuns(allRuns)
            lastError = nil
            if let locationService {
                reconcileTrackingState(locationService: locationService)
            }
        } catch let error as RunTransitionError {
            lastError = readableTransitionError(error)
        } catch let error as RunAdjustmentError {
            lastError = readableAdjustmentError(error)
        } catch {
            lastError = "Unable to update run right now."
        }
    }

    private func readableTransitionError(_ error: RunTransitionError) -> String {
        switch error {
        case .invalidTransition:
            return "That action is not allowed for the run's current state."
        case .invalidStopIndex:
            return "That stop is not currently actionable."
        case .alreadyCompleted:
            return "This run is already completed."
        case .alreadyCancelled:
            return "This run is already cancelled."
        case .notStarted:
            return "Start the run before updating stops."
        }
    }

    private func readableAdjustmentError(_ error: RunAdjustmentError) -> String {
        error.errorDescription ?? "Unable to adjust the route."
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
