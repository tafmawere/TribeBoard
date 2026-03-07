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
    @Published private(set) var status: SyncStatusSnapshot
    @Published private(set) var recentSyncWarning: String?

    private let queueRepository: SyncQueueRepository
    private let auditRepository: SyncAuditRepository
    private let processedChangeRepository: ProcessedChangeRepository
    private let remoteDriver: RemoteSyncDriver?
    private let runRepository: (any RunRepository)?
    private let scheduleRepository: (any ScheduleRepository)?
    private let driverRepository: (any DriverRepository)?
    private let householdRepository: (any HouseholdRepository)?
    private let mergeService = SyncMergeService()
    private var isProcessing = false

    init(
        queueRepository: SyncQueueRepository,
        auditRepository: SyncAuditRepository = LocalSyncAuditRepository(),
        processedChangeRepository: ProcessedChangeRepository = LocalProcessedChangeRepository(),
        remoteDriver: RemoteSyncDriver? = nil,
        runRepository: (any RunRepository)? = nil,
        scheduleRepository: (any ScheduleRepository)? = nil,
        driverRepository: (any DriverRepository)? = nil,
        householdRepository: (any HouseholdRepository)? = nil
    ) {
        self.queueRepository = queueRepository
        self.auditRepository = auditRepository
        self.processedChangeRepository = processedChangeRepository
        self.remoteDriver = remoteDriver
        self.runRepository = runRepository
        self.scheduleRepository = scheduleRepository
        self.driverRepository = driverRepository
        self.householdRepository = householdRepository
        self.status = SyncStatusSnapshot(state: .idle, pendingCount: 0, lastSyncAt: nil, lastError: nil)
    }

    func refreshStatus() async {
        do {
            let changes = try await queueRepository.loadChanges()
            status.pendingCount = changes.count
            if isProcessing {
                status.state = .syncing
            } else if changes.isEmpty {
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
        } catch {
            status.state = .failed
            status.lastError = "Unable to enqueue sync change."
        }
    }

    func processQueue() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        do {
            let queue = try await queueRepository.loadChanges()
            guard !queue.isEmpty else {
                status.state = .idle
                status.pendingCount = 0
                status.lastError = nil
                recentSyncWarning = nil
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
        }
    }

    func clearQueue() async {
        do {
            try await queueRepository.saveChanges([])
            status.pendingCount = 0
            status.state = .idle
            status.lastError = nil
        } catch {
            status.state = .failed
            status.lastError = "Unable to clear sync queue."
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
}

