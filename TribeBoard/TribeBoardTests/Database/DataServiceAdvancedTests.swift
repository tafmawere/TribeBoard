import XCTest
import SwiftData
@testable import TribeBoard

/// Tests for advanced and complex operations in DataService
@MainActor
final class DataServiceAdvancedTests: DatabaseTestBase {
    
    // MARK: - Unique Family Code Generation Tests
    
    func testGenerateUniqueFamilyCodeWithEmptyDatabase() throws {
        // Given - empty database
        try assertRecordCount(Family.self, expectedCount: 0)
        
        // When
        let uniqueCode = try dataService.generateUniqueFamilyCode()
        
        // Then
        XCTAssertFalse(uniqueCode.isEmpty)
        XCTAssertTrue(uniqueCode.count >= 6)
        XCTAssertTrue(uniqueCode.count <= 8)
        XCTAssertTrue(uniqueCode.allSatisfy { $0.isLetter || $0.isNumber })
        
        // Verify the code doesn't exist in database
        let existingFamily = try dataService.fetchFamily(byCode: uniqueCode)
        XCTAssertNil(existingFamily)
    }
    
    func testGenerateUniqueFamilyCodeWithExistingFamilies() throws {
        // Given - create some existing families
        let existingCodes = ["EXIST01", "EXIST02", "EXIST03"]
        for code in existingCodes {
            _ = try createTestFamily(name: "Existing Family", code: code)
        }
        
        // When
        let uniqueCode = try dataService.generateUniqueFamilyCode()
        
        // Then
        XCTAssertFalse(uniqueCode.isEmpty)
        XCTAssertTrue(uniqueCode.count >= 6)
        XCTAssertTrue(uniqueCode.count <= 8)
        XCTAssertTrue(uniqueCode.allSatisfy { $0.isLetter || $0.isNumber })
        
        // Verify the code is not one of the existing codes
        XCTAssertFalse(existingCodes.contains(uniqueCode))
        
        // Verify the code doesn't exist in database
        let existingFamily = try dataService.fetchFamily(byCode: uniqueCode)
        XCTAssertNil(existingFamily)
    }
    
    func testGenerateMultipleUniqueFamilyCodes() throws {
        // Given
        let numberOfCodes = 10
        var generatedCodes: Set<String> = []
        
        // When - generate multiple codes
        for _ in 1...numberOfCodes {
            let uniqueCode = try dataService.generateUniqueFamilyCode()
            generatedCodes.insert(uniqueCode)
        }
        
        // Then - all codes should be unique
        XCTAssertEqual(generatedCodes.count, numberOfCodes, "All generated codes should be unique")
        
        // Verify all codes are valid format
        for code in generatedCodes {
            XCTAssertTrue(code.count >= 6)
            XCTAssertTrue(code.count <= 8)
            XCTAssertTrue(code.allSatisfy { $0.isLetter || $0.isNumber })
        }
    }
    
    func testGenerateUniqueFamilyCodeAvoidanceOfExistingCodes() throws {
        // Given - create families with codes that might be generated
        let potentialCodes = ["ABC123", "DEF456", "GHI789", "JKL012"]
        for code in potentialCodes {
            _ = try createTestFamily(name: "Potential Family", code: code)
        }
        
        // When - generate multiple unique codes
        var generatedCodes: Set<String> = []
        for _ in 1...20 {
            let uniqueCode = try dataService.generateUniqueFamilyCode()
            generatedCodes.insert(uniqueCode)
        }
        
        // Then - none of the generated codes should match existing codes
        let intersection = generatedCodes.intersection(Set(potentialCodes))
        XCTAssertTrue(intersection.isEmpty, "Generated codes should not match existing codes")
    }
    
    func testGenerateUniqueFamilyCodeUsesValidCharacters() throws {
        // Given
        let validCharacters = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        
        // When - generate multiple codes
        for _ in 1...10 {
            let uniqueCode = try dataService.generateUniqueFamilyCode()
            
            // Then - verify all characters are valid
            for character in uniqueCode {
                XCTAssertTrue(validCharacters.contains(character), "Code '\(uniqueCode)' contains invalid character '\(character)'")
            }
        }
    }
    
    // MARK: - Membership Role Update Tests
    
