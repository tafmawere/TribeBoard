//
//  ScheduleRunGenerator.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import Foundation

/// Converts RunSchedule templates into ScheduledRunPreview objects for display
class ScheduleRunGenerator {
    
    // MARK: - Private Properties
    
    private let scheduleStore: ScheduleStore
    private let calendar: Calendar
    
    // MARK: - Initialization
    
    init(scheduleStore: ScheduleStore, calendar: Calendar = .current) {
        self.scheduleStore = scheduleStore
        self.calendar = calendar
    }
    
    // MARK: - Public Methods
    
    /// Generate previews for a specific date
    /// - Parameter date: The date to generate previews for
    /// - Returns: Array of ScheduledRunPreview objects for the given date
    func occurrences(on date: Date) -> [ScheduledRunPreview] {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        
        // Use the range method with a single-day range
        let range = startOfDay...endOfDay
        return occurrences(in: range).filter { preview in
            calendar.isDate(preview.occurrenceDateTime, inSameDayAs: date)
        }
    }
    
    /// Generate previews for a date range
    /// - Parameter dateRange: The closed range of dates to generate previews for
    /// - Returns: Array of ScheduledRunPreview objects within the range
    func occurrences(in dateRange: ClosedRange<Date>) -> [ScheduledRunPreview] {
        var previews: [ScheduledRunPreview] = []
        
        // Get all enabled schedules
        let enabledSchedules = scheduleStore.schedules.filter { $0.isEnabled }
        
        // For each schedule, generate previews for dates in the range
        for schedule in enabledSchedules {
            let schedulePreviews = generatePreviews(for: schedule, in: dateRange)
            previews.append(contentsOf: schedulePreviews)
        }
        
        return previews
    }
    
    // MARK: - Private Helper Methods
    
    /// Generate previews for a specific schedule within a date range
    private func generatePreviews(
        for schedule: RunSchedule,
        in dateRange: ClosedRange<Date>
    ) -> [ScheduledRunPreview] {
        var previews: [ScheduledRunPreview] = []
        
        // Determine the effective date range considering schedule boundaries
        let effectiveStartDate = max(
            calendar.startOfDay(for: dateRange.lowerBound),
            calendar.startOfDay(for: schedule.startDate)
        )
        
        let effectiveEndDate: Date
        if let scheduleEndDate = schedule.endDate {
            effectiveEndDate = min(
                calendar.startOfDay(for: dateRange.upperBound),
                calendar.startOfDay(for: scheduleEndDate)
            )
        } else {
            effectiveEndDate = calendar.startOfDay(for: dateRange.upperBound)
        }
        
        // If the effective range is invalid, return empty
        guard effectiveStartDate <= effectiveEndDate else {
            return []
        }
        
        // Generate occurrences based on recurrence pattern
        switch schedule.recurrence {
        case .none(let oneOffDate):
            // Single occurrence on the one-off date
            let oneOffDay = calendar.startOfDay(for: oneOffDate)
            if oneOffDay >= effectiveStartDate && oneOffDay <= effectiveEndDate {
                if let preview = createPreview(from: schedule, on: oneOffDay) {
                    previews.append(preview)
                }
            }
            
        case .daily:
            // Generate preview for every day in the range
            var currentDate = effectiveStartDate
            while currentDate <= effectiveEndDate {
                if let preview = createPreview(from: schedule, on: currentDate) {
                    previews.append(preview)
                }
                guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                    break
                }
                currentDate = nextDate
            }
            
        case .weekly(let weekdays):
            // Generate preview only on specified weekdays
            var currentDate = effectiveStartDate
            while currentDate <= effectiveEndDate {
                if shouldInclude(schedule: schedule, on: currentDate) {
                    if let preview = createPreview(from: schedule, on: currentDate) {
                        previews.append(preview)
                    }
                }
                guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                    break
                }
                currentDate = nextDate
            }
        }
        
        return previews
    }
    
    /// Check if a schedule should generate a preview on a specific date
    /// Used primarily for weekly recurrence to check weekday match
    private func shouldInclude(schedule: RunSchedule, on date: Date) -> Bool {
        // Check if date is within schedule boundaries
        let dateDay = calendar.startOfDay(for: date)
        let scheduleStartDay = calendar.startOfDay(for: schedule.startDate)
        
        guard dateDay >= scheduleStartDay else {
            return false
        }
        
        if let endDate = schedule.endDate {
            let scheduleEndDay = calendar.startOfDay(for: endDate)
            guard dateDay <= scheduleEndDay else {
                return false
            }
        }
        
        // Check recurrence pattern
        switch schedule.recurrence {
        case .none(let oneOffDate):
            let oneOffDay = calendar.startOfDay(for: oneOffDate)
            return dateDay == oneOffDay
            
        case .daily:
            return true
            
        case .weekly(let weekdays):
            // Check if the date's weekday matches one of the specified weekdays
            let weekdayComponent = calendar.component(.weekday, from: date)
            guard let dateWeekday = Weekday(calendarWeekday: weekdayComponent) else {
                return false
            }
            return weekdays.contains(dateWeekday)
        }
    }
    
    /// Create a ScheduledRunPreview from a schedule and occurrence date
    private func createPreview(
        from schedule: RunSchedule,
        on date: Date
    ) -> ScheduledRunPreview? {
        // Combine the occurrence date with the schedule's time of day
        let occurrenceDateTime = schedule.timeOfDay.combined(with: date, calendar: calendar)
        
        return ScheduledRunPreview(
            scheduleId: schedule.id,
            title: schedule.title,
            occurrenceDateTime: occurrenceDateTime,
            driverUserId: schedule.driverUserId,
            passengerUserIds: schedule.passengerUserIds,
            stops: schedule.stops,
            source: .schedule
        )
    }
    
    /// Generate unique preview ID from schedule ID and date
    private func generatePreviewId(scheduleId: String, date: Date) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let dateString = dateFormatter.string(from: date)
        return "\(scheduleId)-\(dateString)"
    }
}
