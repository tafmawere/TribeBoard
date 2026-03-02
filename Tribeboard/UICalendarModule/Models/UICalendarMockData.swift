import Foundation

enum UICalendarMockData {
    static let calendar = Calendar.current

    static let rue = UICalendarUser(name: "Rue", roles: [.parent, .observer])
    static let tafadzwa = UICalendarUser(name: "Tafadzwa", roles: [.parent, .driver])
    static let tj = UICalendarUser(name: "TJ", roles: [.child, .passenger])
    static let tawana = UICalendarUser(name: "Tawana", roles: [.child, .passenger])

    static let users: [UICalendarUser] = [rue, tafadzwa, tj, tawana]

    static let schoolDropoff = UISchedule(
        title: "School Dropoff",
        timeOfDay: DateComponents(hour: 6, minute: 45),
        recurrence: .weekly(days: [2, 3, 4, 5, 6]), // Mon-Fri
        startDate: calendar.startOfDay(for: Date()),
        driver: tafadzwa,
        passengers: [tj, tawana],
        stops: [
            UICalendarStop(type: .pickup, label: "Home"),
            UICalendarStop(type: .dropoff, label: "Lincoln Elementary"),
            UICalendarStop(type: .dropoff, label: "Westside Preschool")
        ],
        isEnabled: true
    )

    static let schoolPickup = UISchedule(
        title: "School Pickup",
        timeOfDay: DateComponents(hour: 14, minute: 30),
        recurrence: .weekly(days: [2, 3, 4, 5, 6]), // Mon-Fri
        startDate: calendar.startOfDay(for: Date()),
        driver: rue,
        passengers: [tj, tawana],
        stops: [
            UICalendarStop(type: .pickup, label: "Lincoln Elementary"),
            UICalendarStop(type: .dropoff, label: "Home")
        ],
        isEnabled: true
    )

    static let schedules: [UISchedule] = [schoolDropoff, schoolPickup]

    static func occurrencesForMonth(containing date: Date, schedules: [UISchedule] = schedules) -> [UIScheduleOccurrence] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: date),
            let days = calendar.range(of: .day, in: .month, for: date)
        else {
            return []
        }

        return days.flatMap { day -> [UIScheduleOccurrence] in
            guard let dayDate = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) else {
                return []
            }
            return occurrencesForDay(dayDate, schedules: schedules)
        }
        .sorted { $0.dateTime < $1.dateTime }
    }

    static func occurrencesForDay(_ dayDate: Date, schedules: [UISchedule] = schedules) -> [UIScheduleOccurrence] {
        schedules
            .filter { $0.isEnabled }
            .compactMap { schedule -> UIScheduleOccurrence? in
                guard shouldGenerate(schedule: schedule, on: dayDate) else { return nil }
                guard let dateTime = combine(dayDate: dayDate, time: schedule.timeOfDay) else { return nil }

                // Mock a few already-materialized runs.
                let hasRun = calendar.component(.day, from: dayDate).isMultiple(of: 3)
                return UIScheduleOccurrence(
                    scheduleId: schedule.id,
                    dateTime: dateTime,
                    title: schedule.title,
                    driver: schedule.driver,
                    passengers: schedule.passengers,
                    stops: schedule.stops,
                    hasMaterializedRun: hasRun
                )
            }
            .sorted { $0.dateTime < $1.dateTime }
    }

    private static func shouldGenerate(schedule: UISchedule, on dayDate: Date) -> Bool {
        let day = calendar.startOfDay(for: dayDate)
        guard day >= calendar.startOfDay(for: schedule.startDate) else { return false }
        if let endDate = schedule.endDate, day > calendar.startOfDay(for: endDate) { return false }

        switch schedule.recurrence {
        case let .oneOff(date):
            return calendar.isDate(day, inSameDayAs: date)
        case .daily:
            return true
        case let .weekly(days):
            let weekday = calendar.component(.weekday, from: day)
            return days.contains(weekday)
        }
    }

    private static func combine(dayDate: Date, time: DateComponents) -> Date? {
        var day = calendar.dateComponents([.year, .month, .day], from: dayDate)
        day.hour = time.hour
        day.minute = time.minute
        return calendar.date(from: day)
    }
}
