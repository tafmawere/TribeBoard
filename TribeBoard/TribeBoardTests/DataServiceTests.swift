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
    
    func testCreateFamilyWithInvalidName() {
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
    
    func testCreateFamilyWithInvalidCode() {
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
    
    func testCreateUserProfileWithInvalidName() {
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
        
        let membership1 = try dataService.createMembership(
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
    
    // MARK: - Validation Tests
    
    func testFamilyValidation() throws {
        let validResult = try dataService.validateFamily(name: "Valid Family", code: "VALID1")
        XCTAssertTrue(validResult.isValid)
        XCTAssertTrue(validResult.errors.isEmpty)
        
        let invalidResult = try dataService.validateFamily(name: "", code: "12")
        XCTAssertFalse(invalidResult.isValid)
        XCTAssertFalse(invalidResult.errors.isEmpty)
    }
    
    func testUserProfileValidation() {
        let validResult = dataService.validateUserProfile(displayName: "John Doe", appleUserIdHash: "hash123456789")
        XCTAssertTrue(validResult.isValid)
        
        let invalidResult = dataService.validateUserProfile(displayName: "", appleUserIdHash: "")
        XCTAssertFalse(invalidResult.isValid)
    }
    
    func testFamilyCodeFormat() {
        XCTAssertTrue(dataService.isValidFamilyCodeFormat("ABC123"))
        XCTAssertTrue(dataService.isValidFamilyCodeFormat("ABCD1234"))
        XCTAssertFalse(dataService.isValidFamilyCodeFormat("AB12")) // Too short
        XCTAssertFalse(dataService.isValidFamilyCodeFormat("ABCD12345")) // Too long
        XCTAssertFalse(dataService.isValidFamilyCodeFormat("ABC-123")) // Invalid character
        XCTAssertFalse(dataService.isValidFamilyCodeFormat("")) // Empty
    }
}