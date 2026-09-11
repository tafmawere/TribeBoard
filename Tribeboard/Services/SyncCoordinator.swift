import Foundation
import Combine

struct SyncDiagnosticsSnapshot {
    let auditRecordCount: Int
    let processedChangeCount: Int
    let conflictCount: Int
    let latestAuditRecords: [SyncAuditRecord]
}

@MainActor
final class SyncCoordinator: ObservableObject {
    private enum CoordinatorError: LocalizedError {
        case dependencyNotReady(String)
    }
    @Published private(set) var status: SyncStatusSnapshot
    @Published private(set) var recentSyncWarning: String?
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastError: String?
    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var lastProcessedOperationType: String?
    @Published private(set) var lastSkippedDuplicateOperation: String?

    private let queueRepository: SyncQueueRepository
    private let queueStore: SyncQueueStore
    private let auditRepository: SyncAuditRepository
    private let processedChangeRepository: ProcessedChangeRepository
    private let remoteDriver: RemoteSyncDriver?
    private let scheduleBackendService: ScheduleBackendService
    private let runBackendService: RunBackendService
    private let runRepository: (any RunRepository)?
    private let scheduleRepository: (any ScheduleRepository)?
    private let driverRepository: (any DriverRepository)?
    private let householdRepository: (any HouseholdRepository)?
    private let mergeService = SyncMergeService()
    private var isProcessing = false
    private var hasQueuedSyncRequest = false

    init(
        queueRepository: SyncQueueRepository,
        queueStore: SyncQueueStore? = nil,
        auditRepository: SyncAuditRepository? = nil,
        processedChangeRepository: ProcessedChangeRepository? = nil,
        remoteDriver: RemoteSyncDriver? = nil,
        scheduleBackendService: ScheduleBackendService? = nil,
        runBackendService: RunBackendService? = nil,
        runRepository: (any RunRepository)? = nil,
        scheduleRepository: (any ScheduleRepository)? = nil,
        driverRepository: (any DriverRepository)? = nil,
        householdRepository: (any HouseholdRepository)? = nil
    ) {
        self.queueRepository = queueRepository
        self.queueStore = queueStore ?? SyncQueueStore()
        self.auditRepository = auditRepository ?? LocalSyncAuditRepository()
        self.processedChangeRepository = processedChangeRepository ?? LocalProcessedChangeRepository()
        self.remoteDriver = remoteDriver
        self.scheduleBackendService = scheduleBackendService ?? SupabaseScheduleBackendService()
        self.runBackendService = runBackendService ?? SupabaseRunBackendService()
        self.runRepository = runRepository
        self.scheduleRepository = scheduleRepository
        self.driverRepository = driverRepository
        self.householdRepository = householdRepository
        self.status = SyncStatusSnapshot(state: .idle, pendingCount: 0, lastSyncAt: nil, lastError: nil)
        self.lastError = nil
        self.pendingCount = self.queueStore.pendingOperations().count
    }

    func refreshStatus() async {
        do {
            let changes = try await queueRepository.loadChanges()
            let operationCount = queueStore.pendingOperations().count
            status.pendingCount = changes.count + operationCount
            if isProcessing {
                status.state = .syncing
            } else if changes.isEmpty && operationCount == 0 {
                if status.state != .failed {
                    status.state = status.lastSyncAt == nil ? .idle : .succeeded
                }
            } else {
                status.state = .pending
            }
            if status.state != .failed {
                status.lastError = nil
            }
        } catch {
            status.state = .failed
            status.lastError = "Unable to read sync queue."
        }
        syncPublishedStatus()
    }

    func enqueue(_ change: SyncChange) async {
        await enqueue(changes: [change])
    }

    func enqueue(changes: [SyncChange]) async {
        guard !changes.isEmpty else { return }
        do {
            var queue = try await queueRepository.loadChanges()
            queue.append(contentsOf: changes)
            try await queueRepository.saveChanges(queue)
            status.pendingCount = queue.count
            status.state = queue.isEmpty ? .idle : .pending
            status.lastError = nil
            syncPublishedStatus()
        } catch {
            status.state = .failed
            status.lastError = "Unable to enqueue sync change."
            syncPublishedStatus()
        }
    }
    
