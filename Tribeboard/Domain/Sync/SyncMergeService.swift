import Foundation

struct SyncMergeResult {
    let appliedCount: Int
    let skippedCount: Int
    let duplicateCount: Int
    let conflictCount: Int
    let processedChanges: [ProcessedSyncChange]
    let conflicts: [SyncConflict]
    let auditRecords: [SyncAuditRecord]
}

struct SyncMergeService {
    func merge(
        resolvedChanges: [ResolvedSyncChange],
        runRepository: any RunRepository,
        scheduleRepository: any ScheduleRepository,
        driverRepository: any DriverRepository,
        householdRepository: any HouseholdRepository,
        processedChangeIDs: Set<UUID>,
        now: Date = Date()
    ) async throws -> SyncMergeResult {
        guard !resolvedChanges.isEmpty else {
            return SyncMergeResult(
                appliedCount: 0,
                skippedCount: 0,
                duplicateCount: 0,
                conflictCount: 0,
                processedChanges: [],
                conflicts: [],
                auditRecords: []
            )
        }

        var runCacheByHousehold: [UUID: [SystemDomain.RunInstance]] = [:]
        var scheduleCacheByHousehold: [UUID: [SystemDomain.ScheduleTemplate]] = [:]
        var driverCacheByHousehold: [UUID: [SystemDomain.Driver]] = [:]
        var householdCache: [Household]?

        var appliedCount = 0
        var skippedCount = 0
        var duplicateCount = 0
        var conflictCount = 0
        var processedToAppend: [ProcessedSyncChange] = []
        var conflicts: [SyncConflict] = []
        var auditRecords: [SyncAuditRecord] = []

        for resolved in resolvedChanges.sorted(by: { $0.change.createdAt < $1.change.createdAt }) {
            if processedChangeIDs.contains(resolved.change.id) {
                duplicateCount += 1
                auditRecords.append(
                    makeAuditRecord(
                        for: resolved,
                        result: .duplicate,
                        message: "Duplicate remote change skipped.",
                        createdAt: now
                    )
                )
                continue
            }

            let householdId = resolved.change.householdId
            let remoteTimestamp = resolved.change.effectiveUpdatedAt ?? resolved.change.createdAt

            switch resolved.change.entityType {
            case .run:
                if runCacheByHousehold[householdId] == nil {
                    runCacheByHousehold[householdId] = try await runRepository.loadRuns(for: householdId)
                }
                let decision = applyRunChange(
                    resolved,
                    runs: &runCacheByHousehold[householdId]!,
                    remoteTimestamp: remoteTimestamp,
                    now: now
                )
                updateDecisionState(
                    decision,
                    resolved: resolved,
                    now: now,
                    appliedCount: &appliedCount,
                    skippedCount: &skippedCount,
                    conflictCount: &conflictCount,
                    processedToAppend: &processedToAppend,
                    conflicts: &conflicts,
                    auditRecords: &auditRecords
                )
            case .schedule:
                if scheduleCacheByHousehold[householdId] == nil {
                    scheduleCacheByHousehold[householdId] = try await scheduleRepository.loadTemplates(for: householdId)
                }
                let decision = applyScheduleChange(
                    resolved,
                    schedules: &scheduleCacheByHousehold[householdId]!,
                    remoteTimestamp: remoteTimestamp,
                    now: now
                )
                updateDecisionState(
                    decision,
                    resolved: resolved,
                    now: now,
                    appliedCount: &appliedCount,
                    skippedCount: &skippedCount,
                    conflictCount: &conflictCount,
                    processedToAppend: &processedToAppend,
                    conflicts: &conflicts,
                    auditRecords: &auditRecords
                )
            case .driver:
                if driverCacheByHousehold[householdId] == nil {
                    driverCacheByHousehold[householdId] = try await driverRepository.loadDrivers(for: householdId)
                }
                let decision = applyDriverChange(
                    resolved,
                    drivers: &driverCacheByHousehold[householdId]!,
                    remoteTimestamp: remoteTimestamp,
                    now: now
                )
                updateDecisionState(
                    decision,
                    resolved: resolved,
                    now: now,
                    appliedCount: &appliedCount,
                    skippedCount: &skippedCount,
                    conflictCount: &conflictCount,
                    processedToAppend: &processedToAppend,
                    conflicts: &conflicts,
                    auditRecords: &auditRecords
                )
            case .household:
                if householdCache == nil {
                    householdCache = try await householdRepository.loadHouseholds()
                }
                let decision = applyHouseholdChange(
                    resolved,
                    households: &householdCache!,
                    remoteTimestamp: remoteTimestamp,
                    now: now
                )
                updateDecisionState(
                    decision,
                    resolved: resolved,
                    now: now,
                    appliedCount: &appliedCount,
                    skippedCount: &skippedCount,
                    conflictCount: &conflictCount,
                    processedToAppend: &processedToAppend,
                    conflicts: &conflicts,
                    auditRecords: &auditRecords
                )
            }
        }

        for (householdId, runs) in runCacheByHousehold {
            try await runRepository.saveRuns(runs, for: householdId)
        }
        for (householdId, schedules) in scheduleCacheByHousehold {
            try await scheduleRepository.saveTemplates(schedules, for: householdId)
        }
        for (householdId, drivers) in driverCacheByHousehold {
            try await driverRepository.saveDrivers(drivers, for: householdId)
        }
        if let householdCache {
            try await householdRepository.saveHouseholds(householdCache)
        }

        return SyncMergeResult(
            appliedCount: appliedCount,
            skippedCount: skippedCount,
            duplicateCount: duplicateCount,
            conflictCount: conflictCount,
            processedChanges: processedToAppend,
            conflicts: conflicts,
            auditRecords: auditRecords
        )
    }

