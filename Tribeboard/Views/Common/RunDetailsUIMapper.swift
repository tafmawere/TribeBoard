import Foundation

enum RunDetailsUIMapper {
    static func map(
        _ run: SystemDomain.RunInstance,
        childName: String? = nil
    ) -> RunDetailsData.UIRun {
        let trimmedChild = childName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let passengerName = (trimmedChild?.isEmpty == false) ? trimmedChild! : "Passenger"
        let driver = run.assignedDriverName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let driverName = (driver?.isEmpty == false) ? driver! : "Unassigned"
        let title = run.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let isTerminal = run.status == .completed || run.status == .cancelled
        let isEditable = run.status == .scheduled || run.status == .assigned

        return RunDetailsData.UIRun(
            id: run.id,
            title: (title?.isEmpty == false) ? title! : "Scheduled Run",
            scheduledTime: run.date,
            status: statusLabel(run.status),
            driverName: driverName,
            passengerNames: [passengerName],
            passengerStatuses: [isTerminal ? "Dropped" : "Waiting"],
            stops: mapStops(run),
            timeline: mapTimeline(run),
            canEdit: isEditable,
            canCancel: !isTerminal,
            isHistory: isTerminal
        )
    }

    static func resolve(
        runId: String,
        run: (String) -> SystemDomain.RunInstance?,
        childName: String? = nil
    ) -> RunDetailsData.UIRun? {
        guard let instance = run(runId) else { return nil }
        return map(instance, childName: childName)
    }

    private static func statusLabel(_ status: SystemDomain.RunStatus) -> String {
        switch status {
        case .scheduled: return "Scheduled"
        case .assigned: return "Assigned"
        case .inProgress: return "In progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    private static func mapStops(_ run: SystemDomain.RunInstance) -> [RunDetailsData.UIStop] {
        run.stopSnapshots.sorted { $0.order < $1.order }.map { stop in
            let kind = stop.kind?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let type: String = {
                if kind.lowercased() == RunStopLabelCodec.pickup.lowercased() { return "Pickup" }
                if kind.lowercased() == RunStopLabelCodec.dropoff.lowercased() { return "Dropoff" }
                return stop.order == 0 ? "Pickup" : "Dropoff"
            }()
            let label = stop.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return RunDetailsData.UIStop(
                id: stop.id,
                type: type,
                label: label.isEmpty ? type : label,
                placeName: "",
                address: "",
                latitude: stop.latitude,
                longitude: stop.longitude,
                locationId: stop.locationId,
                timeEstimate: "--"
            )
        }
    }

    private static func mapTimeline(_ run: SystemDomain.RunInstance) -> [RunDetailsData.UITimelineEvent] {
        var events: [RunDetailsData.UITimelineEvent] = [
            .init(
                time: run.createdAt,
                title: "Scheduled",
                detail: "Run created",
                iconName: "calendar",
                severity: .normal
            )
        ]
        if let startedAt = run.startedAt {
            events.append(
                .init(
                    time: startedAt,
                    title: "Started",
                    detail: "Driver began run",
                    iconName: "play.fill",
                    severity: .normal
                )
            )
        }
        if let completedAt = run.completedAt {
            events.append(
                .init(
                    time: completedAt,
                    title: "Completed",
                    detail: "Run finished",
                    iconName: "checkmark.circle.fill",
                    severity: .success
                )
            )
        }
        if let cancelledAt = run.cancelledAt {
            events.append(
                .init(
                    time: cancelledAt,
                    title: "Cancelled",
                    detail: "Run cancelled",
                    iconName: "xmark.circle.fill",
                    severity: .warn
                )
            )
        }
        return events
    }
}
