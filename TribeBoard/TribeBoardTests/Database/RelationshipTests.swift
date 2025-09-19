import XCTest
import SwiftData
@testable import TribeBoard

/// Tests for model relationship validation and cascade behaviors
@MainActor
final class RelationshipTests: DatabaseTestBase {
    
    // MARK: - Family Cascade Delete Tests
    
    /// Test that deleting Family cascades to delete all associated Memberships
    func testFamilyDeletionCascadesToMemberships() throws {
        print("🧪 Testing family deletion cascades to memberships...")
        
        // Create test data
        let family = try createTestFamily(name: "Test Family", code: "TEST123")
        let user1 = try createTestUser(displayName: "User 1", appleUserIdHash: "hash1_1234567890")
        let user2 = try createTestUser(displayName: "User 2", appleUserIdHash: "hash2_1234567890")
        
        let membership1 = try createTestMembership(family: family, user: user1, role: .parentAdmin)
        let membership2 = try createTestMembership(family: family, user: user2, role: .kid)
        
        // Verify initial state
        try assertRecordCount(Family.self, expectedCount: 1)
        try assertRecordCount(UserProfile.self, expectedCount: 2)
        try assertRecordCount(Membership.self, expectedCount: 2)
        
        // Verify relationships are established
        XCTAssertEqual(family.memberships?.count, 2, "Family should have 2 memberships")
        XCTAssertEqual(user1.memberships?.count, 1, "User1 should have 1 membership")
        XCTAssertEqual(user2.memberships?.count, 1, "User2 should have 1 membership")
        
        // Delete the family
        testContext.delete(family)
        try saveContext()
        
        // Verify cascade deletion
        try assertRecordCount(Family.self, expectedCount: 0)
        try assertRecordCount(UserProfile.self, expectedCount: 2) // Users should remain
        try assertRecordCount(Membership.self, expectedCount: 0) // Memberships should be deleted
        
        print("✅ Family deletion cascade test passed")
    }
    
    /// Test that deleting Family with multiple memberships cascades correctly
    func testFamilyDeletionWithMultipleMembersCascades() throws {
        print("🧪 Testing family deletion with multiple members cascades...")
        
        // Create family with multiple members using TestDataFactory
        let (family, users, memberships) = TestDataFactory.createFamilyWithMembers(memberCount: 5)
        
        // Insert all data
        testContext.insert(family)
        for user in users {
            testContext.insert(user)
        }
        for membership in memberships {
            testContext.insert(membership)
        }
        try saveContext()
        
        // Verify initial state
        try assertRecordCount(Family.self, expectedCount: 1)
        try assertRecordCount(UserProfile.self, expectedCount: 5)
        try assertRecordCount(Membership.self, expectedCount: 5)
        
        // Verify relationships
        XCTAssertEqual(family.memberships?.count, 5, "Family should have 5 memberships")
        
        // Delete the family
        testContext.delete(family)
        try saveContext()
        
        // Verify cascade deletion
        try assertRecordCount(Family.self, expectedCount: 0)
        try assertRecordCount(UserProfile.self, expectedCount: 5) // Users should remain
        try assertRecordCount(Membership.self, expectedCount: 0) // All memberships should be deleted
        
        print("✅ Family deletion with multiple members cascade test passed")
    }
    
    // MARK: - UserProfile Cascade Delete Tests
    
