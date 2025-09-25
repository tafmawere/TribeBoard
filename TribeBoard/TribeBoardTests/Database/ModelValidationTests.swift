import XCTest
import SwiftData
@testable import TribeBoard

/// Comprehensive tests for model validation methods and business rules
@MainActor
final class ModelValidationTests: DatabaseTestBase {
    
    // MARK: - Family Model Validation Tests
    
    func testFamilyNameValidation_ValidNames() throws {
        // Test minimum valid length (2 characters)
        let family1 = Family(name: "AB", code: "TEST123", createdByUserId: UUID())
        XCTAssertTrue(family1.isNameValid, "2-character name should be valid")
        
        // Test normal length name
        let family2 = Family(name: "Test Family", code: "TEST123", createdByUserId: UUID())
        XCTAssertTrue(family2.isNameValid, "Normal length name should be valid")
        
        // Test maximum valid length (50 characters)
        let maxLengthName = String(repeating: "A", count: 50)
        let family3 = Family(name: maxLengthName, code: "TEST123", createdByUserId: UUID())
        XCTAssertTrue(family3.isNameValid, "50-character name should be valid")
        
        // Test name with spaces (should be valid after trimming)
        let family4 = Family(name: "  Valid Name  ", code: "TEST123", createdByUserId: UUID())
        XCTAssertTrue(family4.isNameValid, "Name with leading/trailing spaces should be valid after trimming")
    }
    
    func testFamilyNameValidation_InvalidNames() throws {
        // Test empty name
        let family1 = Family(name: "", code: "TEST123", createdByUserId: UUID())
        XCTAssertFalse(family1.isNameValid, "Empty name should be invalid")
        
        // Test name with only whitespace
        let family2 = Family(name: "   ", code: "TEST123", createdByUserId: UUID())
        XCTAssertFalse(family2.isNameValid, "Whitespace-only name should be invalid")
        
        // Test too short name (1 character)
        let family3 = Family(name: "A", code: "TEST123", createdByUserId: UUID())
        XCTAssertFalse(family3.isNameValid, "1-character name should be invalid")
        
        // Test too long name (51 characters)
        let tooLongName = String(repeating: "A", count: 51)
        let family4 = Family(name: tooLongName, code: "TEST123", createdByUserId: UUID())
        XCTAssertFalse(family4.isNameValid, "51-character name should be invalid")
    }
    
    func testFamilyCodeValidation_ValidCodes() throws {
        // Test minimum valid length (6 characters)
        let family1 = Family(name: "Test Family", code: "ABC123", createdByUserId: UUID())
        XCTAssertTrue(family1.isCodeValid, "6-character alphanumeric code should be valid")
        
        // Test normal length code (7 characters)
        let family2 = Family(name: "Test Family", code: "TEST123", createdByUserId: UUID())
        XCTAssertTrue(family2.isCodeValid, "7-character alphanumeric code should be valid")
        
        // Test maximum valid length (8 characters)
        let family3 = Family(name: "Test Family", code: "ABCD1234", createdByUserId: UUID())
        XCTAssertTrue(family3.isCodeValid, "8-character alphanumeric code should be valid")
        
        // Test letters only
        let family4 = Family(name: "Test Family", code: "ABCDEF", createdByUserId: UUID())
        XCTAssertTrue(family4.isCodeValid, "Letters-only code should be valid")
        
        // Test numbers only
        let family5 = Family(name: "Test Family", code: "123456", createdByUserId: UUID())
        XCTAssertTrue(family5.isCodeValid, "Numbers-only code should be valid")
        
        // Test mixed case
        let family6 = Family(name: "Test Family", code: "AbC123", createdByUserId: UUID())
        XCTAssertTrue(family6.isCodeValid, "Mixed case alphanumeric code should be valid")
    }
    
