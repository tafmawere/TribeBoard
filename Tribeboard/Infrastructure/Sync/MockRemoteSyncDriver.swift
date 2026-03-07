import Foundation

final class MockRemoteSyncDriver: RemoteSyncDriver, RemoteSyncDebuggable {
    private let store: RemoteMirrorStore

    init(store: RemoteMirrorStore = RemoteMirrorStore()) {
        self.store = store
    }

    func push(changes: [ResolvedSyncChange]) async throws {
        guard !changes.isEmpty else { return }
        var snapshot = store.load()
        var seenChangeIDs = Set(snapshot.changes.map { $0.change.id })

        for resolved in changes {
            guard !seenChangeIDs.contains(resolved.change.id) else { continue }
            apply(resolved, to: &snapshot)
            snapshot.changes.append(resolved)
            seenChangeIDs.insert(resolved.change.id)
        }

        snapshot.changes.sort { $0.change.createdAt < $1.change.createdAt }
        store.save(snapshot)
    }

    func pull(since: Date?, householdId: UUID?) async throws -> [ResolvedSyncChange] {
        let snapshot = store.load()
        return snapshot.changes
            .filter { change in
                let matchesHousehold = householdId.map { change.change.householdId == $0 } ?? true
                let matchesSince = since.map { change.change.createdAt > $0 } ?? true
                return matchesHousehold && matchesSince
            }
            .sorted { $0.change.createdAt < $1.change.createdAt }
    }

    func seedRemoteMirrorDemoData(for householdId: UUID) async throws {
        var snapshot = store.load()
        let now = Date()

        let household = Household(
            id: householdId,
            name: "Remote Household",
            createdAt: now.addingTimeInterval(-7200)
        )
        upsertHousehold(household, in: &snapshot.households)

        let driver = SystemDomain.Driver(
            id: UUID(),
            householdId: householdId,
            name: "Remote Driver",
            phoneNumber: "+263771999000",
            isActive: true,
            createdAt: now.addingTimeInterval(-3600)
        )
        upsertDriver(driver, in: &snapshot.drivers)

        let stopA = SystemDomain.Stop(id: UUID(), name: "Remote Home", latitude: -17.8249, longitude: 31.0530, order: 0)
        let stopB = SystemDomain.Stop(id: UUID(), name: "Remote School", latitude: -17.8015, longitude: 31.0476, order: 1)
        let schedule = SystemDomain.ScheduleTemplate(
            id: UUID(),
            householdId: householdId,
            name: "Remote School Route",
            childId: UUID(),
            driverId: driver.id,
            weekdays: [2, 3, 4, 5, 6],
            hour: 7,
            minute: 15,
            stops: [stopA, stopB],
            isActive: true,
            createdAt: now.addingTimeInterval(-3000)
        )
        upsertSchedule(schedule, in: &snapshot.schedules)

        let run = SystemDomain.RunInstance(
            id: UUID(),
            householdId: householdId,
            templateId: schedule.id,
            title: "Remote Synced Run",
            date: now.addingTimeInterval(3600),
            status: .scheduled,
            stops: [
                SystemDomain.RunStopProgress(stopId: stopA.id, status: .pending, arrivedAt: nil, departedAt: nil),
                SystemDomain.RunStopProgress(stopId: stopB.id, status: .pending, arrivedAt: nil, departedAt: nil)
            ],
            stopSnapshots: [stopA, stopB],
            startedAt: nil,
            completedAt: nil,
            cancelledAt: nil,
            activeStopIndex: nil,
            assignedDriverId: driver.id,
            assignedDriverName: driver.name,
            driverId: driver.id,
            childId: schedule.childId,
            createdAt: now.addingTimeInterval(-2400)
        )
        upsertRun(run, in: &snapshot.runs)

        let seededChanges: [ResolvedSyncChange] = [
            resolved(.household, entityId: household.id, householdId: household.id, operation: .update, createdAt: now.addingTimeInterval(-180), household: household),
            resolved(.driver, entityId: driver.id, householdId: householdId, operation: .update, createdAt: now.addingTimeInterval(-120), driver: driver),
            resolved(.schedule, entityId: schedule.id, householdId: householdId, operation: .update, createdAt: now.addingTimeInterval(-90), schedule: schedule),
            resolved(.run, entityId: run.id, householdId: householdId, operation: .update, createdAt: now.addingTimeInterval(-60), run: run)
        ]

        let existingIDs = Set(snapshot.changes.map { $0.change.id })
        for change in seededChanges where !existingIDs.contains(change.id) {
            snapshot.changes.append(change)
        }
        snapshot.changes.sort { $0.change.createdAt < $1.change.createdAt }
        store.save(snapshot)
    }