    private enum MergeAction {
        case applied(String)
        case skipped(String)
        case conflict(SyncConflict)
    }

    private func applyRunChange(
        _ resolved: ResolvedSyncChange,
        runs: inout [SystemDomain.RunInstance],
        remoteTimestamp: Date,
        now: Date
    ) -> MergeAction {
        let local = runs.first(where: { $0.id == resolved.change.entityId })
        let localTimestamp = local?.createdAt
        switch resolved.change.operation {
        case .delete:
            guard let local else {
                return .skipped("Delete skipped; entity already absent locally.")
            }
            if let localTimestamp, remoteTimestamp < localTimestamp {
                return .conflict(
                    makeConflict(
                        for: resolved,
                        type: .deleteVsUpdate,
                        localTimestamp: localTimestamp,
                        remoteTimestamp: remoteTimestamp,
                        message: "Remote delete is older than local run update.",
                        now: now
                    )
                )
            }
            runs.removeAll { $0.id == local.id }
            return .applied("Remote delete applied.")
        case .create, .update:
            guard let incoming = resolved.run else {
                return .skipped("Upsert skipped; remote payload missing.")
            }
            if let localTimestamp {
                if remoteTimestamp < localTimestamp {
                    return .conflict(
                        makeConflict(
                            for: resolved,
                            type: .staleRemoteChange,
                            localTimestamp: localTimestamp,
                            remoteTimestamp: remoteTimestamp,
                            message: "Remote run change is older than local record.",
                            now: now
                        )
                    )
                }
                if remoteTimestamp == localTimestamp {
                    return .conflict(
                        makeConflict(
                            for: resolved,
                            type: .competingUpdates,
                            localTimestamp: localTimestamp,
                            remoteTimestamp: remoteTimestamp,
                            message: "Run change has competing timestamps with different device origins.",
                            now: now
                        )
                    )
                }
            }
            upsert(incoming: incoming, items: &runs, id: \.id)
            return .applied("Remote upsert applied.")
        }
    }