    func enqueue(operation: SyncOperation) async {
        queueStore.enqueue(operation: operation)
        pendingCount = queueStore.pendingOperations().count
        status.pendingCount = pendingCount
        if pendingCount > 0, status.state == .idle || status.state == .succeeded {
            status.state = .pending
        }
    }
    
    func startSync() async {
        if isProcessing {
            hasQueuedSyncRequest = true
            return
        }
        await processQueue()
    }
    
    func retryFailedOperations() async {
        await processQueue()
    }

    func processQueue() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer {
            isProcessing = false
            if hasQueuedSyncRequest {
                hasQueuedSyncRequest = false
                Task { await self.processQueue() }
            }
        }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await processOperationQueue()
            let queue = try await queueRepository.loadChanges()
            guard !queue.isEmpty else {
                status.state = .idle
                status.pendingCount = 0
                status.lastError = nil
                recentSyncWarning = nil
                syncPublishedStatus()
                return
            }

            status.state = .syncing
            status.pendingCount = queue.count

            if let remoteDriver {
                let resolved = try await resolveQueuedChanges(queue)
                try await remoteDriver.push(changes: resolved)
                try await appendAuditRecords(
                    queue.map { change in
                        SyncAuditRecord(
                            id: UUID(),
                            householdId: change.householdId,
                            entityType: change.entityType,
                            entityId: change.entityId,
                            direction: .push,
                            result: .success,
                            changeId: change.id,
                            message: "Pushed queued sync change.",
                            createdAt: Date()
                        )
                    }
                )
            } else {
                try await appendAuditRecord(
                    SyncAuditRecord(
                        id: UUID(),
                        householdId: nil,
                        entityType: nil,
                        entityId: nil,
                        direction: .push,
                        result: .skipped,
                        changeId: nil,
                        message: "Remote driver unavailable; queue processed in local simulation mode.",
                        createdAt: Date()
                    )
                )
            }