    func testUpdateMembershipRoleValidChanges() throws {
        // Given
        let family = try createTestFamily(name: "Role Update Family", code: "ROLE01")
        let user = try createTestUser(displayName: "Role User", appleUserIdHash: "role_user_hash")
        let membership = try dataService.createMembership(family: family, user: user, role: .kid)
        
        let originalJoinedAt = membership.joinedAt
        XCTAssertEqual(membership.role, .kid)
        XCTAssertNil(membership.lastRoleChangeAt)
        
        // When - update to adult role
        try dataService.updateMembershipRole(membership, to: .adult)
        
        // Then
        XCTAssertEqual(membership.role, .adult)
        XCTAssertNotNil(membership.lastRoleChangeAt)
        XCTAssertEqual(membership.joinedAt, originalJoinedAt) // joinedAt should not change
        XCTAssertTrue(membership.needsSync) // Should be marked for sync
        
        // Test another role change
        let firstRoleChangeTime = membership.lastRoleChangeAt
        
        // Wait a small amount to ensure different timestamp
        Thread.sleep(forTimeInterval: 0.01)
        
        // When - update to visitor role
        try dataService.updateMembershipRole(membership, to: .visitor)
        
        // Then
        XCTAssertEqual(membership.role, .visitor)
        XCTAssertNotNil(membership.lastRoleChangeAt)
        XCTAssertNotEqual(membership.lastRoleChangeAt, firstRoleChangeTime) // Should be updated
    }
    
    func testUpdateMembershipRoleToParentAdminWhenNoneExists() throws {
        // Given
        let family = try createTestFamily(name: "Admin Promotion Family", code: "ADMIN01")
        let user = try createTestUser(displayName: "Future Admin", appleUserIdHash: "future_admin_hash")
        let membership = try dataService.createMembership(family: family, user: user, role: .adult)
        
        XCTAssertFalse(family.hasParentAdmin)
        
        // When
        try dataService.updateMembershipRole(membership, to: .parentAdmin)
        
        // Then
        XCTAssertEqual(membership.role, .parentAdmin)
        XCTAssertTrue(family.hasParentAdmin)
        XCTAssertEqual(family.parentAdmin?.id, membership.id)
        XCTAssertNotNil(membership.lastRoleChangeAt)
    }
    
    func testUpdateMembershipRoleFromParentAdminToOther() throws {
        // Given
        let family = try createTestFamily(name: "Admin Demotion Family", code: "DEMOTE1")
        let admin = try createTestUser(displayName: "Current Admin", appleUserIdHash: "current_admin_hash")
        let adminMembership = try dataService.createMembership(family: family, user: admin, role: .parentAdmin)
        
        XCTAssertTrue(family.hasParentAdmin)
        XCTAssertEqual(family.parentAdmin?.id, adminMembership.id)
        
        // When
        try dataService.updateMembershipRole(adminMembership, to: .adult)
        
        // Then
        XCTAssertEqual(adminMembership.role, .adult)
        XCTAssertFalse(family.hasParentAdmin)
        XCTAssertNil(family.parentAdmin)
        XCTAssertNotNil(adminMembership.lastRoleChangeAt)
    }
    
    func testUpdateMembershipRoleInvalidChanges() throws {
        // Given
        let family = try createTestFamily(name: "Invalid Change Family", code: "INVALID")
        let admin = try createTestUser(displayName: "Admin", appleUserIdHash: "admin_hash")
        let member = try createTestUser(displayName: "Member", appleUserIdHash: "member_hash")
        
        let adminMembership = try dataService.createMembership(family: family, user: admin, role: .parentAdmin)
        let memberMembership = try dataService.createMembership(family: family, user: member, role: .kid)
        
        // When & Then - attempt to change member to parent admin should fail
        XCTAssertThrowsError(try dataService.updateMembershipRole(memberMembership, to: .parentAdmin)) { error in
            guard let dataServiceError = error as? DataServiceError else {
                XCTFail("Expected DataServiceError")
                return
            }
            
            switch dataServiceError {
            case .validationFailed(let messages):
                XCTAssertTrue(messages.contains { $0.contains("Parent Admin already exists") })
            default:
                XCTFail("Expected validation failed error")
            }
        }
        
        // Verify roles remain unchanged
        XCTAssertEqual(adminMembership.role, .parentAdmin)
        XCTAssertEqual(memberMembership.role, .kid)
    }
    
