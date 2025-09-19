import XCTest
import SwiftData
@testable import TribeBoard

/// Tests for business rule enforcement and constraint validation in DataService
@MainActor
final class DataServiceConstraintTests: DatabaseTestBase {
    
    // MARK: - Family Code Uniqueness Constraint Tests
    
    func testCreateFamilyWithDuplicateCodeFails() throws {
        // Given
        let familyName1 = "First Family"
        let familyName2 = "Second Family"
        let duplicateCode = "DUPLIC8"
        let createdByUserId1 = UUID()
        let createdByUserId2 = UUID()
        
        // Create first family successfully
        let firstFamily = try dataService.createFamily(name: familyName1, code: duplicateCode, createdByUserId: createdByUserId1)
        XCTAssertEqual(firstFamily.code, duplicateCode)
        
        // When & Then - attempt to create second family with same code should fail
        XCTAssertThrowsError(try dataService.createFamily(name: familyName2, code: duplicateCode, createdByUserId: createdByUserId2)) { error in
            guard let dataServiceError = error as? DataServiceError else {
                XCTFail("Expected DataServiceError, got \(type(of: error))")
                return
            }
            
            switch dataServiceError {
            case .validationFailed(let messages):
                XCTAssertTrue(messages.contains { $0.contains("already exists") }, "Error should mention code already exists")
            default:
                XCTFail("Expected validation failed error, got \(dataServiceError)")
            }
        }
        
        // Verify only one family was created
        try assertRecordCount(Family.self, expectedCount: 1)
        
        // Verify the existing family is unchanged
        let existingFamily = try dataService.fetchFamily(byCode: duplicateCode)
        XCTAssertNotNil(existingFamily)
        XCTAssertEqual(existingFamily?.name, familyName1)
        XCTAssertEqual(existingFamily?.id, firstFamily.id)
    }
    
    func testFamilyCodeUniquenessAcrossMultipleFamilies() throws {
        // Given
        let codes = ["UNIQUE1", "UNIQUE2", "UNIQUE3"]
        var createdFamilies: [Family] = []
        
        // Create multiple families with unique codes
        for (index, code) in codes.enumerated() {
            let family = try dataService.createFamily(
                name: "Family \(index + 1)",
                code: code,
                createdByUserId: UUID()
            )
            createdFamilies.append(family)
        }
        
        // Verify all families were created
        try assertRecordCount(Family.self, expectedCount: codes.count)
        
        // When & Then - attempt to create family with any existing code should fail
        for existingCode in codes {
            XCTAssertThrowsError(try dataService.createFamily(name: "Duplicate Family", code: existingCode, createdByUserId: UUID())) { error in
                guard let dataServiceError = error as? DataServiceError else {
                    XCTFail("Expected DataServiceError")
                    return
                }
                
                switch dataServiceError {
                case .validationFailed(let messages):
                    XCTAssertTrue(messages.contains { $0.contains("already exists") })
                default:
                    XCTFail("Expected validation failed error")
                }
            }
        }
        
        // Verify no additional families were created
        try assertRecordCount(Family.self, expectedCount: codes.count)
    }
    
    func testFamilyCodeCaseSensitivity() throws {
        // Given
        let baseCode = "CASE123"
        let lowerCode = "case123"
        
        // Create family with uppercase code
        let upperFamily = try dataService.createFamily(name: "Upper Family", code: baseCode, createdByUserId: UUID())
        XCTAssertEqual(upperFamily.code, baseCode)
        
        // When & Then - attempt to create family with lowercase version of same code
        // This should succeed since codes are case-sensitive
        let lowerFamily = try dataService.createFamily(name: "Lower Family", code: lowerCode, createdByUserId: UUID())
        XCTAssertEqual(lowerFamily.code, lowerCode)
        
        // Verify both families exist
        try assertRecordCount(Family.self, expectedCount: 2)
        
        let fetchedUpper = try dataService.fetchFamily(byCode: baseCode)
        let fetchedLower = try dataService.fetchFamily(byCode: lowerCode)
        
        XCTAssertNotNil(fetchedUpper)
        XCTAssertNotNil(fetchedLower)
        XCTAssertNotEqual(fetchedUpper?.id, fetchedLower?.id)
    }
    
    // MARK: - Parent Admin Uniqueness Constraint Tests
    
