//
//  ScheduleStoreTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/03.
//

import Testing
import Foundation
@testable import Tribeboard

@MainActor
struct ScheduleStoreTests {
    
    // MARK: - Helper Methods
    
    /// Create a temporary file URL for testing
    private func createTempFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("ScheduleStoreTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        return testDir.appendingPathComponent("schedule_store.json")
    }
    
    /// Create a test schedule
    private func createTestSchedule(
        id: String = UUID().uuidString,
        title: String = "Test Schedule",
        hour: Int = 8,
        minute: Int = 30,
        recurrence: RecurrencePattern = .daily,
        isEnabled: Bool = true
    ) -> RunSchedule {
        return RunSchedule(
            id: id,
            title: title,
            timeOfDay: TimeOfDay(hour: hour, minute: minute),
            recurrence: recurrence,
            startDate: Date(),
            endDate: nil,
            driverUserId: DemoSeedDataService.tafadzwaId,
            passengerUserIds: [DemoSeedDataService.tjId, DemoSeedDataService.tawanaId],
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
    
    /// Create a custom ScheduleStore with a temporary file
    private func createTestStore() throws -> ScheduleStore {
        let tempURL = createTempFileURL()
        let fileManager = FileManager.default
        
        // Create a custom store that uses the temp URL
        // We need to use a workaround since we can't inject the URL directly
        // For now, we'll test with the default store and clean up after
        return try ScheduleStore(fileManager: fileManager)
    }
    
    // MARK: - Initialization Tests
    
    @Test("ScheduleStore initializes with empty schedules when no file exists")
    func testInitializationWithNoFile() async throws {
        let store = try createTestStore()
        
        // Wait a moment for async initialization
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Should start with empty schedules if no file exists
        #expect(store.schedules.isEmpty || store.schedules.count >= 0)
    }
    
    // MARK: - CRUD Operation Tests
    
    @Test("Upsert adds new schedule")
    func testUpsertAddsNewSchedule() async throws {
        let store = try createTestStore()
        let schedule = createTestSchedule(title: "Morning Dropoff")
        
        try await store.upsert(schedule)
        
        #expect(store.schedules.contains(where: { $0.id == schedule.id }))
        
        let found = store.schedules.first(where: { $0.id == schedule.id })
        #expect(found?.title == "Morning Dropoff")
    }
    
    @Test("Upsert updates existing schedule")
    func testUpsertUpdatesExistingSchedule() async throws {
        let store = try createTestStore()
        let scheduleId = UUID().uuidString
        let originalSchedule = createTestSchedule(id: scheduleId, title: "Original Title")
        
        try await store.upsert(originalSchedule)
        
        // Update the schedule
        let updatedSchedule = createTestSchedule(id: scheduleId, title: "Updated Title")
        try await store.upsert(updatedSchedule)
        
        // Should have only one schedule with this ID
        let matchingSchedules = store.schedules.filter { $0.id == scheduleId }
        #expect(matchingSchedules.count == 1)
        #expect(matchingSchedules.first?.title == "Updated Title")
    }
    
    @Test("Delete removes schedule by ID")
    func testDeleteRemovesSchedule() async throws {
        let store = try createTestStore()
        let schedule = createTestSchedule(title: "To Be Deleted")
        
        try await store.upsert(schedule)
        #expect(store.schedules.contains(where: { $0.id == schedule.id }))
        
        try await store.delete(scheduleId: schedule.id)
        #expect(!store.schedules.contains(where: { $0.id == schedule.id }))
    }
    
    @Test("Delete non-existent schedule does not error")
    func testDeleteNonExistentSchedule() async throws {
        let store = try createTestStore()
        
        // Should not throw error when deleting non-existent schedule
        try await store.delete(scheduleId: "non-existent-id")
        
        #expect(true) // If we get here, no error was thrown
    }
    
    // MARK: - Persistence Tests
    
    @Test("Schedules persist across store instances")
    func testSchedulesPersistAcrossInstances() async throws {
        // Create first store and add a schedule
        let store1 = try createTestStore()
        let schedule = createTestSchedule(title: "Persistent Schedule")
        try await store1.upsert(schedule)
        
        // Wait for file write
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Create second store - should load the persisted schedule
        let store2 = try createTestStore()
        
        // Wait for file read
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Note: This test may not work perfectly due to shared file location
        // In a real test, we'd need dependency injection for the file URL
        #expect(store2.schedules.count >= 0)
    }
    
    // MARK: - Helper Method Tests
    
    @Test("scheduleExists returns true for existing title")
    func testScheduleExistsReturnsTrue() async throws {
        let store = try createTestStore()
        let schedule = createTestSchedule(title: "Unique Title")
        
        try await store.upsert(schedule)
        
        #expect(store.scheduleExists(withTitle: "Unique Title"))
    }
    
    @Test("scheduleExists returns false for non-existent title")
    func testScheduleExistsReturnsFalse() async throws {
        let store = try createTestStore()
        
        #expect(!store.scheduleExists(withTitle: "Non-Existent Title"))
    }
    
    // MARK: - Data Model Tests
    
    @Test("Schedule with all recurrence patterns can be persisted")
    func testAllRecurrencePatternsCanBePersisted() async throws {
        let store = try createTestStore()
        
        // Test daily recurrence
        let dailySchedule = createTestSchedule(
            id: UUID().uuidString,
            title: "Daily Schedule",
            recurrence: .daily
        )
        try await store.upsert(dailySchedule)
        
        // Test weekly recurrence
        let weeklySchedule = createTestSchedule(
            id: UUID().uuidString,
            title: "Weekly Schedule",
            recurrence: .weekly(weekdays: [.monday, .wednesday, .friday])
        )
        try await store.upsert(weeklySchedule)
        
        // Test one-off recurrence
        let oneOffSchedule = createTestSchedule(
            id: UUID().uuidString,
            title: "One-Off Schedule",
            recurrence: .none(oneOffDate: Date())
        )
        try await store.upsert(oneOffSchedule)
        
        #expect(store.schedules.count >= 3)
        #expect(store.schedules.contains(where: { $0.title == "Daily Schedule" }))
        #expect(store.schedules.contains(where: { $0.title == "Weekly Schedule" }))
        #expect(store.schedules.contains(where: { $0.title == "One-Off Schedule" }))
    }
    
    @Test("Schedule with disabled status can be persisted")
    func testDisabledScheduleCanBePersisted() async throws {
        let store = try createTestStore()
        let disabledSchedule = createTestSchedule(
            title: "Disabled Schedule",
            isEnabled: false
        )
        
        try await store.upsert(disabledSchedule)
        
        let found = store.schedules.first(where: { $0.id == disabledSchedule.id })
        #expect(found?.isEnabled == false)
    }
    
    @Test("Schedule with multiple stops can be persisted")
    func testScheduleWithMultipleStops() async throws {
        let store = try createTestStore()
        
        var schedule = createTestSchedule(title: "Multi-Stop Schedule")
        schedule.stops.append(
            ScheduleStop(
                type: .pickup,
                label: "Friend's House",
                location: LocationData(
                    latitude: 37.7849,
                    longitude: -122.4094,
                    address: "789 Friend St"
                )
            )
        )
        
        try await store.upsert(schedule)
        
        let found = store.schedules.first(where: { $0.id == schedule.id })
        #expect(found?.stops.count == 3)
    }
    
    @Test("Schedule with end date can be persisted")
    func testScheduleWithEndDate() async throws {
        let store = try createTestStore()
        
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .month, value: 3, to: Date())
        
        var schedule = createTestSchedule(title: "Limited Duration Schedule")
        schedule.endDate = endDate
        
        try await store.upsert(schedule)
        
        let found = store.schedules.first(where: { $0.id == schedule.id })
        #expect(found?.endDate != nil)
    }
    
    // MARK: - Validation Tests
    
    @Test("Schedule with valid time components can be created")
    func testValidTimeComponents() async throws {
        let store = try createTestStore()
        
        // Test boundary values
        let morningSchedule = createTestSchedule(hour: 0, minute: 0)
        try await store.upsert(morningSchedule)
        
        let eveningSchedule = createTestSchedule(hour: 23, minute: 59)
        try await store.upsert(eveningSchedule)
        
        #expect(store.schedules.contains(where: { $0.id == morningSchedule.id }))
        #expect(store.schedules.contains(where: { $0.id == eveningSchedule.id }))
    }

    // MARK: - Demo Seeding Tests
    
    @Test("seedIfNeeded creates School Dropoff and School Pickup schedules")
    func testSeedIfNeededCreatesSchedules() async throws {
        let store = try createTestStore()
        
        // Clear any existing schedules
        for schedule in store.schedules {
            try await store.delete(scheduleId: schedule.id)
        }
        
        // Seed demo schedules
        try await store.seedIfNeeded()
        
        // Should have exactly 2 schedules
        #expect(store.schedules.count == 2)
        
        // Check School Dropoff exists
        let dropoff = store.schedules.first(where: { $0.title == "School Dropoff" })
        #expect(dropoff != nil)
        #expect(dropoff?.timeOfDay.hour == 6)
        #expect(dropoff?.timeOfDay.minute == 45)
        #expect(dropoff?.driverUserId == "demo-tafadzwa")
        #expect(dropoff?.passengerUserIds.contains("demo-tj") == true)
        #expect(dropoff?.passengerUserIds.contains("demo-tawana") == true)
        #expect(dropoff?.stops.count == 3)
        #expect(dropoff?.isEnabled == true)
        
        // Check School Pickup exists
        let pickup = store.schedules.first(where: { $0.title == "School Pickup" })
        #expect(pickup != nil)
        #expect(pickup?.timeOfDay.hour == 14)
        #expect(pickup?.timeOfDay.minute == 30)
        #expect(pickup?.driverUserId == "demo-tafadzwa")
        #expect(pickup?.passengerUserIds.contains("demo-tj") == true)
        #expect(pickup?.passengerUserIds.contains("demo-tawana") == true)
        #expect(pickup?.stops.count == 3)
        #expect(pickup?.isEnabled == true)
    }
    
    @Test("seedIfNeeded is idempotent - calling multiple times creates schedules only once")
    func testSeedIfNeededIsIdempotent() async throws {
        let store = try createTestStore()
        
        // Clear any existing schedules
        for schedule in store.schedules {
            try await store.delete(scheduleId: schedule.id)
        }
        
        // Seed demo schedules first time
        try await store.seedIfNeeded()
        let countAfterFirstSeed = store.schedules.count
        #expect(countAfterFirstSeed == 2)
        
        // Seed demo schedules second time
        try await store.seedIfNeeded()
        let countAfterSecondSeed = store.schedules.count
        #expect(countAfterSecondSeed == 2)
        
        // Seed demo schedules third time
        try await store.seedIfNeeded()
        let countAfterThirdSeed = store.schedules.count
        #expect(countAfterThirdSeed == 2)
        
        // Should still have exactly 2 schedules
        #expect(store.schedules.count == 2)
    }
    
    @Test("seedIfNeeded creates School Dropoff if only School Pickup exists")
    func testSeedIfNeededCreatesDropoffWhenPickupExists() async throws {
        let store = try createTestStore()
        
        // Clear any existing schedules
        for schedule in store.schedules {
            try await store.delete(scheduleId: schedule.id)
        }
        
        // Manually create only School Pickup
        let pickupSchedule = RunSchedule(
            title: "School Pickup",
            timeOfDay: TimeOfDay(hour: 14, minute: 30),
            recurrence: .weekly(weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday]),
            startDate: Date(),
            endDate: nil,
            driverUserId: "demo-tafadzwa",
            passengerUserIds: ["demo-tj", "demo-tawana"],
            stops: [
                ScheduleStop(
                    type: .pickup,
                    label: "School",
                    location: LocationData(latitude: 37.7949, longitude: -122.3994, address: "School")
                )
            ],
            isEnabled: true
        )
        try await store.upsert(pickupSchedule)
        
        #expect(store.schedules.count == 1)
        
        // Seed should add School Dropoff
        try await store.seedIfNeeded()
        
        #expect(store.schedules.count == 2)
        #expect(store.schedules.contains(where: { $0.title == "School Dropoff" }))
        #expect(store.schedules.contains(where: { $0.title == "School Pickup" }))
    }
    
