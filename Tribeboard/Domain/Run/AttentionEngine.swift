import Foundation

enum AttentionType: String, Equatable {
    case driverMissing
    case runOverdue
    case driverConflict
    case runStuck
}

enum AttentionSeverity: String, Equatable {
    case info
    case warning
    case critical
}

struct AttentionItem: Identifiable, Equatable {
    let id: UUID
    let type: AttentionType
    let runId: UUID?
    let message: String
    let severity: AttentionSeverity
}

struct AttentionEngine {
    func evaluate(
        runs: [SystemDomain.RunInstance],
        conflicts: [RunConflict],
        now: Date,
        calendar: Calendar = .current
    ) -> [AttentionItem] {
        var items: [AttentionItem] = []

        for run in runs {
            if isDriverMissing(run: run, now: now) {
                items.append(
                    AttentionItem(
                        id: stableItemID(kind: "driver-missing", runId: run.id),
                        type: .driverMissing,
                        runId: run.id,
                        message: "Driver missing for \(runTitle(run))",
                        severity: .warning
                    )
                )
            }

            if isRunOverdue(run: run, now: now) {
                items.append(
                    AttentionItem(
                        id: stableItemID(kind: "run-overdue", runId: run.id),
                        type: .runOverdue,
                        runId: run.id,
                        message: "Run overdue: \(runTitle(run))",
                        severity: .critical
                    )
                )
            }

            if isRunStuck(run: run, now: now) {
                items.append(
                    AttentionItem(
                        id: stableItemID(kind: "run-stuck", runId: run.id),
                        type: .runStuck,
                        runId: run.id,
                        message: "Run may be stuck: \(runTitle(run))",
                        severity: .warning
                    )
                )
            }
        }

        for conflict in conflicts {
            items.append(
                AttentionItem(
                    id: stableItemID(kind: "driver-conflict", runId: conflict.id),
                    type: .driverConflict,
                    runId: nil,
                    message: "Driver conflict detected",
                    severity: .warning
                )
            )
        }

        return items.sorted { lhs, rhs in
            let lhsRank = severityRank(lhs.severity)
            let rhsRank = severityRank(rhs.severity)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            if lhs.message != rhs.message {
                return lhs.message < rhs.message
            }
            let lhsDate = lhs.runId.flatMap { id in runs.first(where: { $0.id == id })?.date } ?? DayKey.key(for: now, calendar: calendar)
            let rhsDate = rhs.runId.flatMap { id in runs.first(where: { $0.id == id })?.date } ?? DayKey.key(for: now, calendar: calendar)
            return lhsDate < rhsDate
        }
    }

    private func isDriverMissing(run: SystemDomain.RunInstance, now: Date) -> Bool {
        guard run.status == .scheduled else { return false }
        guard run.assignedDriverId == nil else { return false }
        let delta = run.date.timeIntervalSince(now)
        return delta >= 0 && delta <= 3600
    }

    private func isRunOverdue(run: SystemDomain.RunInstance, now: Date) -> Bool {
        run.status == .scheduled && now > run.date.addingTimeInterval(15 * 60)
    }

    private func isRunStuck(run: SystemDomain.RunInstance, now: Date) -> Bool {
        guard run.status == .inProgress else { return false }
        guard let startedAt = run.startedAt else { return false }
        return now > startedAt.addingTimeInterval(2 * 3600)
    }

    private func runTitle(_ run: SystemDomain.RunInstance) -> String {
        let trimmed = run.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Scheduled Run" : trimmed
    }

    private func severityRank(_ severity: AttentionSeverity) -> Int {
        switch severity {
        case .critical: return 0
        case .warning: return 1
        case .info: return 2
        }
    }

    private func stableItemID(kind: String, runId: UUID) -> UUID {
        let runHex = runId.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let prefix = String(runHex.prefix(20))
        let suffixSeed = kind.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let suffix = padLeft(String(String(suffixSeed, radix: 16).suffix(12)), to: 12, with: "0")
        let combined = prefix + suffix
        let uuidString = "\(combined.prefix(8))-\(combined.dropFirst(8).prefix(4))-\(combined.dropFirst(12).prefix(4))-\(combined.dropFirst(16).prefix(4))-\(combined.dropFirst(20).prefix(12))"
        return UUID(uuidString: uuidString) ?? UUID()
    }

    private func padLeft(_ value: String, to length: Int, with character: Character) -> String {
        if value.count >= length { return value }
        return String(repeating: String(character), count: length - value.count) + value
    }
}
