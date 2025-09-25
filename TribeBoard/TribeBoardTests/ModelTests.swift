import XCTest
import SwiftData
@testable import TribeBoard

@MainActor
final class ModelTests: XCTestCase {
    
    // MARK: - Family Model Tests
    
    @MainActor func testFamilyValidation() {
        let validFamily = Family(
            name: "Valid Family",
            code: "VALID1",
            createdByUserId: UUID()
        )
        
        XCTAssertTrue(validFamily.isNameValid)
        XCTAssertTrue(validFamily.isCodeValid)
        XCTAssertTrue(validFamily.isFullyValid)
    }
    
    @MainActor func testFamilyNameValidation() {
        let shortNameFamily = Family(
            name: "A",
            code: "VALID1",
            createdByUserId: UUID()
        )
        XCTAssertFalse(shortNameFamily.isNameValid)
        
        let longNameFamily = Family(
            name: String(repeating: "A", count: 51),
            code: "VALID1",
            createdByUserId: UUID()
        )
        XCTAssertFalse(longNameFamily.isNameValid)
        
        let emptyNameFamily = Family(
            name: "",
            code: "VALID1",
            createdByUserId: UUID()
        )
        XCTAssertFalse(emptyNameFamily.isNameValid)
    }
    
    @MainActor func testFamilyCodeValidation() {
        let shortCodeFamily = Family(
            name: "Valid Family",
            code: "ABC12",
            createdByUserId: UUID()
        )
        XCTAssertFalse(shortCodeFamily.isCodeValid)
        
        let longCodeFamily = Family(
            name: "Valid Family",
            code: "ABCD12345",
            createdByUserId: UUID()
        )
        XCTAssertFalse(longCodeFamily.isCodeValid)
        
        let invalidCharFamily = Family(
            name: "Valid Family",
            code: "ABC-123",
            createdByUserId: UUID()
        )
        XCTAssertFalse(invalidCharFamily.isCodeValid)
        
        let emptyCodeFamily = Family(
            name: "Valid Family",
            code: "",
            createdByUserId: UUID()
        )
        XCTAssertFalse(emptyCodeFamily.isCodeValid)
    }
    
    // MARK: - UserProfile Model Tests
    
    @MainActor func testUserProfileValidation() {
        let validUser = UserProfile(
            displayName: "John Doe",
            appleUserIdHash: "hash123456789"
        )
        
        XCTAssertTrue(validUser.isDisplayNameValid)
        XCTAssertTrue(validUser.isAppleUserIdHashValid)
        XCTAssertTrue(validUser.isFullyValid)
    }
    
    @MainActor func testUserProfileDisplayNameValidation() {
        let emptyNameUser = UserProfile(
            displayName: "",
            appleUserIdHash: "hash123456789"
        )
        XCTAssertFalse(emptyNameUser.isDisplayNameValid)
        
        let longNameUser = UserProfile(
            displayName: String(repeating: "A", count: 51),
            appleUserIdHash: "hash123456789"
        )
        XCTAssertFalse(longNameUser.isDisplayNameValid)
        
        let whitespaceNameUser = UserProfile(
            displayName: "   ",
            appleUserIdHash: "hash123456789"
        )
        XCTAssertFalse(whitespaceNameUser.isDisplayNameValid)
    }
    
    @MainActor func testUserProfileAppleIdHashValidation() {
        let emptyHashUser = UserProfile(
            displayName: "John Doe",
            appleUserIdHash: ""
        )
        XCTAssertFalse(emptyHashUser.isAppleUserIdHashValid)
        
        let shortHashUser = UserProfile(
            displayName: "John Doe",
            appleUserIdHash: "short"
        )
        XCTAssertFalse(shortHashUser.isAppleUserIdHashValid)
    }
    
    // MARK: - Membership Model Tests
    
    @MainActor func testMembershipValidation() {
        let user = UserProfile(
            displayName: "John Doe",
            appleUserIdHash: "hash123456789"
        )
        
        let family = Family(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: user.id
        )
        
        let membership = Membership(
            family: family,
            user: user,
            role: .adult
        )
        
        XCTAssertTrue(membership.isValid)
        XCTAssertTrue(membership.isActive)
        XCTAssertTrue(membership.isFullyValid)
        XCTAssertFalse(membership.isParentAdmin)
    }
    
    @MainActor func testMembershipRoleProperties() {
        let user = UserProfile(
            displayName: "John Doe",
            appleUserIdHash: "hash123456789"
        )
        
        let family = Family(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: user.id
        )
        
        let parentAdminMembership = Membership(
            family: family,
            user: user,
            role: .parentAdmin
        )
        
        XCTAssertTrue(parentAdminMembership.isParentAdmin)
        XCTAssertEqual(parentAdminMembership.userDisplayName, "John Doe")
        XCTAssertEqual(parentAdminMembership.familyName, "Test Family")
    }
    
