import Foundation

final class RunGeneratorService {
    typealias ScheduleTemplate = SystemDomain.ScheduleTemplate
    typealias RunInstance = SystemDomain.RunInstance
    typealias RunStatus = SystemDomain.RunStatus

    func generateRuns(
        from templates: [ScheduleTemplate],
        existingRuns: [RunInstance],
        daysAhead: Int = 14
    ) -> [RunInstance] {
        let calendar = Calendar.current
        let startOfToday = DayKey.key(for: Date(), calendar: calendar)
        var generated: [RunInstance] = []

        for dayOffset in 0...daysAhead {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
            let day = DayKey.key(for: dayDate, calendar: calendar)
            // Convention is Calendar weekday encoding: Sunday = 1 ... Saturday = 7.
            let weekday = calendar.component(.weekday, from: day)

            for template in templates where template.isActive && template.weekdays.contains(weekday) {
                guard let runDate = calendar.date(
                    bySettingHour: template.hour,
                    minute: template.minute,
                    second: 0,
                    of: day
                ) else { continue }

                let alreadyExistsInExisting = existingRuns.contains {
                    isSameOccurrence($0, template.id, runDate, calendar: calendar)
                }
                let alreadyExistsInGenerated = generated.contains {
                    isSameOccurrence($0, template.id, runDate, calendar: calendar)
                }

                guard !alreadyExistsInExisting && !alreadyExistsInGenerated else { continue }

                generated.append(
                    RunInstance(
                        id: Self.deterministicRunID(templateId: template.id, day: day, calendar: calendar),
                        householdId: template.householdId,
                        templateId: template.id,
                        title: template.name,
                        date: runDate,
                        departureTime: RunScheduleSnapshot.departureTime(from: template),
                        status: template.driverId == nil ? .scheduled : .assigned,
                        stops: template.stops.sorted { $0.order < $1.order }.map {
                            SystemDomain.RunStopProgress(stopId: $0.id, status: .pending, arrivedAt: nil, departedAt: nil)
                        },
                        stopSnapshots: template.stops,
                        assignedDriverId: template.driverId,
                        driverId: template.driverId,
                        childId: template.childId,
                        createdAt: Date()
                    )
                )
            }
        }

        return generated
    }

    static func debugWeekdayConvention(for date: Date) -> Int {
        Calendar.current.component(.weekday, from: date)
    }

    func isSameOccurrence(_ a: RunInstance, _ templateId: UUID, _ day: Date) -> Bool {
        isSameOccurrence(a, templateId, day, calendar: .current)
    }

    private func isSameOccurrence(_ a: RunInstance, _ templateId: UUID, _ day: Date, calendar: Calendar) -> Bool {
        a.templateId == templateId && DayKey.key(for: a.date, calendar: calendar) == DayKey.key(for: day, calendar: calendar)
    }

    static func deterministicRunID(templateId: UUID, day: Date, calendar: Calendar = .current) -> UUID {
        let hex = templateId.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let prefix = String(hex.prefix(20))
        let dayKey = Int(DayKey.key(for: day, calendar: calendar).timeIntervalSince1970 / 86_400)
        let dayHex = String(dayKey, radix: 16)
        let suffix = String(dayHex.suffix(12)).leftPadded(to: 12, with: "0")
        let combined = prefix + suffix
        let uuidString = "\(combined.prefix(8))-\(combined.dropFirst(8).prefix(4))-\(combined.dropFirst(12).prefix(4))-\(combined.dropFirst(16).prefix(4))-\(combined.dropFirst(20).prefix(12))"
        return UUID(uuidString: uuidString) ?? UUID()
    }
}

private extension String {
    func leftPadded(to length: Int, with character: Character) -> String {
        if count >= length { return self }
        return String(repeating: String(character), count: length - count) + self
    }
}
