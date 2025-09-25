import XCTest
import SwiftData
@testable import TribeBoard

/// Tests for basic CRUD operations in DataService
@MainActor
final class DataServiceCRUDTests: DatabaseTestBase {
    
    // MARK: - Family CRUD Tests
    
    func testCreateFamilyWithValidData() throws {
        // Given
        let name = "Test Family"
        let code = "TEST123"
        let createdByUserId = UUID()
        
        // When
        let family = try dataService.createFamily(name: name, code: code, createdByUserId: createdByUserId)
        
        // Then
        XCTAssertNotNil(family.id)
        XCTAssertEqual(family.name, name)
        XCTAssertEqual(family.code, code)
        XCTAssertEqual(family.createdByUserId, createdByUserId)
        XCTAssertTrue(family.isFullyValid)
        XCTAssertTrue(family.needsSync)
        XCTAssertNotNil(family.createdAt)
        
        // Verify it was saved to database
        try assertRecordCount(Family.self, expectedCount: 1)
        
        let savedFamily = try dataService.fetchFamily(byCode: code)
        XCTAssertNotNil(savedFamily)
        XCTAssertEqual(savedFamily?.id, family.id)
    }
    
    func testFetchFamilyByCodeExisting() throws {
        // Given
        let testFamily = try createTestFamily(name: "Existing Family", code: "EXIST01", createdByUserId: UUID())
        
        // When
        let fetchedFamily = try dataService.fetchFamily(byCode: "EXIST01")
        
        // Then
        XCTAssertNotNil(fetchedFamily)
        XCTAssertEqual(fetchedFamily?.id, testFamily.id)
        XCTAssertEqual(fetchedFamily?.name, "Existing Family")
        XCTAssertEqual(fetchedFamily?.code, "EXIST01")
    }
    
    func testFetchFamilyByCodeNonExisting() throws {
        // Given - no families in database
        
        // When
        let fetchedFamily = try dataService.fetchFamily(byCode: "NONEXIST")
        
        // Then
        XCTAssertNil(fetchedFamily)
    }
    
    func testFetchFamilyByIdExisting() throws {
        // Given
        let testFamily = try createTestFamily(name: "Existing Family", code: "EXIST02", createdByUserId: UUID())
        
        // When
        let fetchedFamily = try dataService.fetchFamily(byId: testFamily.id)
        
        // Then
        XCTAssertNotNil(fetchedFamily)
        XCTAssertEqual(fetchedFamily?.id, testFamily.id)
        XCTAssertEqual(fetchedFamily?.name, "Existing Family")
        XCTAssertEqual(fetchedFamily?.code, "EXIST02")
    }
    
    func testFetchFamilyByIdNonExisting() throws {
        // Given
        let nonExistentId = UUID()
        
        // When
        let fetchedFamily = try dataService.fetchFamily(byId: nonExistentId)
        
        // Then
        XCTAssertNil(fetchedFamily)
    }
    
    func testFetchFamilyByCodeWithEmptyCode() throws {
        // Given
        let emptyCode = ""
        
        // When & Then
        XCTAssertThrowsError(try dataService.fetchFamily(byCode: emptyCode)) { error in
            guard let dataServiceError = error as? DataServiceError else {
                XCTFail("Expected DataServiceError")
                return
            }
            
            switch dataServiceError {
            case .invalidData(let message):
                XCTAssertTrue(message.contains("cannot be empty"))
            default:
                XCTFail("Expected invalidData error")
            }
        }
    }
    
    // MARK: - UserProfile CRUD Tests
    
    func testCreateUserProfileWithValidData() throws {
        // Given
        let displayName = "Test User"
        let appleUserIdHash = "test_hash_1234567890"
        let avatarUrl = URL(string: "https://example.com/avatar.jpg")
        
        // When
        let userProfile = try dataService.createUserProfile(
            displayName: displayName,
            appleUserIdHash: appleUserIdHash,
            avatarUrl: avatarUrl
        )
        
        // Then
        XCTAssertNotNil(userProfile.id)
        XCTAssertEqual(userProfile.displayName, displayName)
        XCTAssertEqual(userProfile.appleUserIdHash, appleUserIdHash)
        XCTAssertEqual(userProfile.avatarUrl, avatarUrl)
        XCTAssertTrue(userProfile.isFullyValid)
        XCTAssertTrue(userProfile.needsSync)
        XCTAssertNotNil(userProfile.createdAt)
        
        // Verify it was saved to database
        try assertRecordCount(UserProfile.self, expectedCount: 1)
        
        let savedUser = try dataService.fetchUserProfile(byAppleUserIdHash: appleUserIdHash)
        XCTAssertNotNil(savedUser)
        XCTAssertEqual(savedUser?.id, userProfile.id)
    }
    
