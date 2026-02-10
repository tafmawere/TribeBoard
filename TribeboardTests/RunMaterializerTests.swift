//
//  RunMaterializerTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/03.
//

import Testing
import Foundation
@testable import Tribeboard

@MainActor
struct RunMaterializerTests {
    
    // MARK: - Helper Methods
    
    /// Create a test preview
    private func createTestPreview(
        scheduleId: String = UUID().uuidString,
        title: String = "School Dropoff",
        occurrenceDateTime: Date = Date().addingTimeInterval(3600), // 1 hour from now
        driverUserId: String = DemoSeedDataService.tafadzwaId,
        passengerUserIds: [String] = [DemoSeedDataService.tjId, DemoSeedDataService.tawanaId]
    ) -> ScheduledRunPreview {
        return ScheduledRunPreview(
            scheduleId: scheduleId,
            title: title,
            occurrenceDateTime: occurrenceDateTime,
            driverUserId: driverUserId,
            passengerUserIds: passengerUserIds,
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
            source: .schedule
        )
    }
    
    /// Create test dependencies
    private func createTestDependencies() -> (MockFirebaseRunService, RoleContext) {
        let firebaseService = MockFirebaseRunService()
        let roleContext = RoleContext(
            userId: DemoSeedDataService.rueId,
            role: .admin,
            familyId: DemoSeedDataService.demoFamilyId
        )
        return (firebaseService, roleContext)
    }
    
    // MARK: - Materialization Tests
    
    @Test("Materialize creates new run from preview")
    func testMaterializeCreatesNewRun() async throws {
        let (firebaseService, roleContext) = createTestDependencies()
        let materializer = RunMaterializer(firebaseService: firebaseService, roleContext: roleContext)
        
        let preview = createTestPreview(title: "Test Run")
        
        let run = try await materializer.materialize(preview)
        
        // Verify run was created with correct data
        #expect(run.title == preview.title)
        #expect(run.scheduledTime == preview.occurrenceDateTime)
        #expect(run.driverId == preview.driverUserId)
        #expect(run.status == .scheduled)
        #expect(run.stops.count == preview.stops.count)
        #expect(run.passengers.count == preview.passengerUserIds.count)
        #expect(run.familyId == roleContext.familyId)
        #expect(run.createdBy == roleContext.userId)
    }
    
    @Test("Materialize returns existing run when duplicate exists")
    func testMaterializeReturnsDuplicateRun() async throws {
        let (firebaseService, roleContext) = createTestDependencies()
        let materializer = RunMaterializer(firebaseService: firebaseService, roleContext: roleContext)
        
        let preview = createTestPreview(title: "Duplicate Test")
        
        // Create first run
        let firstRun = try await materializer.materialize(preview)
        
        // Try to materialize again with same preview
        let secondRun = try await materializer.materialize(preview)
        
        // Should return the same run (by ID)
        #expect(firstRun.id == secondRun.id)
    }
    
    @Test("Materialize detects duplicate within 5 minute window")
    func testMaterializeDetectsDuplicateWithinTimeWindow() async throws {
        let (firebaseService, roleContext) = createTestDependencies()
        let materializer = RunMaterializer(firebaseService: firebaseService, roleContext: roleContext)
        
        let baseTime = Date().addingTimeInterval(3600) // 1 hour from now
        let preview1 = createTestPreview(title: "Time Window Test", occurrenceDateTime: baseTime)
        
        // Create first run
        let firstRun = try await materializer.materialize(preview1)
        
        // Create preview with time 4 minutes later (within ±5 min window)
        let preview2 = createTestPreview(
            title: "Time Window Test",
            occurrenceDateTime: baseTime.addingTimeInterval(4 * 60)
        )
        
        // Should return existing run
        let secondRun = try await materializer.materialize(preview2)
        #expect(firstRun.id == secondRun.id)
    }
    