    func testCreateSecondParentAdminInSameFamilyFails() throws {
        // Given
        let family = try createTestFamily(name: "Admin Family", code: "ADMIN01")
        let firstAdmin = try createTestUser(displayName: "First Admin", appleUserIdHash: "first_admin_hash")
        let secondAdmin = try createTestUser(displayName: "Second Admin", appleUserIdHash: "second_admin_hash")
        
        // Create first parent admin successfully
        let firstMembership = try dataService.createMembership(family: family, user: firstAdmin, role: .parentAdmin)
        XCTAssertEqual(firstMembership.role, .parentAdmin)
        XCTAssertTrue(family.hasParentAdmin)
        
        // When & Then - attempt to create second parent admin should fail
        XCTAssertThrowsError(try dataService.createMembership(family: family, user: secondAdmin, role: .parentAdmin)) { error in
            guard let dataServiceError = error as? DataServiceError else {
                XCTFail("Expected DataServiceError, got \(type(of: error))")
                return
            }
            
            switch dataServiceError {
            case .constraintViolation(let message):
                XCTAssertTrue(message.contains("Parent Admin already exists"), "Error should mention parent admin constraint")
            default:
                XCTFail("Expected constraint violation error, got \(dataServiceError)")
            }
        }
        
        // Verify only one membership was created
        let memberships = try dataService.fetchMemberships(forFamily: family)
        XCTAssertEqual(memberships.count, 1)
        XCTAssertEqual(memberships.first?.role, .parentAdmin)
        XCTAssertEqual(memberships.first?.user?.id, firstAdmin.id)
    }
    
    func testParentAdminUniquenessDifferentFamilies() throws {
        // Given
        let family1 = try createTestFamily(name: "Family 1", code: "FAM001")
        let family2 = try createTestFamily(name: "Family 2", code: "FAM002")
        let admin1 = try createTestUser(displayName: "Admin 1", appleUserIdHash: "admin1_hash")
        let admin2 = try createTestUser(displayName: "Admin 2", appleUserIdHash: "admin2_hash")
        
        // When - create parent admin in each family
        let membership1 = try dataService.createMembership(family: family1, user: admin1, role: .parentAdmin)
        let membership2 = try dataService.createMembership(family: family2, user: admin2, role: .parentAdmin)
        
        // Then - both should succeed
        XCTAssertEqual(membership1.role, .parentAdmin)
        XCTAssertEqual(membership2.role, .parentAdmin)
        XCTAssertTrue(family1.hasParentAdmin)
        XCTAssertTrue(family2.hasParentAdmin)
        
        // Verify each family has its own parent admin
        XCTAssertEqual(family1.parentAdmin?.user?.id, admin1.id)
        XCTAssertEqual(family2.parentAdmin?.user?.id, admin2.id)
    }
    
    func testSameUserAsParentAdminInDifferentFamilies() throws {
        // Given
        let family1 = try createTestFamily(name: "Family 1", code: "MULTI01")
        let family2 = try createTestFamily(name: "Family 2", code: "MULTI02")
        let admin = try createTestUser(displayName: "Multi Admin", appleUserIdHash: "multi_admin_hash")
        
        // When - same user becomes parent admin in different families
        let membership1 = try dataService.createMembership(family: family1, user: admin, role: .parentAdmin)
        let membership2 = try dataService.createMembership(family: family2, user: admin, role: .parentAdmin)
        
        // Then - both should succeed
        XCTAssertEqual(membership1.role, .parentAdmin)
        XCTAssertEqual(membership2.role, .parentAdmin)
        XCTAssertEqual(membership1.user?.id, admin.id)
        XCTAssertEqual(membership2.user?.id, admin.id)
        
        // Verify user has memberships in both families
        let userMemberships = try dataService.fetchMemberships(forUser: admin)
        XCTAssertEqual(userMemberships.count, 2)
        
        let familyIds = Set(userMemberships.compactMap { $0.family?.id })
        XCTAssertTrue(familyIds.contains(family1.id))
        XCTAssertTrue(familyIds.contains(family2.id))
    }
    
