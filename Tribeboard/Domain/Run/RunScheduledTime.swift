import Foundation

/// Combines persisted `run_date` + `departure_time` without consulting schedule templates.
enum RunScheduledTime {
    static func format(hour: Int, minute: Int, second: Int = 0) -> String {
        String(format: "%02d:%02d:%02d", hour, minute, second)
    }

    static func from(date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return format(
            hour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: components.second ?? 0
        )
    }

    static func parse(_ sqlTime: String) -> DateComponents? {
        let trimmed = sqlTime.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }
        let second = parts.count >= 3 ? (Int(parts[2]) ?? 0) : 0
        guard (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second) else {
            return nil
        }
        return DateComponents(hour: hour, minute: minute, second: second)
    }

    static func merge(runDay: Date, departureTime: String, calendar: Calendar = .current) -> Date? {
        guard let time = parse(departureTime) else { return nil }
        let day = calendar.startOfDay(for: runDay)
        return calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: day
        )
    }

    static func merge(runDate: Date, departureTime: String, calendar: Calendar = .current) -> Date {
        merge(runDay: runDate, departureTime: departureTime, calendar: calendar) ?? runDate
    }
}

enum RunScheduleSnapshot {
    static func departureTime(from template: SystemDomain.ScheduleTemplate) -> String {
        RunScheduledTime.format(hour: template.hour, minute: template.minute)
    }

    static func scheduledDate(
        on day: Date,
        template: SystemDomain.ScheduleTemplate,
        calendar: Calendar = .current
    ) -> Date? {
        RunScheduledTime.merge(
            runDay: day,
            departureTime: departureTime(from: template),
            calendar: calendar
        )
    }
}