    private func applyScheduleChange(
        _ resolved: ResolvedSyncChange,
        schedules: inout [SystemDomain.ScheduleTemplate],
        remoteTimestamp: Date,
        now: Date
    ) -> MergeAction {
        let local = schedules.first(where: { $0.id == resolved.change.entityId })
        let localTimestamp = local?.createdAt
        switch resolved.change.operation {
        case .delete:
            guard let local else {
                return .skipped("Delete skipped; entity already absent locally.")
            }
            if let localTimestamp, remoteTimestamp < localTimestamp {
                return .conflict(
                    makeConflict(
                        for: resolved,
                        type: .deleteVsUpdate,
                        localTimestamp: localTimestamp,
                        remoteTimestamp: remoteTimestamp,
                        message: "Remote delete is older than local schedule update.",
                        now: now
                    )
                )
            }
            schedules.removeAll { $0.id == local.id }
            return .applied("Remote delete applied.")
        case .create, .update:
            guard let incoming = resolved.schedule else {
                return .skipped("Upsert skipped; remote payload missing.")
            }
            if let localTimestamp {
                if remoteTimestamp < localTimestamp {
                    return .conflict(
                        makeConflict(
                            for: resolved,
                            type: .staleRemoteChange,
                            localTimestamp: localTimestamp,
                            remoteTimestamp: remoteTimestamp,
                            message: "Remote schedule change is older than local record.",
                            now: now
                        )
                    )
                }
                if remoteTimestamp == localTimestamp {
                    return .conflict(
                        makeConflict(
                            for: resolved,
                            type: .competingUpdates,
                            localTimestamp: localTimestamp,
                            remoteTimestamp: remoteTimestamp,
                            message: "Schedule change has competing timestamps.",
                            now: now
                        )
                    )
                }
            }
            upsert(incoming: incoming, items: &schedules, id: \.id)
            return .applied("Remote upsert applied.")
        }
    }

    private func applyDriverChange(
        _ resolved: ResolvedSyncChange,
        drivers: inout [SystemDomain.Driver],
        remoteTimestamp: Date,
        now: Date
    ) -> MergeAction {
        let local = drivers.first(where: { $0.id == resolved.change.entityId })
        let localTimestamp = local?.createdAt
        switch resolved.change.operation {
        case .delete:
            guard let local else {
                return .skipped("Delete skipped; entity already absent locally.")
            }
            if let localTimestamp, remoteTimestamp < localTimestamp {
                return .conflict(
                    makeConflict(
                        for: resolved,
                        type: .deleteVsUpdate,
                        localTimestamp: localTimestamp,
                        remoteTimestamp: remoteTimestamp,
                        message: "Remote delete is older than local driver update.",
                        now: now
                    )
                )
            }
            drivers.removeAll { $0.id == local.id }
            return .applied("Remote delete applied.")
        case .create, .update:
            guard let incoming = resolved.driver else {
                return .skipped("Upsert skipped; remote payload missing.")
            }
            if let localTimestamp {
                if remoteTimestamp < localTimestamp {
                    return .conflict(
                        makeConflict(
                            for: resolved,
                            type: .staleRemoteChange,
                            localTimestamp: localTimestamp,
                            remoteTimestamp: remoteTimestamp,
                            message: "Remote driver change is older than local record.",
                            now: now
                        )
                    )
                }
                if remoteTimestamp == localTimestamp {
                    return .conflict(
                        makeConflict(
                            for: resolved,
                            type: .competingUpdates,
                            localTimestamp: localTimestamp,
                            remoteTimestamp: remoteTimestamp,
                            message: "Driver change has competing timestamps.",
                            now: now
                        )
                    )
                }
            }
            upsert(incoming: incoming, items: &drivers, id: \.id)
            return .applied("Remote upsert applied.")
        }
    }