    func testCreateUserProfileWithoutAvatarUrl() throws {
        // Given
        let displayName = "Test User No Avatar"
        let appleUserIdHash = "test_hash_no_avatar_123"
        
        // When
        let userProfile = try dataService.createUserProfile(
            displayName: displayName,
            appleUserIdHash: appleUserIdHash
        )
        
        // Then
        XCTAssertNotNil(userProfile.id)
        XCTAssertEqual(userProfile.displayName, displayName)
        XCTAssertEqual(userProfile.appleUserIdHash, appleUserIdHash)
        XCTAssertNil(userProfile.avatarUrl)
        XCTAssertTrue(userProfile.isFullyValid)
    }
    
    func testFetchUserProfileByAppleUserIdHashExisting() throws {
        // Given
        let testUser = try createTestUser(displayName: "Existing User", appleUserIdHash: "existing_hash_123")
        
        // When
        let fetchedUser = try dataService.fetchUserProfile(byAppleUserIdHash: "existing_hash_123")
        
        // Then
        XCTAssertNotNil(fetchedUser)
        XCTAssertEqual(fetchedUser?.id, testUser.id)
        XCTAssertEqual(fetchedUser?.displayName, "Existing User")
        XCTAssertEqual(fetchedUser?.appleUserIdHash, "existing_hash_123")
    }
    
    func testFetchUserProfileByAppleUserIdHashNonExisting() throws {
        // Given - no users in database
        
        // When
        let fetchedUser = try dataService.fetchUserProfile(byAppleUserIdHash: "nonexistent_hash")
        
        // Then
        XCTAssertNil(fetchedUser)
    }
    
    func testFetchUserProfileByIdExisting() throws {
        // Given
        let testUser = try createTestUser(displayName: "Existing User", appleUserIdHash: "existing_hash_456")
        
        // When
        let fetchedUser = try dataService.fetchUserProfile(byId: testUser.id)
        
        // Then
        XCTAssertNotNil(fetchedUser)
        XCTAssertEqual(fetchedUser?.id, testUser.id)
        XCTAssertEqual(fetchedUser?.displayName, "Existing User")
        XCTAssertEqual(fetchedUser?.appleUserIdHash, "existing_hash_456")
    }
    
    func testFetchUserProfileByIdNonExisting() throws {
        // Given
        let nonExistentId = UUID()
        
        // When
        let fetchedUser = try dataService.fetchUserProfile(byId: nonExistentId)
        
        // Then
        XCTAssertNil(fetchedUser)
    }
    
    func testFetchUserProfileByAppleUserIdHashWithEmptyHash() throws {
        // Given
        let emptyHash = ""
        
        // When & Then
        XCTAssertThrowsError(try dataService.fetchUserProfile(byAppleUserIdHash: emptyHash)) { error in
            guard let dataServiceError = error as? DataServiceError else {
                XCTFail("Expected DataServiceError")
                return
            }
            
            switch dataServiceError {
            case .invalidData(let message):
                XCTAssertTrue(message.contains("cannot be empty"))
            default:
                XCTFail("Expected invalidData error")
            }
        }
    }
    
    // MARK: - Membership CRUD Tests
    
    func testCreateMembershipWithValidRelationships() throws {
        // Given
        let family = try createTestFamily(name: "Test Family", code: "MEMBER01", createdByUserId: UUID())
        let user = try createTestUser(displayName: "Test User", appleUserIdHash: "member_hash_123")
        let role = Role.kid
        
        // When
        let membership = try dataService.createMembership(family: family, user: user, role: role)
        
        // Then
        XCTAssertNotNil(membership.id)
        XCTAssertEqual(membership.role, role)
        XCTAssertEqual(membership.status, .active)
        XCTAssertEqual(membership.family?.id, family.id)
        XCTAssertEqual(membership.user?.id, user.id)
        XCTAssertTrue(membership.isFullyValid)
        XCTAssertTrue(membership.needsSync)
        XCTAssertNotNil(membership.joinedAt)
        
        // Verify it was saved to database
        try assertRecordCount(Membership.self, expectedCount: 1)
        
        // Verify relationships work both ways
        let familyMemberships = try dataService.fetchMemberships(forFamily: family)
        XCTAssertEqual(familyMemberships.count, 1)
        XCTAssertEqual(familyMemberships.first?.id, membership.id)
        
        let userMemberships = try dataService.fetchMemberships(forUser: user)
        XCTAssertEqual(userMemberships.count, 1)
        XCTAssertEqual(userMemberships.first?.id, membership.id)
    }
    
