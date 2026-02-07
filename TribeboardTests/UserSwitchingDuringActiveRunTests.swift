//
//  UserSwitchingDuringActiveRunTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/06.
//

import XCTest
@testable import Tribeboard
import CoreLocation

/// Tests for switching to Rue (observer) during an active run
/// Validates Requirements 2.4, 2.5, 8, 13.7, 13.8
/// Task 11.10: Switch to Rue during active run
@MainActor
final class UserSwitchingDuringActiveRunTests: XCTestCase {
    
    var mockFirebaseService: MockFirebaseRunService!
    var roleManagementService: RoleManagementService!
    var runEventService: RunEventService!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create services directly without DependencyContainer
        mockFirebaseService = MockFirebaseRunService()
        roleManagementService = RoleManagementService()
        runEventService = RunEventService(firebaseService: mockFirebaseService)
    }
    
    override func tearDown() async throws {
        runEventService = nil
        roleManagementService = nil
        mockFirebaseService = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Test User Switching During Active Run
    
    /// Test switching from driver (Tafadzwa) to observer (Rue) during active run
    /// Validates: Requirements 2.4, 2.5, 13.7
    func testSwitchToRueDuringActiveRun() async throws {
        // Given: An active run with Tafadzwa as driver
        let run = createActiveRun()
        _ = try await mockFirebaseService.upsertRun(run)
        
        // Set current user as driver (Tafadzwa)
        roleManagementService.setCurrentUser(
            userId: DemoSeedDataService.tafadzwaId,
            displayName: "Tafadzwa Mawere",
            role: .driver,
            familyId: DemoSeedDataService.demoFamilyId
        )
        
        XCTAssertEqual(roleManagementService.currentUserId, DemoSeedDataService.tafadzwaId)
        XCTAssertEqual(roleManagementService.currentUserRole, .driver)
        
        // When: Switch to Rue (observer)
        roleManagementService.setCurrentUser(
            userId: DemoSeedDataService.rueId,
            displayName: "Rue Mawere",
            role: .observer,
            familyId: DemoSeedDataService.demoFamilyId
        )
        
        // Then: Current user should be Rue with observer role
        XCTAssertEqual(roleManagementService.currentUserId, DemoSeedDataService.rueId)
        XCTAssertEqual(roleManagementService.currentUserRole, .observer)
        XCTAssertEqual(roleManagementService.currentFamilyId, DemoSeedDataService.demoFamilyId)
        
        // Verify UI configuration changes to observer interface
        let uiConfig = roleManagementService.getUIConfiguration(for: run)
        XCTAssertTrue(uiConfig.showObserverInterface, "Observer interface should be shown")
        XCTAssertFalse(uiConfig.showDriverInterface, "Driver interface should not be shown")
        XCTAssertEqual(uiConfig.primaryInterface, .observerTracking, "Primary interface should be observer tracking")
    }
    
    /// Test that observer can view active run details
    /// Validates: Requirements 8.1, 8.2, 8.5, 8.8
    func testObserverCanViewActiveRunDetails() async throws {
        // Given: An active run
        let run = createActiveRun()
        _ = try await mockFirebaseService.upsertRun(run)
        
        // Set current user as observer (Rue)
        roleManagementService.setCurrentUser(
            userId: DemoSeedDataService.rueId,
            displayName: "Rue Mawere",
            role: .observer,
            familyId: DemoSeedDataService.demoFamilyId
        )
        
        // When: Check observer permissions
        let canViewDetails = roleManagementService.canPerformOperation(.viewRunDetails, on: run)
        let canViewTimeline = roleManagementService.canPerformOperation(.viewRunTimeline, on: run)
        let canViewLocation = roleManagementService.canPerformOperation(.viewDriverLocation, on: run)
        
        // Then: Observer should have view permissions
        XCTAssertTrue(canViewDetails, "Observer should be able to view run details")
        XCTAssertTrue(canViewTimeline, "Observer should be able to view run timeline")
        XCTAssertTrue(canViewLocation, "Observer should be able to view driver location")
    }
    
    /// Test that observer cannot perform driver actions
    /// Validates: Requirements 2.5
    func testObserverCannotPerformDriverActions() async throws {
        // Given: An active run
        let run = createActiveRun()
        _ = try await mockFirebaseService.upsertRun(run)
        
        // Set current user as observer (Rue)
        roleManagementService.setCurrentUser(
            userId: DemoSeedDataService.rueId,
            displayName: "Rue Mawere",
            role: .observer,
            familyId: DemoSeedDataService.demoFamilyId
        )
        
        // When: Check driver action permissions
        let canStartRun = roleManagementService.canPerformOperation(.startRun, on: run)
        let canConfirmPickup = roleManagementService.canPerformOperation(.confirmPickup, on: run)
        let canConfirmDropoff = roleManagementService.canPerformOperation(.confirmDropoff, on: run)
        let canEndRun = roleManagementService.canPerformOperation(.endRun, on: run)
        
        // Then: Observer should not have driver action permissions
        XCTAssertFalse(canStartRun, "Observer should not be able to start run")
        XCTAssertFalse(canConfirmPickup, "Observer should not be able to confirm pickup")
        XCTAssertFalse(canConfirmDropoff, "Observer should not be able to confirm dropoff")
        XCTAssertFalse(canEndRun, "Observer should not be able to end run")
    }
    
    /// Test navigation to observer tracking view after user switch
    /// Validates: Requirements 13.7
    func testNavigationToObserverTrackingAfterSwitch() async throws {
        // Given: An active run
        let run = createActiveRun()
        _ = try await mockFirebaseService.upsertRun(run)
        
        // Start as driver
        roleManagementService.setCurrentUser(
            userId: DemoSeedDataService.tafadzwaId,
            displayName: "Tafadzwa Mawere",
            role: .driver,
            familyId: DemoSeedDataService.demoFamilyId
        )
        
        // When: Switch to observer
        roleManagementService.setCurrentUser(
            userId: DemoSeedDataService.rueId,
            displayName: "Rue Mawere",
            role: .observer,
            familyId: DemoSeedDataService.demoFamilyId
        )
        
        // Then: UI configuration should indicate observer tracking
        let uiConfig = roleManagementService.getUIConfiguration(for: run)
        XCTAssertEqual(uiConfig.primaryInterface, .observerTracking, "Primary interface should be observer tracking after switch")
        XCTAssertTrue(uiConfig.showObserverInterface, "Observer interface should be shown")
        XCTAssertFalse(uiConfig.showDriverInterface, "Driver interface should not be shown")
    }
    
    /// Test UI configuration updates immediately after user switch
    /// Validates: Requirements 2.5, 13.8
    func testUIConfigurationUpdatesImmediately() async throws {
        // Given: An active run
        let run = createActiveRun()
        _ = try await mockFirebaseService.upsertRun(run)
        
        // Start as driver
        roleManagementService.setCurrentUser(
            userId: DemoSeedDataService.tafadzwaId,
            displayName: "Tafadzwa Mawere",
            role: .driver,
            familyId: DemoSeedDataService.demoFamilyId
        )
        
        let driverConfig = roleManagementService.getUIConfiguration(for: run)
        XCTAssertTrue(driverConfig.showDriverInterface, "Driver interface should be shown initially")
        
        // When: Switch to observer
        roleManagementService.setCurrentUser(
            userId: DemoSeedDataService.rueId,
            displayName: "Rue Mawere",
            role: .observer,
            familyId: DemoSeedDataService.demoFamilyId
        )
        
        // Then: UI configuration should update immediately
        let observerConfig = roleManagementService.getUIConfiguration(for: run)
        XCTAssertTrue(observerConfig.showObserverInterface, "Observer interface should be shown after switch")
        XCTAssertFalse(observerConfig.showDriverInterface, "Driver interface should not be shown after switch")
        
        // Verify available actions changed
        XCTAssertTrue(driverConfig.availableDriverActions.count > 0, "Driver should have driver actions")
        XCTAssertTrue(observerConfig.availableDriverActions.isEmpty, "Observer should not have driver actions")
    }
    
    /// Test that observer sees real-time updates during active run
    /// Validates: Requirements 8, 13.8
    func testObserverSeesRealTimeUpdates() async throws {
        // Given: An active run with initial location
        var run = createActiveRun()
        _ = try await mockFirebaseService.upsertRun(run)
        
        // Set current user as observer (Rue)
        roleManagementService.setCurrentUser(
            userId: DemoSeedDataService.rueId,
            displayName: "Rue Mawere",
            role: .observer,
            familyId: DemoSeedDataService.demoFamilyId
        )
        
        // When: Driver location is updated
        let newLocation = GeoPoint(
            latitude: 37.7849,
            longitude: -122.4094
        )
        
        run.lastLocation = newLocation
        run.lastLocationUpdatedAt = Date()
        _ = try await mockFirebaseService.upsertRun(run)
        
        // Then: Observer should be able to fetch updated run
        let updatedRun = try await mockFirebaseService.fetchRun(runId: run.id)
        XCTAssertNotNil(updatedRun.lastLocation, "Driver location should be updated")
        XCTAssertEqual(updatedRun.lastLocation?.latitude ?? 0, newLocation.latitude, accuracy: 0.0001)
        XCTAssertEqual(updatedRun.lastLocation?.longitude ?? 0, newLocation.longitude, accuracy: 0.0001)
    }
    
    /// Test switching between multiple users during active run
    /// Validates: Requirements 2.4, 2.5
    func testSwitchingBetweenMultipleUsersDuringActiveRun() async throws {
        // Given: An active run
        let run = createActiveRun()
        _ = try await mockFirebaseService.upsertRun(run)
        
        let users: [(id: String, name: String, role: FamilyRole)] = [
            (DemoSeedDataService.tafadzwaId, "Tafadzwa Mawere", .driver),
            (DemoSeedDataService.rueId, "Rue Mawere", .observer),
            (DemoSeedDataService.tjId, "TJ", .observer),
            (DemoSeedDataService.tawanaId, "Tawana", .observer)
        ]
        
        // When: Switch between all users
        for user in users {
            roleManagementService.setCurrentUser(
                userId: user.id,
                displayName: user.name,
                role: user.role,
                familyId: DemoSeedDataService.demoFamilyId
            )
            
            // Then: Current user should match
            XCTAssertEqual(roleManagementService.currentUserId, user.id, "Failed to switch to \(user.name)")
            XCTAssertEqual(roleManagementService.currentUserRole, user.role, "Role mismatch for \(user.name)")
            
            // Verify UI configuration is appropriate for role
            let uiConfig = roleManagementService.getUIConfiguration(for: run)
            
            if user.role == .driver && run.driverId == user.id {
                XCTAssertTrue(uiConfig.showDriverInterface, "\(user.name) should see driver interface")
            } else {
                XCTAssertTrue(uiConfig.showObserverInterface, "\(user.name) should see observer interface")
            }
        }
    }
    
    /// Test that user switcher maintains family context during active run
    /// Validates: Requirements 2.1, 2.4
    func testUserSwitcherMaintainsFamilyContextDuringActiveRun() async throws {
        // Given: An active run
        let run = createActiveRun()
        _ = try await mockFirebaseService.upsertRun(run)
        
        let users = [
            DemoSeedDataService.rueId,
            DemoSeedDataService.tafadzwaId,
            DemoSeedDataService.tjId,
            DemoSeedDataService.tawanaId
        ]
        
        // When: Switch between users
        for userId in users {
            let (displayName, role) = getUserInfo(for: userId)
            roleManagementService.setCurrentUser(
                userId: userId,
                displayName: displayName,
                role: role,
                familyId: DemoSeedDataService.demoFamilyId
            )
            
            // Then: Family ID should remain consistent
            XCTAssertEqual(
                roleManagementService.currentFamilyId,
                DemoSeedDataService.demoFamilyId,
                "Family ID should remain consistent when switching users during active run"
            )
            
            // Verify user can still see the run (same family)
            let filteredRuns = roleManagementService.getFilteredRuns([run])
            XCTAssertTrue(filteredRuns.contains(where: { $0.id == run.id }), "\(displayName) should see family run")
        }
    }
    
    /// Test observer tracking view model with switched user
    /// Validates: Requirements 8, 13.7
    func testObserverTrackingViewModelWithSwitchedUser() async throws {
        // Given: An active run
        let run = createActiveRun()
        _ = try await mockFirebaseService.upsertRun(run)
        
        // Switch to observer (Rue)
        roleManagementService.setCurrentUser(
            userId: DemoSeedDataService.rueId,
            displayName: "Rue Mawere",
            role: .observer,
            familyId: DemoSeedDataService.demoFamilyId
        )
        
        // When: Create observer tracking view model
        let roleContext = RoleContext(
            userId: roleManagementService.currentUserId,
            role: roleManagementService.currentUserRole,
            familyId: roleManagementService.currentFamilyId
        )
        
        let viewModel = ObserverTrackingViewModel(
            runId: run.id,
            runEventService: runEventService,
            roleContext: roleContext
        )
        
        // Wait for async load
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Then: View model should load run successfully
        let runInfo = viewModel.getCurrentRunInfo()
        XCTAssertNotNil(runInfo, "Observer should be able to load run")
        XCTAssertEqual(runInfo?.run.id, run.id, "Loaded run should match")
        
        // Verify observer can see driver location
        XCTAssertNotNil(runInfo?.run.lastLocation, "Observer should see driver location")
        
        // Verify observer can see passenger statuses
        XCTAssertEqual(runInfo?.run.passengers.count, 2, "Observer should see all passengers")
    }
    
    // MARK: - Helper Methods
    
    private func createActiveRun() -> Run {
        let now = Date()
        
        // Create stops
        let stop1 = RunStop(
            id: "stop1",
            type: .pickup,
            label: "Home",
            scheduledTime: now.addingTimeInterval(-300), // 5 minutes ago (already passed)
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
            scheduledTime: now.addingTimeInterval(300), // 5 minutes from now
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
            scheduledTime: now.addingTimeInterval(900), // 15 minutes from now
            requiredPassengerIds: ["passenger1", "passenger2"],
            location: LocationData(
                latitude: 37.7949,
                longitude: -122.3994,
                address: "789 Pine St, San Francisco, CA"
            )
        )
        
        // Create passengers (onboard after pickup)
        let passenger1 = MemberSummary(
            id: DemoSeedDataService.tjId,
            displayName: "TJ",
            role: .passenger,
            status: .onboard
        )
        
        let passenger2 = MemberSummary(
            id: DemoSeedDataService.tawanaId,
            displayName: "Tawana",
            role: .passenger,
            status: .onboard
        )
        
        // Create active run (en route to next stop)
        return Run(
            id: "active-run-1",
            title: "School Run",
            scheduledTime: now.addingTimeInterval(-300),
            driverId: DemoSeedDataService.tafadzwaId,
            status: .activeEnroute,
            stops: [stop1, stop2, stop3],
            passengers: [passenger1, passenger2],
            createdBy: DemoSeedDataService.rueId,
            familyId: DemoSeedDataService.demoFamilyId,
            currentStopIndex: 1, // En route to stop 2
            lastLocation: GeoPoint(
                latitude: 37.7799,
                longitude: -122.4144
            ),
            lastLocationUpdatedAt: now
        )
    }
    
    private func getUserInfo(for userId: String) -> (displayName: String, role: FamilyRole) {
        switch userId {
        case DemoSeedDataService.rueId:
            return ("Rue Mawere", .observer)
        case DemoSeedDataService.tafadzwaId:
            return ("Tafadzwa Mawere", .driver)
        case DemoSeedDataService.tjId:
            return ("TJ", .observer)
        case DemoSeedDataService.tawanaId:
            return ("Tawana", .observer)
        default:
            return ("Unknown", .observer)
        }
    }
}