    func testCreateNonParentAdminRolesWithExistingParentAdmin() throws {
        // Given
        let family = try createTestFamily(name: "Mixed Role Family", code: "MIXED01")
        let admin = try createTestUser(displayName: "Admin", appleUserIdHash: "admin_hash")
        let adult = try createTestUser(displayName: "Adult", appleUserIdHash: "adult_hash")
        let kid = try createTestUser(displayName: "Kid", appleUserIdHash: "kid_hash")
        let visitor = try createTestUser(displayName: "Visitor", appleUserIdHash: "visitor_hash")
        
        // Create parent admin first
        let adminMembership = try dataService.createMembership(family: family, user: admin, role: .parentAdmin)
        XCTAssertEqual(adminMembership.role, .parentAdmin)
        
        // When & Then - create other roles should succeed
        let adultMembership = try dataService.createMembership(family: family, user: adult, role: .adult)
        let kidMembership = try dataService.createMembership(family: family, user: kid, role: .kid)
        let visitorMembership = try dataService.createMembership(family: family, user: visitor, role: .visitor)
        
        XCTAssertEqual(adultMembership.role, .adult)
        XCTAssertEqual(kidMembership.role, .kid)
        XCTAssertEqual(visitorMembership.role, .visitor)
        
        // Verify all memberships exist
        let familyMemberships = try dataService.fetchMemberships(forFamily: family)
        XCTAssertEqual(familyMemberships.count, 4)
        
        let roles = Set(familyMemberships.map { $0.role })
        XCTAssertEqual(roles, Set([.parentAdmin, .adult, .kid, .visitor]))
    }
    
    // MARK: - Duplicate Membership Constraint Tests
    
    func testUserCannotJoinSameFamilyTwice() throws {
        // Given
        let family = try createTestFamily(name: "Single Join Family", code: "SINGLE1")
        let user = try createTestUser(displayName: "Single User", appleUserIdHash: "single_user_hash")
        
        // Create first membership successfully
        let firstMembership = try dataService.createMembership(family: family, user: user, role: .kid)
        XCTAssertEqual(firstMembership.status, .active)
        
        // When & Then - attempt to create second membership should fail
        XCTAssertThrowsError(try dataService.createMembership(family: family, user: user, role: .adult)) { error in
            guard let dataServiceError = error as? DataServiceError else {
                XCTFail("Expected DataServiceError, got \(type(of: error))")
                return
            }
            
            switch dataServiceError {
            case .constraintViolation(let message):
                XCTAssertTrue(message.contains("already a member"), "Error should mention user is already a member")
            default:
                XCTFail("Expected constraint violation error, got \(dataServiceError)")
            }
        }
        
        // Verify only one membership exists
        let familyMemberships = try dataService.fetchMemberships(forFamily: family)
        XCTAssertEqual(familyMemberships.count, 1)
        XCTAssertEqual(familyMemberships.first?.id, firstMembership.id)
        XCTAssertEqual(familyMemberships.first?.role, .kid) // Original role preserved
    }
    
    func testUserCanJoinAfterLeavingFamily() throws {
        // Given
        let family = try createTestFamily(name: "Rejoin Family", code: "REJOIN1")
        let user = try createTestUser(displayName: "Rejoin User", appleUserIdHash: "rejoin_user_hash")
        
        // Create initial membership
        let initialMembership = try dataService.createMembership(family: family, user: user, role: .kid)
        XCTAssertEqual(initialMembership.status, .active)
        
        // Remove the membership (soft delete)
        try dataService.removeMembership(initialMembership)
        XCTAssertEqual(initialMembership.status, .removed)
        
        // When - user tries to join again
        let newMembership = try dataService.createMembership(family: family, user: user, role: .adult)
        
        // Then - should succeed
        XCTAssertEqual(newMembership.status, .active)
        XCTAssertEqual(newMembership.role, .adult)
        XCTAssertNotEqual(newMembership.id, initialMembership.id) // Different membership
        
        // Verify both memberships exist but only one is active
        let allMemberships = try dataService.fetchMemberships(forFamily: family)
        XCTAssertEqual(allMemberships.count, 2)
        
        let activeMemberships = try dataService.fetchActiveMemberships(forFamily: family)
        XCTAssertEqual(activeMemberships.count, 1)
        XCTAssertEqual(activeMemberships.first?.id, newMembership.id)
    }
    
