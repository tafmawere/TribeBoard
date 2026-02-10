//
//  DemoSeedDataServiceIntegrationTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/05.
//

import Testing
import Foundation
@testable import Tribeboard

@MainActor
struct DemoSeedDataServiceIntegrationTests {
    
    // MARK: - Helper Methods
    
    /// Create a test DemoSeedDataService with dependencies
    private func createTestService() throws -> (service: DemoSeedDataService, scheduleStore: ScheduleStore) {
        let firebaseService = MockFirebaseRunService()
        let scheduleStore = try ScheduleStore()
        let service = DemoSeedDataService(firebaseService: firebaseService, scheduleStore: scheduleStore)
        return (service, scheduleStore)
    }
    
    // MARK: - Integration Tests
    
    @Test("DemoSeedDataService seeds schedules when seedIfNeeded is called")
    func testSeedIfNeededCreatesSchedules() async throws {
        let (service, scheduleStore) = try createTestService()
        
        // Clear any existing schedules
        for schedule in scheduleStore.schedules {
            try await scheduleStore.delete(scheduleId: schedule.id)
        }
        
        // Verify schedules are empty
        #expect(scheduleStore.schedules.isEmpty)
        
        // Call seedIfNeeded
        await service.seedIfNeeded()
        
        // Wait a moment for async operations
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Verify schedules were created
        #expect(scheduleStore.schedules.count >= 2)
        
        // Verify School Dropoff schedule exists
        let dropoffSchedule = scheduleStore.schedules.first { $0.title == "School Dropoff" }
        #expect(dropoffSchedule != nil)
        if let dropoff = dropoffSchedule {
            #expect(dropoff.timeOfDay.hour == 6)
            #expect(dropoff.timeOfDay.minute == 45)
            #expect(dropoff.driverUserId == DemoSeedDataService.tafadzwaId)
            #expect(dropoff.passengerUserIds.contains(DemoSeedDataService.tjId))
            #expect(dropoff.passengerUserIds.contains(DemoSeedDataService.tawanaId))
        }
        
        // Verify School Pickup schedule exists
        let pickupSchedule = scheduleStore.schedules.first { $0.title == "School Pickup" }
        #expect(pickupSchedule != nil)
        if let pickup = pickupSchedule {
            #expect(pickup.timeOfDay.hour == 14)
            #expect(pickup.timeOfDay.minute == 30)
            #expect(pickup.driverUserId == DemoSeedDataService.tafadzwaId)
            #expect(pickup.passengerUserIds.contains(DemoSeedDataService.tjId))
            #expect(pickup.passengerUserIds.contains(DemoSeedDataService.tawanaId))
        }
    }
    
    @Test("DemoSeedDataService seedIfNeeded is idempotent")
    func testSeedIfNeededIsIdempotent() async throws {
        let (service, scheduleStore) = try createTestService()
        
        // Clear any existing schedules
        for schedule in scheduleStore.schedules {
            try await scheduleStore.delete(scheduleId: schedule.id)
        }
        
        // Call seedIfNeeded twice
        await service.seedIfNeeded()
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        let countAfterFirstSeed = scheduleStore.schedules.count
        
        await service.seedIfNeeded()
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        let countAfterSecondSeed = scheduleStore.schedules.count
        
        // Count should remain the same (idempotent)
        #expect(countAfterFirstSeed == countAfterSecondSeed)
    }
    
    @Test("DemoSeedDataService seedDemoFamily seeds schedules")
    func testSeedDemoFamilyCreatesSchedules() async throws {
        let (service, scheduleStore) = try createTestService()
        
        // Clear any existing schedules
        for schedule in scheduleStore.schedules {
            try await scheduleStore.delete(scheduleId: schedule.id)
        }
        
        // Verify schedules are empty
        #expect(scheduleStore.schedules.isEmpty)
        
        // Call seedDemoFamily
        await service.seedDemoFamily()
        
        // Wait a moment for async operations
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Verify schedules were created
        #expect(scheduleStore.schedules.count >= 2)
        
        // Verify both demo schedules exist
        let hasDropoff = scheduleStore.schedules.contains { $0.title == "School Dropoff" }
        let hasPickup = scheduleStore.schedules.contains { $0.title == "School Pickup" }
        
        #expect(hasDropoff)
        #expect(hasPickup)
    }
}