    func testCreateMembershipWithParentAdminRole() throws {
        // Given
        let family = try createTestFamily(name: "Admin Family", code: "ADMIN01", createdByUserId: UUID())
        let user = try createTestUser(displayName: "Admin User", appleUserIdHash: "admin_hash_123")
        let role = Role.parentAdmin
        
        // When
        let membership = try dataService.createMembership(family: family, user: user, role: role)
        
        // Then
        XCTAssertEqual(membership.role, .parentAdmin)
        XCTAssertTrue(membership.isParentAdmin)
        XCTAssertTrue(family.hasParentAdmin)
        
        // Verify parent admin relationship
        XCTAssertEqual(family.parentAdmin?.id, membership.id)
    }
    
    func testCreateMembershipWithDifferentRoles() throws {
        // Given
        let family = try createTestFamily(name: "Multi Role Family", code: "MULTI01", createdByUserId: UUID())
        let roles: [Role] = [.parentAdmin, .adult, .kid, .visitor]
        var createdMemberships: [Membership] = []
        
        // When & Then
        for (index, role) in roles.enumerated() {
            let user = try createTestUser(
                displayName: "\(role.displayName) User",
                appleUserIdHash: "role_hash_\(index)"
            )
            
            let membership = try dataService.createMembership(family: family, user: user, role: role)
            createdMemberships.append(membership)
            
            XCTAssertEqual(membership.role, role)
            XCTAssertEqual(membership.userDisplayName, "\(role.displayName) User")
            XCTAssertEqual(membership.familyName, "Multi Role Family")
        }
        
        // Verify all memberships were created
        try assertRecordCount(Membership.self, expectedCount: roles.count)
        
        let familyMemberships = try dataService.fetchMemberships(forFamily: family)
        XCTAssertEqual(familyMemberships.count, roles.count)
    }
    
    func testFetchMembershipsForFamily() throws {
        // Given
        let family = try createTestFamily(name: "Family With Members", code: "FWMEM01", createdByUserId: UUID())
        let user1 = try createTestUser(displayName: "User 1", appleUserIdHash: "user1_hash")
        let user2 = try createTestUser(displayName: "User 2", appleUserIdHash: "user2_hash")
        
        let membership1 = try dataService.createMembership(family: family, user: user1, role: .parentAdmin)
        let membership2 = try dataService.createMembership(family: family, user: user2, role: .kid)
        
        // When
        let memberships = try dataService.fetchMemberships(forFamily: family)
        
        // Then
        XCTAssertEqual(memberships.count, 2)
        
        let membershipIds = Set(memberships.map { $0.id })
        XCTAssertTrue(membershipIds.contains(membership1.id))
        XCTAssertTrue(membershipIds.contains(membership2.id))
        
        // Verify roles
        let parentAdmin = memberships.first { $0.role == .parentAdmin }
        let kid = memberships.first { $0.role == .kid }
        
        XCTAssertNotNil(parentAdmin)
        XCTAssertNotNil(kid)
        XCTAssertEqual(parentAdmin?.user?.id, user1.id)
        XCTAssertEqual(kid?.user?.id, user2.id)
    }
    
    func testFetchMembershipsForUser() throws {
        // Given
        let user = try createTestUser(displayName: "Multi Family User", appleUserIdHash: "multi_user_hash")
        let family1 = try createTestFamily(name: "Family 1", code: "FAM001", createdByUserId: UUID())
        let family2 = try createTestFamily(name: "Family 2", code: "FAM002", createdByUserId: UUID())
        
        let membership1 = try dataService.createMembership(family: family1, user: user, role: .adult)
        let membership2 = try dataService.createMembership(family: family2, user: user, role: .visitor)
        
        // When
        let memberships = try dataService.fetchMemberships(forUser: user)
        
        // Then
        XCTAssertEqual(memberships.count, 2)
        
        let membershipIds = Set(memberships.map { $0.id })
        XCTAssertTrue(membershipIds.contains(membership1.id))
        XCTAssertTrue(membershipIds.contains(membership2.id))
        
        // Verify families
        let family1Membership = memberships.first { $0.family?.id == family1.id }
        let family2Membership = memberships.first { $0.family?.id == family2.id }
        
        XCTAssertNotNil(family1Membership)
        XCTAssertNotNil(family2Membership)
        XCTAssertEqual(family1Membership?.role, .adult)
        XCTAssertEqual(family2Membership?.role, .visitor)
    }
    
    func testFetchMembershipsForEmptyFamily() throws {
        // Given
        let family = try createTestFamily(name: "Empty Family", code: "EMPTY01", createdByUserId: UUID())
        
        // When
        let memberships = try dataService.fetchMemberships(forFamily: family)
        
        // Then
        XCTAssertEqual(memberships.count, 0)
    }
    
    func testFetchMembershipsForUserWithNoMemberships() throws {
        // Given
        let user = try createTestUser(displayName: "Lonely User", appleUserIdHash: "lonely_hash")
        
        // When
        let memberships = try dataService.fetchMemberships(forUser: user)
        
        // Then
        XCTAssertEqual(memberships.count, 0)
    }
    
    // MARK: - Computed Properties Tests
    