    /// Test that deleting UserProfile cascades to delete all associated Memberships
    func testUserProfileDeletionCascadesToMemberships() throws {
        print("🧪 Testing user profile deletion cascades to memberships...")
        
        // Create test data
        let family1 = try createTestFamily(name: "Family 1", code: "FAM001")
        let family2 = try createTestFamily(name: "Family 2", code: "FAM002")
        let user = try createTestUser(displayName: "Test User", appleUserIdHash: "user_hash_1234567890")
        
        let membership1 = try createTestMembership(family: family1, user: user, role: .adult)
        let membership2 = try createTestMembership(family: family2, user: user, role: .visitor)
        
        // Verify initial state
        try assertRecordCount(Family.self, expectedCount: 2)
        try assertRecordCount(UserProfile.self, expectedCount: 1)
        try assertRecordCount(Membership.self, expectedCount: 2)
        
        // Verify relationships are established
        XCTAssertEqual(user.memberships?.count, 2, "User should have 2 memberships")
        XCTAssertEqual(family1.memberships?.count, 1, "Family1 should have 1 membership")
        XCTAssertEqual(family2.memberships?.count, 1, "Family2 should have 1 membership")
        
        // Delete the user
        testContext.delete(user)
        try saveContext()
        
        // Verify cascade deletion
        try assertRecordCount(Family.self, expectedCount: 2) // Families should remain
        try assertRecordCount(UserProfile.self, expectedCount: 0)
        try assertRecordCount(Membership.self, expectedCount: 0) // Memberships should be deleted
        
        print("✅ User profile deletion cascade test passed")
    }
    
    /// Test that deleting UserProfile with multiple family memberships cascades correctly
    func testUserProfileDeletionWithMultipleFamiliesCascades() throws {
        print("🧪 Testing user profile deletion with multiple families cascades...")
        
        // Create multiple families
        let families = TestDataFactory.createFamiliesWithUniqueCodes(count: 3)
        let user = TestDataFactory.createValidUserProfile(displayName: "Multi-Family User")
        
        // Insert families and user
        for family in families {
            testContext.insert(family)
        }
        testContext.insert(user)
        
        // Create memberships for user in all families
        var memberships: [Membership] = []
        for (index, family) in families.enumerated() {
            let role: Role = index == 0 ? .parentAdmin : .kid
            let membership = TestDataFactory.createMembership(family: family, user: user, role: role)
            memberships.append(membership)
            testContext.insert(membership)
        }
        
        try saveContext()
        
        // Verify initial state
        try assertRecordCount(Family.self, expectedCount: 3)
        try assertRecordCount(UserProfile.self, expectedCount: 1)
        try assertRecordCount(Membership.self, expectedCount: 3)
        
        // Verify relationships
        XCTAssertEqual(user.memberships?.count, 3, "User should have 3 memberships")
        
        // Delete the user
        testContext.delete(user)
        try saveContext()
        
        // Verify cascade deletion
        try assertRecordCount(Family.self, expectedCount: 3) // Families should remain
        try assertRecordCount(UserProfile.self, expectedCount: 0)
        try assertRecordCount(Membership.self, expectedCount: 0) // All memberships should be deleted
        
        print("✅ User profile deletion with multiple families cascade test passed")
    }
    
    // MARK: - Membership Relationship Tests
    
    /// Test that Membership.family and Membership.user relationships work correctly
    func testMembershipRelationshipsWork() throws {
        print("🧪 Testing membership relationships work correctly...")
        
        // Create test data
        let family = try createTestFamily(name: "Relationship Family", code: "REL123")
        let user = try createTestUser(displayName: "Relationship User", appleUserIdHash: "rel_hash_1234567890")
        let membership = try createTestMembership(family: family, user: user, role: .adult)
        
        // Test membership -> family relationship
        XCTAssertNotNil(membership.family, "Membership should have a family")
        XCTAssertEqual(membership.family?.id, family.id, "Membership family should match created family")
        XCTAssertEqual(membership.family?.name, "Relationship Family", "Membership family name should be correct")
        XCTAssertEqual(membership.family?.code, "REL123", "Membership family code should be correct")
        
        // Test membership -> user relationship
        XCTAssertNotNil(membership.user, "Membership should have a user")
        XCTAssertEqual(membership.user?.id, user.id, "Membership user should match created user")
        XCTAssertEqual(membership.user?.displayName, "Relationship User", "Membership user name should be correct")
        XCTAssertEqual(membership.user?.appleUserIdHash, "rel_hash_1234567890", "Membership user hash should be correct")
        
        // Test computed properties
        XCTAssertEqual(membership.familyId, family.id, "Membership familyId should match family ID")
        XCTAssertEqual(membership.userId, user.id, "Membership userId should match user ID")
        XCTAssertEqual(membership.userDisplayName, "Relationship User", "Membership userDisplayName should be correct")
        XCTAssertEqual(membership.familyName, "Relationship Family", "Membership familyName should be correct")
        
        print("✅ Membership relationships test passed")
    }
    
