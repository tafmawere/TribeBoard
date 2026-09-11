import Foundation

struct CalendarSchoolItem: Identifiable {
    let id: UUID
    let childName: String
    let schoolName: String
    let startTimeText: String?
    let endTimeText: String?
}

struct CalendarActivityItem: Identifiable {
    let id: UUID
    let childName: String
    let activityName: String
    let summaryLine: String
    let detailLine: String?
}

struct CalendarScheduleItem: Identifiable {
    let id: UUID
    let template: SystemDomain.ScheduleTemplate
}

struct CalendarRunItem: Identifiable {
    let id: UUID
    let run: SystemDomain.RunInstance
    let driverName: String?
    let destinationContext: String?
}

struct CalendarDayContext {
    let schoolItems: [CalendarSchoolItem]
    let activityItems: [CalendarActivityItem]
    let scheduleItems: [CalendarScheduleItem]
    let runItems: [CalendarRunItem]

    var hasAnyLogistics: Bool {
        !schoolItems.isEmpty || !activityItems.isEmpty || !scheduleItems.isEmpty || !runItems.isEmpty
    }
}

enum CalendarDayContextBuilder {
    static func build(
        date: Date,
        calendar: Calendar = .current,
        children: [TribeMember],
        schedules: [SystemDomain.ScheduleTemplate],
        runs: [SystemDomain.RunInstance],
        driverNameProvider: ((UUID) -> String?)? = nil
    ) -> CalendarDayContext {
        let weekday = calendar.component(.weekday, from: date)
        let weekdayValue = mapToWeekday(weekday)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        let schoolItems = children
            .filter { $0.memberType == .child }
            .filter { child in
                guard child.hasSchoolConfigured else { return false }
                guard let days = child.schoolDays else { return false }
                return days.contains(weekdayValue)
            }
            .map { child in
                CalendarSchoolItem(
                    id: child.id,
                    childName: child.preferredDisplayName,
                    schoolName: child.schoolName ?? "School",
                    startTimeText: formatTime(child.schoolStartTime, calendar: calendar, formatter: formatter),
                    endTimeText: formatTime(child.schoolEndTime, calendar: calendar, formatter: formatter)
                )
            }
            .sorted { $0.childName.localizedCaseInsensitiveCompare($1.childName) == .orderedAscending }

        let activityItems = children
            .filter { $0.memberType == .child }
            .flatMap { child in
                child.activities
                    .filter { $0.days.contains(weekdayValue) }
                    .map { activity in
                        CalendarActivityItem(
                            id: activity.id,
                            childName: child.preferredDisplayName,
                            activityName: activity.name,
                            summaryLine: activity.activitySummaryLine,
                            detailLine: activity.activityLocationSummary
                        )
                    }
            }

        let validChildIds = Set(children.filter { $0.memberType == .child }.map(\.id))
        let scheduleItems = schedules
            .filter { $0.isActive && $0.weekdays.contains(weekday) && validChildIds.contains($0.childId) }
            .sorted {
                if $0.hour == $1.hour { return $0.minute < $1.minute }
                return $0.hour < $1.hour
            }
            .map { CalendarScheduleItem(id: $0.id, template: $0) }

        let runItems = runs
            .sorted { $0.date < $1.date }
            .map { run in
                let resolvedDriverName: String?
                if let assignedDriverName = run.assignedDriverName?.trimmingCharacters(in: .whitespacesAndNewlines), !assignedDriverName.isEmpty {
                    resolvedDriverName = assignedDriverName
                } else if let driverId = run.assignedDriverId {
                    resolvedDriverName = driverNameProvider?(driverId)
                } else {
                    resolvedDriverName = nil
                }
                let destinationContext = run.stopSnapshots.sorted { $0.order < $1.order }.last?.name
                return CalendarRunItem(
                    id: run.id,
                    run: run,
                    driverName: resolvedDriverName,
                    destinationContext: destinationContext
                )
            }

        return CalendarDayContext(
            schoolItems: schoolItems,
            activityItems: activityItems,
            scheduleItems: scheduleItems,
            runItems: runItems
        )
    }

    private static func mapToWeekday(_ value: Int) -> Weekday {
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

    private static func formatTime(_ components: DateComponents?, calendar: Calendar, formatter: DateFormatter) -> String? {
        guard let components, let date = calendar.date(from: components) else { return nil }
        return formatter.string(from: date)
    }
}