    func testUpdateMembershipRoleToSameRole() throws {
        // Given
        let family = try createTestFamily(name: "Same Role Family", code: "SAME01")
        let user = try createTestUser(displayName: "User", appleUserIdHash: "user_hash")
        let membership = try dataService.createMembership(family: family, user: user, role: .adult)
        
        let originalLastRoleChangeAt = membership.lastRoleChangeAt
        
        // When & Then - attempt to change to same role should fail
        XCTAssertThrowsError(try dataService.updateMembershipRole(membership, to: .adult)) { error in
            guard let dataServiceError = error as? DataServiceError else {
                XCTFail("Expected DataServiceError")
                return
            }
            
            switch dataServiceError {
            case .validationFailed(let messages):
                XCTAssertTrue(messages.contains { $0.contains("already has this role") })
            default:
                XCTFail("Expected validation failed error")
            }
        }
        
        // Verify role and timestamp remain unchanged
        XCTAssertEqual(membership.role, .adult)
        XCTAssertEqual(membership.lastRoleChangeAt, originalLastRoleChangeAt)
    }
    
    // MARK: - Membership Removal (Soft Delete) Tests
    
    func testRemoveMembershipSoftDelete() throws {
        // Given
        let family = try createTestFamily(name: "Removal Family", code: "REMOVE1")
        let user = try createTestUser(displayName: "Leaving User", appleUserIdHash: "leaving_user_hash")
        let membership = try dataService.createMembership(family: family, user: user, role: .kid)
        
        XCTAssertEqual(membership.status, .active)
        XCTAssertFalse(membership.needsSync) // Assume it was synced
        membership.needsSync = false // Reset for test
        
        // When
        try dataService.removeMembership(membership)
        
        // Then
        XCTAssertEqual(membership.status, .removed)
        XCTAssertTrue(membership.needsSync) // Should be marked for sync
        
        // Verify membership still exists in database (soft delete)
        let allMemberships = try dataService.fetchMemberships(forFamily: family)
        XCTAssertEqual(allMemberships.count, 1)
        XCTAssertEqual(allMemberships.first?.id, membership.id)
        XCTAssertEqual(allMemberships.first?.status, .removed)
        
        // Verify it doesn't appear in active memberships
        let activeMemberships = try dataService.fetchActiveMemberships(forFamily: family)
        XCTAssertEqual(activeMemberships.count, 0)
    }
    
    func testRemoveParentAdminMembership() throws {
        // Given
        let family = try createTestFamily(name: "Admin Removal Family", code: "ADMREM1")
        let admin = try createTestUser(displayName: "Leaving Admin", appleUserIdHash: "leaving_admin_hash")
        let adminMembership = try dataService.createMembership(family: family, user: admin, role: .parentAdmin)
        
        XCTAssertTrue(family.hasParentAdmin)
        XCTAssertEqual(family.parentAdmin?.id, adminMembership.id)
        
        // When
        try dataService.removeMembership(adminMembership)
        
        // Then
        XCTAssertEqual(adminMembership.status, .removed)
        XCTAssertFalse(family.hasParentAdmin) // Family should no longer have parent admin
        XCTAssertNil(family.parentAdmin)
        
        // Verify active members count
        XCTAssertEqual(family.activeMembers.count, 0)
    }
    
    func testRemoveMembershipFromFamilyWithMultipleMembers() throws {
        // Given
        let family = try createTestFamily(name: "Multi Member Family", code: "MULTI01")
        let admin = try createTestUser(displayName: "Admin", appleUserIdHash: "admin_hash")
        let member1 = try createTestUser(displayName: "Member 1", appleUserIdHash: "member1_hash")
        let member2 = try createTestUser(displayName: "Member 2", appleUserIdHash: "member2_hash")
        
        let adminMembership = try dataService.createMembership(family: family, user: admin, role: .parentAdmin)
        let membership1 = try dataService.createMembership(family: family, user: member1, role: .adult)
        let membership2 = try dataService.createMembership(family: family, user: member2, role: .kid)
        
        XCTAssertEqual(family.activeMembers.count, 3)
        
        // When - remove one member
        try dataService.removeMembership(membership1)
        
        // Then
        XCTAssertEqual(membership1.status, .removed)
        XCTAssertEqual(adminMembership.status, .active)
        XCTAssertEqual(membership2.status, .active)
        
        // Verify active members count
        XCTAssertEqual(family.activeMembers.count, 2)
        
        let activeMemberships = try dataService.fetchActiveMemberships(forFamily: family)
        XCTAssertEqual(activeMemberships.count, 2)
        
        let activeMembershipIds = Set(activeMemberships.map { $0.id })
        XCTAssertTrue(activeMembershipIds.contains(adminMembership.id))
        XCTAssertTrue(activeMembershipIds.contains(membership2.id))
        XCTAssertFalse(activeMembershipIds.contains(membership1.id))
    }
    