    func testFamilyCodeValidation_InvalidCodes() throws {
        // Test empty code
        let family1 = Family(name: "Test Family", code: "", createdByUserId: UUID())
        XCTAssertFalse(family1.isCodeValid, "Empty code should be invalid")
        
        // Test too short code (5 characters)
        let family2 = Family(name: "Test Family", code: "ABC12", createdByUserId: UUID())
        XCTAssertFalse(family2.isCodeValid, "5-character code should be invalid")
        
        // Test too long code (9 characters)
        let family3 = Family(name: "Test Family", code: "ABCD12345", createdByUserId: UUID())
        XCTAssertFalse(family3.isCodeValid, "9-character code should be invalid")
        
        // Test code with special characters
        let family4 = Family(name: "Test Family", code: "ABC-123", createdByUserId: UUID())
        XCTAssertFalse(family4.isCodeValid, "Code with special characters should be invalid")
        
        // Test code with spaces
        let family5 = Family(name: "Test Family", code: "ABC 123", createdByUserId: UUID())
        XCTAssertFalse(family5.isCodeValid, "Code with spaces should be invalid")
        
        // Test code with symbols
        let family6 = Family(name: "Test Family", code: "ABC@123", createdByUserId: UUID())
        XCTAssertFalse(family6.isCodeValid, "Code with symbols should be invalid")
    }
    
    func testFamilyIsFullyValid_ValidCombinations() throws {
        // Test fully valid family
        let family1 = Family(name: "Test Family", code: "TEST123", createdByUserId: UUID())
        XCTAssertTrue(family1.isFullyValid, "Family with valid name, code, and user ID should be fully valid")
        
        // Test with minimum valid values
        let family2 = Family(name: "AB", code: "ABC123", createdByUserId: UUID())
        XCTAssertTrue(family2.isFullyValid, "Family with minimum valid values should be fully valid")
        
        // Test with maximum valid values
        let maxName = String(repeating: "A", count: 50)
        let family3 = Family(name: maxName, code: "ABCD1234", createdByUserId: UUID())
        XCTAssertTrue(family3.isFullyValid, "Family with maximum valid values should be fully valid")
    }
    
    func testFamilyIsFullyValid_InvalidCombinations() throws {
        // Test with invalid name
        let family1 = Family(name: "", code: "TEST123", createdByUserId: UUID())
        XCTAssertFalse(family1.isFullyValid, "Family with invalid name should not be fully valid")
        
        // Test with invalid code
        let family2 = Family(name: "Test Family", code: "T1", createdByUserId: UUID())
        XCTAssertFalse(family2.isFullyValid, "Family with invalid code should not be fully valid")
        
        // Test with both invalid name and code
        let family3 = Family(name: "", code: "T1", createdByUserId: UUID())
        XCTAssertFalse(family3.isFullyValid, "Family with invalid name and code should not be fully valid")
    }
    
    func testFamilyHasParentAdmin_WithParentAdmin() throws {
        // Create family and users
        let family = try createTestFamily()
        let parentUser = try createTestUser(displayName: "Parent User")
        let kidUser = try createTestUser(displayName: "Kid User")
        
        // Create parent admin membership
        let parentMembership = Membership(family: family, user: parentUser, role: .parentAdmin)
        testContext.insert(parentMembership)
        
        // Create kid membership
        let kidMembership = Membership(family: family, user: kidUser, role: .kid)
        testContext.insert(kidMembership)
        
        try saveContext()
        
        // Test that family has parent admin
        XCTAssertTrue(family.hasParentAdmin, "Family should have parent admin")
        XCTAssertNotNil(family.parentAdmin, "Family should return parent admin membership")
        XCTAssertEqual(family.parentAdmin?.role, .parentAdmin, "Parent admin should have correct role")
    }
    
    func testFamilyHasParentAdmin_WithoutParentAdmin() throws {
        // Create family and users
        let family = try createTestFamily()
        let adultUser = try createTestUser(displayName: "Adult User")
        let kidUser = try createTestUser(displayName: "Kid User")
        
        // Create non-parent admin memberships
        let adultMembership = Membership(family: family, user: adultUser, role: .adult)
        testContext.insert(adultMembership)
        
        let kidMembership = Membership(family: family, user: kidUser, role: .kid)
        testContext.insert(kidMembership)
        
        try saveContext()
        
        // Test that family doesn't have parent admin
        XCTAssertFalse(family.hasParentAdmin, "Family should not have parent admin")
        XCTAssertNil(family.parentAdmin, "Family should not return parent admin membership")
    }
    
    func testFamilyHasParentAdmin_WithInactiveParentAdmin() throws {
        // Create family and user
        let family = try createTestFamily()
        let parentUser = try createTestUser(displayName: "Parent User")
        
        // Create inactive parent admin membership
        let parentMembership = Membership(family: family, user: parentUser, role: .parentAdmin)
        parentMembership.status = .removed
        testContext.insert(parentMembership)
        
        try saveContext()
        
        // Test that family doesn't have active parent admin
        XCTAssertFalse(family.hasParentAdmin, "Family should not have active parent admin")
        XCTAssertNil(family.parentAdmin, "Family should not return inactive parent admin")
    }
    
