//
//  ScheduleRunGeneratorTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/03.
//

import Testing
import Foundation
@testable import Tribeboard

@MainActor
struct ScheduleRunGeneratorTests {
    
    // MARK: - Helper Methods
    
    /// Create a test schedule store with predefined schedules
    private func createTestStore(with schedules: [RunSchedule] = []) throws -> ScheduleStore {
        let store = try ScheduleStore(fileManager: .default)
        
        // Clear existing schedules
        Task {
            for schedule in store.schedules {
                try await store.delete(scheduleId: schedule.id)
            }
            
            // Add test schedules
            for schedule in schedules {
                try await store.upsert(schedule)
            }
        }
        
        return store
    }
    
    /// Create a test schedule
    private func createTestSchedule(
        id: String = UUID().uuidString,
        title: String = "Test Schedule",
        hour: Int = 8,
        minute: Int = 30,
        recurrence: RecurrencePattern = .daily,
        startDate: Date = Date(),
        endDate: Date? = nil,
        isEnabled: Bool = true
    ) -> RunSchedule {
        return RunSchedule(
            id: id,
            title: title,
            timeOfDay: TimeOfDay(hour: hour, minute: minute),
            recurrence: recurrence,
            startDate: startDate,
            endDate: endDate,
            driverUserId: "demo-tafadzwa",
            passengerUserIds: ["demo-tj", "demo-tawana"],
            stops: [
                ScheduleStop(
                    type: .pickup,
                    label: "Home",
                    location: LocationData(
                        latitude: 37.7749,
                        longitude: -122.4194,
                        address: "123 Main St"
                    )
                ),
                ScheduleStop(
                    type: .dropoff,
                    label: "School",
                    location: LocationData(
                        latitude: 37.7949,
                        longitude: -122.3994,
                        address: "456 School Ave"
                    )
                )
            ],
            isEnabled: isEnabled
        )
    }
    
    /// Get a specific date for testing
    private func date(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone.current
        return Calendar.current.date(from: components)!
    }
    
    // MARK: - Disabled Schedule Filtering Tests
    
    @Test("Generator filters out disabled schedules")
    func testDisabledScheduleFiltering() async throws {
        let enabledSchedule = createTestSchedule(
            id: "enabled-1",
            title: "Enabled Schedule",
            isEnabled: true
        )
        
        let disabledSchedule = createTestSchedule(
            id: "disabled-1",
            title: "Disabled Schedule",
            isEnabled: false
        )
        
        let store = try createTestStore(with: [enabledSchedule, disabledSchedule])
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let generator = ScheduleRunGenerator(scheduleStore: store)
        
        let today = Date()
        let previews = generator.occurrences(on: today)
        
        // Should only include enabled schedule
        #expect(previews.contains(where: { $0.scheduleId == "enabled-1" }))
        #expect(!previews.contains(where: { $0.scheduleId == "disabled-1" }))
    }
    
    // MARK: - Recurrence Pattern Tests
    
    @Test("Daily recurrence generates preview for every day in range")
    func testDailyRecurrence() async throws {
        let startDate = date(year: 2025, month: 1, day: 1)
        let schedule = createTestSchedule(
            title: "Daily Schedule",
            recurrence: .daily,
            startDate: startDate
        )
        
        let store = try createTestStore(with: [schedule])
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let generator = ScheduleRunGenerator(scheduleStore: store)
        
        // Generate for 7-day range
        let rangeStart = date(year: 2025, month: 1, day: 1)
        let rangeEnd = date(year: 2025, month: 1, day: 7)
        let previews = generator.occurrences(in: rangeStart...rangeEnd)
        
        // Should have 7 previews (one for each day)
        let schedulePreviews = previews.filter { $0.scheduleId == schedule.id }
        #expect(schedulePreviews.count == 7)
    }
    
