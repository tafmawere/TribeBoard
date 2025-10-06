import XCTest
@testable import TribeBoard

/// Comprehensive unit tests for InMemoryFamilyDataManager covering all CRUD operations
@MainActor
class InMemoryFamilyDataManagerTests: TestBase {
    
    // MARK: - Properties
    
    var dataManager: InMemoryFamilyDataManager!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        dataManager = InMemoryFamilyDataManager()
    }
    
    override func tearDown() {
        dataManager.clearAllData()
        dataManager = nil
        super.tearDown()
    }
    
    // MARK: - Family Creation Tests
    
    func testCreateFamily_Success() {
        // Given
        let familyName = "Test Family"
        let creatorId = UUID()
        
        // When
        let createdFamily = dataManager.createFamily(name: familyName, createdByUserId: creatorId)
        
        // Then
        XCTAssertEqual(createdFamily.name, familyName)
        XCTAssertEqual(createdFamily.code.count, 6)
        XCTAssertTrue(FamilyCodeGenerator.isValidCodeFormat(createdFamily.code))
        XCTAssertEqual(dataManager.families.count, 1)
        XCTAssertEqual(dataManager.families.first?.id, createdFamily.id)
    }
    
    func testCreateFamily_GeneratesUniqueCode() {
        // Given
        let familyName1 = "Family One"
        let familyName2 = "Family Two"
        let creatorId = UUID()
        
        // When
        let family1 = dataManager.createFamily(name: familyName1, createdByUserId: creatorId)
        let family2 = dataManager.createFamily(name: familyName2, createdByUserId: creatorId)
        
        // Then
        XCTAssertNotEqual(family1.code, family2.code)
        XCTAssertEqual(dataManager.families.count, 2)
    }
    
    func testCreateFamily_UpdatesPublishedProperty() {
        // Given
        let familyName = "Test Family"
        let creatorId = UUID()
        let initialCount = dataManager.families.count
        
        // When
        _ = dataManager.createFamily(name: familyName, createdByUserId: creatorId)
        
        // Then
        XCTAssertEqual(dataManager.families.count, initialCount + 1)
    }
    
    // MARK: - Family Lookup Tests
    
    func testFindFamily_ByCode_Success() {
        // Given
        let familyName = "Test Family"
        let creatorId = UUID()
        let createdFamily = dataManager.createFamily(name: familyName, createdByUserId: creatorId)
        
        // When
        let foundFamily = dataManager.findFamily(byCode: createdFamily.code)
        
        // Then
        XCTAssertNotNil(foundFamily)
        XCTAssertEqual(foundFamily?.id, createdFamily.id)
        XCTAssertEqual(foundFamily?.name, familyName)
    }
    
    func testFindFamily_ByCode_CaseInsensitive() {
        // Given
        let familyName = "Test Family"
        let creatorId = UUID()
        let createdFamily = dataManager.createFamily(name: familyName, createdByUserId: creatorId)
        let lowercaseCode = createdFamily.code.lowercased()
        
        // When
        let foundFamily = dataManager.findFamily(byCode: lowercaseCode)
        
        // Then
        XCTAssertNotNil(foundFamily)
        XCTAssertEqual(foundFamily?.id, createdFamily.id)
    }
    
    func testFindFamily_ByCode_NotFound() {
        // Given
        let nonExistentCode = "NOTFND"
        
        // When
        let foundFamily = dataManager.findFamily(byCode: nonExistentCode)
        
        // Then
        XCTAssertNil(foundFamily)
    }
    
    // MARK: - User Creation Tests
    
    func testCreateUser_Success() {
        // Given
        let userName = "Test User"
        
        // When
        let createdUser = dataManager.createUser(name: userName)
        
        // Then
        XCTAssertEqual(createdUser.name, userName)
        XCTAssertNotNil(createdUser.id)
        XCTAssertEqual(dataManager.users.count, 1)
        XCTAssertEqual(dataManager.users.first?.id, createdUser.id)
    }
    
    func testCreateUser_UpdatesPublishedProperty() {
        // Given
        let userName = "Test User"
        let initialCount = dataManager.users.count
        
        // When
        _ = dataManager.createUser(name: userName)
        
        // Then
        XCTAssertEqual(dataManager.users.count, initialCount + 1)
    }
    
    // MARK: - Member Addition Tests
    
    func testAddMemberToFamily_Success() {
        // Given
        let family = dataManager.createFamily(name: "Test Family", createdByUserId: UUID())
        let user = dataManager.createUser(name: "Test User")
        let role = InMemoryRole.parent
        
        // When
        let success = dataManager.addMemberToFamily(familyId: family.id, user: user, role: role)
        
        // Then
        XCTAssertTrue(success)
        XCTAssertEqual(family.members.count, 1)
        
        let addedMember = family.members.first
        XCTAssertNotNil(addedMember)
        XCTAssertEqual(addedMember?.userId, user.id)
        XCTAssertEqual(addedMember?.familyId, family.id)
        XCTAssertEqual(addedMember?.role, role)
    }
    
    func testAddMemberToFamily_FamilyNotFound() {
        // Given
        let nonExistentFamilyId = UUID()
        let user = dataManager.createUser(name: "Test User")
        let role = InMemoryRole.parent
        
        // When
        let success = dataManager.addMemberToFamily(familyId: nonExistentFamilyId, user: user, role: role)
        
        // Then
        XCTAssertFalse(success)
    }
    
    func testAddMemberToFamily_UserAlreadyMember() {
        // Given
        let family = dataManager.createFamily(name: "Test Family", createdByUserId: UUID())
        let user = dataManager.createUser(name: "Test User")
        let role = InMemoryRole.parent
        
        // Add user first time
        _ = dataManager.addMemberToFamily(familyId: family.id, user: user, role: role)
        
        // When - try to add same user again
        let success = dataManager.addMemberToFamily(familyId: family.id, user: user, role: .child)
        
        // Then
        XCTAssertFalse(success)
        XCTAssertEqual(family.members.count, 1) // Should still be 1
    }
    
    func testAddMemberToFamily_AddsUserToUsersArray() {
        // Given
        let family = dataManager.createFamily(name: "Test Family", createdByUserId: UUID())
        let user = InMemoryUser(name: "Test User") // Create user without adding to manager
        let role = InMemoryRole.parent
        
        // When
        let success = dataManager.addMemberToFamily(familyId: family.id, user: user, role: role)
        
        // Then
        XCTAssertTrue(success)
        XCTAssertTrue(dataManager.users.contains { $0.id == user.id })
    }
    
    // MARK: - Role Update Tests
    
    func testUpdateUserRole_Success() {
        // Given
        let family = dataManager.createFamily(name: "Test Family", createdByUserId: UUID())
        let user = dataManager.createUser(name: "Test User")
        let initialRole = InMemoryRole.parent
        let newRole = InMemoryRole.child
        
        _ = dataManager.addMemberToFamily(familyId: family.id, user: user, role: initialRole)
        
        // When
        let success = dataManager.updateUserRole(userId: user.id, familyId: family.id, newRole: newRole)
        
        // Then
        XCTAssertTrue(success)
        
        let updatedMember = family.member(withUserId: user.id)
        XCTAssertNotNil(updatedMember)
        XCTAssertEqual(updatedMember?.role, newRole)
    }
    
    func testUpdateUserRole_FamilyNotFound() {
        // Given
        let nonExistentFamilyId = UUID()
        let user = dataManager.createUser(name: "Test User")
        let newRole = InMemoryRole.child
        
        // When
        let success = dataManager.updateUserRole(userId: user.id, familyId: nonExistentFamilyId, newRole: newRole)
        
        // Then
        XCTAssertFalse(success)
    }
    
    func testUpdateUserRole_UserNotMember() {
        // Given
        let family = dataManager.createFamily(name: "Test Family", createdByUserId: UUID())
        let user = dataManager.createUser(name: "Test User")
        let newRole = InMemoryRole.child
        
        // When - try to update role without adding user as member first
        let success = dataManager.updateUserRole(userId: user.id, familyId: family.id, newRole: newRole)
        
        // Then
        XCTAssertFalse(success)
    }
    
    // MARK: - Utility Method Tests
    
    func testGetUser_ById_Success() {
        // Given
        let user = dataManager.createUser(name: "Test User")
        
        // When
        let foundUser = dataManager.getUser(byId: user.id)
        
        // Then
        XCTAssertNotNil(foundUser)
        XCTAssertEqual(foundUser?.id, user.id)
        XCTAssertEqual(foundUser?.name, user.name)
    }
    
    func testGetUser_ById_NotFound() {
        // Given
        let nonExistentUserId = UUID()
        
        // When
        let foundUser = dataManager.getUser(byId: nonExistentUserId)
        
        // Then
        XCTAssertNil(foundUser)
    }
    
    func testGetFamilyMembersWithUserDetails_Success() {
        // Given
        let family = dataManager.createFamily(name: "Test Family", createdByUserId: UUID())
        let user1 = dataManager.createUser(name: "User 1")
        let user2 = dataManager.createUser(name: "User 2")
        
        _ = dataManager.addMemberToFamily(familyId: family.id, user: user1, role: .parent)
        _ = dataManager.addMemberToFamily(familyId: family.id, user: user2, role: .child)
        
        // When
        let membersWithUsers = dataManager.getFamilyMembersWithUserDetails(familyId: family.id)
        
        // Then
        XCTAssertEqual(membersWithUsers.count, 2)
        
        let member1 = membersWithUsers.first { $0.member.userId == user1.id }
        XCTAssertNotNil(member1)
        XCTAssertEqual(member1?.user?.name, "User 1")
        XCTAssertEqual(member1?.member.role, .parent)
        
        let member2 = membersWithUsers.first { $0.member.userId == user2.id }
        XCTAssertNotNil(member2)
        XCTAssertEqual(member2?.user?.name, "User 2")
        XCTAssertEqual(member2?.member.role, .child)
    }
    
    func testGetFamilyMembersWithUserDetails_FamilyNotFound() {
        // Given
        let nonExistentFamilyId = UUID()
        
        // When
        let membersWithUsers = dataManager.getFamilyMembersWithUserDetails(familyId: nonExistentFamilyId)
        
        // Then
        XCTAssertTrue(membersWithUsers.isEmpty)
    }
    
    func testIsValidFamilyCodeFormat_ValidCodes() {
        // Given
        let validCodes = ["ABC123", "XYZ789", "TEST01", "FAM999"]
        
        // When & Then
        for code in validCodes {
            XCTAssertTrue(dataManager.isValidFamilyCodeFormat(code), "Code \(code) should be valid")
        }
    }
    
    func testIsValidFamilyCodeFormat_InvalidCodes() {
        // Given
        let invalidCodes = ["ABC12", "ABCD123", "ABC-123", "ABC 123", ""]
        
        // When & Then
        for code in invalidCodes {
            XCTAssertFalse(dataManager.isValidFamilyCodeFormat(code), "Code \(code) should be invalid")
        }
    }
    
    // MARK: - Data Management Tests
    
    func testClearAllData_Success() {
        // Given
        _ = dataManager.createFamily(name: "Test Family", createdByUserId: UUID())
        _ = dataManager.createUser(name: "Test User")
        dataManager.setError(FamilyDataManagerError.familyNotFound)
        dataManager.isLoading = true
        
        // When
        dataManager.clearAllData()
        
        // Then
        XCTAssertTrue(dataManager.families.isEmpty)
        XCTAssertTrue(dataManager.users.isEmpty)
        XCTAssertNil(dataManager.lastError)
        XCTAssertFalse(dataManager.isLoading)
    }
    
    // MARK: - Error Handling Tests
    
    func testSetError_Success() {
        // Given
        let error = FamilyDataManagerError.familyNotFound
        
        // When
        dataManager.setError(error)
        
        // Then
        XCTAssertNotNil(dataManager.lastError)
        XCTAssertEqual(dataManager.lastError as? FamilyDataManagerError, error)
    }
    
    func testClearError_Success() {
        // Given
        dataManager.setError(FamilyDataManagerError.familyNotFound)
        
        // When
        dataManager.clearError()
        
        // Then
        XCTAssertNil(dataManager.lastError)
    }
    
    // MARK: - Loading State Tests
    
    func testLoadingState_DuringFamilyCreation() {
        // Given
        let familyName = "Test Family"
        let creatorId = UUID()
        
        // When
        let family = dataManager.createFamily(name: familyName, createdByUserId: creatorId)
        
        // Then
        // Loading should be false after completion
        XCTAssertFalse(dataManager.isLoading)
        XCTAssertNotNil(family)
    }
    
    // MARK: - Singleton Tests
    
    func testSharedInstance_IsSingleton() {
        // Given
        let instance1 = InMemoryFamilyDataManager.shared
        let instance2 = InMemoryFamilyDataManager.shared
        
        // When & Then
        XCTAssertTrue(instance1 === instance2)
    }
    
    // MARK: - Integration Tests
    
    func testCompleteUserFlow_CreateFamilyAndAddMembers() {
        // Given
        let familyName = "Integration Test Family"
        let creatorId = UUID()
        
        // When - Create family
        let family = dataManager.createFamily(name: familyName, createdByUserId: creatorId)
        
        // Create users
        let user1 = dataManager.createUser(name: "Parent User")
        let user2 = dataManager.createUser(name: "Child User")
        
        // Add members
        let success1 = dataManager.addMemberToFamily(familyId: family.id, user: user1, role: .parent)
        let success2 = dataManager.addMemberToFamily(familyId: family.id, user: user2, role: .child)
        
        // Update role
        let roleUpdateSuccess = dataManager.updateUserRole(userId: user2.id, familyId: family.id, newRole: .helper)
        
        // Then
        XCTAssertTrue(success1)
        XCTAssertTrue(success2)
        XCTAssertTrue(roleUpdateSuccess)
        XCTAssertEqual(family.members.count, 2)
        XCTAssertEqual(dataManager.users.count, 2)
        XCTAssertEqual(dataManager.families.count, 1)
        
        // Verify final state
        let updatedMember = family.member(withUserId: user2.id)
        XCTAssertEqual(updatedMember?.role, .helper)
    }
    
    func testMultipleFamilies_IndependentOperations() {
        // Given
        let family1 = dataManager.createFamily(name: "Family 1", createdByUserId: UUID())
        let family2 = dataManager.createFamily(name: "Family 2", createdByUserId: UUID())
        
        let user1 = dataManager.createUser(name: "User 1")
        let user2 = dataManager.createUser(name: "User 2")
        
        // When
        _ = dataManager.addMemberToFamily(familyId: family1.id, user: user1, role: .parent)
        _ = dataManager.addMemberToFamily(familyId: family2.id, user: user2, role: .child)
        
        // Then
        XCTAssertEqual(family1.members.count, 1)
        XCTAssertEqual(family2.members.count, 1)
        XCTAssertEqual(family1.members.first?.userId, user1.id)
        XCTAssertEqual(family2.members.first?.userId, user2.id)
    }
}