    func testFamilyActiveMembers_OnlyActiveMembers() throws {
        // Create family and users
        let family = try createTestFamily()
        let activeUser1 = try createTestUser(displayName: "Active User 1")
        let activeUser2 = try createTestUser(displayName: "Active User 2")
        let removedUser = try createTestUser(displayName: "Removed User")
        let invitedUser = try createTestUser(displayName: "Invited User")
        
        // Create memberships with different statuses
        let activeMembership1 = Membership(family: family, user: activeUser1, role: .adult)
        activeMembership1.status = .active
        testContext.insert(activeMembership1)
        
        let activeMembership2 = Membership(family: family, user: activeUser2, role: .kid)
        activeMembership2.status = .active
        testContext.insert(activeMembership2)
        
        let removedMembership = Membership(family: family, user: removedUser, role: .kid)
        removedMembership.status = .removed
        testContext.insert(removedMembership)
        
        let invitedMembership = Membership(family: family, user: invitedUser, role: .visitor)
        invitedMembership.status = .invited
        testContext.insert(invitedMembership)
        
        try saveContext()
        
        // Test that only active members are returned
        let activeMembers = family.activeMembers
        XCTAssertEqual(activeMembers.count, 2, "Should return only active members")
        
        let activeMemberIds = Set(activeMembers.compactMap { $0.user?.id })
        XCTAssertTrue(activeMemberIds.contains(activeUser1.id), "Should include active user 1")
        XCTAssertTrue(activeMemberIds.contains(activeUser2.id), "Should include active user 2")
        XCTAssertFalse(activeMemberIds.contains(removedUser.id), "Should not include removed user")
        XCTAssertFalse(activeMemberIds.contains(invitedUser.id), "Should not include invited user")
    }
    
    func testFamilyActiveMembers_EmptyWhenNoActiveMembers() throws {
        // Create family and user with inactive membership
        let family = try createTestFamily()
        let user = try createTestUser()
        
        let membership = Membership(family: family, user: user, role: .kid)
        membership.status = .removed
        testContext.insert(membership)
        
        try saveContext()
        
        // Test that no active members are returned
        let activeMembers = family.activeMembers
        XCTAssertEqual(activeMembers.count, 0, "Should return no active members when all are inactive")
    }
    
    func testFamilyActiveMembers_EmptyWhenNoMemberships() throws {
        // Create family with no memberships
        let family = try createTestFamily()
        
        // Test that no active members are returned
        let activeMembers = family.activeMembers
        XCTAssertEqual(activeMembers.count, 0, "Should return no active members when no memberships exist")
    }
    
    // MARK: - UserProfile Model Validation Tests
    
    func testUserProfileDisplayNameValidation_ValidNames() throws {
        // Test minimum valid length (1 character)
        let user1 = UserProfile(displayName: "A", appleUserIdHash: "test_hash_1234567890")
        XCTAssertTrue(user1.isDisplayNameValid, "1-character display name should be valid")
        
        // Test normal length name
        let user2 = UserProfile(displayName: "Test User", appleUserIdHash: "test_hash_1234567890")
        XCTAssertTrue(user2.isDisplayNameValid, "Normal length display name should be valid")
        
        // Test maximum valid length (50 characters)
        let maxLengthName = String(repeating: "A", count: 50)
        let user3 = UserProfile(displayName: maxLengthName, appleUserIdHash: "test_hash_1234567890")
        XCTAssertTrue(user3.isDisplayNameValid, "50-character display name should be valid")
        
        // Test name with spaces (should be valid after trimming)
        let user4 = UserProfile(displayName: "  Valid Name  ", appleUserIdHash: "test_hash_1234567890")
        XCTAssertTrue(user4.isDisplayNameValid, "Display name with leading/trailing spaces should be valid after trimming")
        
        // Test name with special characters
        let user5 = UserProfile(displayName: "User-Name_123", appleUserIdHash: "test_hash_1234567890")
        XCTAssertTrue(user5.isDisplayNameValid, "Display name with special characters should be valid")
        
        // Test name with emoji
        let user6 = UserProfile(displayName: "🙂 Emoji User", appleUserIdHash: "test_hash_1234567890")
        XCTAssertTrue(user6.isDisplayNameValid, "Display name with emoji should be valid")
        
        // Test name with accented characters
        let user7 = UserProfile(displayName: "Ñoñó Àccénts", appleUserIdHash: "test_hash_1234567890")
        XCTAssertTrue(user7.isDisplayNameValid, "Display name with accented characters should be valid")
    }
    
