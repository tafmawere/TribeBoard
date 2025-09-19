import XCTest
import SwiftData
@testable import TribeBoard

/// Tests for input validation in DataService operations
@MainActor
final class DataServiceValidationTests: DatabaseTestBase {
    
    // MARK: - Family Validation Tests
    
    func testCreateFamilyWithEmptyName() throws {
        // Given
        let emptyName = ""
        let validCode = "TEST123"
        let createdByUserId = UUID()
        
        // When & Then
        XCTAssertThrowsError(try dataService.createFamily(name: emptyName, code: validCode, createdByUserId: createdByUserId)) { error in
            assertValidationError(error, containsMessages: ["name"])
        }
        
        // Verify no family was created
        try assertRecordCount(Family.self, expectedCount: 0)
    }
    
    func testCreateFamilyWithTooShortName() throws {
        // Given
        let shortName = "A" // Only 1 character, minimum is 2
        let validCode = "TEST123"
        let createdByUserId = UUID()
        
        // When & Then
        XCTAssertThrowsError(try dataService.createFamily(name: shortName, code: validCode, createdByUserId: createdByUserId)) { error in
            assertValidationError(error, containsMessages: ["name"])
        }
        
        // Verify no family was created
        try assertRecordCount(Family.self, expectedCount: 0)
    }
    
    func testCreateFamilyWithTooLongName() throws {
        // Given
        let longName = String(repeating: "A", count: 51) // Maximum is 50 characters
        let validCode = "TEST123"
        let createdByUserId = UUID()
        
        // When & Then
        XCTAssertThrowsError(try dataService.createFamily(name: longName, code: validCode, createdByUserId: createdByUserId)) { error in
            assertValidationError(error, containsMessages: ["name"])
        }
        
        // Verify no family was created
        try assertRecordCount(Family.self, expectedCount: 0)
    }
    
    func testCreateFamilyWithWhitespaceOnlyName() throws {
        // Given
        let whitespaceName = "   " // Only whitespace
        let validCode = "TEST123"
        let createdByUserId = UUID()
        
        // When & Then
        XCTAssertThrowsError(try dataService.createFamily(name: whitespaceName, code: validCode, createdByUserId: createdByUserId)) { error in
            assertValidationError(error, containsMessages: ["name"])
        }
        
        // Verify no family was created
        try assertRecordCount(Family.self, expectedCount: 0)
    }
    
    func testCreateFamilyWithValidNameBoundaries() throws {
        // Test minimum valid length (2 characters)
        let minValidName = "AB"
        let family1 = try dataService.createFamily(name: minValidName, code: "MIN123", createdByUserId: UUID())
        XCTAssertEqual(family1.name, minValidName)
        XCTAssertTrue(family1.isFullyValid)
        
        // Test maximum valid length (50 characters)
        let maxValidName = String(repeating: "A", count: 50)
        let family2 = try dataService.createFamily(name: maxValidName, code: "MAX123", createdByUserId: UUID())
        XCTAssertEqual(family2.name, maxValidName)
        XCTAssertTrue(family2.isFullyValid)
        
        // Verify both families were created
        try assertRecordCount(Family.self, expectedCount: 2)
    }
    
    func testCreateFamilyWithEmptyCode() throws {
        // Given
        let validName = "Test Family"
        let emptyCode = ""
        let createdByUserId = UUID()
        
        // When & Then
        XCTAssertThrowsError(try dataService.createFamily(name: validName, code: emptyCode, createdByUserId: createdByUserId)) { error in
            assertValidationError(error, containsMessages: ["code"])
        }
        
        // Verify no family was created
        try assertRecordCount(Family.self, expectedCount: 0)
    }
    