    private func applyHouseholdChange(
        _ resolved: ResolvedSyncChange,
        households: inout [Household],
        remoteTimestamp: Date,
        now: Date
    ) -> MergeAction {
        let local = households.first(where: { $0.id == resolved.change.entityId })
        let localTimestamp = local?.createdAt
        switch resolved.change.operation {
        case .delete:
            guard let local else {
                return .skipped("Delete skipped; entity already absent locally.")
            }
            if let localTimestamp, remoteTimestamp < localTimestamp {
                return .conflict(
                    makeConflict(
                        for: resolved,
                        type: .deleteVsUpdate,
                        localTimestamp: localTimestamp,
                        remoteTimestamp: remoteTimestamp,
                        message: "Remote delete is older than local household update.",
                        now: now
                    )
                )
            }
            households.removeAll { $0.id == local.id }
            return .applied("Remote delete applied.")
        case .create, .update:
            guard let incoming = resolved.household else {
                return .skipped("Upsert skipped; remote payload missing.")
            }
            if let localTimestamp {
                if remoteTimestamp < localTimestamp {
                    return .conflict(
                        makeConflict(
                            for: resolved,
                            type: .staleRemoteChange,
                            localTimestamp: localTimestamp,
                            remoteTimestamp: remoteTimestamp,
                            message: "Remote household change is older than local record.",
                            now: now
                        )
                    )
                }
                if remoteTimestamp == localTimestamp {
                    return .conflict(
                        makeConflict(
                            for: resolved,
                            type: .competingUpdates,
                            localTimestamp: localTimestamp,
                            remoteTimestamp: remoteTimestamp,
                            message: "Household change has competing timestamps.",
                            now: now
                        )
                    )
                }
            }
            upsert(incoming: incoming, items: &households, id: \.id)
            return .applied("Remote upsert applied.")
        }
    }

    private func upsert<Item, ID: Equatable>(
        incoming: Item,
        items: inout [Item],
        id: KeyPath<Item, ID>
    ) {
        if let index = items.firstIndex(where: { $0[keyPath: id] == incoming[keyPath: id] }) {
            items[index] = incoming
        } else {
            items.append(incoming)
        }
    }

    private func makeConflict(
        for resolved: ResolvedSyncChange,
        type: SyncConflictType,
        localTimestamp: Date?,
        remoteTimestamp: Date?,
        message: String,
        now: Date
    ) -> SyncConflict {
        SyncConflict(
            id: UUID(),
            householdId: resolved.change.householdId,
            entityType: resolved.change.entityType,
            entityId: resolved.change.entityId,
            type: type,
            localTimestamp: localTimestamp,
            remoteTimestamp: remoteTimestamp,
            message: message,
            createdAt: now
        )
    }

    private func updateDecisionState(
        _ action: MergeAction,
        resolved: ResolvedSyncChange,
        now: Date,
        appliedCount: inout Int,
        skippedCount: inout Int,
        conflictCount: inout Int,
        processedToAppend: inout [ProcessedSyncChange],
        conflicts: inout [SyncConflict],
        auditRecords: inout [SyncAuditRecord]
    ) {
        switch action {
        case let .applied(message):
            appliedCount += 1
            processedToAppend.append(
                ProcessedSyncChange(id: UUID(), changeId: resolved.change.id, processedAt: now)
            )
            auditRecords.append(
                makeAuditRecord(for: resolved, result: .success, message: message, createdAt: now)
            )
        case let .skipped(message):
            skippedCount += 1
            processedToAppend.append(
                ProcessedSyncChange(id: UUID(), changeId: resolved.change.id, processedAt: now)
            )
            auditRecords.append(
                makeAuditRecord(for: resolved, result: .skipped, message: message, createdAt: now)
            )
        case let .conflict(conflict):
            conflictCount += 1
            skippedCount += 1
            processedToAppend.append(
                ProcessedSyncChange(id: UUID(), changeId: resolved.change.id, processedAt: now)
            )
            conflicts.append(conflict)
            auditRecords.append(
                makeAuditRecord(
                    for: resolved,
                    result: .conflict,
                    message: conflict.message,
                    createdAt: now
                )
            )
        }
    }

    private func makeAuditRecord(
        for resolved: ResolvedSyncChange,
        result: SyncAuditResult,
        message: String,
        createdAt: Date
    ) -> SyncAuditRecord {
        SyncAuditRecord(
            id: UUID(),
            householdId: resolved.change.householdId,
            entityType: resolved.change.entityType,
            entityId: resolved.change.entityId,
            direction: .merge,
            result: result,
            changeId: resolved.change.id,
            message: message,
            createdAt: createdAt
        )
    }
}