    @Test("Materialize creates new run when time difference exceeds 5 minutes")
    func testMaterializeCreatesNewRunOutsideTimeWindow() async throws {
        let (firebaseService, roleContext) = createTestDependencies()
        let materializer = RunMaterializer(firebaseService: firebaseService, roleContext: roleContext)
        
        let baseTime = Date().addingTimeInterval(3600) // 1 hour from now
        let preview1 = createTestPreview(title: "Time Window Test", occurrenceDateTime: baseTime)
        
        // Create first run
        let firstRun = try await materializer.materialize(preview1)
        
        // Create preview with time 6 minutes later (outside ±5 min window)
        let preview2 = createTestPreview(
            title: "Time Window Test",
            occurrenceDateTime: baseTime.addingTimeInterval(6 * 60)
        )
        
        // Should create new run
        let secondRun = try await materializer.materialize(preview2)
        #expect(firstRun.id != secondRun.id)
    }
    
    @Test("Materialize creates new run when driver is different")
    func testMaterializeCreatesNewRunWithDifferentDriver() async throws {
        let (firebaseService, roleContext) = createTestDependencies()
        let materializer = RunMaterializer(firebaseService: firebaseService, roleContext: roleContext)
        
        let preview1 = createTestPreview(
            title: "Driver Test",
            driverUserId: DemoSeedDataService.tafadzwaId
        )
        
        // Create first run
        let firstRun = try await materializer.materialize(preview1)
        
        // Create preview with different driver
        let preview2 = createTestPreview(
            title: "Driver Test",
            driverUserId: DemoSeedDataService.rueId
        )
        
        // Should create new run (different driver)
        let secondRun = try await materializer.materialize(preview2)
        #expect(firstRun.id != secondRun.id)
    }
    
    @Test("Materialize creates new run when title is different")
    func testMaterializeCreatesNewRunWithDifferentTitle() async throws {
        let (firebaseService, roleContext) = createTestDependencies()
        let materializer = RunMaterializer(firebaseService: firebaseService, roleContext: roleContext)
        
        let preview1 = createTestPreview(title: "Morning Dropoff")
        
        // Create first run
        let firstRun = try await materializer.materialize(preview1)
        
        // Create preview with different title
        let preview2 = createTestPreview(title: "Afternoon Pickup")
        
        // Should create new run (different title)
        let secondRun = try await materializer.materialize(preview2)
        #expect(firstRun.id != secondRun.id)
    }
    
    @Test("Materialize maps stops correctly")
    func testMaterializeMapsStopsCorrectly() async throws {
        let (firebaseService, roleContext) = createTestDependencies()
        let materializer = RunMaterializer(firebaseService: firebaseService, roleContext: roleContext)
        
        let preview = createTestPreview()
        let run = try await materializer.materialize(preview)
        
        // Verify stops are mapped correctly
        #expect(run.stops.count == preview.stops.count)
        
        for (index, stop) in run.stops.enumerated() {
            let scheduleStop = preview.stops[index]
            #expect(stop.type == scheduleStop.type)
            #expect(stop.label == scheduleStop.label)
            #expect(stop.location.latitude == scheduleStop.location.latitude)
            #expect(stop.location.longitude == scheduleStop.location.longitude)
            #expect(stop.notes == scheduleStop.notes)
        }
    }
    
    @Test("Materialize maps passengers with correct display names")
    func testMaterializeMapsPassengersWithDisplayNames() async throws {
        let (firebaseService, roleContext) = createTestDependencies()
        let materializer = RunMaterializer(firebaseService: firebaseService, roleContext: roleContext)
        
        let preview = createTestPreview(
            passengerUserIds: [DemoSeedDataService.tjId, DemoSeedDataService.tawanaId]
        )
        let run = try await materializer.materialize(preview)
        
        // Verify passengers are mapped with correct display names
        #expect(run.passengers.count == 2)
        #expect(run.passengers[0].id == DemoSeedDataService.tjId)
        #expect(run.passengers[0].displayName == "TJ")
        #expect(run.passengers[1].id == DemoSeedDataService.tawanaId)
        #expect(run.passengers[1].displayName == "Tawana")
    }
    
    @Test("Materialize sets all passengers to waiting status")
    func testMaterializeSetsPassengersToWaitingStatus() async throws {
        let (firebaseService, roleContext) = createTestDependencies()
        let materializer = RunMaterializer(firebaseService: firebaseService, roleContext: roleContext)
        
        let preview = createTestPreview()
        let run = try await materializer.materialize(preview)
        
        // Verify all passengers start with waiting status
        for passenger in run.passengers {
            #expect(passenger.status == .waiting)
            #expect(passenger.role == .passenger)
        }
    }
}