    func testCreateFamilyWithTooShortCode() throws {
        // Given
        let validName = "Test Family"
        let shortCode = "ABC12" // Only 5 characters, minimum is 6
        let createdByUserId = UUID()
        
        // When & Then
        XCTAssertThrowsError(try dataService.createFamily(name: validName, code: shortCode, createdByUserId: createdByUserId)) { error in
            assertValidationError(error, containsMessages: ["code"])
        }
        
        // Verify no family was created
        try assertRecordCount(Family.self, expectedCount: 0)
    }
    
    func testCreateFamilyWithTooLongCode() throws {
        // Given
        let validName = "Test Family"
        let longCode = "ABCDE1234" // 9 characters, maximum is 8
        let createdByUserId = UUID()
        
        // When & Then
        XCTAssertThrowsError(try dataService.createFamily(name: validName, code: longCode, createdByUserId: createdByUserId)) { error in
            assertValidationError(error, containsMessages: ["code"])
        }
        
        // Verify no family was created
        try assertRecordCount(Family.self, expectedCount: 0)
    }
    
    func testCreateFamilyWithInvalidCodeFormat() throws {
        let validName = "Test Family"
        let createdByUserId = UUID()
        
        let invalidCodes = [
            "ABC-123",  // Contains dash
            "ABC 123",  // Contains space
            "ABC@123",  // Contains special character
            "abc.123",  // Contains period
            "ABC_123",  // Contains underscore
            "ABC#123"   // Contains hash
        ]
        
        for invalidCode in invalidCodes {
            // When & Then
            XCTAssertThrowsError(try dataService.createFamily(name: validName, code: invalidCode, createdByUserId: createdByUserId)) { error in
                assertValidationError(error, containsMessages: ["code"])
            }
        }
        
        // Verify no families were created
        try assertRecordCount(Family.self, expectedCount: 0)
    }
    
    func testCreateFamilyWithValidCodeFormats() throws {
        let validName = "Test Family"
        let createdByUserId = UUID()
        
        let validCodes = [
            "ABC123",    // 6 characters, mixed
            "ABCD1234",  // 8 characters, mixed
            "123456",    // Numbers only
            "ABCDEF",    // Letters only
            "abc123",    // Lowercase
            "ABC123"     // Uppercase
        ]
        
        for (index, validCode) in validCodes.enumerated() {
            // When
            let family = try dataService.createFamily(name: "\(validName) \(index)", code: validCode, createdByUserId: createdByUserId)
            
            // Then
            XCTAssertEqual(family.code, validCode)
            XCTAssertTrue(family.isFullyValid)
        }
        
        // Verify all families were created
        try assertRecordCount(Family.self, expectedCount: validCodes.count)
    }
    
    func testCreateFamilyWithValidCodeBoundaries() throws {
        let validName = "Test Family"
        let createdByUserId = UUID()
        
        // Test minimum valid length (6 characters)
        let minValidCode = "ABC123"
        let family1 = try dataService.createFamily(name: "\(validName) Min", code: minValidCode, createdByUserId: createdByUserId)
        XCTAssertEqual(family1.code, minValidCode)
        XCTAssertTrue(family1.isFullyValid)
        
        // Test maximum valid length (8 characters)
        let maxValidCode = "ABCD1234"
        let family2 = try dataService.createFamily(name: "\(validName) Max", code: maxValidCode, createdByUserId: createdByUserId)
        XCTAssertEqual(family2.code, maxValidCode)
        XCTAssertTrue(family2.isFullyValid)
        
        // Verify both families were created
        try assertRecordCount(Family.self, expectedCount: 2)
    }
    
    // MARK: - UserProfile Validation Tests
    
    func testCreateUserProfileWithEmptyDisplayName() throws {
        // Given
        let emptyDisplayName = ""
        let validAppleUserIdHash = "valid_hash_1234567890"
        
        // When & Then
        XCTAssertThrowsError(try dataService.createUserProfile(displayName: emptyDisplayName, appleUserIdHash: validAppleUserIdHash)) { error in
            assertValidationError(error, containsMessages: ["display name"])
        }
        
        // Verify no user was created
        try assertRecordCount(UserProfile.self, expectedCount: 0)
    }
    
