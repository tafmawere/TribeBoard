import Foundation

enum RunPersistenceMapper {
    static func package(from run: SystemDomain.RunInstance) -> BackendRunPackage {
        let sortedSnapshots = run.stopSnapshots.sorted { $0.order < $1.order }
        let progressByStopId = Dictionary(uniqueKeysWithValues: run.stops.map { ($0.stopId, $0) })

        let backendStops: [BackendRunStop] = sortedSnapshots.enumerated().map { index, snapshot in
            let progress = progressByStopId[snapshot.id]
            let validated = RunStopLifecycle.validatedForPersistence(
                status: progress?.status ?? .pending,
                arrivedAt: progress?.arrivedAt,
                departedAt: progress?.departedAt
            )
            return BackendRunStop(
                id: snapshot.id,
                runId: run.id,
                childId: run.childId,
                label: RunStopLabelCodec.backendLabel(
                    for: snapshot,
                    order: index,
                    total: sortedSnapshots.count
                ),
                latitude: snapshot.latitude,
                longitude: snapshot.longitude,
                stopOrder: index,
                status: BackendRunStopStatusCodec.encode(validated.status),
                locationId: snapshot.locationId,
                arrivedAt: validated.arrivedAt,
                departedAt: validated.departedAt
            )
        }

        let backendRun = BackendRun(
            id: run.id,
            householdId: run.householdId,
            scheduleId: run.templateId,
            childId: run.childId,
            title: run.title,
            runDate: Calendar.current.startOfDay(for: run.date),
            departureTime: run.departureTime,
            status: BackendRunStatusCodec.encode(run.status),
            driverId: run.assignedDriverId ?? run.driverId,
            startedAt: run.startedAt,
            completedAt: run.completedAt,
            cancelledAt: run.cancelledAt,
            createdAt: run.createdAt
        )
        #if DEBUG
        NSLog(
            "[RunMapper] mapped driver fields direction=domain_to_backend run_id=%@ driver_id=%@ assigned_driver_id=%@ driver_name=%@",
            run.id.uuidString,
            backendRun.driverId?.uuidString ?? "nil",
            run.assignedDriverId?.uuidString ?? "nil",
            run.assignedDriverName ?? "nil"
        )
        #endif
        return BackendRunPackage(run: backendRun, stops: backendStops)
    }

    static func runInstance(
        from package: BackendRunPackage,
        template: SystemDomain.ScheduleTemplate?,
        driverName: String?,
        childId: UUID? = nil
    ) -> SystemDomain.RunInstance {
        let sortedStops = package.stops.sorted { $0.stopOrder < $1.stopOrder }
        let snapshots: [SystemDomain.Stop] = sortedStops.enumerated().map { index, stop in
            let trimmedLabel = stop.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let kindFromLabel = RunStopLabelCodec.normalizedKind(trimmedLabel)
            let resolvedKind = kindFromLabel
                ?? RunStopLabelCodec.inferredKind(order: index, total: sortedStops.count)
            let resolvedName = kindFromLabel == nil ? trimmedLabel : ""
            return SystemDomain.Stop(
                id: stop.id,
                name: resolvedName,
                latitude: stop.latitude,
                longitude: stop.longitude,
                order: stop.stopOrder,
                locationId: stop.locationId,
                kind: resolvedKind
            )
        }
        let progress: [SystemDomain.RunStopProgress] = sortedStops.map { stop in
            let decodedStatus = BackendRunStopStatusCodec.decode(stop.status)
            let sanitized = RunStopLifecycle.sanitized(
                status: decodedStatus,
                arrivedAt: stop.arrivedAt,
                departedAt: stop.departedAt
            )
            return SystemDomain.RunStopProgress(
                stopId: stop.id,
                status: sanitized.status,
                arrivedAt: sanitized.arrivedAt,
                departedAt: sanitized.departedAt
            )
        }

        let status = BackendRunStatusCodec.decode(package.run.status)
        let activeStopIndex = deriveActiveStopIndex(from: progress, status: status)
        let resolvedTitle = package.run.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

        #if DEBUG
        NSLog(
            "[RunMapper] mapped driver fields direction=backend_to_domain run_id=%@ driver_id=%@ driver_name=%@",
            package.run.id.uuidString,
            package.run.driverId?.uuidString ?? "nil",
            driverName ?? "nil"
        )
        #endif

        return SystemDomain.RunInstance(
            id: package.run.id,
            householdId: package.run.householdId,
            templateId: package.run.scheduleId,
            title: resolvedTitle,
            date: RunScheduledTime.merge(
                runDate: package.run.runDate,
                departureTime: package.run.departureTime
            ),
            departureTime: package.run.departureTime,
            status: status,
            stops: progress,
            stopSnapshots: snapshots,
            startedAt: package.run.startedAt,
            completedAt: package.run.completedAt,
            cancelledAt: package.run.cancelledAt,
            activeStopIndex: activeStopIndex,
            assignedDriverId: package.run.driverId,
            assignedDriverName: driverName,
            driverId: package.run.driverId,
            childId: package.run.childId ?? childId ?? sortedStops.first?.childId ?? template?.childId ?? UUID(),
            createdAt: package.run.createdAt
        )
    }

    static func deriveActiveStopIndex(
        from stops: [SystemDomain.RunStopProgress],
        status: SystemDomain.RunStatus
    ) -> Int? {
        guard status == .inProgress else { return nil }
        if let arrived = stops.firstIndex(where: { $0.status == .arrived }) {
            return arrived
        }
        if let enRoute = stops.firstIndex(where: { $0.status == .enRoute }) {
            return enRoute
        }
        if let pending = stops.firstIndex(where: { $0.status == .pending }) {
            return pending
        }
        return nil
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