    func testUserProfileDisplayNameValidation_InvalidNames() throws {
        // Test empty name
        let user1 = UserProfile(displayName: "", appleUserIdHash: "test_hash_1234567890")
        XCTAssertFalse(user1.isDisplayNameValid, "Empty display name should be invalid")
        
        // Test name with only whitespace
        let user2 = UserProfile(displayName: "   ", appleUserIdHash: "test_hash_1234567890")
        XCTAssertFalse(user2.isDisplayNameValid, "Whitespace-only display name should be invalid")
        
        // Test too long name (51 characters)
        let tooLongName = String(repeating: "A", count: 51)
        let user3 = UserProfile(displayName: tooLongName, appleUserIdHash: "test_hash_1234567890")
        XCTAssertFalse(user3.isDisplayNameValid, "51-character display name should be invalid")
    }
    
    func testUserProfileAppleUserIdHashValidation_ValidHashes() throws {
        // Test minimum valid length (10 characters)
        let user1 = UserProfile(displayName: "Test User", appleUserIdHash: "1234567890")
        XCTAssertTrue(user1.isAppleUserIdHashValid, "10-character hash should be valid")
        
        // Test normal length hash
        let user2 = UserProfile(displayName: "Test User", appleUserIdHash: "test_hash_1234567890")
        XCTAssertTrue(user2.isAppleUserIdHashValid, "Normal length hash should be valid")
        
        // Test very long hash
        let longHash = String(repeating: "A", count: 100)
        let user3 = UserProfile(displayName: "Test User", appleUserIdHash: longHash)
        XCTAssertTrue(user3.isAppleUserIdHashValid, "Very long hash should be valid")
        
        // Test hash with underscores
        let user4 = UserProfile(displayName: "Test User", appleUserIdHash: "hash_with_underscores_123456789")
        XCTAssertTrue(user4.isAppleUserIdHashValid, "Hash with underscores should be valid")
        
        // Test hash with dashes
        let user5 = UserProfile(displayName: "Test User", appleUserIdHash: "hash-with-dashes-123456789")
        XCTAssertTrue(user5.isAppleUserIdHashValid, "Hash with dashes should be valid")
        
        // Test uppercase hash
        let user6 = UserProfile(displayName: "Test User", appleUserIdHash: "UPPERCASE_HASH_123456789")
        XCTAssertTrue(user6.isAppleUserIdHashValid, "Uppercase hash should be valid")
        
        // Test lowercase hash
        let user7 = UserProfile(displayName: "Test User", appleUserIdHash: "lowercase_hash_123456789")
        XCTAssertTrue(user7.isAppleUserIdHashValid, "Lowercase hash should be valid")
        
        // Test mixed case hash
        let user8 = UserProfile(displayName: "Test User", appleUserIdHash: "MiXeD_cAsE_hAsH_123456789")
        XCTAssertTrue(user8.isAppleUserIdHashValid, "Mixed case hash should be valid")
    }
    
    func testUserProfileAppleUserIdHashValidation_InvalidHashes() throws {
        // Test empty hash
        let user1 = UserProfile(displayName: "Test User", appleUserIdHash: "")
        XCTAssertFalse(user1.isAppleUserIdHashValid, "Empty hash should be invalid")
        
        // Test too short hash (9 characters)
        let user2 = UserProfile(displayName: "Test User", appleUserIdHash: "123456789")
        XCTAssertFalse(user2.isAppleUserIdHashValid, "9-character hash should be invalid")
        
        // Test very short hash
        let user3 = UserProfile(displayName: "Test User", appleUserIdHash: "short")
        XCTAssertFalse(user3.isAppleUserIdHashValid, "Very short hash should be invalid")
    }
    
