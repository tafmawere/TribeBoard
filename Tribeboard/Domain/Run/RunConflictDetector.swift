import Foundation

struct RunConflict: Identifiable, Equatable {
    let id: UUID
    let driverId: UUID
    let runIds: [UUID]
    let date: Date
    let message: String
}

struct RunConflictDetector {
    private let conflictWindowSeconds: TimeInterval = 3600

    func detectConflicts(
        _ runs: [SystemDomain.RunInstance],
        for date: Date,
        calendar: Calendar = .current
    ) -> [RunConflict] {
        let day = DayKey.key(for: date, calendar: calendar)
        let dayRuns = runs.filter {
            DayKey.key(for: $0.date, calendar: calendar) == day && $0.status != .cancelled
        }

        let runsByDriver = Dictionary(grouping: dayRuns.compactMap { run -> (UUID, SystemDomain.RunInstance)? in
            guard let driverId = run.assignedDriverId else { return nil }
            return (driverId, run)
        }) { $0.0 }

        var conflicts: [RunConflict] = []
        for (driverId, grouped) in runsByDriver {
            let sortedRuns = grouped.map(\.1).sorted { $0.date < $1.date }
            guard sortedRuns.count > 1 else { continue }

            var conflictPairs = Set<String>()
            var affectedRunIDs = Set<UUID>()

            for lhsIndex in sortedRuns.indices {
                for rhsIndex in sortedRuns.indices where rhsIndex > lhsIndex {
                    let lhs = sortedRuns[lhsIndex]
                    let rhs = sortedRuns[rhsIndex]
                    let interval = abs(lhs.date.timeIntervalSince(rhs.date))
                    if interval < conflictWindowSeconds {
                        let pairKey = pairSignature(lhs.id, rhs.id)
                        guard !conflictPairs.contains(pairKey) else { continue }
                        conflictPairs.insert(pairKey)
                        affectedRunIDs.insert(lhs.id)
                        affectedRunIDs.insert(rhs.id)
                    }
                }
            }

            let runIds = affectedRunIDs.sorted { $0.uuidString < $1.uuidString }
            guard runIds.count > 1 else { continue }
            let message = "Driver has \(runIds.count) runs scheduled within 60 minutes."
            conflicts.append(
                RunConflict(
                    id: conflictID(driverId: driverId, day: day, calendar: calendar),
                    driverId: driverId,
                    runIds: runIds,
                    date: day,
                    message: message
                )
            )
        }

        return conflicts.sorted { lhs, rhs in
            if lhs.driverId == rhs.driverId {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.driverId.uuidString < rhs.driverId.uuidString
        }
    }

    private func pairSignature(_ a: UUID, _ b: UUID) -> String {
        let ordered = [a.uuidString, b.uuidString].sorted()
        return "\(ordered[0])::\(ordered[1])"
    }

    private func conflictID(driverId: UUID, day: Date, calendar: Calendar) -> UUID {
        let driverHex = driverId.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let prefix = String(driverHex.prefix(20))
        let dayKey = Int(DayKey.key(for: day, calendar: calendar).timeIntervalSince1970 / 86_400)
        let mixed = (dayKey << 11) ^ 60
        let suffix = padLeft(String(String(mixed, radix: 16).suffix(12)), to: 12, with: "0")
        let combined = prefix + suffix
        let uuidString = "\(combined.prefix(8))-\(combined.dropFirst(8).prefix(4))-\(combined.dropFirst(12).prefix(4))-\(combined.dropFirst(16).prefix(4))-\(combined.dropFirst(20).prefix(12))"
        return UUID(uuidString: uuidString) ?? UUID()
    }

    private func padLeft(_ value: String, to length: Int, with character: Character) -> String {
        if value.count >= length { return value }
        return String(repeating: String(character), count: length - value.count) + value
    }
}