    /// Test that Family.memberships and UserProfile.memberships relationships work correctly
    func testFamilyAndUserMembershipRelationshipsWork() throws {
        print("🧪 Testing family and user membership relationships work correctly...")
        
        // Create test data with multiple relationships
        let family = try createTestFamily(name: "Multi-Member Family", code: "MULTI1")
        let user1 = try createTestUser(displayName: "Parent User", appleUserIdHash: "parent_hash_1234567890")
        let user2 = try createTestUser(displayName: "Kid User", appleUserIdHash: "kid_hash_1234567890")
        let user3 = try createTestUser(displayName: "Adult User", appleUserIdHash: "adult_hash_1234567890")
        
        let membership1 = try createTestMembership(family: family, user: user1, role: .parentAdmin)
        let membership2 = try createTestMembership(family: family, user: user2, role: .kid)
        let membership3 = try createTestMembership(family: family, user: user3, role: .adult)
        
        // Test family -> memberships relationship
        XCTAssertNotNil(family.memberships, "Family should have memberships")
        XCTAssertEqual(family.memberships?.count, 3, "Family should have 3 memberships")
        
        let familyMembershipIds = Set(family.memberships?.map { $0.id } ?? [])
        let expectedMembershipIds = Set([membership1.id, membership2.id, membership3.id])
        XCTAssertEqual(familyMembershipIds, expectedMembershipIds, "Family memberships should match created memberships")
        
        // Test user -> memberships relationship
        XCTAssertNotNil(user1.memberships, "User1 should have memberships")
        XCTAssertEqual(user1.memberships?.count, 1, "User1 should have 1 membership")
        XCTAssertEqual(user1.memberships?.first?.id, membership1.id, "User1 membership should match")
        
        XCTAssertNotNil(user2.memberships, "User2 should have memberships")
        XCTAssertEqual(user2.memberships?.count, 1, "User2 should have 1 membership")
        XCTAssertEqual(user2.memberships?.first?.id, membership2.id, "User2 membership should match")
        
        XCTAssertNotNil(user3.memberships, "User3 should have memberships")
        XCTAssertEqual(user3.memberships?.count, 1, "User3 should have 1 membership")
        XCTAssertEqual(user3.memberships?.first?.id, membership3.id, "User3 membership should match")
        
        // Test computed properties
        let activeMembers = family.activeMembers
        XCTAssertEqual(activeMembers.count, 3, "Family should have 3 active members")
        
        let parentAdmin = family.parentAdmin
        XCTAssertNotNil(parentAdmin, "Family should have a parent admin")
        XCTAssertEqual(parentAdmin?.id, membership1.id, "Parent admin should be membership1")
        XCTAssertTrue(family.hasParentAdmin, "Family should have parent admin")
        
        let user1ActiveMemberships = user1.activeMemberships
        XCTAssertEqual(user1ActiveMemberships.count, 1, "User1 should have 1 active membership")
        XCTAssertEqual(user1ActiveMemberships.first?.id, membership1.id, "User1 active membership should match")
        
        print("✅ Family and user membership relationships test passed")
    }
    
    // MARK: - Complex Relationship Tests
    