    func testUserProfileIsFullyValid_ValidCombinations() throws {
        // Test fully valid user profile
        let user1 = UserProfile(displayName: "Test User", appleUserIdHash: "test_hash_1234567890")
        XCTAssertTrue(user1.isFullyValid, "User with valid display name and hash should be fully valid")
        
        // Test with minimum valid values
        let user2 = UserProfile(displayName: "A", appleUserIdHash: "1234567890")
        XCTAssertTrue(user2.isFullyValid, "User with minimum valid values should be fully valid")
        
        // Test with maximum valid display name
        let maxName = String(repeating: "A", count: 50)
        let user3 = UserProfile(displayName: maxName, appleUserIdHash: "test_hash_1234567890")
        XCTAssertTrue(user3.isFullyValid, "User with maximum valid display name should be fully valid")
        
        // Test with avatar URL
        let avatarURL = URL(string: "https://example.com/avatar.jpg")
        let user4 = UserProfile(displayName: "Test User", appleUserIdHash: "test_hash_1234567890", avatarUrl: avatarURL)
        XCTAssertTrue(user4.isFullyValid, "User with avatar URL should be fully valid")
    }
    
    func testUserProfileIsFullyValid_InvalidCombinations() throws {
        // Test with invalid display name
        let user1 = UserProfile(displayName: "", appleUserIdHash: "test_hash_1234567890")
        XCTAssertFalse(user1.isFullyValid, "User with invalid display name should not be fully valid")
        
        // Test with invalid hash
        let user2 = UserProfile(displayName: "Test User", appleUserIdHash: "short")
        XCTAssertFalse(user2.isFullyValid, "User with invalid hash should not be fully valid")
        
        // Test with both invalid display name and hash
        let user3 = UserProfile(displayName: "", appleUserIdHash: "short")
        XCTAssertFalse(user3.isFullyValid, "User with invalid display name and hash should not be fully valid")
    }
    
    func testUserProfileActiveMemberships_OnlyActiveMembers() throws {
        // Create user and families
        let user = try createTestUser()
        let family1 = try createTestFamily(name: "Family 1", code: "FAM001", createdByUserId: UUID())
        let family2 = try createTestFamily(name: "Family 2", code: "FAM002", createdByUserId: UUID())
        let family3 = try createTestFamily(name: "Family 3", code: "FAM003", createdByUserId: UUID())
        
        // Create memberships with different statuses
        let activeMembership1 = Membership(family: family1, user: user, role: .adult)
        activeMembership1.status = .active
        testContext.insert(activeMembership1)
        
        let activeMembership2 = Membership(family: family2, user: user, role: .kid)
        activeMembership2.status = .active
        testContext.insert(activeMembership2)
        
        let removedMembership = Membership(family: family3, user: user, role: .visitor)
        removedMembership.status = .removed
        testContext.insert(removedMembership)
        
        try saveContext()
        
        // Test that only active memberships are returned
        let activeMemberships = user.activeMemberships
        XCTAssertEqual(activeMemberships.count, 2, "Should return only active memberships")
        
        let activeFamilyIds = Set(activeMemberships.compactMap { $0.family?.id })
        XCTAssertTrue(activeFamilyIds.contains(family1.id), "Should include membership in family 1")
        XCTAssertTrue(activeFamilyIds.contains(family2.id), "Should include membership in family 2")
        XCTAssertFalse(activeFamilyIds.contains(family3.id), "Should not include removed membership")
    }
    
    func testUserProfileActiveMemberships_EmptyWhenNoActiveMembers() throws {
        // Create user and family with inactive membership
        let user = try createTestUser()
        let family = try createTestFamily()
        
        let membership = Membership(family: family, user: user, role: .kid)
        membership.status = .removed
        testContext.insert(membership)
        
        try saveContext()
        
        // Test that no active memberships are returned
        let activeMemberships = user.activeMemberships
        XCTAssertEqual(activeMemberships.count, 0, "Should return no active memberships when all are inactive")
    }
    
    func testUserProfileActiveMemberships_EmptyWhenNoMemberships() throws {
        // Create user with no memberships
        let user = try createTestUser()
        
        // Test that no active memberships are returned
        let activeMemberships = user.activeMemberships
        XCTAssertEqual(activeMemberships.count, 0, "Should return no active memberships when no memberships exist")
    }
    
    func testUserProfileCurrentFamilyMembership_ReturnsFirstActive() throws {
        // Create user and families
        let user = try createTestUser()
        let family1 = try createTestFamily(name: "Family 1", code: "FAM001", createdByUserId: UUID())
        let family2 = try createTestFamily(name: "Family 2", code: "FAM002", createdByUserId: UUID())
        
        // Create active memberships (first one should be returned)
        let membership1 = Membership(family: family1, user: user, role: .adult)
        membership1.status = .active
        testContext.insert(membership1)
        
        let membership2 = Membership(family: family2, user: user, role: .kid)
        membership2.status = .active
        testContext.insert(membership2)
        
        try saveContext()
        
        // Test that first active membership is returned
        let currentMembership = user.currentFamilyMembership
        XCTAssertNotNil(currentMembership, "Should return current family membership")
        
        // Note: The exact membership returned depends on the order, but it should be one of the active ones
        let returnedFamilyId = currentMembership?.family?.id
        XCTAssertTrue(
            returnedFamilyId == family1.id || returnedFamilyId == family2.id,
            "Should return one of the active memberships"
        )
    }
    
