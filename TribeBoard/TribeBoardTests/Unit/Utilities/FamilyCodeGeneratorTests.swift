import XCTest
@testable import TribeBoard

/// Comprehensive unit tests for FamilyCodeGenerator covering code generation and validation
class FamilyCodeGeneratorTests: TestBase {
    
    // MARK: - Code Generation Tests
    
    func testGenerateCode_ReturnsCorrectLength() {
        // When
        let code = FamilyCodeGenerator.generateCode()
        
        // Then
        XCTAssertEqual(code.count, 6, "Generated code should be exactly 6 characters")
    }
    
    func testGenerateCode_ContainsOnlyValidCharacters() {
        // Given
        let validCharacters = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        
        // When
        let code = FamilyCodeGenerator.generateCode()
        
        // Then
        for character in code {
            XCTAssertTrue(validCharacters.contains(character), "Code contains invalid character: \(character)")
        }
    }
    
    func testGenerateCode_IsAlphanumeric() {
        // When
        let code = FamilyCodeGenerator.generateCode()
        
        // Then
        XCTAssertTrue(code.allSatisfy { $0.isLetter || $0.isNumber }, "Code should contain only letters and numbers")
    }
    
    func testGenerateCode_IsUppercase() {
        // When
        let code = FamilyCodeGenerator.generateCode()
        
        // Then
        XCTAssertEqual(code, code.uppercased(), "Generated code should be uppercase")
    }
    
    func testGenerateCode_GeneratesUniqueCodesInSequence() {
        // Given
        let numberOfCodes = 100
        var generatedCodes = Set<String>()
        
        // When
        for _ in 0..<numberOfCodes {
            let code = FamilyCodeGenerator.generateCode()
            generatedCodes.insert(code)
        }
        
        // Then
        // While theoretically possible to have duplicates, with 36^6 possibilities,
        // generating 100 unique codes should be highly likely
        XCTAssertGreaterThan(generatedCodes.count, numberOfCodes * 0.95, 
                           "Should generate mostly unique codes (at least 95% unique)")
    }
    
    func testGenerateCode_PerformanceTest() {
        // Given
        let iterations = 1000
        
        // When
        measure {
            for _ in 0..<iterations {
                _ = FamilyCodeGenerator.generateCode()
            }
        }
        
        // Then - Test passes if it completes within reasonable time
    }
    
    // MARK: - Code Validation Tests
    
    func testIsValidCodeFormat_ValidCodes() {
        // Given
        let validCodes = [
            "ABC123",
            "XYZ789",
            "TEST01",
            "FAM999",
            "HOME12",
            "CLAN99",
            "123456",
            "ABCDEF",
            "A1B2C3",
            "9Z8Y7X"
        ]
        
        // When & Then
        for code in validCodes {
            XCTAssertTrue(FamilyCodeGenerator.isValidCodeFormat(code), 
                         "Code '\(code)' should be valid")
        }
    }
    
    func testIsValidCodeFormat_InvalidCodes_TooShort() {
        // Given
        let shortCodes = [
            "",
            "A",
            "AB",
            "ABC",
            "ABCD",
            "ABCDE"
        ]
        
        // When & Then
        for code in shortCodes {
            XCTAssertFalse(FamilyCodeGenerator.isValidCodeFormat(code), 
                          "Code '\(code)' should be invalid (too short)")
        }
    }
    
    func testIsValidCodeFormat_InvalidCodes_TooLong() {
        // Given
        let longCodes = [
            "ABCDEFG",
            "ABCDEFGH",
            "ABCDEFGHI",
            "1234567890"
        ]
        
        // When & Then
        for code in longCodes {
            XCTAssertFalse(FamilyCodeGenerator.isValidCodeFormat(code), 
                          "Code '\(code)' should be invalid (too long)")
        }
    }
    
    func testIsValidCodeFormat_InvalidCodes_SpecialCharacters() {
        // Given
        let codesWithSpecialChars = [
            "ABC-123",
            "ABC_123",
            "ABC 123",
            "ABC.123",
            "ABC@123",
            "ABC#123",
            "ABC$123",
            "ABC%123",
            "ABC&123",
            "ABC*123",
            "ABC+123",
            "ABC=123",
            "ABC!123",
            "ABC?123"
        ]
        
        // When & Then
        for code in codesWithSpecialChars {
            XCTAssertFalse(FamilyCodeGenerator.isValidCodeFormat(code), 
                          "Code '\(code)' should be invalid (contains special characters)")
        }
    }
    
