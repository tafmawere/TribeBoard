import XCTest
@testable import TribeBoard

@MainActor
class MockDataServiceTests: XCTestCase {
    
    var mockDataService: MockDataService!
    
    override func setUp() async throws {
        await super.setUp()
        mockDataService = MockDataService()
    }
    
    override func tearDown() async throws {
        mockDataService = nil
        await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        // Then
        XCTAssertTrue(mockDataService.shouldSucceed)
        XCTAssertEqual(mockDataService.getStoredItemCount(for: .userProfile), 0)
        XCTAssertEqual(mockDataService.getStoredItemCount(for: .family), 0)
        XCTAssertEqual(mockDataService.getStoredItemCount(for: .membership), 0)
    }
    
    // MARK: - User Profile Tests
    
    func testCreateUserProfileSuccess() throws {
        // Given
        let displayName = "Test User"
        let appleUserIdHash = "test_hash_123"
        
        // When
        let userProfile = try mockDataService.createUserProfile(
            displayName: displayName,
            appleUserIdHash: appleUserIdHash
        )
        
        // Then
        XCTAssertEqual(userProfile.displayName, displayName)
        XCTAssertEqual(userProfile.appleUserIdHash, appleUserIdHash)
        XCTAssertEqual(mockDataService.createUserProfileCallCount, 1)
        XCTAssertEqual(mockDataService.getStoredItemCount(for: .userProfile), 1)
        XCTAssertTrue(mockDataService.hasUser(withHash: appleUserIdHash))
    }
    
    func testCreateUserProfileDuplicateHash() throws {
        // Given
        let displayName = "Test User"
        let appleUserIdHash = "duplicate_hash"
        
        // Create first user
        _ = try mockDataService.createUserProfile(
            displayName: displayName,
            appleUserIdHash: appleUserIdHash
        )
        
        // When/Then - try to create duplicate
        XCTAssertThrowsError(try mockDataService.createUserProfile(
            displayName: "Another User",
            appleUserIdHash: appleUserIdHash
        )) { error in
            if case DataServiceError.constraintViolation(let message) = error {
                XCTAssertTrue(message.contains("already exists"))
            } else {
                XCTFail("Expected constraintViolation error, got \(error)")
            }
        }
    }
    
