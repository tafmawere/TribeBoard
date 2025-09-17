import XCTest
import SwiftData
@testable import TribeBoard

/// Tests to validate SwiftData model definitions and schema
final class SwiftDataModelValidationTests: XCTestCase {
    
    func testSchemaCreation() throws {
        // Test that the schema can be created without errors
        let schema = Schema([
            Family.self,
            UserProfile.self,
            Membership.self
        ])
        
        XCTAssertEqual(schema.entities.count, 3, "Schema should contain exactly 3 entities")
    }
    
    func testModelContainerValidation() throws {
        // Test that ModelContainer validation passes
        XCTAssertNoThrow(try ModelContainerConfiguration.validateSchema())
    }
    
    func testAppInitializationDoesNotCrash() throws {
        // Test that the app initialization logic doesn't crash
        // This simulates what happens in TribeBoardApp.init()
        XCTAssertNoThrow(try ModelContainerConfiguration.validateSchema())
        
        // Test that we can create a fallback container
        let container = ModelContainerConfiguration.createWithFallback()
        XCTAssertNotNil(container, "Fallback container creation should succeed")
    }
    
    func testInMemoryContainerCreation() throws {
        // Test that we can create an in-memory container
        let container = try ModelContainerConfiguration.createInMemory()
        XCTAssertNotNil(container, "In-memory container should be created successfully")
    }
    
    func testFamilyModelInitialization() throws {
        // Test Family model can be initialized
        let family = Family(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: UUID()
        )
        
        XCTAssertEqual(family.name, "Test Family")
        XCTAssertEqual(family.code, "TEST123")
        XCTAssertTrue(family.memberships.isEmpty)
        XCTAssertTrue(family.needsSync)
    }
    
    func testUserProfileModelInitialization() throws {
        // Test UserProfile model can be initialized
        let user = UserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash_123"
        )
        
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertEqual(user.appleUserIdHash, "test_hash_123")
        XCTAssertTrue(user.memberships.isEmpty)
        XCTAssertTrue(user.needsSync)
    }
    
    func testMembershipModelInitialization() throws {
        // Test Membership model can be initialized
        let family = Family(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: UUID()
        )
        
        let user = UserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash_123"
        )
        
        let membership = Membership(
            family: family,
            user: user,
            role: .adult
        )
        
        XCTAssertEqual(membership.role, .adult)
        XCTAssertEqual(membership.status, .active)
        XCTAssertEqual(membership.family?.id, family.id)
        XCTAssertEqual(membership.user?.id, user.id)
        XCTAssertTrue(membership.needsSync)
    }
    
    func testModelValidation() throws {
        // Test model validation methods
        let family = Family(
            name: "Valid Family Name",
            code: "VALID1",
            createdByUserId: UUID()
        )
        
        XCTAssertTrue(family.isNameValid, "Valid family name should pass validation")
        XCTAssertTrue(family.isCodeValid, "Valid family code should pass validation")
        XCTAssertTrue(family.isFullyValid, "Valid family should pass full validation")
        
        let user = UserProfile(
            displayName: "Valid User",
            appleUserIdHash: "valid_hash_123456"
        )
        
        XCTAssertTrue(user.isDisplayNameValid, "Valid display name should pass validation")
        XCTAssertTrue(user.isAppleUserIdHashValid, "Valid Apple user ID hash should pass validation")
        XCTAssertTrue(user.isFullyValid, "Valid user should pass full validation")
    }
    
    func testRoleEnumValues() throws {
        // Test that Role enum values are properly defined
        XCTAssertEqual(Role.parentAdmin.rawValue, "parent_admin")
        XCTAssertEqual(Role.adult.rawValue, "adult")
        XCTAssertEqual(Role.kid.rawValue, "kid")
        XCTAssertEqual(Role.visitor.rawValue, "visitor")
        
        // Test that Role can be created from raw values
        XCTAssertEqual(Role(rawValue: "parent_admin"), .parentAdmin)
        XCTAssertEqual(Role(rawValue: "adult"), .adult)
        XCTAssertEqual(Role(rawValue: "kid"), .kid)
        XCTAssertEqual(Role(rawValue: "visitor"), .visitor)
    }
    
    func testMembershipStatusEnumValues() throws {
        // Test that MembershipStatus enum values are properly defined
        XCTAssertEqual(MembershipStatus.active.rawValue, "active")
        XCTAssertEqual(MembershipStatus.invited.rawValue, "invited")
        XCTAssertEqual(MembershipStatus.removed.rawValue, "removed")
        
        // Test that MembershipStatus can be created from raw values
        XCTAssertEqual(MembershipStatus(rawValue: "active"), .active)
        XCTAssertEqual(MembershipStatus(rawValue: "invited"), .invited)
        XCTAssertEqual(MembershipStatus(rawValue: "removed"), .removed)
    }
}