    func testRemoveAlreadyRemovedMembership() throws {
        // Given
        let family = try createTestFamily(name: "Already Removed Family", code: "ALRREM1")
        let user = try createTestUser(displayName: "User", appleUserIdHash: "user_hash")
        let membership = try dataService.createMembership(family: family, user: user, role: .kid)
        
        // Remove membership first time
        try dataService.removeMembership(membership)
        XCTAssertEqual(membership.status, .removed)
        
        // Reset sync flag to test it gets set again
        membership.needsSync = false
        
        // When - remove again
        try dataService.removeMembership(membership)
        
        // Then - should still be removed and marked for sync
        XCTAssertEqual(membership.status, .removed)
        XCTAssertTrue(membership.needsSync)
    }
    
    // MARK: - Fetch Active Memberships Tests
    
    func testFetchActiveMembershipsWithMixedStatuses() throws {
        // Given
        let family = try createTestFamily(name: "Mixed Status Family", code: "MIXED01")
        let user1 = try createTestUser(displayName: "Active User", appleUserIdHash: "active_hash")
        let user2 = try createTestUser(displayName: "Removed User", appleUserIdHash: "removed_hash")
        let user3 = try createTestUser(displayName: "Another Active User", appleUserIdHash: "active2_hash")
        
        let activeMembership1 = try dataService.createMembership(family: family, user: user1, role: .parentAdmin)
        let removedMembership = try dataService.createMembership(family: family, user: user2, role: .adult)
        let activeMembership2 = try dataService.createMembership(family: family, user: user3, role: .kid)
        
        // Remove one membership
        try dataService.removeMembership(removedMembership)
        
        // When
        let activeMemberships = try dataService.fetchActiveMemberships(forFamily: family)
        
        // Then
        XCTAssertEqual(activeMemberships.count, 2)
        
        let activeMembershipIds = Set(activeMemberships.map { $0.id })
        XCTAssertTrue(activeMembershipIds.contains(activeMembership1.id))
        XCTAssertTrue(activeMembershipIds.contains(activeMembership2.id))
        XCTAssertFalse(activeMembershipIds.contains(removedMembership.id))
        
        // Verify all returned memberships are active
        for membership in activeMemberships {
            XCTAssertEqual(membership.status, .active)
        }
    }
    
    func testFetchActiveMembershipsEmptyFamily() throws {
        // Given
        let family = try createTestFamily(name: "Empty Family", code: "EMPTY01")
        
        // When
        let activeMemberships = try dataService.fetchActiveMemberships(forFamily: family)
        
        // Then
        XCTAssertEqual(activeMemberships.count, 0)
    }
    
    func testFetchActiveMembershipsAllRemoved() throws {
        // Given
        let family = try createTestFamily(name: "All Removed Family", code: "ALLREM1")
        let user1 = try createTestUser(displayName: "User 1", appleUserIdHash: "user1_hash")
        let user2 = try createTestUser(displayName: "User 2", appleUserIdHash: "user2_hash")
        
        let membership1 = try dataService.createMembership(family: family, user: user1, role: .parentAdmin)
        let membership2 = try dataService.createMembership(family: family, user: user2, role: .kid)
        
        // Remove all memberships
        try dataService.removeMembership(membership1)
        try dataService.removeMembership(membership2)
        
        // When
        let activeMemberships = try dataService.fetchActiveMemberships(forFamily: family)
        
        // Then
        XCTAssertEqual(activeMemberships.count, 0)
        
        // Verify all memberships still exist but are removed
        let allMemberships = try dataService.fetchMemberships(forFamily: family)
        XCTAssertEqual(allMemberships.count, 2)
        for membership in allMemberships {
            XCTAssertEqual(membership.status, .removed)
        }
    }
    
    // MARK: - Complex Workflow Tests
    