    func testUserCanJoinMultipleDifferentFamilies() throws {
        // Given
        let family1 = try createTestFamily(name: "Family 1", code: "MULTI1")
        let family2 = try createTestFamily(name: "Family 2", code: "MULTI2")
        let family3 = try createTestFamily(name: "Family 3", code: "MULTI3")
        let user = try createTestUser(displayName: "Multi Family User", appleUserIdHash: "multi_family_hash")
        
        // When - user joins multiple families
        let membership1 = try dataService.createMembership(family: family1, user: user, role: .adult)
        let membership2 = try dataService.createMembership(family: family2, user: user, role: .kid)
        let membership3 = try dataService.createMembership(family: family3, user: user, role: .visitor)
        
        // Then - all should succeed
        XCTAssertEqual(membership1.role, .adult)
        XCTAssertEqual(membership2.role, .kid)
        XCTAssertEqual(membership3.role, .visitor)
        
        // Verify user has memberships in all families
        let userMemberships = try dataService.fetchMemberships(forUser: user)
        XCTAssertEqual(userMemberships.count, 3)
        
        let familyIds = Set(userMemberships.compactMap { $0.family?.id })
        XCTAssertTrue(familyIds.contains(family1.id))
        XCTAssertTrue(familyIds.contains(family2.id))
        XCTAssertTrue(familyIds.contains(family3.id))
    }
    
    // MARK: - Role Change Validation Tests
    
    func testCannotChangeToParentAdminWhenOneExists() throws {
        // Given
        let family = try createTestFamily(name: "Role Change Family", code: "ROLE01")
        let admin = try createTestUser(displayName: "Admin", appleUserIdHash: "admin_hash")
        let member = try createTestUser(displayName: "Member", appleUserIdHash: "member_hash")
        
        // Create parent admin and regular member
        let adminMembership = try dataService.createMembership(family: family, user: admin, role: .parentAdmin)
        let memberMembership = try dataService.createMembership(family: family, user: member, role: .kid)
        
        XCTAssertEqual(adminMembership.role, .parentAdmin)
        XCTAssertEqual(memberMembership.role, .kid)
        
        // When & Then - attempt to change member to parent admin should fail
        XCTAssertThrowsError(try dataService.updateMembershipRole(memberMembership, to: .parentAdmin)) { error in
            guard let dataServiceError = error as? DataServiceError else {
                XCTFail("Expected DataServiceError, got \(type(of: error))")
                return
            }
            
            switch dataServiceError {
            case .validationFailed(let messages):
                XCTAssertTrue(messages.contains { $0.contains("Parent Admin already exists") })
            default:
                XCTFail("Expected validation failed error, got \(dataServiceError)")
            }
        }
        
        // Verify roles remain unchanged
        XCTAssertEqual(adminMembership.role, .parentAdmin)
        XCTAssertEqual(memberMembership.role, .kid)
    }
    
    func testCanChangeToParentAdminWhenNoneExists() throws {
        // Given
        let family = try createTestFamily(name: "No Admin Family", code: "NOADMIN")
        let member = try createTestUser(displayName: "Member", appleUserIdHash: "member_hash")
        
        // Create regular member
        let membership = try dataService.createMembership(family: family, user: member, role: .adult)
        XCTAssertEqual(membership.role, .adult)
        XCTAssertFalse(family.hasParentAdmin)
        
        // When - change to parent admin
        try dataService.updateMembershipRole(membership, to: .parentAdmin)
        
        // Then - should succeed
        XCTAssertEqual(membership.role, .parentAdmin)
        XCTAssertTrue(family.hasParentAdmin)
        XCTAssertEqual(family.parentAdmin?.id, membership.id)
    }
    
    func testCanChangeFromParentAdminToOtherRole() throws {
        // Given
        let family = try createTestFamily(name: "Admin Change Family", code: "ADMINCH")
        let admin = try createTestUser(displayName: "Admin", appleUserIdHash: "admin_hash")
        
        // Create parent admin
        let adminMembership = try dataService.createMembership(family: family, user: admin, role: .parentAdmin)
        XCTAssertEqual(adminMembership.role, .parentAdmin)
        XCTAssertTrue(family.hasParentAdmin)
        
        // When - change from parent admin to adult
        try dataService.updateMembershipRole(adminMembership, to: .adult)
        
        // Then - should succeed
        XCTAssertEqual(adminMembership.role, .adult)
        XCTAssertFalse(family.hasParentAdmin)
        XCTAssertNil(family.parentAdmin)
    }
    