    func testIsValidCodeFormat_InvalidCodes_Lowercase() {
        // Given
        let lowercaseCodes = [
            "abc123",
            "xyz789",
            "test01",
            "family",
            "home12"
        ]
        
        // When & Then
        for code in lowercaseCodes {
            XCTAssertFalse(FamilyCodeGenerator.isValidCodeFormat(code), 
                          "Code '\(code)' should be invalid (contains lowercase)")
        }
    }
    
    func testIsValidCodeFormat_InvalidCodes_MixedCase() {
        // Given
        let mixedCaseCodes = [
            "Abc123",
            "ABC123a",
            "AbC123",
            "aBc123",
            "ABC12c"
        ]
        
        // When & Then
        for code in mixedCaseCodes {
            XCTAssertFalse(FamilyCodeGenerator.isValidCodeFormat(code), 
                          "Code '\(code)' should be invalid (mixed case)")
        }
    }
    
    func testIsValidCodeFormat_WithWhitespace() {
        // Given
        let codesWithWhitespace = [
            " ABC123",
            "ABC123 ",
            " ABC123 ",
            "ABC 123",
            "\tABC123",
            "ABC123\n",
            "\nABC123\t"
        ]
        
        // When & Then
        for code in codesWithWhitespace {
            XCTAssertFalse(FamilyCodeGenerator.isValidCodeFormat(code), 
                          "Code '\(code)' should be invalid (contains whitespace)")
        }
    }
    
    func testIsValidCodeFormat_EdgeCases() {
        // Given & When & Then
        XCTAssertFalse(FamilyCodeGenerator.isValidCodeFormat(""), "Empty string should be invalid")
        XCTAssertFalse(FamilyCodeGenerator.isValidCodeFormat("      "), "Whitespace-only string should be invalid")
        XCTAssertFalse(FamilyCodeGenerator.isValidCodeFormat("\n\t\r"), "Control characters should be invalid")
    }
    
    // MARK: - Integration Tests
    
    func testGeneratedCodesPassValidation() {
        // Given
        let numberOfTests = 100
        
        // When & Then
        for _ in 0..<numberOfTests {
            let generatedCode = FamilyCodeGenerator.generateCode()
            XCTAssertTrue(FamilyCodeGenerator.isValidCodeFormat(generatedCode), 
                         "Generated code '\(generatedCode)' should pass validation")
        }
    }
    
    func testValidationConsistency() {
        // Given
        let testCode = "ABC123"
        
        // When & Then
        // Multiple calls should return the same result
        for _ in 0..<10 {
            XCTAssertTrue(FamilyCodeGenerator.isValidCodeFormat(testCode), 
                         "Validation should be consistent")
        }
    }
    
    // MARK: - Boundary Tests
    
    func testIsValidCodeFormat_ExactlyValidLength() {
        // Given
        let exactLengthCodes = [
            "ABCDEF", // 6 letters
            "123456", // 6 numbers
            "A1B2C3", // 6 mixed
            "ZZZZZZ", // 6 same letter
            "999999"  // 6 same number
        ]
        
        // When & Then
        for code in exactLengthCodes {
            XCTAssertTrue(FamilyCodeGenerator.isValidCodeFormat(code), 
                         "Code '\(code)' with exactly 6 characters should be valid")
        }
    }
    
    func testIsValidCodeFormat_BoundaryLengths() {
        // Given
        let fiveCharCode = "ABCDE"
        let sevenCharCode = "ABCDEFG"
        
        // When & Then
        XCTAssertFalse(FamilyCodeGenerator.isValidCodeFormat(fiveCharCode), 
                      "5-character code should be invalid")
        XCTAssertFalse(FamilyCodeGenerator.isValidCodeFormat(sevenCharCode), 
                      "7-character code should be invalid")
    }
    
    // MARK: - Character Set Tests
    
    func testValidCharacterSet_AllLetters() {
        // Given
        let allLetters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        
        // When & Then
        for letter in allLetters {
            let code = String(repeating: String(letter), count: 6)
            XCTAssertTrue(FamilyCodeGenerator.isValidCodeFormat(code), 
                         "Code with letter '\(letter)' should be valid")
        }
    }
    
