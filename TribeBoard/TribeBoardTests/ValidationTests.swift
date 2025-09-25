import XCTest
@testable import TribeBoard

final class ValidationTests: XCTestCase {
    
    // MARK: - Family Name Validation Tests
    
    @MainActor func testValidateFamilyName_ValidNames() {
        let validNames = [
            "Smith Family",
            "The Johnsons",
            "Miller-Brown",
            "O'Connor Family",
            "Family123",
            "AB" // Minimum length
        ]
        
        for name in validNames {
            let result = Validation.validateFamilyName(name)
            XCTAssertTrue(result.isValid, "Family name '\(name)' should be valid")
        }
    }
    
    @MainActor func testValidateFamilyName_InvalidNames() {
        let invalidCases = [
            ("", "Family name cannot be empty"),
            ("   ", "Family name cannot be empty"), // Whitespace only
            ("A", "Family name must be at least 2 characters"),
            (String(repeating: "A", count: 51), "Family name cannot exceed 50 characters"),
            ("Smith@Family", "Family name contains invalid characters"),
            ("Family#123", "Family name contains invalid characters"),
            ("Test$Family", "Family name contains invalid characters")
        ]
        
        for (name, expectedMessage) in invalidCases {
            let result = Validation.validateFamilyName(name)
            XCTAssertFalse(result.isValid, "Family name '\(name)' should be invalid")
            XCTAssertTrue(result.message.contains(expectedMessage.split(separator: " ").first!), 
                         "Error message should contain expected text for '\(name)'")
        }
    }
    
    @MainActor func testValidateFamilyName_WhitespaceHandling() {
        let nameWithWhitespace = "  Smith Family  "
        let result = Validation.validateFamilyName(nameWithWhitespace)
        
        XCTAssertTrue(result.isValid, "Family name with surrounding whitespace should be valid")
    }
    
    // MARK: - Family Code Validation Tests
    
    @MainActor func testValidateFamilyCode_ValidCodes() {
        let validCodes = [
            "ABC123",
            "HELLO1",
            "TEST123",
            "FAMILY01",
            "123456", // All numbers
            "ABCDEF", // All letters
            "ABCDEFGH" // Maximum length
        ]
        
        for code in validCodes {
            let result = Validation.validateFamilyCode(code)
            XCTAssertTrue(result.isValid, "Family code '\(code)' should be valid")
        }
    }
    
    @MainActor func testValidateFamilyCode_InvalidCodes() {
        let invalidCases = [
            ("", "Family code cannot be empty"),
            ("   ", "Family code cannot be empty"), // Whitespace only
            ("ABC12", "Family code must be 6-8 characters"), // Too short
            ("ABCDEFGHI", "Family code must be 6-8 characters"), // Too long
            ("ABC-123", "Family code can only contain letters and numbers"),
            ("ABC 123", "Family code can only contain letters and numbers"),
            ("ABC@123", "Family code can only contain letters and numbers")
        ]
        
        for (code, expectedMessage) in invalidCases {
            let result = Validation.validateFamilyCode(code)
            XCTAssertFalse(result.isValid, "Family code '\(code)' should be invalid")
            XCTAssertTrue(result.message.contains(expectedMessage.split(separator: " ").first!), 
                         "Error message should contain expected text for '\(code)'")
        }
    }
    
    @MainActor func testValidateFamilyCode_CaseInsensitive() {
        let lowercaseCode = "abc123"
        let result = Validation.validateFamilyCode(lowercaseCode)
        
        XCTAssertTrue(result.isValid, "Lowercase family code should be valid")
    }
    
    // MARK: - Display Name Validation Tests
    
    @MainActor func testValidateDisplayName_ValidNames() {
        let validNames = [
            "John",
            "Mary Smith",
            "O'Connor",
            "Jean-Luc",
            "Anna-Maria",
            "John123",
            "A" // Minimum length
        ]
        
        for name in validNames {
            let result = Validation.validateDisplayName(name)
            XCTAssertTrue(result.isValid, "Display name '\(name)' should be valid")
        }
    }
    
