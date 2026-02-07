//
//  UserSwitcherTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/06.
//

import XCTest
@testable import Tribeboard

/// Tests for user switcher functionality in demo mode
/// Validates Requirements 2.4, 2.5
@MainActor
final class UserSwitcherTests: XCTestCase {
    
    var roleManagementService: RoleManagementService!
    
    override func setUp() async throws {
        try await super.setUp()
        roleManagementService = RoleManagementService()
    }
    
    override func tearDown() async throws {
        roleManagementService = nil
        try await super.tearDown()
    }
    
    // MARK: - User Switching Tests
    
    /// Test switching to Tafadzwa user
    /// Validates: Requirements 2.4, 2.5
    func testSwitchToTafadzwaUser() async throws {
        // Given: Initial user is Rue
        roleManagementService.setCurrentUser(
            userId: DemoSeedDataService.rueId,
            displayName: "Rue Mawere",
            role: .observer,
            familyId: DemoSeedDataService.demoFamilyId
        )
        
        XCTAssertEqual(roleManagementService.currentUserId, DemoSeedDataService.rueId)
        XCTAssertEqual(roleManagementService.currentUserRole, .observer)
        
        // When: Switch to Tafadzwa
        roleManagementService.setCurrentUser(
            userId: DemoSeedDataService.tafadzwaId,
            displayName: "Tafadzwa Mawere",
            role: .driver,
            familyId: DemoSeedDataService.demoFamilyId
        )
        
        // Then: Current user should be Tafadzwa with driver role
        XCTAssertEqual(roleManagementService.currentUserId, DemoSeedDataService.tafadzwaId)
        XCTAssertEqual(roleManagementService.currentUserRole, .driver)
        XCTAssertEqual(roleManagementService.currentFamilyId, DemoSeedDataService.demoFamilyId)
    }
    
    /// Test switching between all demo users
    /// Validates: Requirements 2.4, 2.5
    func testSwitchBetweenAllDemoUsers() async throws {
        // Test switching to each user
        let users: [(id: String, name: String, role: FamilyRole)] = [
            (DemoSeedDataService.rueId, "Rue Mawere", .observer),
            (DemoSeedDataService.tafadzwaId, "Tafadzwa Mawere", .driver),
            (DemoSeedDataService.tjId, "TJ", .observer),
            (DemoSeedDataService.tawanaId, "Tawana", .observer)
        ]
        
        for user in users {
            // When: Switch to user
            roleManagementService.setCurrentUser(
                userId: user.id,
                displayName: user.name,
                role: user.role,
                familyId: DemoSeedDataService.demoFamilyId
            )
            
            // Then: Current user should match
            XCTAssertEqual(roleManagementService.currentUserId, user.id, "Failed to switch to \(user.name)")
            XCTAssertEqual(roleManagementService.currentUserRole, user.role, "Role mismatch for \(user.name)")
        }
    }
    
    /// Test that switching user updates available operations
    /// Validates: Requirements 2.5
    func testSwitchingUserUpdatesPermissions() async throws {
        // Given: User is observer (Rue)
        roleManagementService.setCurrentUser(
            userId: DemoSeedDataService.rueId,
            displayName: "Rue Mawere",
            role: .observer,
            familyId: DemoSeedDataService.demoFamilyId
        )
        
        let observerOperations = roleManagementService.availableOperations
        
        // When: Switch to driver (Tafadzwa)
        roleManagementService.setCurrentUser(
            userId: DemoSeedDataService.tafadzwaId,
            displayName: "Tafadzwa Mawere",
            role: .driver,
            familyId: DemoSeedDataService.demoFamilyId
        )
        
        let driverOperations = roleManagementService.availableOperations
        
        // Then: Available operations should be different
        XCTAssertNotEqual(observerOperations, driverOperations, "Operations should differ between observer and driver")
        
        // Driver should have more operations than observer
        XCTAssertTrue(driverOperations.count >= observerOperations.count, "Driver should have at least as many operations as observer")
    }
    
    /// Test that user switcher maintains family context
    /// Validates: Requirements 2.1
    func testUserSwitcherMaintainsFamilyContext() async throws {
        let users = [
            DemoSeedDataService.rueId,
            DemoSeedDataService.tafadzwaId,
            DemoSeedDataService.tjId,
            DemoSeedDataService.tawanaId
        ]
        
        for userId in users {
            // When: Switch to user
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
                "Family ID should remain consistent when switching users"
            )
        }
    }
    
    // MARK: - Helper Methods
    
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