            try await queueRepository.saveChanges([])
            status.state = .succeeded
            status.pendingCount = 0
            status.lastSyncAt = Date()
            status.lastError = nil
            recentSyncWarning = nil
            syncPublishedStatus()
        } catch {
            status.state = .failed
            status.lastError = "Unable to process sync queue."
            recentSyncWarning = nil
            try? await appendAuditRecord(
                SyncAuditRecord(
                    id: UUID(),
                    householdId: nil,
                    entityType: nil,
                    entityId: nil,
                    direction: .push,
                    result: .failed,
                    changeId: nil,
                    message: "Push failed: \(error.localizedDescription)",
                    createdAt: Date()
                )
            )
            await refreshStatus()
            syncPublishedStatus()
        }
    }

    func pull(householdId: UUID?) async {
        guard !isProcessing else { return }
        guard let remoteDriver else { return }
        guard
            let runRepository,
            let scheduleRepository,
            let driverRepository,
            let householdRepository
        else {
            status.state = .failed
            status.lastError = "Sync merge repositories are not configured."
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            status.state = .syncing
            let remoteChanges = try await remoteDriver.pull(
                since: status.lastSyncAt,
                householdId: householdId
            )
            try await appendAuditRecord(
                SyncAuditRecord(
                    id: UUID(),
                    householdId: householdId,
                    entityType: nil,
                    entityId: nil,
                    direction: .pull,
                    result: .success,
                    changeId: nil,
                    message: "Pulled \(remoteChanges.count) remote changes.",
                    createdAt: Date()
                )
            )
            let processed = try await processedChangeRepository.loadProcessed()
            let mergeResult = try await mergeService.merge(
                resolvedChanges: remoteChanges,
                runRepository: runRepository,
                scheduleRepository: scheduleRepository,
                driverRepository: driverRepository,
                householdRepository: householdRepository,
                processedChangeIDs: Set(processed.map(\.changeId))
            )
            try await appendAuditRecords(mergeResult.auditRecords)
            try await processedChangeRepository.append(mergeResult.processedChanges)
            status.lastSyncAt = Date()
            status.state = .succeeded
            status.lastError = nil
            if mergeResult.conflictCount > 0 {
                recentSyncWarning = "Sync completed with \(mergeResult.conflictCount) conflict(s)."
            } else {
                recentSyncWarning = nil
            }
            await refreshStatus()
            syncPublishedStatus()
        } catch {
            status.state = .failed
            status.lastError = "Unable to pull remote changes."
            recentSyncWarning = nil
            try? await appendAuditRecord(
                SyncAuditRecord(
                    id: UUID(),
                    householdId: householdId,
                    entityType: nil,
                    entityId: nil,
                    direction: .pull,
                    result: .failed,
                    changeId: nil,
                    message: "Pull failed: \(error.localizedDescription)",
                    createdAt: Date()
                )
            )
            syncPublishedStatus()
        }
    }

    func clearQueue() async {
        do {
            try await queueRepository.saveChanges([])
            queueStore.clearCompleted()
            status.pendingCount = 0
            status.state = .idle
            status.lastError = nil
            syncPublishedStatus()
        } catch {
            status.state = .failed
            status.lastError = "Unable to clear sync queue."
            syncPublishedStatus()
        }
    }

    func syncDiagnostics(limit: Int = 5) async -> SyncDiagnosticsSnapshot? {
        do {
            let allAudits = try await auditRepository.loadRecords()
            let allProcessed = try await processedChangeRepository.loadProcessed()
            let latestAuditRecords = Array(allAudits.sorted(by: { $0.createdAt > $1.createdAt }).prefix(limit))
            let conflictCount = allAudits.filter { $0.result == .conflict }.count
            return SyncDiagnosticsSnapshot(
                auditRecordCount: allAudits.count,
                processedChangeCount: allProcessed.count,
                conflictCount: conflictCount,
                latestAuditRecords: latestAuditRecords
            )
        } catch {
            status.state = .failed
            status.lastError = "Unable to read sync diagnostics."
            return nil
        }
    }

    func clearSyncAudit() async {
        do {
            try await auditRepository.clear()
            status.lastError = nil
        } catch {
            status.state = .failed
            status.lastError = "Unable to clear sync audit."
        }
    }

    func clearProcessedChangeLog() async {
        do {
            try await processedChangeRepository.clear()
            status.lastError = nil
        } catch {
            status.state = .failed
            status.lastError = "Unable to clear processed change log."
        }
    }
    
    func clearSyncErrorState() {
        status.lastError = nil
        lastError = nil
    }
    
    func pendingOperationGroups() -> [SyncEntityType: Int] {
        queueStore.groupedPendingCounts()
    }
    
    func oldestPendingOperation() -> SyncOperation? {
        queueStore.oldestPendingOperation()
    }
    
    func pendingOperations(for householdId: UUID, entityType: SyncEntityType? = nil) -> [SyncOperation] {
        queueStore.pendingOperations(for: householdId, entityType: entityType)
    }
    
    func resetUserScopedState(clearPendingOperations: Bool = true) async {
        status = SyncStatusSnapshot(state: .idle, pendingCount: 0, lastSyncAt: nil, lastError: nil)
        recentSyncWarning = nil
        isSyncing = false
        lastError = nil
        lastProcessedOperationType = nil
        lastSkippedDuplicateOperation = nil
        hasQueuedSyncRequest = false
        if clearPendingOperations {
            queueStore.clearCompleted()
            try? await queueRepository.saveChanges([])
        }
        syncPublishedStatus()
    }

    func remoteMirrorCounts() async -> RemoteMirrorCounts? {
        guard let debugDriver = remoteDriver as? RemoteSyncDebuggable else { return nil }
        do {
            return try await debugDriver.remoteMirrorCounts()
        } catch {
            status.state = .failed
            status.lastError = "Unable to load remote mirror counts."
            return nil
        }
    }

    func seedRemoteMirrorDemoData(for householdId: UUID) async {
        guard let debugDriver = remoteDriver as? RemoteSyncDebuggable else { return }
        do {
            try await debugDriver.seedRemoteMirrorDemoData(for: householdId)
            status.lastError = nil
        } catch {
            status.state = .failed
            status.lastError = "Unable to seed remote mirror."
        }
    }

    func clearRemoteMirror() async {
        guard let debugDriver = remoteDriver as? RemoteSyncDebuggable else { return }
        do {
            try await debugDriver.clearRemoteMirror()
            status.lastError = nil
        } catch {
            status.state = .failed
            status.lastError = "Unable to clear remote mirror."
        }
    }

    func seedDuplicateRemoteChange(for householdId: UUID) async {
        guard let debugDriver = remoteDriver as? RemoteSyncDebuggable else { return }
        do {
            try await debugDriver.seedDuplicateRemoteChange(for: householdId)
            status.lastError = nil
        } catch {
            status.state = .failed
            status.lastError = "Unable to seed duplicate remote change."
        }
    }

    func seedStaleRemoteChange(for householdId: UUID) async {
        guard let debugDriver = remoteDriver as? RemoteSyncDebuggable else { return }
        do {
            try await debugDriver.seedStaleRemoteChange(for: householdId)
            status.lastError = nil
        } catch {
            status.state = .failed
            status.lastError = "Unable to seed stale remote change."
        }
    }

    func seedNewerRemoteChange(for householdId: UUID) async {
        guard let debugDriver = remoteDriver as? RemoteSyncDebuggable else { return }
        do {
            try await debugDriver.seedNewerRemoteChange(for: householdId)
            status.lastError = nil
        } catch {
            status.state = .failed
            status.lastError = "Unable to seed newer remote change."
        }
    }

    func corruptSyncAuditFile() async {
        do {
            try corruptFile(named: "sync_audit.json")
            status.lastError = nil
        } catch {
            status.state = .failed
            status.lastError = "Unable to corrupt sync audit file."
        }
    }

    func corruptProcessedChangeFile() async {
        do {
            try corruptFile(named: "processed_sync_changes.json")
            status.lastError = nil
        } catch {
            status.state = .failed
            status.lastError = "Unable to corrupt processed change file."
        }
    }

    private func processOperationQueue() async throws {
        var operations = queueStore.pendingOperations()
        guard !operations.isEmpty else {
            pendingCount = 0
            return
        }
        pendingCount = operations.count
        status.pendingCount = operations.count
        status.state = .syncing
        
        var processedIds: Set<UUID> = []
        for operation in operations {
            do {
                guard shouldProcess(operation: operation, queue: operations, alreadyProcessed: processedIds) else {
                    continue
                }
                try await dispatch(operation: operation)
                processedIds.insert(operation.id)
                lastProcessedOperationType = "\(operation.entityType.rawValue).\(operation.operationType.rawValue)"
            } catch let error as CoordinatorError {
                // Dependency order safety: keep queued until prerequisite is available.
                if case .dependencyNotReady(let message) = error {
                    status.lastError = message
                }
            } catch {
                // Keep failed operations queued; sync should never block the UI.
                lastError = error.localizedDescription
                status.lastError = error.localizedDescription
            }
        }
        
        if !processedIds.isEmpty {
            operations.removeAll { processedIds.contains($0.id) }
            queueStore.clearCompleted()
            for remaining in operations {
                queueStore.enqueue(operation: remaining)
            }
        }
        
        pendingCount = operations.count
        status.pendingCount = operations.count
        if operations.isEmpty {
            if status.state != .failed {
                status.state = .succeeded
            }
        } else {
            status.state = .pending
        }
        syncPublishedStatus()
    }
    
    private func shouldProcess(
        operation: SyncOperation,
        queue: [SyncOperation],
        alreadyProcessed: Set<UUID>
    ) -> Bool {
        switch operation.entityType {
        case .schedule:
            return true
        case .run:
            let earlierScheduleCreates = queue.contains { queued in
                queued.id != operation.id
                    && !alreadyProcessed.contains(queued.id)
                    && queued.householdId == operation.householdId
                    && queued.entityType == .schedule
                    && queued.operationType == .create
                    && queued.createdAt <= operation.createdAt
            }
            if earlierScheduleCreates {
                return false
            }
            return true
        case .runAssignment:
            let earlierRunCreates = queue.contains { queued in
                queued.id != operation.id
                    && !alreadyProcessed.contains(queued.id)
                    && queued.householdId == operation.householdId
                    && queued.entityType == .run
                    && queued.operationType == .create
                    && queued.createdAt <= operation.createdAt
            }
            if earlierRunCreates {
                return false
            }
            return true
        case .driver, .household:
            return true
        }
    }
    
    private func dispatch(operation: SyncOperation) async throws {
        switch operation.entityType {
        case .schedule:
            try await dispatchScheduleOperation(operation)
        case .run:
            try await dispatchRunOperation(operation)
        case .runAssignment:
            // Legacy queue entries: driver assignment is persisted on runs.driver_id.
            try await dispatchRunOperation(
                SyncOperation(
                    id: operation.id,
                    entityType: .run,
                    operationType: .update,
                    entityId: operation.entityId,
                    householdId: operation.householdId,
                    createdAt: operation.createdAt
                )
            )
        case .driver, .household:
            // Not part of Sprint 44 offline scope.
            return
        }
    }
    
    private func dispatchScheduleOperation(_ operation: SyncOperation) async throws {
        guard let scheduleRepository else { return }
        let localTemplates = try await scheduleRepository.loadTemplates(for: operation.householdId)
        let localTemplate = localTemplates.first(where: { $0.id == operation.entityId })
        
        switch operation.operationType {
        case .create:
            let remote = try await scheduleBackendService.fetchSchedules(householdId: operation.householdId)
            if remote.contains(where: { $0.id == operation.entityId }) {
                lastSkippedDuplicateOperation = "schedule.create \(operation.entityId.uuidString)"
                return
            }
            guard let localTemplate else {
                throw CoordinatorError.dependencyNotReady("Schedule create dependency not ready.")
            }
            _ = try await scheduleBackendService.createSchedule(mapScheduleToBackend(localTemplate))
        case .update:
            guard let localTemplate else {
                throw CoordinatorError.dependencyNotReady("Schedule update dependency not ready.")
            }
            _ = try await scheduleBackendService.updateSchedule(mapScheduleToBackend(localTemplate))
        case .delete:
            try await scheduleBackendService.deleteSchedule(id: operation.entityId)
        }
    }
    
    private func dispatchRunOperation(_ operation: SyncOperation) async throws {
        guard let runRepository else { return }
        let localRuns = try await runRepository.loadRuns(for: operation.householdId)
        let localRun = localRuns.first(where: { $0.id == operation.entityId })
        
        switch operation.operationType {
        case .create:
            let remote = try await runBackendService.fetchRuns(householdId: operation.householdId)
            if remote.contains(where: { $0.id == operation.entityId }) {
                lastSkippedDuplicateOperation = "run.create \(operation.entityId.uuidString)"
                return
            }
            guard let localRun else {
                throw CoordinatorError.dependencyNotReady("Run create dependency not ready.")
            }
            let remoteTemplates = try await scheduleBackendService.fetchSchedules(householdId: operation.householdId)
            let templateExists = remoteTemplates.contains(where: { $0.id == localRun.templateId })
#if DEBUG
            print(
                "[SyncCoordinator] run.create: schedule_id=\(localRun.templateId.uuidString), " +
                "household_id=\(operation.householdId.uuidString), template_exists_in_loaded_templates=\(templateExists)"
            )
#endif
            guard templateExists else {
                throw CoordinatorError.dependencyNotReady("Run create blocked: schedule template missing in backend.")
            }
            _ = try await runBackendService.createRun(mapRunToBackend(localRun))
        case .update:
            guard let localRun else {
                throw CoordinatorError.dependencyNotReady("Run update dependency not ready.")
            }
            _ = try await runBackendService.updateRun(mapRunToBackend(localRun))
        case .delete:
            try await runBackendService.deleteRun(id: operation.entityId)
        }
    }
    
    private func mapRunToBackend(_ run: SystemDomain.RunInstance) -> BackendRun {
        RunPersistenceMapper.package(from: run).run
    }
    
    private func mapScheduleToBackend(_ template: SystemDomain.ScheduleTemplate) -> BackendScheduleTemplate {
        let departureTime = String(format: "%02d:%02d:00", template.hour, template.minute)
        let weekday = weekdayName(for: template.weekdays.sorted().first ?? 2)
        return BackendScheduleTemplate(
            id: template.id,
            householdId: template.householdId,
            childId: template.childId,
            title: template.name,
            weekday: weekday,
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
    
    private func resolveQueuedChanges(_ changes: [SyncChange]) async throws -> [ResolvedSyncChange] {
        guard
            let runRepository,
            let scheduleRepository,
            let driverRepository,
            let householdRepository
        else {
            return changes.map { ResolvedSyncChange(change: $0, run: nil, schedule: nil, driver: nil, household: nil) }
        }

        var runsByHousehold: [UUID: [SystemDomain.RunInstance]] = [:]
        var schedulesByHousehold: [UUID: [SystemDomain.ScheduleTemplate]] = [:]
        var driversByHousehold: [UUID: [SystemDomain.Driver]] = [:]
        var households: [Household]?

        var resolved: [ResolvedSyncChange] = []
        resolved.reserveCapacity(changes.count)

        for change in changes {
            switch change.entityType {
            case .run:
                if runsByHousehold[change.householdId] == nil {
                    runsByHousehold[change.householdId] = try await runRepository.loadRuns(for: change.householdId)
                }
                let run = runsByHousehold[change.householdId]?.first(where: { $0.id == change.entityId })
                resolved.append(
                    ResolvedSyncChange(change: change, run: run, schedule: nil, driver: nil, household: nil)
                )
            case .runAssignment:
                if runsByHousehold[change.householdId] == nil {
                    runsByHousehold[change.householdId] = try await runRepository.loadRuns(for: change.householdId)
                }
                let run = runsByHousehold[change.householdId]?.first(where: { $0.id == change.entityId })
                resolved.append(
                    ResolvedSyncChange(change: change, run: run, schedule: nil, driver: nil, household: nil)
                )
            case .schedule:
                if schedulesByHousehold[change.householdId] == nil {
                    schedulesByHousehold[change.householdId] = try await scheduleRepository.loadTemplates(for: change.householdId)
                }
                let schedule = schedulesByHousehold[change.householdId]?.first(where: { $0.id == change.entityId })
                resolved.append(
                    ResolvedSyncChange(change: change, run: nil, schedule: schedule, driver: nil, household: nil)
                )
            case .driver:
                if driversByHousehold[change.householdId] == nil {
                    driversByHousehold[change.householdId] = try await driverRepository.loadDrivers(for: change.householdId)
                }
                let driver = driversByHousehold[change.householdId]?.first(where: { $0.id == change.entityId })
                resolved.append(
                    ResolvedSyncChange(change: change, run: nil, schedule: nil, driver: driver, household: nil)
                )
            case .household:
                if households == nil {
                    households = try await householdRepository.loadHouseholds()
                }
                let household = households?.first(where: { $0.id == change.entityId })
                resolved.append(
                    ResolvedSyncChange(change: change, run: nil, schedule: nil, driver: nil, household: household)
                )
            }
        }

        return resolved
    }

    private func appendAuditRecord(_ record: SyncAuditRecord) async throws {
        try await auditRepository.append(record)
    }

    private func appendAuditRecords(_ records: [SyncAuditRecord]) async throws {
        guard !records.isEmpty else { return }
        try await auditRepository.append(records)
    }

    private func corruptFile(named fileName: String) throws {
        let directory = JSONFileStore.debugStorageDirectory()
        let fileURL = directory.appendingPathComponent(fileName, isDirectory: false)
        let garbage = Data("THIS_IS_CORRUPTED_JSON".utf8)
        try garbage.write(to: fileURL, options: .atomic)
    }
    
    private func syncPublishedStatus() {
        isSyncing = status.state == .syncing
        if let statusError = status.lastError, !statusError.isEmpty {
            lastError = statusError
        }
        pendingCount = max(status.pendingCount, queueStore.pendingOperations().count)
    }
}

