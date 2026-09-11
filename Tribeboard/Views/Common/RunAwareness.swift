import Foundation

enum RunAwarenessType: Equatable {
    case schoolNeedsRun
    case activityNeedsRun
    case scheduleNeedsRun
    case runNeedsDriver
}

struct RunAwarenessItem: Identifiable, Equatable {
    let id: UUID
    let type: RunAwarenessType
    let childName: String?
    let title: String
    let message: String
    let date: Date
    let relatedScheduleId: UUID?
    let relatedRunId: UUID?
}

struct RunAwarenessBuilder {
    func build(
        date: Date,
        children: [TribeMember],
        schedules: [SystemDomain.ScheduleTemplate],
        runs: [SystemDomain.RunInstance]
    ) -> [RunAwarenessItem] {
        let calendar = Calendar.current
        let weekdayInt = calendar.component(.weekday, from: date)
        let weekday = mapToWeekday(weekdayInt)
        let dayRuns = runs.filter { calendar.isDate($0.date, inSameDayAs: date) }

        var items: [RunAwarenessItem] = []

        // Highest-signal operational gap: run exists but no driver assigned.
        for run in dayRuns where !isTerminal(run) && run.assignedDriverId == nil {
            let title = runTitle(run)
            items.append(
                RunAwarenessItem(
                    id: UUID(),
                    type: .runNeedsDriver,
                    childName: nil,
                    title: title,
                    message: "A run is planned today but no driver is assigned.",
                    date: date,
                    relatedScheduleId: run.templateId,
                    relatedRunId: run.id
                )
            )
        }

        let dayChildRuns = Dictionary(grouping: dayRuns, by: \.childId)
        let childItems = children.filter { $0.memberType == .child }

        for child in childItems {
            let childHasRun = !(dayChildRuns[child.id] ?? []).isEmpty

            if child.hasSchoolConfigured,
               let schoolDays = child.schoolDays,
               schoolDays.contains(weekday),
               !childHasRun {
                items.append(
                    RunAwarenessItem(
                        id: UUID(),
                        type: .schoolNeedsRun,
                        childName: child.preferredDisplayName,
                        title: "\(child.preferredDisplayName) needs a run",
                        message: "\(child.preferredDisplayName) has school today but no run is planned.",
                        date: date,
                        relatedScheduleId: nil,
                        relatedRunId: nil
                    )
                )
            }

            if !childHasRun {
                let dayActivities = child.activities.filter { $0.days.contains(weekday) }
                if dayActivities.count == 1, let activity = dayActivities.first {
                    items.append(
                        RunAwarenessItem(
                            id: UUID(),
                            type: .activityNeedsRun,
                            childName: child.preferredDisplayName,
                            title: "\(activity.name) needs a run",
                            message: "\(child.preferredDisplayName) has \(activity.name) today but no run is planned.",
                            date: date,
                            relatedScheduleId: nil,
                            relatedRunId: nil
                        )
                    )
                } else if dayActivities.count > 1 {
                    items.append(
                        RunAwarenessItem(
                            id: UUID(),
                            type: .activityNeedsRun,
                            childName: child.preferredDisplayName,
                            title: "Activities need runs",
                            message: "\(child.preferredDisplayName) has \(dayActivities.count) activities today but no run is planned.",
                            date: date,
                            relatedScheduleId: nil,
                            relatedRunId: nil
                        )
                    )
                }
            }
        }

        let daySchedules = schedules.filter { $0.isActive && $0.weekdays.contains(weekdayInt) }
        if !daySchedules.isEmpty && dayRuns.isEmpty && !items.contains(where: { $0.type == .schoolNeedsRun || $0.type == .activityNeedsRun }) {
            items.append(
                RunAwarenessItem(
                    id: UUID(),
                    type: .scheduleNeedsRun,
                    childName: nil,
                    title: "Schedules need runs",
                    message: "A scheduled routine exists for today but no run has been created.",
                    date: date,
                    relatedScheduleId: daySchedules.first?.id,
                    relatedRunId: nil
                )
            )
        }

        let deduped = dedupe(items)
        return deduped.sorted { lhs, rhs in
            let leftPriority = priority(lhs.type)
            let rightPriority = priority(rhs.type)
            if leftPriority == rightPriority {
                return lhs.message < rhs.message
            }
            return leftPriority < rightPriority
        }
    }

    private func mapToWeekday(_ value: Int) -> Weekday {
        switch value {
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return .sunday
        }
    }

    private func isTerminal(_ run: SystemDomain.RunInstance) -> Bool {
        run.status == .completed || run.status == .cancelled
    }

    private func runTitle(_ run: SystemDomain.RunInstance) -> String {
        let trimmed = run.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Scheduled run" : trimmed
    }

    private func priority(_ type: RunAwarenessType) -> Int {
        switch type {
        case .runNeedsDriver: return 0
        case .schoolNeedsRun: return 1
        case .activityNeedsRun: return 2
        case .scheduleNeedsRun: return 3
        }
    }

    private func dedupe(_ items: [RunAwarenessItem]) -> [RunAwarenessItem] {
        var seen: Set<String> = []
        var result: [RunAwarenessItem] = []
        for item in items {
            let key = "\(item.type)-\(item.childName ?? "_")-\(item.message)-\(item.relatedScheduleId?.uuidString ?? "_")-\(item.relatedRunId?.uuidString ?? "_")"
            if seen.insert(key).inserted {
                result.append(item)
            }
        }
        return result
    }
}