    func testCompleteUserJoinAndLeaveWorkflow() throws {
        // Given
        let family = try createTestFamily(name: "Workflow Family", code: "WORK01")
        let user = try createTestUser(displayName: "Workflow User", appleUserIdHash: "workflow_hash")
        
        // When - user joins as kid
        let membership = try dataService.createMembership(family: family, user: user, role: .kid)
        XCTAssertEqual(membership.role, .kid)
        XCTAssertEqual(membership.status, .active)
        XCTAssertEqual(family.activeMembers.count, 1)
        
        // User gets promoted to adult
        try dataService.updateMembershipRole(membership, to: .adult)
        XCTAssertEqual(membership.role, .adult)
        XCTAssertNotNil(membership.lastRoleChangeAt)
        
        // User becomes parent admin
        try dataService.updateMembershipRole(membership, to: .parentAdmin)
        XCTAssertEqual(membership.role, .parentAdmin)
        XCTAssertTrue(family.hasParentAdmin)
        
        // User leaves family
        try dataService.removeMembership(membership)
        XCTAssertEqual(membership.status, .removed)
        XCTAssertFalse(family.hasParentAdmin)
        XCTAssertEqual(family.activeMembers.count, 0)
        
        // Then - verify final state
        let activeMemberships = try dataService.fetchActiveMemberships(forFamily: family)
        XCTAssertEqual(activeMemberships.count, 0)
        
        let allMemberships = try dataService.fetchMemberships(forFamily: family)
        XCTAssertEqual(allMemberships.count, 1)
        XCTAssertEqual(allMemberships.first?.status, .removed)
    }
    
    func testFamilyAdminTransitionWorkflow() throws {
        // Given
        let family = try createTestFamily(name: "Admin Transition Family", code: "TRANS01")
        let oldAdmin = try createTestUser(displayName: "Old Admin", appleUserIdHash: "old_admin_hash")
        let newAdmin = try createTestUser(displayName: "New Admin", appleUserIdHash: "new_admin_hash")
        
        // Create old admin and new member
        let oldAdminMembership = try dataService.createMembership(family: family, user: oldAdmin, role: .parentAdmin)
        let newMemberMembership = try dataService.createMembership(family: family, user: newAdmin, role: .adult)
        
        XCTAssertTrue(family.hasParentAdmin)
        XCTAssertEqual(family.parentAdmin?.id, oldAdminMembership.id)
        
        // When - transition admin role
        // Step 1: Demote old admin
        try dataService.updateMembershipRole(oldAdminMembership, to: .adult)
        XCTAssertFalse(family.hasParentAdmin)
        
        // Step 2: Promote new admin
        try dataService.updateMembershipRole(newMemberMembership, to: .parentAdmin)
        XCTAssertTrue(family.hasParentAdmin)
        XCTAssertEqual(family.parentAdmin?.id, newMemberMembership.id)
        
        // Then - verify final state
        XCTAssertEqual(oldAdminMembership.role, .adult)
        XCTAssertEqual(newMemberMembership.role, .parentAdmin)
        XCTAssertEqual(family.activeMembers.count, 2)
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testAdvancedOperationsWithInvalidMembership() throws {
        // Given
        let family = try createTestFamily(name: "Invalid Membership Family", code: "INVALID")
        let user = try createTestUser(displayName: "User", appleUserIdHash: "user_hash")
        let membership = try dataService.createMembership(family: family, user: user, role: .kid)
        
        // Manually break the membership by removing relationships
        membership.family = nil
        
        // When & Then - operations should handle invalid membership gracefully
        XCTAssertThrowsError(try dataService.updateMembershipRole(membership, to: .adult)) { error in
            guard let dataServiceError = error as? DataServiceError else {
                XCTFail("Expected DataServiceError")
                return
            }
            
            switch dataServiceError {
            case .validationFailed(let messages):
                XCTAssertTrue(messages.contains { $0.contains("Invalid membership") || $0.contains("no family") })
            default:
                XCTFail("Expected validation failed error")
            }
        }
    }
    
    func testConcurrentMembershipOperations() throws {
        // Given
        let family = try createTestFamily(name: "Concurrent Family", code: "CONCUR1")
        let user1 = try createTestUser(displayName: "User 1", appleUserIdHash: "user1_hash")
        let user2 = try createTestUser(displayName: "User 2", appleUserIdHash: "user2_hash")
        
        let membership1 = try dataService.createMembership(family: family, user: user1, role: .adult)
        let membership2 = try dataService.createMembership(family: family, user: user2, role: .kid)
        
        // When - perform multiple operations
        try dataService.updateMembershipRole(membership1, to: .parentAdmin)
        try dataService.updateMembershipRole(membership2, to: .adult)
        try dataService.removeMembership(membership2)
        
        // Then - verify final state is consistent
        XCTAssertEqual(membership1.role, .parentAdmin)
        XCTAssertEqual(membership1.status, .active)
        XCTAssertEqual(membership2.role, .adult) // Role change should persist even after removal
        XCTAssertEqual(membership2.status, .removed)
        
        XCTAssertTrue(family.hasParentAdmin)
        XCTAssertEqual(family.activeMembers.count, 1)
    }
}