    func testCreateUserProfileFailure() {
        // Given
        mockDataService.setError(.invalidData("Test error"))
        mockDataService.shouldSucceed = false
        
        // When/Then
        XCTAssertThrowsError(try mockDataService.createUserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash"
        )) { error in
            if case DataServiceError.invalidData(let message) = error {
                XCTAssertEqual(message, "Test error")
            } else {
                XCTFail("Expected invalidData error, got \(error)")
            }
        }
    }
    
    func testFetchUserProfileByHashSuccess() throws {
        // Given
        let displayName = "Test User"
        let appleUserIdHash = "test_hash_123"
        let createdUser = try mockDataService.createUserProfile(
            displayName: displayName,
            appleUserIdHash: appleUserIdHash
        )
        
        // When
        let fetchedUser = try mockDataService.fetchUserProfile(byAppleUserIdHash: appleUserIdHash)
        
        // Then
        XCTAssertNotNil(fetchedUser)
        XCTAssertEqual(fetchedUser?.id, createdUser.id)
        XCTAssertEqual(fetchedUser?.displayName, displayName)
        XCTAssertEqual(mockDataService.fetchUserProfileCallCount, 1)
    }
    
    func testFetchUserProfileByHashNotFound() throws {
        // When
        let fetchedUser = try mockDataService.fetchUserProfile(byAppleUserIdHash: "nonexistent_hash")
        
        // Then
        XCTAssertNil(fetchedUser)
        XCTAssertEqual(mockDataService.fetchUserProfileCallCount, 1)
    }
    
    func testFetchUserProfileByIdSuccess() throws {
        // Given
        let createdUser = try mockDataService.createUserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash"
        )
        
        // When
        let fetchedUser = try mockDataService.fetchUserProfile(byId: createdUser.id)
        
        // Then
        XCTAssertNotNil(fetchedUser)
        XCTAssertEqual(fetchedUser?.id, createdUser.id)
        XCTAssertEqual(fetchedUser?.displayName, "Test User")
    }
    
    // MARK: - Family Tests
    
    func testCreateFamilySuccess() throws {
        // Given
        let familyName = "Test Family"
        let familyCode = "TEST123"
        let createdByUserId = UUID()
        
        // When
        let family = try mockDataService.createFamily(
            name: familyName,
            code: familyCode,
            createdByUserId: createdByUserId
        )
        
        // Then
        XCTAssertEqual(family.name, familyName)
        XCTAssertEqual(family.code, familyCode)
        XCTAssertEqual(family.createdByUserId, createdByUserId)
        XCTAssertEqual(mockDataService.createFamilyCallCount, 1)
        XCTAssertEqual(mockDataService.getStoredItemCount(for: .family), 1)
        XCTAssertTrue(mockDataService.hasFamily(withCode: familyCode))
    }
    
    func testCreateFamilyDuplicateCode() throws {
        // Given
        let familyCode = "DUPLICATE"
        let userId = UUID()
        
        // Create first family
        _ = try mockDataService.createFamily(
            name: "First Family",
            code: familyCode,
            createdByUserId: userId
        )
        
        // When/Then - try to create duplicate
        XCTAssertThrowsError(try mockDataService.createFamily(
            name: "Second Family",
            code: familyCode,
            createdByUserId: userId
        )) { error in
            if case DataServiceError.constraintViolation(let message) = error {
                XCTAssertTrue(message.contains("already exists"))
            } else {
                XCTFail("Expected constraintViolation error, got \(error)")
            }
        }
    }
    
    func testFetchFamilyByCodeSuccess() throws {
        // Given
        let familyCode = "TEST123"
        let createdFamily = try mockDataService.createFamily(
            name: "Test Family",
            code: familyCode,
            createdByUserId: UUID()
        )
        
        // When
        let fetchedFamily = try mockDataService.fetchFamily(byCode: familyCode)
        
        // Then
        XCTAssertNotNil(fetchedFamily)
        XCTAssertEqual(fetchedFamily?.id, createdFamily.id)
        XCTAssertEqual(fetchedFamily?.name, "Test Family")
        XCTAssertEqual(mockDataService.fetchFamilyCallCount, 1)
    }
    
    func testFetchFamilyByCodeNotFound() throws {
        // When
        let fetchedFamily = try mockDataService.fetchFamily(byCode: "NOTFOUND")
        
        // Then
        XCTAssertNil(fetchedFamily)
        XCTAssertEqual(mockDataService.fetchFamilyCallCount, 1)
    }
    
    func testFetchFamilyByIdSuccess() throws {
        // Given
        let createdFamily = try mockDataService.createFamily(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: UUID()
        )
        
        // When
        let fetchedFamily = try mockDataService.fetchFamily(byId: createdFamily.id)
        
        // Then
        XCTAssertNotNil(fetchedFamily)
        XCTAssertEqual(fetchedFamily?.id, createdFamily.id)
        XCTAssertEqual(fetchedFamily?.name, "Test Family")
    }
    
    func testFamilyCodeExists() throws {
        // Given
        let familyCode = "EXISTS123"
        _ = try mockDataService.createFamily(
            name: "Test Family",
            code: familyCode,
            createdByUserId: UUID()
        )
        
        // When/Then
        XCTAssertTrue(try mockDataService.familyCodeExists(familyCode))
        XCTAssertFalse(try mockDataService.familyCodeExists("NOTEXISTS"))
    }
    
    func testFetchAllFamilies() throws {
        // Given
        _ = try mockDataService.createFamily(name: "Family 1", code: "FAM001", createdByUserId: UUID())
        _ = try mockDataService.createFamily(name: "Family 2", code: "FAM002", createdByUserId: UUID())
        
        // When
        let allFamilies = try mockDataService.fetchAllFamilies()
        
        // Then
        XCTAssertEqual(allFamilies.count, 2)
        XCTAssertTrue(allFamilies.contains { $0.name == "Family 1" })
        XCTAssertTrue(allFamilies.contains { $0.name == "Family 2" })
    }
    
    // MARK: - Membership Tests
    
    func testCreateMembershipSuccess() throws {
        // Given
        let user = try mockDataService.createUserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash"
        )
        let family = try mockDataService.createFamily(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: user.id
        )
        
        // When
        let membership = try mockDataService.createMembership(
            family: family,
            user: user,
            role: .parentAdmin
        )
        
        // Then
        XCTAssertEqual(membership.familyId, family.id)
        XCTAssertEqual(membership.userId, user.id)
        XCTAssertEqual(membership.role, .parentAdmin)
        XCTAssertEqual(membership.status, .active)
        XCTAssertEqual(mockDataService.createMembershipCallCount, 1)
        XCTAssertEqual(mockDataService.getStoredItemCount(for: .membership), 1)
    }
    
    func testFetchMembershipsForUser() throws {
        // Given
        let user = try mockDataService.createUserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash"
        )
        let family1 = try mockDataService.createFamily(
            name: "Family 1",
            code: "FAM001",
            createdByUserId: user.id
        )
        let family2 = try mockDataService.createFamily(
            name: "Family 2",
            code: "FAM002",
            createdByUserId: user.id
        )
        
        _ = try mockDataService.createMembership(family: family1, user: user, role: .parentAdmin)
        _ = try mockDataService.createMembership(family: family2, user: user, role: .parent)
        
        // When
        let memberships = try mockDataService.fetchMemberships(forUser: user)
        
        // Then
        XCTAssertEqual(memberships.count, 2)
        XCTAssertTrue(memberships.allSatisfy { $0.userId == user.id })
    }
    
    // MARK: - Error Configuration Tests
    
    func testConfigureSpecificOperationFailure() {
        // Given
        mockDataService.setFailingOperations([.createUserProfile])
        mockDataService.setError(.invalidData("Specific operation failed"))
        
        // When/Then
        XCTAssertThrowsError(try mockDataService.createUserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash"
        )) { error in
            if case DataServiceError.invalidData(let message) = error {
                XCTAssertEqual(message, "Specific operation failed")
            } else {
                XCTFail("Expected invalidData error, got \(error)")
            }
        }
        
        // But other operations should still work
        XCTAssertNoThrow(try mockDataService.fetchUserProfile(byAppleUserIdHash: "test_hash"))
    }
    
    // MARK: - Test Utility Tests
    
    func testReset() throws {
        // Given - populate with data
        _ = try mockDataService.createUserProfile(displayName: "User", appleUserIdHash: "hash")
        _ = try mockDataService.createFamily(name: "Family", code: "CODE123", createdByUserId: UUID())
        mockDataService.shouldSucceed = false
        mockDataService.setError(.invalidData("Test error"))
        
        // When
        mockDataService.reset()
        
        // Then
        XCTAssertEqual(mockDataService.getStoredItemCount(for: .userProfile), 0)
        XCTAssertEqual(mockDataService.getStoredItemCount(for: .family), 0)
        XCTAssertEqual(mockDataService.getStoredItemCount(for: .membership), 0)
        XCTAssertTrue(mockDataService.shouldSucceed)
        XCTAssertEqual(mockDataService.createUserProfileCallCount, 0)
        XCTAssertEqual(mockDataService.createFamilyCallCount, 0)
        
        // Should be able to create successfully after reset
        XCTAssertNoThrow(try mockDataService.createUserProfile(
            displayName: "New User",
            appleUserIdHash: "new_hash"
        ))
    }
    
    func testPrePopulateUser() {
        // Given
        let userProfile = UserProfile(
            id: UUID(),
            displayName: "Pre-populated User",
            appleUserIdHash: "prepop_hash",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When
        mockDataService.prePopulateUser(userProfile, withHash: "prepop_hash")
        
        // Then
        XCTAssertTrue(mockDataService.hasUser(withHash: "prepop_hash"))
        XCTAssertEqual(mockDataService.getStoredItemCount(for: .userProfile), 1)
        
        let fetchedUser = try? mockDataService.fetchUserProfile(byAppleUserIdHash: "prepop_hash")
        XCTAssertEqual(fetchedUser?.displayName, "Pre-populated User")
    }
    
    func testPrePopulateFamily() {
        // Given
        let family = Family(
            id: UUID(),
            name: "Pre-populated Family",
            code: "PREPOP123",
            createdByUserId: UUID(),
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When
        mockDataService.prePopulateFamily(family)
        
        // Then
        XCTAssertTrue(mockDataService.hasFamily(withCode: "PREPOP123"))
        XCTAssertEqual(mockDataService.getStoredItemCount(for: .family), 1)
        
        let fetchedFamily = try? mockDataService.fetchFamily(byCode: "PREPOP123")
        XCTAssertEqual(fetchedFamily?.name, "Pre-populated Family")
    }
    
    func testPopulateWithTestData() {
        // When
        mockDataService.populateWithTestData()
        
        // Then
        XCTAssertEqual(mockDataService.getStoredItemCount(for: .userProfile), 1)
        XCTAssertEqual(mockDataService.getStoredItemCount(for: .family), 1)
        XCTAssertTrue(mockDataService.hasUser(withHash: "test_hash_123"))
        XCTAssertTrue(mockDataService.hasFamily(withCode: "TEST123"))
    }
    
    func testGetCallCounts() throws {
        // Given
        _ = try mockDataService.createUserProfile(displayName: "User", appleUserIdHash: "hash")
        _ = try mockDataService.fetchUserProfile(byAppleUserIdHash: "hash")
        _ = try mockDataService.createFamily(name: "Family", code: "CODE", createdByUserId: UUID())
        _ = try mockDataService.fetchFamily(byCode: "CODE")
        
        // When
        let callCounts = mockDataService.getCallCounts()
        
        // Then
        XCTAssertEqual(callCounts["createUserProfile"], 1)
        XCTAssertEqual(callCounts["fetchUserProfile"], 1)
        XCTAssertEqual(callCounts["createFamily"], 1)
        XCTAssertEqual(callCounts["fetchFamily"], 1)
    }
    
    func testGetAllStoredData() throws {
        // Given
        let user = try mockDataService.createUserProfile(displayName: "User", appleUserIdHash: "hash")
        let family = try mockDataService.createFamily(name: "Family", code: "CODE", createdByUserId: user.id)
        
        // When
        let allUsers = mockDataService.getAllUserProfiles()
        let allFamilies = mockDataService.getAllFamilies()
        
        // Then
        XCTAssertEqual(allUsers.count, 1)
        XCTAssertEqual(allFamilies.count, 1)
        XCTAssertEqual(allUsers[user.id]?.displayName, "User")
        XCTAssertEqual(allFamilies[family.id]?.name, "Family")
    }
}