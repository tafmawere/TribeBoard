//
//  UserSwitchingDuringActiveRunSimpleTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/06.
//

import XCTest
@testable import Tribeboard

/// Simplified tests for switching to Rue (observer) during an active run
/// Validates Requirements 2.4, 2.5, 8, 13.7, 13.8
/// Task 11.10: Switch to Rue during active run
@MainActor
final class UserSwitchingDuringActiveRunSimpleTests: XCTestCase {
    
    // MARK: - Test User Switching Functionality
    
    /// Test switching from driver to observer role
    /// Validates: Requirements 2.4, 2.5
    func testSwitchFromDriverToObserver() {
        // Given: Role management service
        let roleService = RoleManagementService()
        
        // Set as driver initially
        roleService.setCurrentUser(
            userId: "driver-1",
            displayName: "Tafadzwa",
            role: .driver,
            familyId: "family-1"
        )
        
        XCTAssertEqual(roleService.currentUserRole, .driver)
        XCTAssertEqual(roleService.currentUserId, "driver-1")
        
        // When: Switch to observer
        roleService.setCurrentUser(
            userId: "observer-1",
            displayName: "Rue",
            role: .observer,
            familyId: "family-1"
        )
        
        // Then: Role should be updated
        XCTAssertEqual(roleService.currentUserRole, .observer)
        XCTAssertEqual(roleService.currentUserId, "observer-1")
        XCTAssertEqual(roleService.currentFamilyId, "family-1")
    }
    
    /// Test that observer has correct permissions for active run
    /// Validates: Requirements 8.1, 8.2, 8.5, 8.8
    func testObserverPermissionsForActiveRun() {
        // Given: Role management service and an active run
        let roleService = RoleManagementService()
        roleService.setCurrentUser(
            userId: "observer-1",
            displayName: "Rue",
            role: .observer,
            familyId: "family-1"
        )
        
        let run = createTestRun(status: .activeEnroute)
        
        // When: Check observer permissions
        let canViewDetails = roleService.canPerformOperation(.viewRunDetails, on: run)
        let canViewTimeline = roleService.canPerformOperation(.viewRunTimeline, on: run)
        let canViewLocation = roleService.canPerformOperation(.viewDriverLocation, on: run)
        
        // Then: Observer should have view permissions
        XCTAssertTrue(canViewDetails, "Observer should view run details")
        XCTAssertTrue(canViewTimeline, "Observer should view timeline")
        XCTAssertTrue(canViewLocation, "Observer should view driver location")
    }
    
    /// Test that observer cannot perform driver actions
    /// Validates: Requirements 2.5
    func testObserverCannotPerformDriverActions() {
        // Given: Role management service and an active run
        let roleService = RoleManagementService()
        roleService.setCurrentUser(
            userId: "observer-1",
            displayName: "Rue",
            role: .observer,
            familyId: "family-1"
        )
        
        let run = createTestRun(status: .activeEnroute)
        
        // When: Check driver action permissions
        let canStartRun = roleService.canPerformOperation(.startRun, on: run)
        let canConfirmPickup = roleService.canPerformOperation(.confirmPickup, on: run)
        let canEndRun = roleService.canPerformOperation(.endRun, on: run)
        
        // Then: Observer should not have driver permissions
        XCTAssertFalse(canStartRun, "Observer cannot start run")
        XCTAssertFalse(canConfirmPickup, "Observer cannot confirm pickup")
        XCTAssertFalse(canEndRun, "Observer cannot end run")
    }
    
    /// Test UI configuration changes when switching to observer
    /// Validates: Requirements 2.5, 13.8
    func testUIConfigurationForObserver() {
        // Given: Role management service and an active run
        let roleService = RoleManagementService()
        let run = createTestRun(status: .activeEnroute)
        
        // Start as driver
        roleService.setCurrentUser(
            userId: run.driverId,
            displayName: "Tafadzwa",
            role: .driver,
            familyId: run.familyId
        )
        
        let driverConfig = roleService.getUIConfiguration(for: run)
        XCTAssertTrue(driverConfig.showDriverInterface, "Driver should see driver interface")
        
        // When: Switch to observer
        roleService.setCurrentUser(
            userId: "observer-1",
            displayName: "Rue",
            role: .observer,
            familyId: run.familyId
        )
        
        let observerConfig = roleService.getUIConfiguration(for: run)
        
        // Then: UI configuration should change
        XCTAssertTrue(observerConfig.showObserverInterface, "Observer should see observer interface")
        XCTAssertFalse(observerConfig.showDriverInterface, "Observer should not see driver interface")
        XCTAssertEqual(observerConfig.primaryInterface, .observerTracking, "Primary interface should be observer tracking")
    }
    
    /// Test switching maintains family context
    /// Validates: Requirements 2.1, 2.4
    func testSwitchingMaintainsFamilyContext() {
        // Given: Role management service
        let roleService = RoleManagementService()
        let familyId = "family-1"
        
        let users = [
            ("driver-1", "Tafadzwa", FamilyRole.driver),
            ("observer-1", "Rue", FamilyRole.observer),
            ("passenger-1", "TJ", FamilyRole.observer),
            ("passenger-2", "Tawana", FamilyRole.observer)
        ]
        
        // When: Switch between users
        for (userId, displayName, role) in users {
            roleService.setCurrentUser(
                userId: userId,
                displayName: displayName,
                role: role,
                familyId: familyId
            )
            
            // Then: Family ID should remain consistent
            XCTAssertEqual(
                roleService.currentFamilyId,
                familyId,
                "Family ID should remain consistent for \(displayName)"
            )
        }
    }
    
    /// Test that run filtering works for observer
    /// Validates: Requirements 2.5
    func testObserverCanSeeFamilyRuns() {
        // Given: Role management service and runs
        let roleService = RoleManagementService()
        roleService.setCurrentUser(
            userId: "observer-1",
            displayName: "Rue",
            role: .observer,
            familyId: "family-1"
        )
        
        let familyRun = createTestRun(status: .activeEnroute, familyId: "family-1")
        let otherFamilyRun = createTestRun(status: .activeEnroute, familyId: "family-2")
        
        let allRuns = [familyRun, otherFamilyRun]
        
        // When: Filter runs
        let filteredRuns = roleService.getFilteredRuns(allRuns)
        
        // Then: Observer should only see family runs
        XCTAssertEqual(filteredRuns.count, 1, "Observer should see 1 run")
        XCTAssertTrue(filteredRuns.contains(where: { $0.id == familyRun.id }), "Observer should see family run")
        XCTAssertFalse(filteredRuns.contains(where: { $0.id == otherFamilyRun.id }), "Observer should not see other family run")
    }
    
    // MARK: - Helper Methods
    
    private func createTestRun(status: RunStatus, familyId: String = "family-1") -> Run {
        let now = Date()
        
        let stop = RunStop(
            id: "stop1",
            type: .pickup,
            label: "Home",
            scheduledTime: now.addingTimeInterval(300),
            requiredPassengerIds: ["passenger1"],
            location: LocationData(
                latitude: 37.7749,
                longitude: -122.4194,
                address: "123 Main St"
            )
        )
        
        let passenger = MemberSummary(
            id: "passenger1",
            displayName: "TJ",
            role: .passenger,
            status: .waiting
        )
        
        return Run(
            id: "run-\(UUID().uuidString)",
            title: "Test Run",
            scheduledTime: now,
            driverId: "driver-1",
            status: status,
            stops: [stop],
            passengers: [passenger],
            createdBy: "observer-1",
            familyId: familyId
        )
    }
}