    @MainActor func testValidateDisplayName_InvalidNames() {
        let invalidCases = [
            ("", "Display name cannot be empty"),
            ("   ", "Display name cannot be empty"), // Whitespace only
            (String(repeating: "A", count: 31), "Display name cannot exceed 30 characters"),
            ("John@Doe", "Display name contains invalid characters"),
            ("User#123", "Display name contains invalid characters")
        ]
        
        for (name, expectedMessage) in invalidCases {
            let result = Validation.validateDisplayName(name)
            XCTAssertFalse(result.isValid, "Display name '\(name)' should be invalid")
            XCTAssertTrue(result.message.contains(expectedMessage.split(separator: " ").first!), 
                         "Error message should contain expected text for '\(name)'")
        }
    }
    
    // MARK: - URL Validation Tests
    
    @MainActor func testValidateURL_ValidURLs() {
        let validURLs = [
            "https://example.com",
            "http://test.org",
            "https://subdomain.example.com/path",
            "http://localhost:3000",
            "https://api.example.com/v1/users"
        ]
        
        for url in validURLs {
            let result = Validation.validateURL(url)
            XCTAssertTrue(result.isValid, "URL '\(url)' should be valid")
        }
    }
    
    @MainActor func testValidateURL_InvalidURLs() {
        let invalidCases = [
            ("", "URL cannot be empty"),
            ("not-a-url", "Invalid URL format"),
            ("ftp://example.com", "Invalid URL format"), // Wrong scheme
            ("example.com", "Invalid URL format"), // Missing scheme
            ("://example.com", "Invalid URL format") // Empty scheme
        ]
        
        for (url, expectedMessage) in invalidCases {
            let result = Validation.validateURL(url)
            XCTAssertFalse(result.isValid, "URL '\(url)' should be invalid")
            XCTAssertTrue(result.message.contains(expectedMessage.split(separator: " ").first!), 
                         "Error message should contain expected text for '\(url)'")
        }
    }
    
    // MARK: - Helper Methods Tests
    
    @MainActor func testSanitizeInput_TrimsWhitespace() {
        let input = "  Hello World  "
        let sanitized = Validation.sanitizeInput(input)
        
        XCTAssertEqual(sanitized, "Hello World", "Should trim whitespace")
    }
    
    @MainActor func testSanitizeInput_LimitsLength() {
        let longInput = String(repeating: "A", count: 150)
        let sanitized = Validation.sanitizeInput(longInput, maxLength: 50)
        
        XCTAssertEqual(sanitized.count, 50, "Should limit to max length")
    }
    
    @MainActor func testSanitizeInput_DefaultMaxLength() {
        let longInput = String(repeating: "A", count: 150)
        let sanitized = Validation.sanitizeInput(longInput)
        
        XCTAssertEqual(sanitized.count, 100, "Should use default max length of 100")
    }
    
    @MainActor func testFormatFamilyCode_ConvertsToUppercase() {
        let input = "abc123"
        let formatted = Validation.formatFamilyCode(input)
        
        XCTAssertEqual(formatted, "ABC123", "Should convert to uppercase")
    }
    
    @MainActor func testFormatFamilyCode_RemovesInvalidCharacters() {
        let input = "abc-123 def@456"
        let formatted = Validation.formatFamilyCode(input)
        
        XCTAssertEqual(formatted, "ABC123DE", "Should remove invalid characters")
    }
    
    @MainActor func testFormatFamilyCode_LimitsLength() {
        let input = "abcdefghijklmnop"
        let formatted = Validation.formatFamilyCode(input)
        
        XCTAssertEqual(formatted.count, 8, "Should limit to 8 characters")
        XCTAssertEqual(formatted, "ABCDEFGH", "Should keep first 8 valid characters")
    }
    
    @MainActor func testFormatFamilyCode_TrimsWhitespace() {
        let input = "  abc123  "
        let formatted = Validation.formatFamilyCode(input)
        
        XCTAssertEqual(formatted, "ABC123", "Should trim whitespace")
    }
    
    // MARK: - ValidationResult Tests
    
    @MainActor func testValidationResult_Success() {
        let result = ValidationResult.success
        
        XCTAssertTrue(result.isValid, "Success result should be valid")
        XCTAssertEqual(result.message, "Valid", "Success result should have correct message")
    }
    
    @MainActor func testValidationResult_Failure() {
        let errorMessage = "Test error message"
        let result = ValidationResult.failure(errorMessage)
        
        XCTAssertFalse(result.isValid, "Failure result should be invalid")
        XCTAssertEqual(result.message, errorMessage, "Failure result should have correct message")
    }
}