    func testFamilyComputedProperties() throws {
        // Given
        let family = try createTestFamily(name: "Computed Family", code: "COMP01", createdByUserId: UUID())
        let user1 = try createTestUser(displayName: "Parent", appleUserIdHash: "parent_hash")
        let user2 = try createTestUser(displayName: "Child", appleUserIdHash: "child_hash")
        let user3 = try createTestUser(displayName: "Removed User", appleUserIdHash: "removed_hash")
        
        let parentMembership = try dataService.createMembership(family: family, user: user1, role: .parentAdmin)
        let childMembership = try dataService.createMembership(family: family, user: user2, role: .kid)
        let removedMembership = try dataService.createMembership(family: family, user: user3, role: .adult)
        
        // Remove one membership
        try dataService.removeMembership(removedMembership)
        
        // When & Then
        XCTAssertTrue(family.hasParentAdmin)
        XCTAssertEqual(family.parentAdmin?.id, parentMembership.id)
        
        let activeMembers = family.activeMembers
        XCTAssertEqual(activeMembers.count, 2)
        
        let activeMemberIds = Set(activeMembers.map { $0.id })
        XCTAssertTrue(activeMemberIds.contains(parentMembership.id))
        XCTAssertTrue(activeMemberIds.contains(childMembership.id))
        XCTAssertFalse(activeMemberIds.contains(removedMembership.id))
    }
    
    func testUserProfileComputedProperties() throws {
        // Given
        let user = try createTestUser(displayName: "Active User", appleUserIdHash: "active_user_hash")
        let family1 = try createTestFamily(name: "Active Family", code: "ACTIVE1", createdByUserId: UUID())
        let family2 = try createTestFamily(name: "Inactive Family", code: "INACTIVE", createdByUserId: UUID())
        
        let activeMembership = try dataService.createMembership(family: family1, user: user, role: .adult)
        let inactiveMembership = try dataService.createMembership(family: family2, user: user, role: .visitor)
        
        // Remove one membership
        try dataService.removeMembership(inactiveMembership)
        
        // When & Then
        let activeMemberships = user.activeMemberships
        XCTAssertEqual(activeMemberships.count, 1)
        XCTAssertEqual(activeMemberships.first?.id, activeMembership.id)
        
        let currentFamilyMembership = user.currentFamilyMembership
        XCTAssertNotNil(currentFamilyMembership)
        XCTAssertEqual(currentFamilyMembership?.id, activeMembership.id)
        XCTAssertEqual(currentFamilyMembership?.family?.id, family1.id)
    }
    
    func testMembershipComputedProperties() throws {
        // Given
        let family = try createTestFamily(name: "Property Family", code: "PROP01", createdByUserId: UUID())
        let user = try createTestUser(displayName: "Property User", appleUserIdHash: "prop_user_hash")
        let membership = try dataService.createMembership(family: family, user: user, role: .adult)
        
        // When & Then
        XCTAssertEqual(membership.familyId, family.id)
        XCTAssertEqual(membership.userId, user.id)
        XCTAssertEqual(membership.userDisplayName, "Property User")
        XCTAssertEqual(membership.familyName, "Property Family")
        XCTAssertTrue(membership.isValid)
        XCTAssertTrue(membership.isActive)
        XCTAssertFalse(membership.isParentAdmin)
        XCTAssertTrue(membership.isFullyValid)
    }
    
    // MARK: - Edge Cases
    
    func testCreateFamilyWithUnicodeCharacters() throws {
        // Given
        let name = "Família Tëst 🏠"
        let code = "UNICODE1"
        let createdByUserId = UUID()
        
        // When
        let family = try dataService.createFamily(name: name, code: code, createdByUserId: createdByUserId)
        
        // Then
        XCTAssertEqual(family.name, name)
        XCTAssertTrue(family.isFullyValid)
        
        // Verify it can be fetched
        let fetchedFamily = try dataService.fetchFamily(byCode: code)
        XCTAssertNotNil(fetchedFamily)
        XCTAssertEqual(fetchedFamily?.name, name)
    }
    
    func testCreateUserProfileWithUnicodeCharacters() throws {
        // Given
        let displayName = "Ñoñó Àccénts 🙂"
        let appleUserIdHash = "unicode_hash_1234567890"
        
        // When
        let userProfile = try dataService.createUserProfile(displayName: displayName, appleUserIdHash: appleUserIdHash)
        
        // Then
        XCTAssertEqual(userProfile.displayName, displayName)
        XCTAssertTrue(userProfile.isFullyValid)
        
        // Verify it can be fetched
        let fetchedUser = try dataService.fetchUserProfile(byAppleUserIdHash: appleUserIdHash)
        XCTAssertNotNil(fetchedUser)
        XCTAssertEqual(fetchedUser?.displayName, displayName)
    }
}