    func testCanChangeToSameRole() throws {
        // Given
        let family = try createTestFamily(name: "Same Role Family", code: "SAME01")
        let member = try createTestUser(displayName: "Member", appleUserIdHash: "member_hash")
        
        // Create member
        let membership = try dataService.createMembership(family: family, user: member, role: .kid)
        XCTAssertEqual(membership.role, .kid)
        
        // When & Then - attempt to change to same role should fail with validation error
        XCTAssertThrowsError(try dataService.updateMembershipRole(membership, to: .kid)) { error in
            guard let dataServiceError = error as? DataServiceError else {
                XCTFail("Expected DataServiceError, got \(type(of: error))")
                return
            }
            
            switch dataServiceError {
            case .validationFailed(let messages):
                XCTAssertTrue(messages.contains { $0.contains("already has this role") })
            default:
                XCTFail("Expected validation failed error, got \(dataServiceError)")
            }
        }
        
        // Verify role remains unchanged
        XCTAssertEqual(membership.role, .kid)
    }
    
    func testValidRoleChanges() throws {
        // Given
        let family = try createTestFamily(name: "Valid Change Family", code: "VALID01")
        let member = try createTestUser(displayName: "Member", appleUserIdHash: "member_hash")
        
        // Create member as kid
        let membership = try dataService.createMembership(family: family, user: member, role: .kid)
        XCTAssertEqual(membership.role, .kid)
        
        let validRoleChanges: [Role] = [.adult, .visitor, .parentAdmin]
        
        // When & Then - test each valid role change
        for newRole in validRoleChanges {
            try dataService.updateMembershipRole(membership, to: newRole)
            XCTAssertEqual(membership.role, newRole)
            
            // Change back to kid for next test (except for parent admin)
            if newRole != .parentAdmin {
                try dataService.updateMembershipRole(membership, to: .kid)
                XCTAssertEqual(membership.role, .kid)
            }
        }
    }
    
    // MARK: - Constraint Interaction Tests
    
    func testConstraintInteractionParentAdminAndDuplicateMembership() throws {
        // Given
        let family = try createTestFamily(name: "Interaction Family", code: "INTER01")
        let admin = try createTestUser(displayName: "Admin", appleUserIdHash: "admin_hash")
        
        // Create parent admin
        let adminMembership = try dataService.createMembership(family: family, user: admin, role: .parentAdmin)
        XCTAssertEqual(adminMembership.role, .parentAdmin)
        
        // When & Then - attempt to create duplicate membership with parent admin role should fail
        // This should fail on duplicate membership constraint before parent admin constraint
        XCTAssertThrowsError(try dataService.createMembership(family: family, user: admin, role: .parentAdmin)) { error in
            guard let dataServiceError = error as? DataServiceError else {
                XCTFail("Expected DataServiceError")
                return
            }
            
            switch dataServiceError {
            case .constraintViolation(let message):
                // Should fail on duplicate membership constraint
                XCTAssertTrue(message.contains("already a member"))
            default:
                XCTFail("Expected constraint violation error")
            }
        }
    }
    
    func testConstraintValidationOrder() throws {
        // Test that constraints are validated in the expected order
        // This helps ensure consistent error reporting
        
        let family = try createTestFamily(name: "Order Family", code: "ORDER01")
        let user = try createTestUser(displayName: "User", appleUserIdHash: "user_hash")
        
        // Create initial membership
        let membership = try dataService.createMembership(family: family, user: user, role: .kid)
        
        // Test duplicate membership constraint comes before parent admin constraint
        XCTAssertThrowsError(try dataService.createMembership(family: family, user: user, role: .parentAdmin)) { error in
            guard let dataServiceError = error as? DataServiceError else {
                XCTFail("Expected DataServiceError")
                return
            }
            
            switch dataServiceError {
            case .constraintViolation(let message):
                XCTAssertTrue(message.contains("already a member"), "Should fail on duplicate membership first")
            default:
                XCTFail("Expected constraint violation error")
            }
        }
    }
    
    // MARK: - Performance Tests for Constraint Checking
    
    func testConstraintCheckingPerformance() throws {
        // Test that constraint checking doesn't significantly impact performance
        let family = try createTestFamily(name: "Performance Family", code: "PERF01")
        let user = try createTestUser(displayName: "Performance User", appleUserIdHash: "perf_hash")
        
        measure {
            do {
                // Create membership
                let membership = try dataService.createMembership(family: family, user: user, role: .kid)
                
                // Try to create duplicate (should fail quickly)
                do {
                    _ = try dataService.createMembership(family: family, user: user, role: .adult)
                    XCTFail("Should have failed with constraint violation")
                } catch {
                    // Expected to fail
                }
                
                // Clean up
                try dataService.removeMembership(membership)
            } catch {
                XCTFail("Performance test setup failed: \(error)")
            }
        }
    }
}