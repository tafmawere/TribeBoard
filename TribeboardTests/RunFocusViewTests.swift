//
//  RunFocusViewTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/06.
//

import XCTest
@testable import Tribeboard
import CoreLocation

/// Tests for Run Focus View (Requirement 4)
/// Validates task 11.5: View run and verify Run Focus screen displays correctly
@MainActor
final class RunFocusViewTests: XCTestCase {
    
    var mockFirebaseService: MockFirebaseRunService!
    var mockRoleManagementService: RoleManagementService!
    var mockRunEventService: RunEventService!
    var viewModel: RunFocusViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockFirebaseService = MockFirebaseRunService()
        mockRoleManagementService = RoleManagementService()
        mockRunEventService = RunEventService(firebaseService: mockFirebaseService)
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockRunEventService = nil
        mockRoleManagementService = nil
        mockFirebaseService = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Test Run Focus Screen Display
    
    /// Example 9: Run Focus screen shows map, status card, route summary, and passengers
    /// Validates: Requirements 4.1, 4.2, 4.3, 4.4
    func testRunFocusScreenDisplaysAllRequiredElements() async throws {
        // Given: A scheduled run with driver, passengers, and stops
        let run = createTestRun()
        _ = try await mockFirebaseService.upsertRun(run)
        
        // Set current user as driver
        mockRoleManagementService.setCurrentUser(
            userId: run.driverId,
            displayName: "Tafadzwa",
            role: .driver,
            familyId: run.familyId
        )
        
        // When: ViewModel loads the run
        viewModel = RunFocusViewModel(
            runId: run.id,
            firebaseService: mockFirebaseService,
            roleManagementService: mockRoleManagementService,
            runEventService: mockRunEventService
        )
        
        // Wait for async load
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then: Run is loaded successfully
        XCTAssertNotNil(viewModel.run, "Run should be loaded")
        XCTAssertEqual(viewModel.run?.id, run.id, "Loaded run should match requested run")
        XCTAssertFalse(viewModel.isLoading, "Loading should be complete")
        XCTAssertNil(viewModel.error, "No error should occur")
        
        // Verify map data (route markers)
        XCTAssertEqual(viewModel.run?.stops.count, 3, "Should have 3 stops for route markers")
        
        // Verify status card data
        let eta = viewModel.calculateETA()
        XCTAssertNotNil(eta, "ETA should be calculated")
        
        let distance = viewModel.calculateTotalDistance()
        XCTAssertGreaterThan(distance, 0, "Total distance should be greater than 0")
        
        // Verify route summary data
        XCTAssertEqual(viewModel.run?.stops.count, 3, "Route summary should show all stops")
        
        // Verify passenger data
        XCTAssertEqual(viewModel.run?.passengers.count, 2, "Should show 2 passengers")
    }
    
    /// Example 10: Driver role sees "Start Run" button
    /// Validates: Requirements 4.5
    func testDriverCanSeeStartRunButton() async throws {
        // Given: A scheduled run
        let run = createTestRun()
        _ = try await mockFirebaseService.upsertRun(run)
        
        // Set current user as driver
        mockRoleManagementService.setCurrentUser(
            userId: run.driverId,
            displayName: "Tafadzwa",
            role: .driver,
            familyId: run.familyId
        )
        
        // When: ViewModel loads the run
        viewModel = RunFocusViewModel(
            runId: run.id,
            firebaseService: mockFirebaseService,
            roleManagementService: mockRoleManagementService,
            runEventService: mockRunEventService
        )
        
        // Wait for async load
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then: Driver can start run
        XCTAssertTrue(viewModel.canStartRun(), "Driver should be able to start run")
    }
    
    func testNonDriverCannotSeeStartRunButton() async throws {
        // Given: A scheduled run
        let run = createTestRun()
        _ = try await mockFirebaseService.upsertRun(run)
        
        // Set current user as observer (not driver)
        mockRoleManagementService.setCurrentUser(
            userId: "observer-user",
            displayName: "Rue",
            role: .observer,
            familyId: run.familyId
        )
        
        // When: ViewModel loads the run
        viewModel = RunFocusViewModel(
            runId: run.id,
            firebaseService: mockFirebaseService,
            roleManagementService: mockRoleManagementService,
            runEventService: mockRunEventService
        )
        
        // Wait for async load
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then: Non-driver cannot start run
        XCTAssertFalse(viewModel.canStartRun(), "Non-driver should not be able to start run")
    }
    
    // MARK: - Test ETA Calculation
    