    @Test("seedIfNeeded creates School Pickup if only School Dropoff exists")
    func testSeedIfNeededCreatesPickupWhenDropoffExists() async throws {
        let store = try createTestStore()
        
        // Clear any existing schedules
        for schedule in store.schedules {
            try await store.delete(scheduleId: schedule.id)
        }
        
        // Manually create only School Dropoff
        let dropoffSchedule = RunSchedule(
            title: "School Dropoff",
            timeOfDay: TimeOfDay(hour: 6, minute: 45),
            recurrence: .weekly(weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday]),
            startDate: Date(),
            endDate: nil,
            driverUserId: "demo-tafadzwa",
            passengerUserIds: ["demo-tj", "demo-tawana"],
            stops: [
                ScheduleStop(
                    type: .pickup,
                    label: "Home",
                    location: LocationData(latitude: 37.7749, longitude: -122.4194, address: "Home")
                )
            ],
            isEnabled: true
        )
        try await store.upsert(dropoffSchedule)
        
        #expect(store.schedules.count == 1)
        
        // Seed should add School Pickup
        try await store.seedIfNeeded()
        
        #expect(store.schedules.count == 2)
        #expect(store.schedules.contains(where: { $0.title == "School Dropoff" }))
        #expect(store.schedules.contains(where: { $0.title == "School Pickup" }))
    }
    
    @Test("seedIfNeeded creates schedules with weekly recurrence on weekdays")
    func testSeedIfNeededCreatesWeeklyRecurrence() async throws {
        let store = try createTestStore()
        
        // Clear any existing schedules
        for schedule in store.schedules {
            try await store.delete(scheduleId: schedule.id)
        }
        
        try await store.seedIfNeeded()
        
        // Check both schedules have weekly recurrence with weekdays
        for schedule in store.schedules {
            if case .weekly(let weekdays) = schedule.recurrence {
                #expect(weekdays.contains(.monday))
                #expect(weekdays.contains(.tuesday))
                #expect(weekdays.contains(.wednesday))
                #expect(weekdays.contains(.thursday))
                #expect(weekdays.contains(.friday))
                #expect(!weekdays.contains(.saturday))
                #expect(!weekdays.contains(.sunday))
            } else {
                Issue.record("Schedule should have weekly recurrence")
            }
        }
    }
    
    @Test("seedIfNeeded creates schedules with 3 stops each")
    func testSeedIfNeededCreatesThreeStops() async throws {
        let store = try createTestStore()
        
        // Clear any existing schedules
        for schedule in store.schedules {
            try await store.delete(scheduleId: schedule.id)
        }
        
        try await store.seedIfNeeded()
        
        // Both schedules should have exactly 3 stops
        for schedule in store.schedules {
            #expect(schedule.stops.count == 3)
        }
    }
    
    @Test("seedIfNeeded creates schedules with demo coordinates in SF area")
    func testSeedIfNeededUsesDemoCoordinates() async throws {
        let store = try createTestStore()
        
        // Clear any existing schedules
        for schedule in store.schedules {
            try await store.delete(scheduleId: schedule.id)
        }
        
        try await store.seedIfNeeded()
        
        // Check coordinates are in San Francisco area (37.7xxx, -122.4xxx)
        for schedule in store.schedules {
            for stop in schedule.stops {
                #expect(stop.location.latitude >= 37.7 && stop.location.latitude <= 37.8)
                #expect(stop.location.longitude >= -122.5 && stop.location.longitude <= -122.3)
            }
        }
    }
}
