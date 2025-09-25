import XCTest
import SwiftData
@testable import TribeBoard

@MainActor
final class DataServiceTests: XCTestCase {
    var modelContainer: ModelContainer!
    var dataService: DataService!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory container for testing
        modelContainer = try ModelContainerConfiguration.createInMemory()
        dataService = DataService(modelContext: modelContainer.mainContext)
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        dataService = nil
        try await super.tearDown()
    }
    
    // MARK: - Family Tests
    
    func testCreateValidFamily() throws {
        let family = try dataService.createFamily(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: UUID()
        )
        
        XCTAssertEqual(family.name, "Test Family")
        XCTAssertEqual(family.code, "TEST123")
        XCTAssertTrue(family.isFullyValid)
    }
    
    @MainActor func testCreateFamilyWithInvalidName() {
        XCTAssertThrowsError(try dataService.createFamily(
            name: "",
            code: "TEST123",
            createdByUserId: UUID()
        )) { error in
            if case DataServiceError.validationFailed(let errors) = error {
                XCTAssertTrue(errors.contains("Family name cannot be empty"))
            } else {
                XCTFail("Expected validation error")
            }
        }
    }
    
    @MainActor func testCreateFamilyWithInvalidCode() {
        XCTAssertThrowsError(try dataService.createFamily(
            name: "Test Family",
            code: "12", // Too short
            createdByUserId: UUID()
        )) { error in
            if case DataServiceError.validationFailed(let errors) = error {
                XCTAssertTrue(errors.contains("Family code must be 6-8 characters"))
            } else {
                XCTFail("Expected validation error")
            }
        }
    }
    
    func testFamilyCodeUniqueness() throws {
        // Create first family
        _ = try dataService.createFamily(
            name: "Family 1",
            code: "TEST123",
            createdByUserId: UUID()
        )
        
        // Try to create second family with same code
        XCTAssertThrowsError(try dataService.createFamily(
            name: "Family 2",
            code: "TEST123",
            createdByUserId: UUID()
        )) { error in
            if case DataServiceError.validationFailed(let errors) = error {
                XCTAssertTrue(errors.contains("Family code already exists"))
            } else {
                XCTFail("Expected validation error")
            }
        }
    }
    
    func testGenerateUniqueFamilyCode() throws {
        let code = try dataService.generateUniqueFamilyCode()
        XCTAssertTrue(dataService.isValidFamilyCodeFormat(code))
        XCTAssertGreaterThanOrEqual(code.count, 6)
        XCTAssertLessThanOrEqual(code.count, 8)
    }
    
    // MARK: - UserProfile Tests
    
    func testCreateValidUserProfile() throws {
        let userProfile = try dataService.createUserProfile(
            displayName: "John Doe",
            appleUserIdHash: "hash123456789"
        )
        
        XCTAssertEqual(userProfile.displayName, "John Doe")
        XCTAssertEqual(userProfile.appleUserIdHash, "hash123456789")
        XCTAssertTrue(userProfile.isFullyValid)
    }
    
    @MainActor func testCreateUserProfileWithInvalidName() {
        XCTAssertThrowsError(try dataService.createUserProfile(
            displayName: "",
            appleUserIdHash: "hash123456789"
        )) { error in
            if case DataServiceError.validationFailed(let errors) = error {
                XCTAssertTrue(errors.contains("Display name cannot be empty"))
            } else {
                XCTFail("Expected validation error")
            }
        }
    }
    
    // MARK: - Membership Tests
    
    func testCreateValidMembership() throws {
        let user = try dataService.createUserProfile(
            displayName: "John Doe",
            appleUserIdHash: "hash123456789"
        )
        
        let family = try dataService.createFamily(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: user.id
        )
        
        let membership = try dataService.createMembership(
            family: family,
            user: user,
            role: .parentAdmin
        )
        
        XCTAssertEqual(membership.role, .parentAdmin)
        XCTAssertEqual(membership.status, .active)
        XCTAssertTrue(membership.isFullyValid)
    }
    
    func testParentAdminConstraint() throws {
        let user1 = try dataService.createUserProfile(
            displayName: "User 1",
            appleUserIdHash: "hash1"
        )
        
        let user2 = try dataService.createUserProfile(
            displayName: "User 2",
            appleUserIdHash: "hash2"
        )
        
        let family = try dataService.createFamily(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: user1.id
        )
        
        // Create first parent admin
        _ = try dataService.createMembership(
            family: family,
            user: user1,
            role: .parentAdmin
        )
        
        // Try to create second parent admin
        XCTAssertThrowsError(try dataService.createMembership(
            family: family,
            user: user2,
            role: .parentAdmin
        )) { error in
            if case DataServiceError.constraintViolation(let message) = error {
                XCTAssertTrue(message.contains("Parent Admin already exists"))
            } else {
                XCTFail("Expected constraint violation error")
            }
        }
    }
    
    func testDuplicateMembershipConstraint() throws {
        let user = try dataService.createUserProfile(
            displayName: "John Doe",
            appleUserIdHash: "hash123456789"
        )
        
        let family = try dataService.createFamily(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: user.id
        )
        
        // Create first membership
        _ = try dataService.createMembership(
            family: family,
            user: user,
            role: .adult
        )
        
        // Try to create duplicate membership
        XCTAssertThrowsError(try dataService.createMembership(
            family: family,
            user: user,
            role: .kid
        )) { error in
            if case DataServiceError.constraintViolation(let message) = error {
                XCTAssertTrue(message.contains("already a member"))
            } else {
                XCTFail("Expected constraint violation error")
            }
        }
    }
    
    func testRoleChangeValidation() throws {
        let user1 = try dataService.createUserProfile(
            displayName: "User 1",
            appleUserIdHash: "hash1"
        )
        
        let user2 = try dataService.createUserProfile(
            displayName: "User 2",
            appleUserIdHash: "hash2"
        )
        
        let family = try dataService.createFamily(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: user1.id
        )
        
        _ = try dataService.createMembership(
            family: family,
            user: user1,
            role: .parentAdmin
        )
        
        let membership2 = try dataService.createMembership(
            family: family,
            user: user2,
            role: .adult
        )
        
        // Try to change user2 to parent admin (should fail)
        XCTAssertThrowsError(try dataService.updateMembershipRole(membership2, to: .parentAdmin)) { error in
            if case DataServiceError.validationFailed(let errors) = error {
                XCTAssertTrue(errors.contains("Parent Admin already exists"))
            } else {
                XCTFail("Expected validation error")
            }
        }
        
        // Change user2 to kid (should succeed)
        XCTAssertNoThrow(try dataService.updateMembershipRole(membership2, to: .kid))
        XCTAssertEqual(membership2.role, .kid)
    }
    
    // MARK: - Enhanced Safe Operations Tests
    
    func testFetchFamilySafely_ValidCode() throws {
        // Create a family first
        let family = try dataService.createFamily(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: UUID()
        )
        
        // Test safe fetch
        let fetchedFamily = try dataService.fetchFamily(byCode: "TEST123")
        XCTAssertNotNil(fetchedFamily)
        XCTAssertEqual(fetchedFamily?.id, family.id)
        XCTAssertEqual(fetchedFamily?.name, "Test Family")
        XCTAssertEqual(fetchedFamily?.code, "TEST123")
    }
    
    @MainActor func testFetchFamilySafely_InvalidCode() {
        // Test with empty code
        XCTAssertThrowsError(try dataService.fetchFamily(byCode: "")) { error in
            if case DataServiceError.invalidData(let message) = error {
                XCTAssertTrue(message.contains("cannot be empty"))
            } else {
                XCTFail("Expected invalidData error for empty code")
            }
        }
        
        // Test with invalid length
        XCTAssertThrowsError(try dataService.fetchFamily(byCode: "ABC")) { error in
            if case DataServiceError.invalidData(let message) = error {
                XCTAssertTrue(message.contains("6-8 characters"))
            } else {
                XCTFail("Expected invalidData error for short code")
            }
        }
    }
    
    func testFetchFamilySafely_NonExistentCode() throws {
        let result = try dataService.fetchFamily(byCode: "NOEXIST")
        XCTAssertNil(result)
    }
    
    func testFetchFamilySafely_ManualFilteringFallback() throws {
        // Create multiple families to test manual filtering
        let family1 = try dataService.createFamily(
            name: "Family 1",
            code: "FAMILY1",
            createdByUserId: UUID()
        )
        
        let family2 = try dataService.createFamily(
            name: "Family 2", 
            code: "FAMILY2",
            createdByUserId: UUID()
        )
        
        // Test that manual filtering works correctly
        let fetchedFamily1 = try dataService.fetchFamily(byCode: "FAMILY1")
        let fetchedFamily2 = try dataService.fetchFamily(byCode: "FAMILY2")
        
        XCTAssertNotNil(fetchedFamily1)
        XCTAssertNotNil(fetchedFamily2)
        XCTAssertEqual(fetchedFamily1?.id, family1.id)
        XCTAssertEqual(fetchedFamily2?.id, family2.id)
        XCTAssertNotEqual(fetchedFamily1?.id, fetchedFamily2?.id)
    }
    
    func testTransactionSafety_RollbackOnError() throws {
        // Test that failed operations don't leave partial data
        let initialFamilyCount = try dataService.fetchAllFamilies().count
        
        // Try to create family with invalid data that should fail validation
        XCTAssertThrowsError(try dataService.createFamily(
            name: "", // Invalid name
            code: "TEST123",
            createdByUserId: UUID()
        ))
        
        // Verify no partial data was saved
        let finalFamilyCount = try dataService.fetchAllFamilies().count
        XCTAssertEqual(initialFamilyCount, finalFamilyCount)
    }
    
    func testDatabaseStateValidation() throws {
        // Test that database state validation works
        // This is tested implicitly in other operations, but we can verify it doesn't crash
        let family = try dataService.createFamily(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: UUID()
        )
        
        XCTAssertNotNil(family)
        XCTAssertTrue(family.isFullyValid)
    }
    
    func testConcurrentOperations() throws {
        let expectation = XCTestExpectation(description: "Concurrent operations")
        let operationCount = 10
        var completedOperations = 0
        var errors: [Error] = []
        
        // Test concurrent family creation
        DispatchQueue.concurrentPerform(iterations: operationCount) { index in
            do {
                _ = try dataService.createFamily(
                    name: "Family \(index)",
                    code: "FAM\(String(format: "%03d", index))",
                    createdByUserId: UUID()
                )
                
                DispatchQueue.main.async {
                    completedOperations += 1
                    if completedOperations == operationCount {
                        expectation.fulfill()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    errors.append(error)
                    completedOperations += 1
                    if completedOperations == operationCount {
                        expectation.fulfill()
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Should have created all families successfully
        XCTAssertEqual(errors.count, 0, "No errors should occur in concurrent operations")
        
        let allFamilies = try dataService.fetchAllFamilies()
        XCTAssertGreaterThanOrEqual(allFamilies.count, operationCount)
    }
    
    func testErrorLogging() throws {
        // Test that errors are properly logged
        // This is mainly tested by ensuring operations don't crash and provide meaningful errors
        
        XCTAssertThrowsError(try dataService.createFamily(
            name: "",
            code: "TEST123",
            createdByUserId: UUID()
        )) { error in
            // Verify error contains useful information
            XCTAssertNotNil(error.localizedDescription)
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }
    
    func testDataIntegrityValidation() throws {
        let family = try dataService.createFamily(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: UUID()
        )
        
        // Verify family data integrity
        XCTAssertTrue(family.isFullyValid)
        XCTAssertNotNil(family.id)
        XCTAssertFalse(family.name.isEmpty)
        XCTAssertFalse(family.code.isEmpty)
        XCTAssertNotNil(family.createdAt)
        XCTAssertNotNil(family.createdByUserId)
    }
    
    func testConstraintViolationHandling() throws {
        // Test duplicate code constraint
        _ = try dataService.createFamily(
            name: "Family 1",
            code: "DUPLICATE",
            createdByUserId: UUID()
        )
        
        XCTAssertThrowsError(try dataService.createFamily(
            name: "Family 2",
            code: "DUPLICATE",
            createdByUserId: UUID()
        )) { error in
            if case DataServiceError.constraintViolation(let message) = error {
                XCTAssertTrue(message.contains("already exists"))
            } else {
                XCTFail("Expected constraint violation error")
            }
        }
    }
    
    func testPendingSyncOperations() throws {
        let family = try dataService.createFamily(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: UUID()
        )
        
        // Mark as needing sync
        family.needsSync = true
        try dataService.save()
        
        let pendingFamilies = try dataService.fetchPendingSyncFamilies()
        XCTAssertTrue(pendingFamilies.contains { $0.id == family.id })
        
        let pendingCount = try dataService.countPendingSyncFamilies()
        XCTAssertGreaterThan(pendingCount, 0)
    }
    
    // MARK: - Enhanced Validation Tests
    
    func testFamilyValidation() throws {
        let validResult = try dataService.validateFamily(name: "Valid Family", code: "VALID1", createdByUserId: UUID())
        XCTAssertTrue(validResult.isValid)
        
        let invalidResult = try dataService.validateFamily(name: "", code: "12", createdByUserId: UUID())
        XCTAssertFalse(invalidResult.isValid)
        XCTAssertFalse(invalidResult.message.isEmpty)
    }
    
    @MainActor func testUserProfileValidation() {
        let validResult = dataService.validateUserProfile(displayName: "John Doe", appleUserIdHash: "hash123456789")
        XCTAssertTrue(validResult.isValid)
        
        let invalidResult = dataService.validateUserProfile(displayName: "", appleUserIdHash: "")
        XCTAssertFalse(invalidResult.isValid)
        XCTAssertFalse(invalidResult.message.isEmpty)
    }
    
    @MainActor func testFamilyCodeFormat() {
        XCTAssertTrue(dataService.isValidFamilyCodeFormat("ABC123"))
        XCTAssertTrue(dataService.isValidFamilyCodeFormat("ABCD1234"))
        XCTAssertFalse(dataService.isValidFamilyCodeFormat("AB12")) // Too short
        XCTAssertFalse(dataService.isValidFamilyCodeFormat("ABCD12345")) // Too long
        XCTAssertFalse(dataService.isValidFamilyCodeFormat("ABC-123")) // Invalid character
        XCTAssertFalse(dataService.isValidFamilyCodeFormat("")) // Empty
    }
    
    @MainActor func testEdgeCaseValidation() {
        // Test whitespace handling
        XCTAssertThrowsError(try dataService.createFamily(
            name: "   ",
            code: "TEST123",
            createdByUserId: UUID()
        )) { error in
            if case DataServiceError.validationFailed(let errors) = error {
                XCTAssertTrue(errors.contains { $0.contains("empty") })
            } else {
                XCTFail("Expected validation error for whitespace-only name")
            }
        }
        
        // Test boundary lengths
        let longName = String(repeating: "A", count: 100)
        XCTAssertThrowsError(try dataService.createFamily(
            name: longName,
            code: "TEST123",
            createdByUserId: UUID()
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("length") || error.localizedDescription.contains("long"))
        }
    }
}