    func testValidCharacterSet_AllNumbers() {
        // Given
        let allNumbers = "0123456789"
        
        // When & Then
        for number in allNumbers {
            let code = String(repeating: String(number), count: 6)
            XCTAssertTrue(FamilyCodeGenerator.isValidCodeFormat(code), 
                         "Code with number '\(number)' should be valid")
        }
    }
    
    // MARK: - Real-World Scenario Tests
    
    func testRealWorldScenarios_TypicalFamilyCodes() {
        // Given - codes that might be generated in real usage
        let typicalCodes = [
            "SMITH1",
            "JONES2",
            "FAMILY",
            "HOME01",
            "CLAN99",
            "TRIBE1"
        ]
        
        // When & Then
        for code in typicalCodes {
            XCTAssertTrue(FamilyCodeGenerator.isValidCodeFormat(code), 
                         "Typical family code '\(code)' should be valid")
        }
    }
    
    func testRealWorldScenarios_UserInputErrors() {
        // Given - common user input errors
        let commonErrors = [
            "abc123",     // lowercase
            "ABC 123",    // space
            "ABC-123",    // hyphen
            "ABC123!",    // exclamation
            "ABC12",      // too short
            "ABC1234",    // too long
            " ABC123 "    // leading/trailing spaces
        ]
        
        // When & Then
        for errorCode in commonErrors {
            XCTAssertFalse(FamilyCodeGenerator.isValidCodeFormat(errorCode), 
                          "Common error '\(errorCode)' should be invalid")
        }
    }
    
    // MARK: - Performance Tests
    
    func testValidationPerformance() {
        // Given
        let testCodes = (0..<1000).map { _ in FamilyCodeGenerator.generateCode() }
        
        // When
        measure {
            for code in testCodes {
                _ = FamilyCodeGenerator.isValidCodeFormat(code)
            }
        }
        
        // Then - Test passes if it completes within reasonable time
    }
    
    func testGenerationPerformance_LargeScale() {
        // Given
        let iterations = 10000
        
        // When
        measure {
            for _ in 0..<iterations {
                _ = FamilyCodeGenerator.generateCode()
            }
        }
        
        // Then - Test passes if it completes within reasonable time
    }
    
    // MARK: - Thread Safety Tests (if applicable)
    
    func testConcurrentGeneration() {
        // Given
        let expectation = XCTestExpectation(description: "Concurrent generation")
        let iterations = 100
        let concurrentQueues = 5
        var generatedCodes: [String] = []
        let lock = NSLock()
        
        // When
        for _ in 0..<concurrentQueues {
            DispatchQueue.global().async {
                for _ in 0..<iterations {
                    let code = FamilyCodeGenerator.generateCode()
                    lock.lock()
                    generatedCodes.append(code)
                    lock.unlock()
                }
                
                if generatedCodes.count == iterations * concurrentQueues {
                    expectation.fulfill()
                }
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 10.0)
        XCTAssertEqual(generatedCodes.count, iterations * concurrentQueues)
        
        // All generated codes should be valid
        for code in generatedCodes {
            XCTAssertTrue(FamilyCodeGenerator.isValidCodeFormat(code), 
                         "Concurrently generated code '\(code)' should be valid")
        }
    }
    
    func testConcurrentValidation() {
        // Given
        let expectation = XCTestExpectation(description: "Concurrent validation")
        let testCodes = (0..<100).map { _ in FamilyCodeGenerator.generateCode() }
        let concurrentQueues = 5
        var validationResults: [Bool] = []
        let lock = NSLock()
        
        // When
        for _ in 0..<concurrentQueues {
            DispatchQueue.global().async {
                for code in testCodes {
                    let isValid = FamilyCodeGenerator.isValidCodeFormat(code)
                    lock.lock()
                    validationResults.append(isValid)
                    lock.unlock()
                }
                
                if validationResults.count == testCodes.count * concurrentQueues {
                    expectation.fulfill()
                }
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 10.0)
        XCTAssertEqual(validationResults.count, testCodes.count * concurrentQueues)
        
        // All validations should return true (since we're validating generated codes)
        for result in validationResults {
            XCTAssertTrue(result, "All concurrent validations should return true")
        }
    }
}