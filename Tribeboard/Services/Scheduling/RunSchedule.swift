//
//  RunSchedule.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import Foundation

// MARK: - RunSchedule

/// A recurring template that defines when and how school runs should occur
struct RunSchedule: Codable, Identifiable, Sendable {
    let id: String  // UUID as String
    var title: String
    var timeOfDay: TimeOfDay
    var recurrence: RecurrencePattern
    var startDate: Date
    var endDate: Date?
    var driverUserId: String
    var passengerUserIds: [String]
    var stops: [ScheduleStop]
    var isEnabled: Bool
    
    init(
        id: String = UUID().uuidString,
        title: String,
        timeOfDay: TimeOfDay,
        recurrence: RecurrencePattern,
        startDate: Date,
        endDate: Date? = nil,
        driverUserId: String,
        passengerUserIds: [String],
        stops: [ScheduleStop],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.timeOfDay = timeOfDay
        self.recurrence = recurrence
        self.startDate = startDate
        self.endDate = endDate
        self.driverUserId = driverUserId
        self.passengerUserIds = passengerUserIds
        self.stops = stops
        self.isEnabled = isEnabled
    }
}

// MARK: - TimeOfDay

/// Represents a time of day with hour and minute components
struct TimeOfDay: Codable, Sendable {
    let hour: Int  // 0-23
    let minute: Int  // 0-59
    
    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }
    
    /// Create TimeOfDay from a Date by extracting hour and minute components
    init(from date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        self.hour = components.hour ?? 0
        self.minute = components.minute ?? 0
    }
    
    /// Combine this time with a date to create a complete Date
    func combined(with date: Date, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? date
    }
}

// MARK: - RecurrencePattern

/// Defines how a schedule repeats
enum RecurrencePattern: Codable, Sendable {
    case none(oneOffDate: Date)
    case daily
    case weekly(weekdays: Set<Weekday>)
    
    // Custom coding keys for enum with associated values
    private enum CodingKeys: String, CodingKey {
        case type
        case oneOffDate
        case weekdays
    }
    
    private enum PatternType: String, Codable {
        case none
        case daily
        case weekly
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(PatternType.self, forKey: .type)
        
        switch type {
        case .none:
            let date = try container.decode(Date.self, forKey: .oneOffDate)
            self = .none(oneOffDate: date)
        case .daily:
            self = .daily
        case .weekly:
            let weekdays = try container.decode(Set<Weekday>.self, forKey: .weekdays)
            self = .weekly(weekdays: weekdays)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .none(let oneOffDate):
            try container.encode(PatternType.none, forKey: .type)
            try container.encode(oneOffDate, forKey: .oneOffDate)
        case .daily:
            try container.encode(PatternType.daily, forKey: .type)
        case .weekly(let weekdays):
            try container.encode(PatternType.weekly, forKey: .type)
            try container.encode(weekdays, forKey: .weekdays)
        }
    }
}

// MARK: - Weekday

/// Represents days of the week for weekly recurrence patterns
enum Weekday: String, Codable, CaseIterable, Sendable {
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday
    
    /// Maps to Calendar.Component.weekday (1=Sunday, 2=Monday, etc.)
    var calendarWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
    
    /// Create Weekday from Calendar weekday component
    init?(calendarWeekday: Int) {
        switch calendarWeekday {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        case 7: self = .saturday
        default: return nil
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - ScheduleStop

/// A stop in a schedule, similar to RunStop but without completion tracking
struct ScheduleStop: Codable, Identifiable, Sendable {
    let id: String
    let type: StopType
    let label: String
    let location: LocationData
    var notes: String?
    
    init(
        id: String = UUID().uuidString,
        type: StopType,
        label: String,
        location: LocationData,
        notes: String? = nil
    ) {
        self.id = id
        self.type = type
        self.label = label
        self.location = location
        self.notes = notes
    }
}

// MARK: - ScheduledRunPreview

/// A specific instance of a schedule on a particular date, used for display before materialization
struct ScheduledRunPreview: Identifiable, Sendable {
    let id: String  // "\(scheduleId)-\(dateString)"
    let scheduleId: String
    let title: String
    let occurrenceDateTime: Date
    let driverUserId: String
    let passengerUserIds: [String]
    let stops: [ScheduleStop]
    let source: PreviewSource
    
    init(
        scheduleId: String,
        title: String,
        occurrenceDateTime: Date,
        driverUserId: String,
        passengerUserIds: [String],
        stops: [ScheduleStop],
        source: PreviewSource = .schedule
    ) {
        // Generate unique ID from schedule ID and date
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let dateString = dateFormatter.string(from: occurrenceDateTime)
        self.id = "\(scheduleId)-\(dateString)"
        
        self.scheduleId = scheduleId
        self.title = title
        self.occurrenceDateTime = occurrenceDateTime
        self.driverUserId = driverUserId
        self.passengerUserIds = passengerUserIds
        self.stops = stops
        self.source = source
    }
}

// MARK: - PreviewSource

/// Distinguishes scheduled run previews from other run types
enum PreviewSource: Sendable {
    case schedule
}
