import Foundation

enum PlannedNotificationType: String {
    case runStartingSoon
    case driverMissing
    case runOverdue
    case driverConflict
    case runCompleted
}

struct PlannedNotification: Equatable {
    let id: String
    let type: PlannedNotificationType
    let runId: UUID?
    let request: NotificationRequest
}

struct NotificationPlanner {
    func plan(
        runs: [SystemDomain.RunInstance],
        attentionItems: [AttentionItem],
        now: Date,
        calendar: Calendar = .current
    ) -> [PlannedNotification] {
        var plannedByID: [String: PlannedNotification] = [:]
        let dayKey = dayStamp(for: now, calendar: calendar)
        let soonWindow: TimeInterval = 30 * 60
        let urgentLead: TimeInterval = TimeInterval(AppSettings.notificationLeadMinutes * 60)

        for run in runs where run.status == .scheduled {
            let delta = run.date.timeIntervalSince(now)
            guard delta >= 0 && delta <= soonWindow else { continue }

            let title = titleForRun(run)
            let triggerDate: Date
            if delta > urgentLead {
                triggerDate = run.date.addingTimeInterval(-urgentLead)
            } else {
                triggerDate = immediateTriggerDate(now: now)
            }

            let id = notificationID(
                type: .runStartingSoon,
                key: run.id.uuidString,
                dayKey: dayKey
            )
            plannedByID[id] = PlannedNotification(
                id: id,
                type: .runStartingSoon,
                runId: run.id,
                request: NotificationRequest(
                    id: id,
                    title: "Run starting soon",
                    body: "\(title) starts soon.",
                    triggerDate: triggerDate
                )
            )
        }

        for item in attentionItems {
            switch item.type {
            case .driverMissing:
                let key = item.runId?.uuidString ?? item.id.uuidString
                let id = notificationID(type: .driverMissing, key: key, dayKey: dayKey)
                plannedByID[id] = PlannedNotification(
                    id: id,
                    type: .driverMissing,
                    runId: item.runId,
                    request: NotificationRequest(
                        id: id,
                        title: "Driver missing",
                        body: item.message,
                        triggerDate: immediateTriggerDate(now: now)
                    )
                )
            case .runOverdue:
                let key = item.runId?.uuidString ?? item.id.uuidString
                let id = notificationID(type: .runOverdue, key: key, dayKey: dayKey)
                plannedByID[id] = PlannedNotification(
                    id: id,
                    type: .runOverdue,
                    runId: item.runId,
                    request: NotificationRequest(
                        id: id,
                        title: "Run overdue",
                        body: item.message,
                        triggerDate: immediateTriggerDate(now: now)
                    )
                )
            case .driverConflict:
                let id = notificationID(type: .driverConflict, key: item.id.uuidString, dayKey: dayKey)
                plannedByID[id] = PlannedNotification(
                    id: id,
                    type: .driverConflict,
                    runId: nil,
                    request: NotificationRequest(
                        id: id,
                        title: "Driver conflict detected",
                        body: item.message,
                        triggerDate: immediateTriggerDate(now: now)
                    )
                )
            case .runStuck:
                continue
            }
        }

        return plannedByID.values.sorted { $0.id < $1.id }
    }

    private func titleForRun(_ run: SystemDomain.RunInstance) -> String {
        let trimmed = run.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Scheduled Run" : trimmed
    }

    private func notificationID(type: PlannedNotificationType, key: String, dayKey: String) -> String {
        "tb-\(type.rawValue)-\(key)-\(dayKey)"
    }

    private func dayStamp(for date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d%02d%02d", y, m, d)
    }

    private func immediateTriggerDate(now: Date) -> Date {
#if DEBUG
        return now.addingTimeInterval(5)
#else
        return now.addingTimeInterval(60)
#endif
    }
}