    /// Test relationships with multiple families and users
    func testComplexRelationshipScenarios() throws {
        print("🧪 Testing complex relationship scenarios...")
        
        // Create multiple families and users
        let families = TestDataFactory.createFamiliesWithUniqueCodes(count: 2)
        let users = TestDataFactory.createUniqueUserProfiles(count: 3)
        
        // Insert all data
        for family in families {
            testContext.insert(family)
        }
        for user in users {
            testContext.insert(user)
        }
        
        // Create complex membership relationships
        // User 0: Member of both families (parent admin in first, adult in second)
        let membership1 = TestDataFactory.createMembership(family: families[0], user: users[0], role: .parentAdmin)
        let membership2 = TestDataFactory.createMembership(family: families[1], user: users[0], role: .adult)
        
        // User 1: Member of first family only (kid)
        let membership3 = TestDataFactory.createMembership(family: families[0], user: users[1], role: .kid)
        
        // User 2: Member of second family only (parent admin)
        let membership4 = TestDataFactory.createMembership(family: families[1], user: users[2], role: .parentAdmin)
        
        let memberships = [membership1, membership2, membership3, membership4]
        for membership in memberships {
            testContext.insert(membership)
        }
        
        try saveContext()
        
        // Verify initial state
        try assertRecordCount(Family.self, expectedCount: 2)
        try assertRecordCount(UserProfile.self, expectedCount: 3)
        try assertRecordCount(Membership.self, expectedCount: 4)
        
        // Test family relationships
        XCTAssertEqual(families[0].memberships?.count, 2, "Family 0 should have 2 memberships")
        XCTAssertEqual(families[1].memberships?.count, 2, "Family 1 should have 2 memberships")
        
        // Test user relationships
        XCTAssertEqual(users[0].memberships?.count, 2, "User 0 should have 2 memberships")
        XCTAssertEqual(users[1].memberships?.count, 1, "User 1 should have 1 membership")
        XCTAssertEqual(users[2].memberships?.count, 1, "User 2 should have 1 membership")
        
        // Test parent admin detection
        XCTAssertTrue(families[0].hasParentAdmin, "Family 0 should have parent admin")
        XCTAssertTrue(families[1].hasParentAdmin, "Family 1 should have parent admin")
        XCTAssertEqual(families[0].parentAdmin?.user?.id, users[0].id, "Family 0 parent admin should be user 0")
        XCTAssertEqual(families[1].parentAdmin?.user?.id, users[2].id, "Family 1 parent admin should be user 2")
        
        // Test active memberships
        XCTAssertEqual(users[0].activeMemberships.count, 2, "User 0 should have 2 active memberships")
        XCTAssertEqual(users[1].activeMemberships.count, 1, "User 1 should have 1 active membership")
        XCTAssertEqual(users[2].activeMemberships.count, 1, "User 2 should have 1 active membership")
        
        print("✅ Complex relationship scenarios test passed")
    }
    
    /// Test relationship integrity after partial deletions
    func testRelationshipIntegrityAfterPartialDeletions() throws {
        print("🧪 Testing relationship integrity after partial deletions...")
        
        // Create test data
        let (family, users, memberships) = TestDataFactory.createFamilyWithMembers(memberCount: 4)
        
        // Insert all data
        testContext.insert(family)
        for user in users {
            testContext.insert(user)
        }
        for membership in memberships {
            testContext.insert(membership)
        }
        try saveContext()
        
        // Verify initial state
        try assertRecordCount(Family.self, expectedCount: 1)
        try assertRecordCount(UserProfile.self, expectedCount: 4)
        try assertRecordCount(Membership.self, expectedCount: 4)
        XCTAssertEqual(family.memberships?.count, 4, "Family should have 4 memberships")
        
        // Delete one user (should cascade delete their membership)
        let userToDelete = users[2] // Third user (kid role)
        testContext.delete(userToDelete)
        try saveContext()
        
        // Verify partial deletion
        try assertRecordCount(Family.self, expectedCount: 1)
        try assertRecordCount(UserProfile.self, expectedCount: 3)
        try assertRecordCount(Membership.self, expectedCount: 3)
        
        // Verify family relationship integrity
        XCTAssertEqual(family.memberships?.count, 3, "Family should now have 3 memberships")
        XCTAssertTrue(family.hasParentAdmin, "Family should still have parent admin")
        
        // Verify remaining users still have their memberships
        for (index, user) in users.enumerated() {
            if index != 2 { // Skip the deleted user
                XCTAssertEqual(user.memberships?.count, 1, "Remaining user should still have 1 membership")
                XCTAssertEqual(user.memberships?.first?.family?.id, family.id, "User membership should still point to family")
            }
        }
        
        print("✅ Relationship integrity after partial deletions test passed")
    }
}