    @Test("Weekly recurrence generates previews only on specified weekdays")
    func testWeeklyRecurrence() async throws {
        // Create schedule for Monday, Wednesday, Friday
        let startDate = date(year: 2025, month: 1, day: 1) // Adjust to ensure it's before range
        let schedule = createTestSchedule(
            title: "Weekly Schedule",
            recurrence: .weekly(weekdays: [.monday, .wednesday, .friday]),
            startDate: startDate
        )
        
        let store = try createTestStore(with: [schedule])
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let generator = ScheduleRunGenerator(scheduleStore: store)
        
        // Generate for a week starting Monday, Jan 6, 2025
        let rangeStart = date(year: 2025, month: 1, day: 6) // Monday
        let rangeEnd = date(year: 2025, month: 1, day: 12) // Sunday
        let previews = generator.occurrences(in: rangeStart...rangeEnd)
        
        let schedulePreviews = previews.filter { $0.scheduleId == schedule.id }
        
        // Should have 3 previews (Mon, Wed, Fri)
        #expect(schedulePreviews.count == 3)
        
        // Verify the days are correct
        let calendar = Calendar.current
        for preview in schedulePreviews {
            let weekday = calendar.component(.weekday, from: preview.occurrenceDateTime)
            let day = Weekday(calendarWeekday: weekday)
            #expect(day == .monday || day == .wednesday || day == .friday)
        }
    }
    
    @Test("One-off recurrence generates exactly one preview on specified date")
    func testOneOffRecurrence() async throws {
        let oneOffDate = date(year: 2025, month: 1, day: 15)
        let schedule = createTestSchedule(
            title: "One-Off Schedule",
            recurrence: .none(oneOffDate: oneOffDate),
            startDate: oneOffDate
        )
        
        let store = try createTestStore(with: [schedule])
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let generator = ScheduleRunGenerator(scheduleStore: store)
        
        // Generate for a month range that includes the one-off date
        let rangeStart = date(year: 2025, month: 1, day: 1)
        let rangeEnd = date(year: 2025, month: 1, day: 31)
        let previews = generator.occurrences(in: rangeStart...rangeEnd)
        
        let schedulePreviews = previews.filter { $0.scheduleId == schedule.id }
        
        // Should have exactly 1 preview
        #expect(schedulePreviews.count == 1)
        
        // Verify it's on the correct date
        let calendar = Calendar.current
        let previewDate = schedulePreviews[0].occurrenceDateTime
        #expect(calendar.isDate(previewDate, inSameDayAs: oneOffDate))
    }
    
    @Test("One-off recurrence outside range generates no previews")
    func testOneOffRecurrenceOutsideRange() async throws {
        let oneOffDate = date(year: 2025, month: 2, day: 15)
        let schedule = createTestSchedule(
            title: "One-Off Schedule",
            recurrence: .none(oneOffDate: oneOffDate),
            startDate: oneOffDate
        )
        
        let store = try createTestStore(with: [schedule])
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let generator = ScheduleRunGenerator(scheduleStore: store)
        
        // Generate for January (one-off is in February)
        let rangeStart = date(year: 2025, month: 1, day: 1)
        let rangeEnd = date(year: 2025, month: 1, day: 31)
        let previews = generator.occurrences(in: rangeStart...rangeEnd)
        
        let schedulePreviews = previews.filter { $0.scheduleId == schedule.id }
        
        // Should have no previews
        #expect(schedulePreviews.isEmpty)
    }
    
    // MARK: - Date Boundary Tests
    
    @Test("Generator respects schedule start date")
    func testRespectsStartDate() async throws {
        let startDate = date(year: 2025, month: 1, day: 10)
        let schedule = createTestSchedule(
            title: "Future Start Schedule",
            recurrence: .daily,
            startDate: startDate
        )
        
        let store = try createTestStore(with: [schedule])
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let generator = ScheduleRunGenerator(scheduleStore: store)
        
        // Generate for range that starts before schedule start date
        let rangeStart = date(year: 2025, month: 1, day: 1)
        let rangeEnd = date(year: 2025, month: 1, day: 15)
        let previews = generator.occurrences(in: rangeStart...rangeEnd)
        
        let schedulePreviews = previews.filter { $0.scheduleId == schedule.id }
        
        // Should only have previews from Jan 10-15 (6 days)
        #expect(schedulePreviews.count == 6)
        
        // Verify all previews are on or after start date
        let calendar = Calendar.current
        for preview in schedulePreviews {
            let previewDay = calendar.startOfDay(for: preview.occurrenceDateTime)
            let scheduleStartDay = calendar.startOfDay(for: startDate)
            #expect(previewDay >= scheduleStartDay)
        }
    }
    