    func seedDuplicateRemoteChange(for householdId: UUID) async throws {
        var snapshot = store.load()
        guard let base = firstSeedableChange(in: snapshot, householdId: householdId) else { return }

        // Intentionally append duplicate change IDs to validate duplicate suppression.
        snapshot.changes.append(base)
        snapshot.changes.sort { $0.change.createdAt < $1.change.createdAt }
        store.save(snapshot)
    }

    func seedStaleRemoteChange(for householdId: UUID) async throws {
        var snapshot = store.load()
        let now = Date()
        let staleDate = now.addingTimeInterval(-7 * 24 * 60 * 60)

        let run = ensureSeedRun(in: &snapshot, householdId: householdId, now: now)
        var staleRun = run
        staleRun.title = "STALE REMOTE TITLE"
        let stale = resolved(
            .run,
            entityId: staleRun.id,
            householdId: householdId,
            operation: .update,
            createdAt: staleDate,
            run: staleRun
        )
        snapshot.changes.append(stale)
        snapshot.changes.sort { $0.change.createdAt < $1.change.createdAt }
        store.save(snapshot)
    }

    func seedNewerRemoteChange(for householdId: UUID) async throws {
        var snapshot = store.load()
        let now = Date()
        let newerDate = now.addingTimeInterval(90)

        let run = ensureSeedRun(in: &snapshot, householdId: householdId, now: now)
        var newerRun = run
        newerRun.title = "NEWER REMOTE TITLE"
        let newer = resolved(
            .run,
            entityId: newerRun.id,
            householdId: householdId,
            operation: .update,
            createdAt: newerDate,
            run: newerRun
        )
        snapshot.changes.append(newer)
        snapshot.changes.sort { $0.change.createdAt < $1.change.createdAt }
        store.save(snapshot)
    }

    func clearRemoteMirror() async throws {
        store.save(
            RemoteMirrorStore.Snapshot(
                schemaVersion: 1,
                runs: [],
                schedules: [],
                drivers: [],
                households: [],
                changes: []
            )
        )
    }

    func remoteMirrorCounts() async throws -> RemoteMirrorCounts {
        let snapshot = store.load()
        return RemoteMirrorCounts(
            runs: snapshot.runs.count,
            schedules: snapshot.schedules.count,
            drivers: snapshot.drivers.count,
            households: snapshot.households.count,
            changes: snapshot.changes.count
        )
    }

    private func apply(_ resolved: ResolvedSyncChange, to snapshot: inout RemoteMirrorStore.Snapshot) {
        switch resolved.change.entityType {
        case .run:
            applyRun(resolved, to: &snapshot.runs)
        case .schedule:
            applySchedule(resolved, to: &snapshot.schedules)
        case .driver:
            applyDriver(resolved, to: &snapshot.drivers)
        case .household:
            applyHousehold(resolved, to: &snapshot.households)
        }
    }

    private func applyRun(_ resolved: ResolvedSyncChange, to runs: inout [SystemDomain.RunInstance]) {
        switch resolved.change.operation {
        case .delete:
            runs.removeAll { $0.id == resolved.change.entityId && $0.householdId == resolved.change.householdId }
        case .create, .update:
            guard let run = resolved.run else { return }
            upsertRun(run, in: &runs)
        }
    }

    private func applySchedule(_ resolved: ResolvedSyncChange, to schedules: inout [SystemDomain.ScheduleTemplate]) {
        switch resolved.change.operation {
        case .delete:
            schedules.removeAll { $0.id == resolved.change.entityId && $0.householdId == resolved.change.householdId }
        case .create, .update:
            guard let schedule = resolved.schedule else { return }
            upsertSchedule(schedule, in: &schedules)
        }
    }

