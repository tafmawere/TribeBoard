import XCTest
@testable import TribeBoard

final class CodeGeneratorTests: XCTestCase {
    
    var codeGenerator: CodeGenerator!
    
    override func setUp() {
        super.setUp()
        codeGenerator = CodeGenerator()
    }
    
    override func tearDown() {
        codeGenerator = nil
        super.tearDown()
    }
    
    // MARK: - Random Code Generation Tests
    
    func testGenerateRandomCode_DefaultLength() {
        let code = codeGenerator.generateRandomCode()
        
        XCTAssertEqual(code.count, 6, "Default code length should be 6")
        XCTAssertTrue(codeGenerator.isValidCodeFormat(code), "Generated code should be valid format")
    }
    
    func testGenerateRandomCode_CustomLength() {
        let customGenerator = CodeGenerator(codeLength: 8)
        let code = customGenerator.generateRandomCode()
        
        XCTAssertEqual(code.count, 8, "Custom code length should be 8")
        XCTAssertTrue(customGenerator.isValidCodeFormat(code), "Generated code should be valid format")
    }
    
    func testGenerateRandomCode_OnlyAllowedCharacters() {
        let code = codeGenerator.generateRandomCode()
        let allowedCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        
        for character in code {
            XCTAssertTrue(allowedCharacters.contains(character), "Code should only contain allowed characters")
        }
    }
    
    func testGenerateRandomCode_Uniqueness() {
        let codes = Set((0..<100).map { _ in codeGenerator.generateRandomCode() })
        
        // With 36^6 possible combinations, 100 codes should be unique
        XCTAssertEqual(codes.count, 100, "Generated codes should be unique")
    }
    
    // MARK: - Code Format Validation Tests
    
    func testIsValidCodeFormat_ValidCodes() {
        let validCodes = ["ABC123", "HELLO1", "TEST123", "FAMILY01"]
        
        for code in validCodes {
            XCTAssertTrue(codeGenerator.isValidCodeFormat(code), "Code '\(code)' should be valid")
        }
    }
    
    func testIsValidCodeFormat_InvalidLength() {
        let shortCode = "ABC12"  // 5 characters
        let longCode = "ABCDEFGHI"  // 9 characters
        
        XCTAssertFalse(codeGenerator.isValidCodeFormat(shortCode), "Short code should be invalid")
        XCTAssertFalse(codeGenerator.isValidCodeFormat(longCode), "Long code should be invalid")
    }
    
    func testIsValidCodeFormat_InvalidCharacters() {
        let invalidCodes = ["ABC-123", "HELLO!", "test@123", "FAMILY 1"]
        
        for code in invalidCodes {
            XCTAssertFalse(codeGenerator.isValidCodeFormat(code), "Code '\(code)' should be invalid")
        }
    }
    
    func testIsValidCodeFormat_LowercaseHandling() {
        let lowercaseCode = "abc123"
        
        XCTAssertTrue(codeGenerator.isValidCodeFormat(lowercaseCode), "Lowercase code should be valid (handled internally)")
    }
    
    // MARK: - Unique Code Generation Tests
    
    func testGenerateUniqueCode_Success() async throws {
        let expectation = XCTestExpectation(description: "Generate unique code")
        
        let uniqueCode = try await codeGenerator.generateUniqueCode { code in
            // Simulate all codes are unique
            return true
        }
        
        XCTAssertEqual(uniqueCode.count, 6, "Generated unique code should have correct length")
        XCTAssertTrue(codeGenerator.isValidCodeFormat(uniqueCode), "Generated unique code should be valid format")
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testGenerateUniqueCode_CollisionDetection() async throws {
        let expectation = XCTestExpectation(description: "Handle collision detection")
        var attemptCount = 0
        
        let uniqueCode = try await codeGenerator.generateUniqueCode { code in
            attemptCount += 1
            // First 3 attempts return false (collision), 4th returns true
            return attemptCount > 3
        }
        
        XCTAssertEqual(attemptCount, 4, "Should attempt 4 times before finding unique code")
        XCTAssertTrue(codeGenerator.isValidCodeFormat(uniqueCode), "Final code should be valid")
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testGenerateUniqueCode_MaxRetriesExceeded() async {
        let expectation = XCTestExpectation(description: "Max retries exceeded")
        
        do {
            _ = try await codeGenerator.generateUniqueCode { code in
                // Always return false to simulate constant collisions
                return false
            }
            XCTFail("Should throw maxRetriesExceeded error")
        } catch CodeGenerationError.maxRetriesExceeded {
            // Expected error
            expectation.fulfill()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testGenerateUniqueCode_UniquenessCheckFailure() async {
        let expectation = XCTestExpectation(description: "Uniqueness check failure")
        
        do {
            _ = try await codeGenerator.generateUniqueCode { code in
                throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
            }
            XCTFail("Should throw uniquenessCheckFailed error")
        } catch CodeGenerationError.uniquenessCheckFailed(let underlyingError) {
            XCTAssertEqual((underlyingError as NSError).domain, "TestError")
            expectation.fulfill()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Edge Cases
    
    func testCodeGenerator_BoundaryLengths() {
        let minGenerator = CodeGenerator(codeLength: 5) // Should clamp to 6
        let maxGenerator = CodeGenerator(codeLength: 10) // Should clamp to 8
        
        XCTAssertEqual(minGenerator.generateRandomCode().count, 6, "Should clamp minimum to 6")
        XCTAssertEqual(maxGenerator.generateRandomCode().count, 8, "Should clamp maximum to 8")
    }
    
    func testCodeGenerator_EmptyStringValidation() {
        XCTAssertFalse(codeGenerator.isValidCodeFormat(""), "Empty string should be invalid")
    }
}