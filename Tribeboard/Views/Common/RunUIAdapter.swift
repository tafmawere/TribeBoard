import Foundation

enum RunUIAdapter {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, h:mm a"
        return formatter
    }()

    static func mapToUIRun(_ run: SystemDomain.RunInstance) -> UIRun {
        let driverName = run.assignedDriverName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? run.assignedDriverName!
            : "Unassigned"
        let childName = "Passenger"
        let passengerStatus: UIPassengerStatus = (run.status == .completed) ? .droppedOff : .waiting
        let passenger = UIPassenger(id: run.childId, name: childName, status: passengerStatus)
        let stops = run.stopSnapshots.sorted { $0.order < $1.order }.map { stop in
            UIStop(
                id: stop.id,
                type: stop.order == 0 ? .pickup : .dropoff,
                label: stop.name,
                timeText: dateFormatter.string(from: run.date),
                passengerNames: [childName]
            )
        }

        return UIRun(
            id: run.id,
            backingRunId: run.id.uuidString,
            title: preferredTitle(for: run),
            scheduledTime: dateFormatter.string(from: run.date),
            status: mapStatus(run.status),
            driverName: driverName,
            passengers: [passenger],
            stops: stops,
            etaText: run.status == .inProgress ? "In progress" : "Scheduled",
            distanceText: "--"
        )
    }

    private static func mapStatus(_ status: SystemDomain.RunStatus) -> UIRunStatus {
        switch status {
        case .scheduled:
            return .scheduled
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