    func testUserProfileCurrentFamilyMembership_NilWhenNoActiveMembers() throws {
        // Create user and family with inactive membership
        let user = try createTestUser()
        let family = try createTestFamily()
        
        let membership = Membership(family: family, user: user, role: .kid)
        membership.status = .removed
        testContext.insert(membership)
        
        try saveContext()
        
        // Test that no current membership is returned
        let currentMembership = user.currentFamilyMembership
        XCTAssertNil(currentMembership, "Should return nil when no active memberships exist")
    }
    
    func testUserProfileCurrentFamilyMembership_NilWhenNoMemberships() throws {
        // Create user with no memberships
        let user = try createTestUser()
        
        // Test that no current membership is returned
        let currentMembership = user.currentFamilyMembership
        XCTAssertNil(currentMembership, "Should return nil when no memberships exist")
    }    
 
   // MARK: - Membership Model Validation Tests
    
    func testMembershipRelationshipValidation_ValidRelationships() throws {
        // Create family and user
        let family = try createTestFamily()
        let user = try createTestUser()
        
        // Create membership with valid relationships
        let membership = Membership(family: family, user: user, role: .kid)
        testContext.insert(membership)
        try saveContext()
        
        // Test that membership is valid with proper relationships
        XCTAssertTrue(membership.isValid, "Membership with valid family and user should be valid")
        XCTAssertTrue(membership.isFullyValid, "Membership with valid relationships should be fully valid")
        XCTAssertNotNil(membership.family, "Membership should have family relationship")
        XCTAssertNotNil(membership.user, "Membership should have user relationship")
        XCTAssertEqual(membership.family?.id, family.id, "Membership should reference correct family")
        XCTAssertEqual(membership.user?.id, user.id, "Membership should reference correct user")
    }
    
    func testMembershipRelationshipValidation_InvalidRelationships() throws {
        // Create membership without relationships
        let membership = Membership(family: Family(name: "Test", code: "TEST123", createdByUserId: UUID()), 
                                  user: UserProfile(displayName: "Test", appleUserIdHash: "test_hash_1234567890"), 
                                  role: .kid)
        
        // Clear relationships to simulate invalid state
        membership.family = nil
        membership.user = nil
        
        // Test that membership is invalid without relationships
        XCTAssertFalse(membership.isValid, "Membership without family should be invalid")
        XCTAssertFalse(membership.isFullyValid, "Membership without relationships should not be fully valid")
        
        // Test with only family
        let family = try createTestFamily()
        membership.family = family
        XCTAssertFalse(membership.isValid, "Membership without user should be invalid")
        
        // Test with only user
        membership.family = nil
        let user = try createTestUser()
        membership.user = user
        XCTAssertFalse(membership.isValid, "Membership without family should be invalid")
    }
    
    func testMembershipRoleValidation_AllRoles() throws {
        let family = try createTestFamily()
        let user = try createTestUser()
        
        // Test all valid roles
        for role in Role.allCases {
            let membership = Membership(family: family, user: user, role: role)
            testContext.insert(membership)
            
            XCTAssertEqual(membership.role, role, "Membership should have correct role: \(role)")
            XCTAssertTrue(membership.isValid, "Membership with role \(role) should be valid")
            
            // Clean up for next iteration
            testContext.delete(membership)
        }
    }
    
    func testMembershipStatusValidation_AllStatuses() throws {
        let family = try createTestFamily()
        let user = try createTestUser()
        
        // Test all valid statuses
        let statuses: [MembershipStatus] = [.active, .invited, .removed]
        for status in statuses {
            let membership = Membership(family: family, user: user, role: .kid)
            membership.status = status
            testContext.insert(membership)
            
            XCTAssertEqual(membership.status, status, "Membership should have correct status: \(status)")
            XCTAssertTrue(membership.isValid, "Membership with status \(status) should be valid")
            
            // Test status-specific properties
            if status == .active {
                XCTAssertTrue(membership.isActive, "Active membership should return true for isActive")
            } else {
                XCTAssertFalse(membership.isActive, "Non-active membership should return false for isActive")
            }
            
            // Clean up for next iteration
            testContext.delete(membership)
        }
    }
    
