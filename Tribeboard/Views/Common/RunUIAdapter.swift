import Foundation

enum RunUIAdapter {
    static func mapToUIRun(_ run: SystemDomain.RunInstance, childName: String? = nil) -> UIRun {
        let driverName = run.assignedDriverName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? run.assignedDriverName!
            : "Unassigned"
        let childNameKey = childName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let childName = childNameKey.isEmpty ? "Passenger" : childNameKey
        let passengerStatus: UIPassengerStatus = (run.status == .completed) ? .droppedOff : .waiting
        let passenger = UIPassenger(id: run.childId, name: childName, status: passengerStatus)
        let stops = run.stopSnapshots.sorted { $0.order < $1.order }.map { stop in
            let stopType: UIStopType = {
                if stop.kind?.lowercased() == RunStopLabelCodec.pickup.lowercased() { return .pickup }
                if stop.kind?.lowercased() == RunStopLabelCodec.dropoff.lowercased() { return .dropoff }
                return stop.order == 0 ? .pickup : .dropoff
            }()
            let label = stop.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? (stop.kind ?? "Stop")
                : stop.name
            return UIStop(
                id: stop.id,
                type: stopType,
                label: label,
                timeText: formattedDate(run.date),
                passengerNames: [childName]
            )
        }

        return UIRun(
            id: run.id,
            backingRunId: run.id.uuidString,
            title: preferredTitle(for: run),
            scheduledTime: formattedDate(run.date),
            status: mapStatus(run.status),
            driverName: driverName,
            passengers: [passenger],
            stops: stops,
            etaText: run.status == .inProgress ? "In progress" : "Scheduled",
            distanceText: "--"
        )
    }

    private static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, h:mm a"
        return formatter.string(from: date)
    }

    private static func mapStatus(_ status: SystemDomain.RunStatus) -> UIRunStatus {
        switch status {
        case .scheduled:
            return .scheduled
        case .assigned:
            return .assigned
        case .inProgress:
            return .active
        case .completed, .cancelled:
            return .completed
        }
    }

    private static func preferredTitle(for run: SystemDomain.RunInstance) -> String {
        let snapshot = run.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !snapshot.isEmpty {
            return snapshot
        }
        return "Scheduled Run"
    }
}