    @Test("Generator respects schedule end date")
    func testRespectsEndDate() async throws {
        let startDate = date(year: 2025, month: 1, day: 1)
        let endDate = date(year: 2025, month: 1, day: 10)
        let schedule = createTestSchedule(
            title: "Limited Duration Schedule",
            recurrence: .daily,
            startDate: startDate,
            endDate: endDate
        )
        
        let store = try createTestStore(with: [schedule])
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let generator = ScheduleRunGenerator(scheduleStore: store)
        
        // Generate for range that extends beyond schedule end date
        let rangeStart = date(year: 2025, month: 1, day: 1)
        let rangeEnd = date(year: 2025, month: 1, day: 20)
        let previews = generator.occurrences(in: rangeStart...rangeEnd)
        
        let schedulePreviews = previews.filter { $0.scheduleId == schedule.id }
        
        // Should only have previews from Jan 1-10 (10 days)
        #expect(schedulePreviews.count == 10)
        
        // Verify all previews are on or before end date
        let calendar = Calendar.current
        for preview in schedulePreviews {
            let previewDay = calendar.startOfDay(for: preview.occurrenceDateTime)
            let scheduleEndDay = calendar.startOfDay(for: endDate)
            #expect(previewDay <= scheduleEndDay)
        }
    }
    
    @Test("Generator handles schedule with start date after range")
    func testStartDateAfterRange() async throws {
        let startDate = date(year: 2025, month: 2, day: 1)
        let schedule = createTestSchedule(
            title: "Future Schedule",
            recurrence: .daily,
            startDate: startDate
        )
        
        let store = try createTestStore(with: [schedule])
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let generator = ScheduleRunGenerator(scheduleStore: store)
        
        // Generate for January (schedule starts in February)
        let rangeStart = date(year: 2025, month: 1, day: 1)
        let rangeEnd = date(year: 2025, month: 1, day: 31)
        let previews = generator.occurrences(in: rangeStart...rangeEnd)
        
        let schedulePreviews = previews.filter { $0.scheduleId == schedule.id }
        
        // Should have no previews
        #expect(schedulePreviews.isEmpty)
    }
    
    @Test("Generator handles schedule with end date before range")
    func testEndDateBeforeRange() async throws {
        let startDate = date(year: 2024, month: 12, day: 1)
        let endDate = date(year: 2024, month: 12, day: 31)
        let schedule = createTestSchedule(
            title: "Past Schedule",
            recurrence: .daily,
            startDate: startDate,
            endDate: endDate
        )
        
        let store = try createTestStore(with: [schedule])
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let generator = ScheduleRunGenerator(scheduleStore: store)
        
        // Generate for January 2025 (schedule ended in December 2024)
        let rangeStart = date(year: 2025, month: 1, day: 1)
        let rangeEnd = date(year: 2025, month: 1, day: 31)
        let previews = generator.occurrences(in: rangeStart...rangeEnd)
        
        let schedulePreviews = previews.filter { $0.scheduleId == schedule.id }
        
        // Should have no previews
        #expect(schedulePreviews.isEmpty)
    }
    
    // MARK: - Time Combination Tests
    
    @Test("Preview combines date and time correctly")
    func testTimeCombination() async throws {
        let startDate = date(year: 2025, month: 1, day: 1)
        let schedule = createTestSchedule(
            title: "Morning Schedule",
            hour: 8,
            minute: 30,
            recurrence: .daily,
            startDate: startDate
        )
        
        let store = try createTestStore(with: [schedule])
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let generator = ScheduleRunGenerator(scheduleStore: store)
        
        let testDate = date(year: 2025, month: 1, day: 15)
        let previews = generator.occurrences(on: testDate)
        
        let schedulePreviews = previews.filter { $0.scheduleId == schedule.id }
        #expect(schedulePreviews.count == 1)
        
        let preview = schedulePreviews[0]
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: preview.occurrenceDateTime)
        
        // Verify date components
        #expect(components.year == 2025)
        #expect(components.month == 1)
        #expect(components.day == 15)
        