    private func applyDriver(_ resolved: ResolvedSyncChange, to drivers: inout [SystemDomain.Driver]) {
        switch resolved.change.operation {
        case .delete:
            drivers.removeAll { $0.id == resolved.change.entityId && $0.householdId == resolved.change.householdId }
        case .create, .update:
            guard let driver = resolved.driver else { return }
            upsertDriver(driver, in: &drivers)
        }
    }

    private func applyHousehold(_ resolved: ResolvedSyncChange, to households: inout [Household]) {
        switch resolved.change.operation {
        case .delete:
            households.removeAll { $0.id == resolved.change.entityId }
        case .create, .update:
            guard let household = resolved.household else { return }
            upsertHousehold(household, in: &households)
        }
    }

    private func upsertRun(_ run: SystemDomain.RunInstance, in runs: inout [SystemDomain.RunInstance]) {
        if let index = runs.firstIndex(where: { $0.id == run.id }) {
            runs[index] = run
        } else {
            runs.append(run)
        }
    }

    private func upsertSchedule(_ schedule: SystemDomain.ScheduleTemplate, in schedules: inout [SystemDomain.ScheduleTemplate]) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
        } else {
            schedules.append(schedule)
        }
    }

    private func upsertDriver(_ driver: SystemDomain.Driver, in drivers: inout [SystemDomain.Driver]) {
        if let index = drivers.firstIndex(where: { $0.id == driver.id }) {
            drivers[index] = driver
        } else {
            drivers.append(driver)
        }
    }

    private func upsertHousehold(_ household: Household, in households: inout [Household]) {
        if let index = households.firstIndex(where: { $0.id == household.id }) {
            households[index] = household
        } else {
            households.append(household)
        }
    }

    private func resolved(
        _ entityType: SyncEntityType,
        entityId: UUID,
        householdId: UUID,
        operation: SyncOperationType,
        createdAt: Date,
        run: SystemDomain.RunInstance? = nil,
        schedule: SystemDomain.ScheduleTemplate? = nil,
        driver: SystemDomain.Driver? = nil,
        household: Household? = nil
    ) -> ResolvedSyncChange {
        let change = SyncChange(
            id: UUID(),
            householdId: householdId,
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            createdAt: createdAt,
            retryCount: 0,
            lastTriedAt: nil,
            payloadVersion: 1,
            sourceDeviceId: "mock-remote",
            sourceRevision: 1,
            effectiveUpdatedAt: createdAt
        )
        return ResolvedSyncChange(change: change, run: run, schedule: schedule, driver: driver, household: household)
    }

    private func firstSeedableChange(in snapshot: RemoteMirrorStore.Snapshot, householdId: UUID) -> ResolvedSyncChange? {
        snapshot.changes
            .filter { $0.change.householdId == householdId }
            .sorted(by: { $0.change.createdAt < $1.change.createdAt })
            .last
    }

    private func ensureSeedRun(
        in snapshot: inout RemoteMirrorStore.Snapshot,
        householdId: UUID,
        now: Date
    ) -> SystemDomain.RunInstance {
        if let existing = snapshot.runs.first(where: { $0.householdId == householdId }) {
            return existing
        }

        let stopA = SystemDomain.Stop(id: UUID(), name: "Seed Home", latitude: -17.8249, longitude: 31.0530, order: 0)
        let stopB = SystemDomain.Stop(id: UUID(), name: "Seed School", latitude: -17.8015, longitude: 31.0476, order: 1)
        let run = SystemDomain.RunInstance(
            id: UUID(),
            householdId: householdId,
            templateId: UUID(),
            title: "Remote Merge Target",
            date: now.addingTimeInterval(3600),
            status: .scheduled,
            stops: [
                SystemDomain.RunStopProgress(stopId: stopA.id, status: .pending, arrivedAt: nil, departedAt: nil),
                SystemDomain.RunStopProgress(stopId: stopB.id, status: .pending, arrivedAt: nil, departedAt: nil)
            ],
            stopSnapshots: [stopA, stopB],
            startedAt: nil,
            completedAt: nil,
            cancelledAt: nil,
            activeStopIndex: nil,
            assignedDriverId: nil,
            assignedDriverName: nil,
            driverId: nil,
            childId: UUID(),
            createdAt: now.addingTimeInterval(-600)
        )
        upsertRun(run, in: &snapshot.runs)
        return run
    }
}

