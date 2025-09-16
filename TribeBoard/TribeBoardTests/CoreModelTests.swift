import XCTest
import SwiftData
@testable import TribeBoard

@MainActor
final class CoreModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory container for testing
        modelContainer = try ModelContainerConfiguration.createInMemory()
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Model Creation Tests
    
    func testFamilyCreation() throws {
        let context = modelContainer.mainContext
        
        let family = Family(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: UUID()
        )
        
        context.insert(family)
        try context.save()
        
        XCTAssertTrue(family.isFullyValid)
        XCTAssertEqual(family.name, "Test Family")
        XCTAssertEqual(family.code, "TEST123")
    }
    
    func testUserProfileCreation() throws {
        let context = modelContainer.mainContext
        
        let user = UserProfile(
            displayName: "John Doe",
            appleUserIdHash: "hash123456789"
        )
        
        context.insert(user)
        try context.save()
        
        XCTAssertTrue(user.isFullyValid)
        XCTAssertEqual(user.displayName, "John Doe")
        XCTAssertEqual(user.appleUserIdHash, "hash123456789")
    }
    
    func testMembershipCreation() throws {
        let context = modelContainer.mainContext
        
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
            role: .parentAdmin
        )
        
        context.insert(user)
        context.insert(family)
        context.insert(membership)
        try context.save()
        
        XCTAssertTrue(membership.isFullyValid)
        XCTAssertEqual(membership.role, .parentAdmin)
        XCTAssertEqual(membership.status, .active)
        XCTAssertEqual(membership.familyId, family.id)
        XCTAssertEqual(membership.userId, user.id)
    }
    
    // MARK: - Relationship Tests
    
    func testFamilyMembershipRelationship() throws {
        let context = modelContainer.mainContext
        
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
            role: .parentAdmin
        )
        
        context.insert(user)
        context.insert(family)
        context.insert(membership)
        try context.save()
        
        // Test family has the membership
        XCTAssertEqual(family.memberships.count, 1)
        XCTAssertEqual(family.memberships.first?.id, membership.id)
        
        // Test user has the membership
        XCTAssertEqual(user.memberships.count, 1)
        XCTAssertEqual(user.memberships.first?.id, membership.id)
        
        // Test membership references
        XCTAssertEqual(membership.family?.id, family.id)
        XCTAssertEqual(membership.user?.id, user.id)
    }
    
    // MARK: - Validation Tests
    
    func testFamilyValidation() {
        // Valid family
        let validFamily = Family(
            name: "Valid Family",
            code: "VALID1",
            createdByUserId: UUID()
        )
        XCTAssertTrue(validFamily.isFullyValid)
        
        // Invalid name
        let invalidNameFamily = Family(
            name: "",
            code: "VALID1",
            createdByUserId: UUID()
        )
        XCTAssertFalse(invalidNameFamily.isFullyValid)
        
        // Invalid code
        let invalidCodeFamily = Family(
            name: "Valid Family",
            code: "12",
            createdByUserId: UUID()
        )
        XCTAssertFalse(invalidCodeFamily.isFullyValid)
    }
    
    func testUserProfileValidation() {
        // Valid user
        let validUser = UserProfile(
            displayName: "John Doe",
            appleUserIdHash: "hash123456789"
        )
        XCTAssertTrue(validUser.isFullyValid)
        
        // Invalid display name
        let invalidNameUser = UserProfile(
            displayName: "",
            appleUserIdHash: "hash123456789"
        )
        XCTAssertFalse(invalidNameUser.isFullyValid)
        
        // Invalid hash
        let invalidHashUser = UserProfile(
            displayName: "John Doe",
            appleUserIdHash: "short"
        )
        XCTAssertFalse(invalidHashUser.isFullyValid)
    }
    
    // MARK: - CloudKit Sync Properties Tests
    
    func testCloudKitSyncProperties() throws {
        let context = modelContainer.mainContext
        
        let family = Family(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: UUID()
        )
        
        // Initially needs sync
        XCTAssertTrue(family.needsSync)
        XCTAssertNil(family.ckRecordID)
        XCTAssertNil(family.lastSyncDate)
        
        // Simulate sync
        family.ckRecordID = "test-record-id"
        family.lastSyncDate = Date()
        family.needsSync = false
        
        context.insert(family)
        try context.save()
        
        XCTAssertFalse(family.needsSync)
        XCTAssertNotNil(family.ckRecordID)
        XCTAssertNotNil(family.lastSyncDate)
    }
    
    // MARK: - Role and Status Tests
    
    func testRoleEnumValues() {
        XCTAssertEqual(Role.parentAdmin.displayName, "Parent Admin")
        XCTAssertEqual(Role.adult.displayName, "Adult")
        XCTAssertEqual(Role.kid.displayName, "Kid")
        XCTAssertEqual(Role.visitor.displayName, "Visitor")
        
        XCTAssertFalse(Role.parentAdmin.description.isEmpty)
        XCTAssertFalse(Role.adult.description.isEmpty)
        XCTAssertFalse(Role.kid.description.isEmpty)
        XCTAssertFalse(Role.visitor.description.isEmpty)
    }
    
    func testMembershipStatusValues() {
        XCTAssertEqual(MembershipStatus.active.displayName, "Active")
        XCTAssertEqual(MembershipStatus.invited.displayName, "Invited")
        XCTAssertEqual(MembershipStatus.removed.displayName, "Removed")
    }
    
    // MARK: - Family Helper Methods Tests
    
    func testFamilyHelperMethods() throws {
        let context = modelContainer.mainContext
        
        let user1 = UserProfile(displayName: "User 1", appleUserIdHash: "hash1")
        let user2 = UserProfile(displayName: "User 2", appleUserIdHash: "hash2")
        
        let family = Family(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: user1.id
        )
        
        let membership1 = Membership(family: family, user: user1, role: .parentAdmin)
        let membership2 = Membership(family: family, user: user2, role: .adult)
        
        // Remove one membership
        membership2.remove()
        
        context.insert(user1)
        context.insert(user2)
        context.insert(family)
        context.insert(membership1)
        context.insert(membership2)
        try context.save()
        
        // Test active members
        XCTAssertEqual(family.activeMembers.count, 1)
        XCTAssertEqual(family.activeMembers.first?.user?.id, user1.id)
        
        // Test parent admin
        XCTAssertNotNil(family.parentAdmin)
        XCTAssertTrue(family.hasParentAdmin)
        XCTAssertEqual(family.parentAdmin?.user?.id, user1.id)
    }
}