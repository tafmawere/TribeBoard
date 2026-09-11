import Foundation

enum RunNextRunSelector {
    struct SelectionLog: Equatable {
        let runId: UUID
        let title: String
        let status: SystemDomain.RunStatus
        let runDate: Date
        let createdAt: Date
        let stopsCount: Int
        let eligible: Bool
        let exclusionReason: String?
    }

    struct Result {
        let run: SystemDomain.RunInstance?
        let selectionReason: String
        let logs: [SelectionLog]
    }

    static func select(
        from runs: [SystemDomain.RunInstance],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Result {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        var logs: [SelectionLog] = []
        var eligibleRuns: [SystemDomain.RunInstance] = []
        var eligibleWithoutStops: [SystemDomain.RunInstance] = []

        for run in runs {
            let stopsCount = run.stopSnapshots.count
            let title = run.title ?? "(nil)"
            var eligible = false
            var exclusionReason: String?

            switch run.status {
            case .completed, .cancelled:
                exclusionReason = "terminal_status"
            case .inProgress:
                eligible = true
            case .scheduled, .assigned:
                let runDay = calendar.startOfDay(for: run.date)
                if runDay < startOfToday {
                    exclusionReason = "run_date_before_today"
                } else {
                    eligible = true
                }
            }

            if eligible {
                if stopsCount > 0 {
                    eligibleRuns.append(run)
                } else {
                    eligibleWithoutStops.append(run)
                    exclusionReason = "stops_count_zero_deferred"
                    logs.append(
                        SelectionLog(
                            runId: run.id,
                            title: title,
                            status: run.status,
                            runDate: run.date,
                            createdAt: run.createdAt,
                            stopsCount: stopsCount,
                            eligible: false,
                            exclusionReason: exclusionReason
                        )
                    )
                    continue
                }
            }

            logs.append(
                SelectionLog(
                    runId: run.id,
                    title: title,
                    status: run.status,
                    runDate: run.date,
                    createdAt: run.createdAt,
                    stopsCount: stopsCount,
                    eligible: eligible && stopsCount > 0,
                    exclusionReason: eligible ? nil : exclusionReason
                )
            )
        }

        let pool = eligibleRuns.isEmpty ? eligibleWithoutStops : eligibleRuns
        let usedStopFallback = eligibleRuns.isEmpty && !eligibleWithoutStops.isEmpty

        guard !pool.isEmpty else {
            return Result(run: nil, selectionReason: "no_eligible_runs", logs: logs)
        }

        let sorted = pool.sorted { lhs, rhs in
            let lhsRank = statusRank(lhs.status)
            let rhsRank = statusRank(rhs.status)
            if lhsRank != rhsRank { return lhsRank < rhsRank }

            let lhsDay = calendar.startOfDay(for: lhs.date)
            let rhsDay = calendar.startOfDay(for: rhs.date)
            if lhsDay != rhsDay { return lhsDay < rhsDay }

            if lhs.date != rhs.date { return lhs.date < rhs.date }

            return lhs.createdAt > rhs.createdAt
        }

        guard let selected = sorted.first else {
            return Result(run: nil, selectionReason: "no_eligible_runs", logs: logs)
        }

        var reasonParts: [String] = []
        if selected.status == .inProgress {
            reasonParts.append("in_progress")
        } else {
            reasonParts.append("today_or_future")
        }
        if usedStopFallback {
            reasonParts.append("stop_count_fallback")
        }
        reasonParts.append("sorted_by_status_then_run_date_then_created_at")

        #if DEBUG
        for entry in logs {
            NSLog(
                "[NextRun] run_id=%@ title=%@ status=%@ run_date=%@ created_at=%@ stops=%d eligible=%@ reason=%@",
                entry.runId.uuidString,
                entry.title,
                entry.status.rawValue,
                ISO8601DateFormatter().string(from: entry.runDate),
                ISO8601DateFormatter().string(from: entry.createdAt),
                entry.stopsCount,
                entry.eligible ? "true" : "false",
                entry.exclusionReason ?? "-"
            )
        }
        NSLog(
            "[NextRun] selected run_id=%@ reason=%@",
            selected.id.uuidString,
            reasonParts.joined(separator: ",")
        )
        #endif

        return Result(
            run: selected,
            selectionReason: reasonParts.joined(separator: ","),
            logs: logs
        )
    }

    private static func statusRank(_ status: SystemDomain.RunStatus) -> Int {
        switch status {
        case .inProgress: return 0
        case .assigned: return 1
        case .scheduled: return 2
        case .completed, .cancelled: return 99
        }
    }
}