    @MainActor func testMembershipRoleChange() {
        let user = UserProfile(
            displayName: "John Doe",
            appleUserIdHash: "hash123456789"
        )
        
        let family = Family(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: user.id
        )
        
        let membership = Membership(
            family: family,
            user: user,
            role: .adult
        )
        
        // Test role change
        membership.updateRole(to: .kid)
        XCTAssertEqual(membership.role, .kid)
        XCTAssertNotNil(membership.lastRoleChangeAt)
        XCTAssertTrue(membership.needsSync)
    }
    
    @MainActor func testMembershipCanChangeRole() {
        let user1 = UserProfile(
            displayName: "User 1",
            appleUserIdHash: "hash1"
        )
        
        let user2 = UserProfile(
            displayName: "User 2",
            appleUserIdHash: "hash2"
        )
        
        let family = Family(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: user1.id
        )
        
        let parentAdminMembership = Membership(
            family: family,
            user: user1,
            role: .parentAdmin
        )
        
        let adultMembership = Membership(
            family: family,
            user: user2,
            role: .adult
        )
        
        // Add parent admin to family's memberships
        family.memberships.append(parentAdminMembership)
        
        // Adult should not be able to become parent admin when one exists
        XCTAssertFalse(adultMembership.canChangeRole(to: .parentAdmin, in: family))
        
        // Adult should be able to become kid
        XCTAssertTrue(adultMembership.canChangeRole(to: .kid, in: family))
        
        // Same role should return false
        XCTAssertFalse(adultMembership.canChangeRole(to: .adult, in: family))
    }
    
    @MainActor func testMembershipStatusChanges() {
        let user = UserProfile(
            displayName: "John Doe",
            appleUserIdHash: "hash123456789"
        )
        
        let family = Family(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: user.id
        )
        
        let membership = Membership(
            family: family,
            user: user,
            role: .adult
        )
        
        XCTAssertEqual(membership.status, .active)
        XCTAssertTrue(membership.isActive)
        
        // Test removal
        membership.remove()
        XCTAssertEqual(membership.status, .removed)
        XCTAssertFalse(membership.isActive)
        XCTAssertTrue(membership.needsSync)
        
        // Test activation
        membership.activate()
        XCTAssertEqual(membership.status, .active)
        XCTAssertTrue(membership.isActive)
    }
    
    // MARK: - Role Enum Tests
    
    @MainActor func testRoleDisplayNames() {
        XCTAssertEqual(Role.parentAdmin.displayName, "Parent Admin")
        XCTAssertEqual(Role.adult.displayName, "Adult")
        XCTAssertEqual(Role.kid.displayName, "Kid")
        XCTAssertEqual(Role.visitor.displayName, "Visitor")
    }
    
    @MainActor func testRoleDescriptions() {
        XCTAssertFalse(Role.parentAdmin.description.isEmpty)
        XCTAssertFalse(Role.adult.description.isEmpty)
        XCTAssertFalse(Role.kid.description.isEmpty)
        XCTAssertFalse(Role.visitor.description.isEmpty)
    }
    
    // MARK: - MembershipStatus Enum Tests
    
    @MainActor func testMembershipStatusDisplayNames() {
        XCTAssertEqual(MembershipStatus.active.displayName, "Active")
        XCTAssertEqual(MembershipStatus.invited.displayName, "Invited")
        XCTAssertEqual(MembershipStatus.removed.displayName, "Removed")
    }
    
    // MARK: - Family Relationship Tests
    
    @MainActor func testFamilyActiveMembers() {
        let user1 = UserProfile(
            displayName: "User 1",
            appleUserIdHash: "hash1"
        )
        
        let user2 = UserProfile(
            displayName: "User 2",
            appleUserIdHash: "hash2"
        )
        
        let family = Family(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: user1.id
        )
        
        let activeMembership = Membership(
            family: family,
            user: user1,
            role: .parentAdmin
        )
        
        let removedMembership = Membership(
            family: family,
            user: user2,
            role: .adult
        )
        removedMembership.remove()
        
        family.memberships = [activeMembership, removedMembership]
        
        XCTAssertEqual(family.activeMembers.count, 1)
        XCTAssertEqual(family.activeMembers.first?.user?.id, user1.id)
    }
    
    @MainActor func testFamilyParentAdmin() {
        let user1 = UserProfile(
            displayName: "User 1",
            appleUserIdHash: "hash1"
        )
        
        let user2 = UserProfile(
            displayName: "User 2",
            appleUserIdHash: "hash2"
        )
        
        let family = Family(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: user1.id
        )
        
        let parentAdminMembership = Membership(
            family: family,
            user: user1,
            role: .parentAdmin
        )
        
        let adultMembership = Membership(
            family: family,
            user: user2,
            role: .adult
        )
        
        family.memberships = [parentAdminMembership, adultMembership]
        
        XCTAssertNotNil(family.parentAdmin)
        XCTAssertTrue(family.hasParentAdmin)
        XCTAssertEqual(family.parentAdmin?.user?.id, user1.id)
    }
}