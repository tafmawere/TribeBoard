import Foundation

struct DispatchBuckets {
    var unassigned: [SystemDomain.RunInstance]
    var assigned: [SystemDomain.RunInstance]
    var inProgress: [SystemDomain.RunInstance]
    var completed: [SystemDomain.RunInstance]
    var cancelled: [SystemDomain.RunInstance]
}

struct DispatchBucketer {
    func bucket(
        _ runs: [SystemDomain.RunInstance],
        for date: Date,
        calendar: Calendar = .current
    ) -> DispatchBuckets {
        let day = DayKey.key(for: date, calendar: calendar)
        let dayRuns = runs.filter { DayKey.key(for: $0.date, calendar: calendar) == day }

        return DispatchBuckets(
            unassigned: dayRuns.filter { $0.status == .scheduled && $0.assignedDriverId == nil },
            assigned: dayRuns.filter { $0.status == .scheduled && $0.assignedDriverId != nil },
            inProgress: dayRuns.filter { $0.status == .inProgress },
            completed: dayRuns.filter { $0.status == .completed },
            cancelled: dayRuns.filter { $0.status == .cancelled }
        )
    }
}