    func testCreateUserProfileWithWhitespaceOnlyDisplayName() throws {
        // Given
        let whitespaceDisplayName = "   " // Only whitespace
        let validAppleUserIdHash = "valid_hash_1234567890"
        
        // When & Then
        XCTAssertThrowsError(try dataService.createUserProfile(displayName: whitespaceDisplayName, appleUserIdHash: validAppleUserIdHash)) { error in
            assertValidationError(error, containsMessages: ["display name"])
        }
        
        // Verify no user was created
        try assertRecordCount(UserProfile.self, expectedCount: 0)
    }
    
    func testCreateUserProfileWithTooLongDisplayName() throws {
        // Given
        let longDisplayName = String(repeating: "A", count: 51) // Maximum is 50 characters
        let validAppleUserIdHash = "valid_hash_1234567890"
        
        // When & Then
        XCTAssertThrowsError(try dataService.createUserProfile(displayName: longDisplayName, appleUserIdHash: validAppleUserIdHash)) { error in
            assertValidationError(error, containsMessages: ["display name"])
        }
        
        // Verify no user was created
        try assertRecordCount(UserProfile.self, expectedCount: 0)
    }
    
    func testCreateUserProfileWithValidDisplayNameBoundaries() throws {
        let validAppleUserIdHash1 = "valid_hash_1234567890"
        let validAppleUserIdHash2 = "valid_hash_0987654321"
        
        // Test minimum valid length (1 character)
        let minValidDisplayName = "A"
        let user1 = try dataService.createUserProfile(displayName: minValidDisplayName, appleUserIdHash: validAppleUserIdHash1)
        XCTAssertEqual(user1.displayName, minValidDisplayName)
        XCTAssertTrue(user1.isFullyValid)
        
        // Test maximum valid length (50 characters)
        let maxValidDisplayName = String(repeating: "B", count: 50)
        let user2 = try dataService.createUserProfile(displayName: maxValidDisplayName, appleUserIdHash: validAppleUserIdHash2)
        XCTAssertEqual(user2.displayName, maxValidDisplayName)
        XCTAssertTrue(user2.isFullyValid)
        
        // Verify both users were created
        try assertRecordCount(UserProfile.self, expectedCount: 2)
    }
    
    func testCreateUserProfileWithEmptyAppleUserIdHash() throws {
        // Given
        let validDisplayName = "Test User"
        let emptyAppleUserIdHash = ""
        
        // When & Then
        XCTAssertThrowsError(try dataService.createUserProfile(displayName: validDisplayName, appleUserIdHash: emptyAppleUserIdHash)) { error in
            assertValidationError(error, containsMessages: ["Apple ID hash"])
        }
        
        // Verify no user was created
        try assertRecordCount(UserProfile.self, expectedCount: 0)
    }
    
    func testCreateUserProfileWithTooShortAppleUserIdHash() throws {
        // Given
        let validDisplayName = "Test User"
        let shortAppleUserIdHash = "short123" // Only 8 characters, minimum is 10
        
        // When & Then
        XCTAssertThrowsError(try dataService.createUserProfile(displayName: validDisplayName, appleUserIdHash: shortAppleUserIdHash)) { error in
            assertValidationError(error, containsMessages: ["Apple ID hash"])
        }
        
        // Verify no user was created
        try assertRecordCount(UserProfile.self, expectedCount: 0)
    }
    