    func testMembershipCanChangeRole_ValidRoleChanges() throws {
        let family = try createTestFamily()
        let user = try createTestUser()
        
        // Test changing from kid to adult (should be allowed)
        let membership1 = Membership(family: family, user: user, role: .kid)
        testContext.insert(membership1)
        try saveContext()
        
        XCTAssertTrue(membership1.canChangeRole(to: .adult, in: family), "Should allow changing from kid to adult")
        XCTAssertTrue(membership1.canChangeRole(to: .visitor, in: family), "Should allow changing from kid to visitor")
        
        // Test changing from adult to kid (should be allowed)
        membership1.role = .adult
        XCTAssertTrue(membership1.canChangeRole(to: .kid, in: family), "Should allow changing from adult to kid")
        XCTAssertTrue(membership1.canChangeRole(to: .visitor, in: family), "Should allow changing from adult to visitor")
        
        // Clean up
        testContext.delete(membership1)
        try saveContext()
    }
    
    func testMembershipCanChangeRole_ToParentAdminWhenNoneExists() throws {
        let family = try createTestFamily()
        let user = try createTestUser()
        
        // Create membership without existing parent admin
        let membership = Membership(family: family, user: user, role: .adult)
        testContext.insert(membership)
        try saveContext()
        
        // Should allow changing to parent admin when none exists
        XCTAssertTrue(membership.canChangeRole(to: .parentAdmin, in: family), 
                     "Should allow changing to parent admin when none exists")
    }
    
    func testMembershipCanChangeRole_ToParentAdminWhenOneExists() throws {
        let family = try createTestFamily()
        let parentUser = try createTestUser(displayName: "Parent User")
        let adultUser = try createTestUser(displayName: "Adult User")
        
        // Create existing parent admin
        let parentMembership = Membership(family: family, user: parentUser, role: .parentAdmin)
        testContext.insert(parentMembership)
        
        // Create adult membership
        let adultMembership = Membership(family: family, user: adultUser, role: .adult)
        testContext.insert(adultMembership)
        
        try saveContext()
        
        // Should not allow changing to parent admin when one already exists
        XCTAssertFalse(adultMembership.canChangeRole(to: .parentAdmin, in: family), 
                      "Should not allow changing to parent admin when one already exists")
    }
    
    func testMembershipCanChangeRole_ToSameRole() throws {
        let family = try createTestFamily()
        let user = try createTestUser()
        
        // Create membership
        let membership = Membership(family: family, user: user, role: .adult)
        testContext.insert(membership)
        try saveContext()
        
        // Should not allow changing to same role
        XCTAssertFalse(membership.canChangeRole(to: .adult, in: family), 
                      "Should not allow changing to same role")
    }
    
    func testMembershipCanChangeRole_FromParentAdminToOtherRoles() throws {
        let family = try createTestFamily()
        let user = try createTestUser()
        
        // Create parent admin membership
        let membership = Membership(family: family, user: user, role: .parentAdmin)
        testContext.insert(membership)
        try saveContext()
        
        // Should allow changing from parent admin to other roles
        XCTAssertTrue(membership.canChangeRole(to: .adult, in: family), 
                     "Should allow changing from parent admin to adult")
        XCTAssertTrue(membership.canChangeRole(to: .kid, in: family), 
                     "Should allow changing from parent admin to kid")
        XCTAssertTrue(membership.canChangeRole(to: .visitor, in: family), 
                     "Should allow changing from parent admin to visitor")
    }
    
    func testMembershipComputedProperties_FamilyAndUserIds() throws {
        let family = try createTestFamily()
        let user = try createTestUser()
        
        // Create membership
        let membership = Membership(family: family, user: user, role: .kid)
        testContext.insert(membership)
        try saveContext()
        
        // Test computed properties
        XCTAssertEqual(membership.familyId, family.id, "familyId should return correct family ID")
        XCTAssertEqual(membership.userId, user.id, "userId should return correct user ID")
    }
    