        // Verify time components
        #expect(components.hour == 8)
        #expect(components.minute == 30)
    }
    
    @Test("Preview preserves schedule time across different dates")
    func testTimePreservationAcrossDates() async throws {
        let startDate = date(year: 2025, month: 1, day: 1)
        let schedule = createTestSchedule(
            title: "Consistent Time Schedule",
            hour: 14,
            minute: 45,
            recurrence: .daily,
            startDate: startDate
        )
        
        let store = try createTestStore(with: [schedule])
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let generator = ScheduleRunGenerator(scheduleStore: store)
        
        // Generate for multiple days
        let rangeStart = date(year: 2025, month: 1, day: 1)
        let rangeEnd = date(year: 2025, month: 1, day: 5)
        let previews = generator.occurrences(in: rangeStart...rangeEnd)
        
        let schedulePreviews = previews.filter { $0.scheduleId == schedule.id }
        #expect(schedulePreviews.count == 5)
        
        // Verify all previews have the same time
        let calendar = Calendar.current
        for preview in schedulePreviews {
            let components = calendar.dateComponents([.hour, .minute], from: preview.occurrenceDateTime)
            #expect(components.hour == 14)
            #expect(components.minute == 45)
        }
    }
    
    // MARK: - Date-Specific Occurrence Tests
    
    @Test("occurrences(on:) returns only previews for specified date")
    func testDateSpecificOccurrences() async throws {
        let startDate = date(year: 2025, month: 1, day: 1)
        let schedule = createTestSchedule(
            title: "Daily Schedule",
            recurrence: .daily,
            startDate: startDate
        )
        
        let store = try createTestStore(with: [schedule])
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let generator = ScheduleRunGenerator(scheduleStore: store)
        
        let testDate = date(year: 2025, month: 1, day: 15)
        let previews = generator.occurrences(on: testDate)
        
        // Should have exactly one preview for this date
        let schedulePreviews = previews.filter { $0.scheduleId == schedule.id }
        #expect(schedulePreviews.count == 1)
        
        // Verify it's on the correct date
        let calendar = Calendar.current
        #expect(calendar.isDate(schedulePreviews[0].occurrenceDateTime, inSameDayAs: testDate))
    }
    
    @Test("occurrences(on:) returns empty for date with no schedules")
    func testDateSpecificOccurrencesEmpty() async throws {
        // Create schedule for weekdays only
        let startDate = date(year: 2025, month: 1, day: 1)
        let schedule = createTestSchedule(
            title: "Weekday Schedule",
            recurrence: .weekly(weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday]),
            startDate: startDate
        )
        
        let store = try createTestStore(with: [schedule])
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let generator = ScheduleRunGenerator(scheduleStore: store)
        
        // Test on a Saturday (Jan 4, 2025)
        let saturday = date(year: 2025, month: 1, day: 4)
        let previews = generator.occurrences(on: saturday)
        
        let schedulePreviews = previews.filter { $0.scheduleId == schedule.id }
        #expect(schedulePreviews.isEmpty)
    }
    
    // MARK: - Date Range Occurrence Tests
    
    @Test("occurrences(in:) returns all previews within range")
    func testDateRangeOccurrences() async throws {
        let startDate = date(year: 2025, month: 1, day: 1)
        let schedule = createTestSchedule(
            title: "Daily Schedule",
            recurrence: .daily,
            startDate: startDate
        )
        
        let store = try createTestStore(with: [schedule])
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let generator = ScheduleRunGenerator(scheduleStore: store)
        
        let rangeStart = date(year: 2025, month: 1, day: 10)
        let rangeEnd = date(year: 2025, month: 1, day: 20)
        let previews = generator.occurrences(in: rangeStart...rangeEnd)
        
        let schedulePreviews = previews.filter { $0.scheduleId == schedule.id }
        
        // Should have 11 previews (Jan 10-20 inclusive)
        #expect(schedulePreviews.count == 11)
        
        // Verify all are within range
        let calendar = Calendar.current
        for preview in schedulePreviews {
            let previewDay = calendar.startOfDay(for: preview.occurrenceDateTime)
            let rangeStartDay = calendar.startOfDay(for: rangeStart)
            let rangeEndDay = calendar.startOfDay(for: rangeEnd)
            #expect(previewDay >= rangeStartDay)
            #expect(previewDay <= rangeEndDay)
        }
    }
    
    @Test("occurrences(in:) handles multiple schedules")
    func testDateRangeMultipleSchedules() async throws {
        let startDate = date(year: 2025, month: 1, day: 1)
        
        let schedule1 = createTestSchedule(
            id: "schedule-1",
            title: "Morning Schedule",
            hour: 8,
            minute: 0,
            recurrence: .daily,
            startDate: startDate
        )
        
        let schedule2 = createTestSchedule(
            id: "schedule-2",
            title: "Afternoon Schedule",
            hour: 14,
            minute: 0,
            recurrence: .daily,
            startDate: startDate
        )
        
        let store = try createTestStore(with: [schedule1, schedule2])
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let generator = ScheduleRunGenerator(scheduleStore: store)
        
        let rangeStart = date(year: 2025, month: 1, day: 1)
        let rangeEnd = date(year: 2025, month: 1, day: 5)
        let previews = generator.occurrences(in: rangeStart...rangeEnd)
        
        // Should have 10 previews total (5 days × 2 schedules)
        #expect(previews.count == 10)
        
        // Verify both schedules are represented
        let schedule1Previews = previews.filter { $0.scheduleId == "schedule-1" }
        let schedule2Previews = previews.filter { $0.scheduleId == "schedule-2" }
        #expect(schedule1Previews.count == 5)
        #expect(schedule2Previews.count == 5)
    }
    
    // MARK: - Preview Data Tests
    
    @Test("Preview contains all schedule data")
    func testPreviewContainsScheduleData() async throws {
        let startDate = date(year: 2025, month: 1, day: 1)
        let schedule = createTestSchedule(
            id: "test-schedule-id",
            title: "Test Schedule",
            hour: 9,
            minute: 15,
            recurrence: .daily,
            startDate: startDate
        )
        
        let store = try createTestStore(with: [schedule])
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let generator = ScheduleRunGenerator(scheduleStore: store)
        
        let testDate = date(year: 2025, month: 1, day: 15)
        let previews = generator.occurrences(on: testDate)
        
        #expect(previews.count == 1)
        let preview = previews[0]
        
        // Verify preview data matches schedule
        #expect(preview.scheduleId == "test-schedule-id")
        #expect(preview.title == "Test Schedule")
        #expect(preview.driverUserId == "demo-tafadzwa")
        #expect(preview.passengerUserIds == ["demo-tj", "demo-tawana"])
        #expect(preview.stops.count == 2)
        #expect(preview.source == .schedule)
    }
    
    @Test("Preview ID is unique for same schedule on different dates")
    func testPreviewIdUniqueness() async throws {
        let startDate = date(year: 2025, month: 1, day: 1)
        let schedule = createTestSchedule(
            id: "same-schedule",
            title: "Daily Schedule",
            recurrence: .daily,
            startDate: startDate
        )
        
        let store = try createTestStore(with: [schedule])
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let generator = ScheduleRunGenerator(scheduleStore: store)
        
        let date1 = date(year: 2025, month: 1, day: 10)
        let date2 = date(year: 2025, month: 1, day: 11)
        
        let previews1 = generator.occurrences(on: date1)
        let previews2 = generator.occurrences(on: date2)
        
        #expect(previews1.count == 1)
        #expect(previews2.count == 1)
        
        // IDs should be different
        #expect(previews1[0].id != previews2[0].id)
        
        // IDs should contain schedule ID and date
        #expect(previews1[0].id.contains("same-schedule"))
        #expect(previews2[0].id.contains("same-schedule"))
    }
    
    @Test("Preview source is always .schedule")
    func testPreviewSourceIsSchedule() async throws {
        let startDate = date(year: 2025, month: 1, day: 1)
        let schedule = createTestSchedule(
            recurrence: .daily,
            startDate: startDate
        )
        
        let store = try createTestStore(with: [schedule])
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let generator = ScheduleRunGenerator(scheduleStore: store)
        
        let rangeStart = date(year: 2025, month: 1, day: 1)
        let rangeEnd = date(year: 2025, month: 1, day: 10)
        let previews = generator.occurrences(in: rangeStart...rangeEnd)
        
        // All previews should have source = .schedule
        for preview in previews {
            #expect(preview.source == .schedule)
        }
    }
}