    func testCreateUserProfileWithValidAppleUserIdHashBoundaries() throws {
        let validDisplayName = "Test User"
        
        // Test minimum valid length (10 characters)
        let minValidHash = "1234567890"
        let user1 = try dataService.createUserProfile(displayName: "\(validDisplayName) 1", appleUserIdHash: minValidHash)
        XCTAssertEqual(user1.appleUserIdHash, minValidHash)
        XCTAssertTrue(user1.isFullyValid)
        
        // Test longer hash (should also be valid)
        let longerValidHash = "very_long_apple_user_id_hash_1234567890"
        let user2 = try dataService.createUserProfile(displayName: "\(validDisplayName) 2", appleUserIdHash: longerValidHash)
        XCTAssertEqual(user2.appleUserIdHash, longerValidHash)
        XCTAssertTrue(user2.isFullyValid)
        
        // Verify both users were created
        try assertRecordCount(UserProfile.self, expectedCount: 2)
    }
    
    func testCreateUserProfileWithValidSpecialCharactersInDisplayName() throws {
        let validAppleUserIdHash = "valid_hash_1234567890"
        
        let validDisplayNames = [
            "User with spaces",
            "User-with-dashes",
            "User_with_underscores",
            "User123",
            "🙂 Emoji User",
            "Ñoñó Àccénts",
            "User.with.dots",
            "User@domain.com"
        ]
        
        for (index, displayName) in validDisplayNames.enumerated() {
            // When
            let user = try dataService.createUserProfile(
                displayName: displayName,
                appleUserIdHash: "\(validAppleUserIdHash)_\(index)"
            )
            
            // Then
            XCTAssertEqual(user.displayName, displayName)
            XCTAssertTrue(user.isFullyValid)
        }
        
        // Verify all users were created
        try assertRecordCount(UserProfile.self, expectedCount: validDisplayNames.count)
    }
    
    // MARK: - Validation Error Message Tests
    
    func testValidationErrorsProvideSpecificMessages() throws {
        // Test family name validation error message
        XCTAssertThrowsError(try dataService.createFamily(name: "", code: "TEST123", createdByUserId: UUID())) { error in
            guard let dataServiceError = error as? DataServiceError else {
                XCTFail("Expected DataServiceError")
                return
            }
            
            let errorMessage = dataServiceError.localizedDescription
            XCTAssertTrue(errorMessage.contains("Validation failed"), "Error message should indicate validation failure")
            XCTAssertTrue(errorMessage.lowercased().contains("name"), "Error message should mention the name field")
        }
        
        // Test family code validation error message
        XCTAssertThrowsError(try dataService.createFamily(name: "Valid Name", code: "ABC", createdByUserId: UUID())) { error in
            guard let dataServiceError = error as? DataServiceError else {
                XCTFail("Expected DataServiceError")
                return
            }
            
            let errorMessage = dataServiceError.localizedDescription
            XCTAssertTrue(errorMessage.contains("Validation failed"), "Error message should indicate validation failure")
            XCTAssertTrue(errorMessage.lowercased().contains("code"), "Error message should mention the code field")
        }
        
        // Test user display name validation error message
        XCTAssertThrowsError(try dataService.createUserProfile(displayName: "", appleUserIdHash: "valid_hash_123")) { error in
            guard let dataServiceError = error as? DataServiceError else {
                XCTFail("Expected DataServiceError")
                return
            }
            
            let errorMessage = dataServiceError.localizedDescription
            XCTAssertTrue(errorMessage.contains("Validation failed"), "Error message should indicate validation failure")
            XCTAssertTrue(errorMessage.lowercased().contains("display name"), "Error message should mention the display name field")
        }
        
        // Test user Apple ID hash validation error message
        XCTAssertThrowsError(try dataService.createUserProfile(displayName: "Valid Name", appleUserIdHash: "short")) { error in
            guard let dataServiceError = error as? DataServiceError else {
                XCTFail("Expected DataServiceError")
                return
            }
            
            let errorMessage = dataServiceError.localizedDescription
            XCTAssertTrue(errorMessage.contains("Validation failed"), "Error message should indicate validation failure")
            XCTAssertTrue(errorMessage.lowercased().contains("apple id hash"), "Error message should mention the Apple ID hash field")
        }
    }
    