    func testMembershipComputedProperties_DisplayNames() throws {
        let family = try createTestFamily(name: "Test Family")
        let user = try createTestUser(displayName: "Test User")
        
        // Create membership
        let membership = Membership(family: family, user: user, role: .kid)
        testContext.insert(membership)
        try saveContext()
        
        // Test display name properties
        XCTAssertEqual(membership.userDisplayName, "Test User", "userDisplayName should return correct user display name")
        XCTAssertEqual(membership.familyName, "Test Family", "familyName should return correct family name")
    }
    
    func testMembershipComputedProperties_WithNilRelationships() throws {
        // Create membership with nil relationships
        let membership = Membership(family: Family(name: "Test", code: "TEST123", createdByUserId: UUID()), 
                                  user: UserProfile(displayName: "Test", appleUserIdHash: "test_hash_1234567890"), 
                                  role: .kid)
        membership.family = nil
        membership.user = nil
        
        // Test computed properties with nil relationships
        XCTAssertNil(membership.familyId, "familyId should return nil when family is nil")
        XCTAssertNil(membership.userId, "userId should return nil when user is nil")
        XCTAssertEqual(membership.userDisplayName, "Unknown User", "userDisplayName should return default when user is nil")
        XCTAssertEqual(membership.familyName, "Unknown Family", "familyName should return default when family is nil")
    }
    
    func testMembershipIsParentAdmin_Property() throws {
        let family = try createTestFamily()
        let user = try createTestUser()
        
        // Test parent admin role
        let parentMembership = Membership(family: family, user: user, role: .parentAdmin)
        XCTAssertTrue(parentMembership.isParentAdmin, "Parent admin membership should return true for isParentAdmin")
        
        // Test non-parent admin roles
        for role in Role.allCases where role != .parentAdmin {
            let membership = Membership(family: family, user: user, role: role)
            XCTAssertFalse(membership.isParentAdmin, "Non-parent admin membership (\(role)) should return false for isParentAdmin")
        }
    }
    
    func testMembershipUpdateRole_ValidUpdate() throws {
        let family = try createTestFamily()
        let user = try createTestUser()
        
        // Create membership
        let membership = Membership(family: family, user: user, role: .kid)
        testContext.insert(membership)
        try saveContext()
        
        let originalChangeDate = membership.lastRoleChangeAt
        
        // Update role
        membership.updateRole(to: .adult)
        
        // Test that role was updated
        XCTAssertEqual(membership.role, .adult, "Role should be updated to adult")
        XCTAssertNotNil(membership.lastRoleChangeAt, "lastRoleChangeAt should be set")
        XCTAssertNotEqual(membership.lastRoleChangeAt, originalChangeDate, "lastRoleChangeAt should be updated")
        XCTAssertTrue(membership.needsSync, "needsSync should be set to true after role update")
    }
    
    func testMembershipUpdateRole_SameRole() throws {
        let family = try createTestFamily()
        let user = try createTestUser()
        
        // Create membership
        let membership = Membership(family: family, user: user, role: .adult)
        testContext.insert(membership)
        try saveContext()
        
        let originalChangeDate = membership.lastRoleChangeAt
        
        // Try to update to same role
        membership.updateRole(to: .adult)
        
        // Test that nothing changed
        XCTAssertEqual(membership.role, .adult, "Role should remain adult")
        XCTAssertEqual(membership.lastRoleChangeAt, originalChangeDate, "lastRoleChangeAt should not change")
    }
    
    func testMembershipRemove_SoftDelete() throws {
        let family = try createTestFamily()
        let user = try createTestUser()
        
        // Create active membership
        let membership = Membership(family: family, user: user, role: .kid)
        membership.status = .active
        testContext.insert(membership)
        try saveContext()
        
        // Remove membership
        membership.remove()
        
        // Test that membership was soft deleted
        XCTAssertEqual(membership.status, .removed, "Status should be set to removed")
        XCTAssertFalse(membership.isActive, "Membership should not be active after removal")
        XCTAssertTrue(membership.needsSync, "needsSync should be set to true after removal")
    }
    
    func testMembershipActivate_RestoresMembership() throws {
        let family = try createTestFamily()
        let user = try createTestUser()
        
        // Create removed membership
        let membership = Membership(family: family, user: user, role: .kid)
        membership.status = .removed
        testContext.insert(membership)
        try saveContext()
        
        // Activate membership
        membership.activate()
        
        // Test that membership was activated
        XCTAssertEqual(membership.status, .active, "Status should be set to active")
        XCTAssertTrue(membership.isActive, "Membership should be active after activation")
        XCTAssertTrue(membership.needsSync, "needsSync should be set to true after activation")
    }
}