    func testETACalculationUsesLastStopTime() async throws {
        // Given: A run with multiple stops
        let run = createTestRun()
        _ = try await mockFirebaseService.upsertRun(run)
        
        mockRoleManagementService.setCurrentUser(
            userId: run.driverId,
            displayName: "Tafadzwa",
            role: .driver,
            familyId: run.familyId
        )
        
        viewModel = RunFocusViewModel(
            runId: run.id,
            firebaseService: mockFirebaseService,
            roleManagementService: mockRoleManagementService,
            runEventService: mockRunEventService
        )
        
        // Wait for async load
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // When: ETA is calculated
        let eta = viewModel.calculateETA()
        
        // Then: ETA should match last stop's scheduled time
        let lastStopTime = run.stops.last?.scheduledTime
        XCTAssertNotNil(lastStopTime, "Last stop should have scheduled time")
        XCTAssertEqual(eta.timeIntervalSince1970, lastStopTime?.timeIntervalSince1970 ?? 0, accuracy: 1.0, "ETA should match last stop time")
    }
    
    // MARK: - Test Distance Calculation
    
    func testDistanceCalculationForMultipleStops() async throws {
        // Given: A run with 3 stops
        let run = createTestRun()
        _ = try await mockFirebaseService.upsertRun(run)
        
        mockRoleManagementService.setCurrentUser(
            userId: run.driverId,
            displayName: "Tafadzwa",
            role: .driver,
            familyId: run.familyId
        )
        
        viewModel = RunFocusViewModel(
            runId: run.id,
            firebaseService: mockFirebaseService,
            roleManagementService: mockRoleManagementService,
            runEventService: mockRunEventService
        )
        
        // Wait for async load
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // When: Distance is calculated
        let distance = viewModel.calculateTotalDistance()
        
        // Then: Distance should be positive and reasonable
        XCTAssertGreaterThan(distance, 0, "Distance should be greater than 0")
        XCTAssertLessThan(distance, 100000, "Distance should be less than 100km for test data")
    }
    
    // MARK: - Test Error Handling
    
    func testRunNotFoundShowsError() async throws {
        // Given: A non-existent run ID
        let nonExistentRunId = "non-existent-run"
        
        mockRoleManagementService.setCurrentUser(
            userId: "test-user",
            displayName: "Test User",
            role: .observer,
            familyId: "test-family"
        )
        
        // When: ViewModel tries to load non-existent run
        viewModel = RunFocusViewModel(
            runId: nonExistentRunId,
            firebaseService: mockFirebaseService,
            roleManagementService: mockRoleManagementService,
            runEventService: mockRunEventService
        )
        
        // Wait for async load
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then: Error should be set
        XCTAssertNil(viewModel.run, "Run should not be loaded")
        XCTAssertNotNil(viewModel.error, "Error should be set")
    }
    
    // MARK: - Helper Methods
    
    private func createTestRun() -> Run {
        let now = Date()
        
        // Create stops
        let stop1 = RunStop(
            id: "stop1",
            type: .pickup,
            label: "Home",
            scheduledTime: now.addingTimeInterval(300), // 5 minutes from now
            requiredPassengerIds: ["passenger1", "passenger2"],
            location: LocationData(
                latitude: 37.7749,
                longitude: -122.4194,
                address: "123 Main St, San Francisco, CA"
            )
        )
        
        let stop2 = RunStop(
            id: "stop2",
            type: .waypoint,
            label: "School",
            scheduledTime: now.addingTimeInterval(900), // 15 minutes from now
            requiredPassengerIds: [],
            location: LocationData(
                latitude: 37.7849,
                longitude: -122.4094,
                address: "456 Oak Ave, San Francisco, CA"
            )
        )
        
        let stop3 = RunStop(
            id: "stop3",
            type: .dropoff,
            label: "Park",
            scheduledTime: now.addingTimeInterval(1800), // 30 minutes from now
            requiredPassengerIds: ["passenger1", "passenger2"],
            location: LocationData(
                latitude: 37.7949,
                longitude: -122.3994,
                address: "789 Pine St, San Francisco, CA"
            )
        )
        
        // Create passengers
        let passenger1 = MemberSummary(
            id: "passenger1",
            displayName: "TJ",
            role: .passenger,
            status: .waiting
        )
        
        let passenger2 = MemberSummary(
            id: "passenger2",
            displayName: "Tawana",
            role: .passenger,
            status: .waiting
        )
        
        // Create run
        return Run(
            id: "test-run-1",
            title: "School Run",
            scheduledTime: now.addingTimeInterval(300),
            driverId: "user_taf",
            status: .scheduled,
            stops: [stop1, stop2, stop3],
            passengers: [passenger1, passenger2],
            createdBy: "user_rue",
            familyId: "demo-family-1"
        )
    }
}