    func testValidationErrorsAreActionable() throws {
        // Test that error messages provide actionable information
        
        // Family name too short
        XCTAssertThrowsError(try dataService.createFamily(name: "A", code: "TEST123", createdByUserId: UUID())) { error in
            let errorMessage = error.localizedDescription
            XCTAssertTrue(
                errorMessage.contains("2") || errorMessage.contains("length") || errorMessage.contains("characters"),
                "Error message should provide actionable information about length requirements: \(errorMessage)"
            )
        }
        
        // Family code invalid format
        XCTAssertThrowsError(try dataService.createFamily(name: "Valid Name", code: "ABC-123", createdByUserId: UUID())) { error in
            let errorMessage = error.localizedDescription
            XCTAssertTrue(
                errorMessage.contains("format") || errorMessage.contains("alphanumeric") || errorMessage.contains("characters"),
                "Error message should provide actionable information about format requirements: \(errorMessage)"
            )
        }
        
        // User Apple ID hash too short
        XCTAssertThrowsError(try dataService.createUserProfile(displayName: "Valid Name", appleUserIdHash: "short")) { error in
            let errorMessage = error.localizedDescription
            XCTAssertTrue(
                errorMessage.contains("10") || errorMessage.contains("length") || errorMessage.contains("format"),
                "Error message should provide actionable information about hash requirements: \(errorMessage)"
            )
        }
    }
    
    // MARK: - Multiple Validation Errors
    
    func testMultipleValidationErrors() throws {
        // Test that when multiple fields are invalid, all errors are reported
        // Note: Current implementation validates fields sequentially, so we test individual field validation
        
        // Test family with both invalid name and code
        XCTAssertThrowsError(try dataService.createFamily(name: "", code: "ABC", createdByUserId: UUID())) { error in
            // Should fail on name validation first
            assertValidationError(error, containsMessages: ["name"])
        }
        
        // Test user with both invalid display name and Apple ID hash
        XCTAssertThrowsError(try dataService.createUserProfile(displayName: "", appleUserIdHash: "short")) { error in
            // Should fail on display name validation first
            assertValidationError(error, containsMessages: ["display name"])
        }
    }
    
    // MARK: - Edge Cases with Trimming
    
    func testFamilyNameTrimmingBehavior() throws {
        // Test that names with leading/trailing whitespace are handled appropriately
        let nameWithSpaces = "  Valid Family Name  "
        let validCode = "TRIM123"
        let createdByUserId = UUID()
        
        // The validation should handle trimming internally
        // If trimmed name is valid, family should be created successfully
        let family = try dataService.createFamily(name: nameWithSpaces, code: validCode, createdByUserId: createdByUserId)
        
        // The stored name should be the original (with spaces) as that's what was provided
        XCTAssertEqual(family.name, nameWithSpaces)
        XCTAssertTrue(family.isFullyValid)
    }
    
    func testUserDisplayNameTrimmingBehavior() throws {
        // Test that display names with leading/trailing whitespace are handled appropriately
        let displayNameWithSpaces = "  Valid User Name  "
        let validAppleUserIdHash = "trim_hash_1234567890"
        
        // The validation should handle trimming internally
        // If trimmed name is valid, user should be created successfully
        let user = try dataService.createUserProfile(displayName: displayNameWithSpaces, appleUserIdHash: validAppleUserIdHash)
        
        // The stored name should be the original (with spaces) as that's what was provided
        XCTAssertEqual(user.displayName, displayNameWithSpaces)
        XCTAssertTrue(user.isFullyValid)
    }
    
    // MARK: - Validation Performance
    
    func testValidationPerformance() throws {
        // Test that validation doesn't significantly impact performance
        let validName = "Performance Test Family"
        let validCode = "PERF123"
        let createdByUserId = UUID()
        
        measure {
            do {
                // Create and immediately delete to avoid accumulating test data
                let family = try dataService.createFamily(name: validName, code: validCode, createdByUserId: createdByUserId)
                try dataService.delete(family)
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
}