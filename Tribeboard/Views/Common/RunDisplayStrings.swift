import Foundation

enum RunDisplayStrings {
    static func childName(for run: SystemDomain.RunInstance, children: [BackendChild]) -> String {
        guard let child = children.first(where: { $0.id == run.childId }) else {
            return "Passenger"
        }
        return child.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? child.legalName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? "Passenger"
    }

    static func routeEndpoints(for run: SystemDomain.RunInstance) -> (pickup: String, dropoff: String) {
        let ordered = run.stopSnapshots.sorted { $0.order < $1.order }
        let pickup = ordered.first {
            RunStopLabelCodec.normalizedKind($0.kind) == RunStopLabelCodec.pickup
        } ?? ordered.first
        let dropoff = ordered.last {
            RunStopLabelCodec.normalizedKind($0.kind) == RunStopLabelCodec.dropoff
        } ?? ordered.last
        return (
            pickup: stopName(pickup, fallback: "Origin not set"),
            dropoff: stopName(dropoff, fallback: "Destination not set")
        )
    }

    private static func stopName(_ stop: SystemDomain.Stop?, fallback: String) -> String {
        guard let stop else { return fallback }
        return stop.name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? RunStopLabelCodec.normalizedKind(stop.kind)
            ?? fallback
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
