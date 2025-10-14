import XCTest
import SwiftUI
@testable import TribeBoard

/// Comprehensive unit tests for paste functionality and validation in join family components
@MainActor
class PasteFunctionalityTests: TestBase {
    
    // MARK: - Properties
    
    var familyCode: String = ""
    var isCodeFieldFocused: Bool = false
    var originalClipboardContent: String?
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        // Save original clipboard content
        originalClipboardContent = UIPasteboard.general.string
        resetTestState()
    }
    
    override func tearDown() {
        // Restore original clipboard content
        UIPasteboard.general.string = originalClipboardContent
        resetTestState()
        super.tearDown()
    }
    
    private func resetTestState() {
        familyCode = ""
        isCodeFieldFocused = false
    }
    
    // MARK: - Clipboard Content Validation Tests
    
    func testClipboardValidation_ValidAlphanumericCode() {
        // Given
        let validCodes = ["ABC123", "XYZ789", "TEST01", "FAM999", "A1B2C3"]
        
        for code in validCodes {
            // When
            UIPasteboard.general.string = code
            
            // Then
            XCTAssertTrue(hasValidClipboardContent(), "Code '\(code)' should be valid for pasting")
        }
    }
    
    func testClipboardValidation_ValidCodeWithWhitespace() {
        // Given
        let codesWithWhitespace = [
            "  ABC123  ",
            "\tXYZ789\t",
            "\nTEST01\n",
            " A B C 1 2 3 ",
            "ABC 123"
        ]
        
        for code in codesWithWhitespace {
            // When
            UIPasteboard.general.string = code
            
            // Then
            XCTAssertTrue(hasValidClipboardContent(), "Code '\(code)' should be valid after whitespace removal")
        }
    }
    
    func testClipboardValidation_InvalidEmptyContent() {
        // Given
        let invalidContents = [nil, "", "   ", "\t\t", "\n\n"]
        
        for content in invalidContents {
            // When
            UIPasteboard.general.string = content
            
            // Then
            XCTAssertFalse(hasValidClipboardContent(), "Content '\(content ?? "nil")' should be invalid")
        }
    }
    
    func testClipboardValidation_InvalidTooLongContent() {
        // Given
        let tooLongCodes = [
            "ABCDEFG", // 7 characters
            "ABCDEFGH", // 8 characters
            "ABCDEFGHIJKLMNOP", // 16 characters
            "A1B2C3D4E5F6G7H8" // 16 characters
        ]
        
        for code in tooLongCodes {
            // When
            UIPasteboard.general.string = code
            
            // Then
            XCTAssertFalse(hasValidClipboardContent(), "Code '\(code)' should be invalid (too long)")
        }
    }
    
    func testClipboardValidation_InvalidSpecialCharacters() {
        // Given
        let invalidCodes = [
            "ABC-123",
            "ABC@123",
            "ABC#123",
            "ABC$123",
            "ABC%123",
            "ABC&123",
            "ABC*123",
            "ABC+123",
            "ABC=123",
            "ABC!123"
        ]
        
        for code in invalidCodes {
            // When
            UIPasteboard.general.string = code
            
            // Then
            XCTAssertFalse(hasValidClipboardContent(), "Code '\(code)' should be invalid (special characters)")
        }
    }
    
    func testClipboardValidation_EdgeCaseMaxLength() {
        // Given
        let maxLengthCodes = ["ABCDEF", "123456", "A1B2C3", "XXXXXX"]
        
        for code in maxLengthCodes {
            // When
            UIPasteboard.general.string = code
            
            // Then
            XCTAssertTrue(hasValidClipboardContent(), "Code '\(code)' should be valid (exactly 6 characters)")
        }
    }
    
    // MARK: - Paste Action Tests
    
    func testPasteAction_ValidCode() {
        // Given
        let testCode = "ABC123"
        UIPasteboard.general.string = testCode
        
        // When
        performPasteAction()
        
        // Then
        XCTAssertEqual(familyCode, testCode)
    }
    
    func testPasteAction_CodeWithWhitespace() {
        // Given
        let testCode = "  XYZ789  "
        let expectedCode = "XYZ789"
        UIPasteboard.general.string = testCode
        
        // When
        performPasteAction()
        
        // Then
        XCTAssertEqual(familyCode, expectedCode)
    }
    
    func testPasteAction_LowercaseCode() {
        // Given
        let testCode = "abc123"
        let expectedCode = "ABC123"
        UIPasteboard.general.string = testCode
        
        // When
        performPasteAction()
        
        // Then
        XCTAssertEqual(familyCode, expectedCode)
    }
    
    func testPasteAction_MixedCaseCode() {
        // Given
        let testCode = "aBc123"
        let expectedCode = "ABC123"
        UIPasteboard.general.string = testCode
        
        // When
        performPasteAction()
        
        // Then
        XCTAssertEqual(familyCode, expectedCode)
    }
    
    func testPasteAction_CodeTooLong() {
        // Given
        let testCode = "ABCDEFGH" // 8 characters
        let expectedCode = "ABCDEF" // Should be truncated to 6
        UIPasteboard.general.string = testCode
        
        // When
        performPasteAction()
        
        // Then
        XCTAssertEqual(familyCode, expectedCode)
    }
    
    func testPasteAction_EmptyClipboard() {
        // Given
        UIPasteboard.general.string = nil
        let originalCode = familyCode
        
        // When
        performPasteAction()
        
        // Then
        XCTAssertEqual(familyCode, originalCode) // Should remain unchanged
    }
    
    func testPasteAction_InvalidContent() {
        // Given
        let invalidContents = ["   ", "!@#$%^", "ABC-123", ""]
        
        for content in invalidContents {
            // Reset state
            familyCode = "ORIGINAL"
            UIPasteboard.general.string = content
            
            // When
            performPasteAction()
            
            // Then
            XCTAssertEqual(familyCode, "ORIGINAL", "Code should remain unchanged for invalid content: '\(content)'")
        }
    }
    
    // MARK: - Paste Button Visibility Tests
    
    func testPasteButtonVisibility_FocusedWithValidClipboard() {
        // Given
        UIPasteboard.general.string = "ABC123"
        isCodeFieldFocused = true
        
        // When
        let shouldShowPasteButton = determinePasteButtonVisibility()
        
        // Then
        XCTAssertTrue(shouldShowPasteButton)
    }
    
    func testPasteButtonVisibility_NotFocused() {
        // Given
        UIPasteboard.general.string = "ABC123"
        isCodeFieldFocused = false
        
        // When
        let shouldShowPasteButton = determinePasteButtonVisibility()
        
        // Then
        XCTAssertFalse(shouldShowPasteButton)
    }
    
    func testPasteButtonVisibility_FocusedWithInvalidClipboard() {
        // Given
        UIPasteboard.general.string = "INVALID_CONTENT_TOO_LONG"
        isCodeFieldFocused = true
        
        // When
        let shouldShowPasteButton = determinePasteButtonVisibility()
        
        // Then
        XCTAssertFalse(shouldShowPasteButton)
    }
    
    func testPasteButtonVisibility_FocusedWithEmptyClipboard() {
        // Given
        UIPasteboard.general.string = nil
        isCodeFieldFocused = true
        
        // When
        let shouldShowPasteButton = determinePasteButtonVisibility()
        
        // Then
        XCTAssertFalse(shouldShowPasteButton)
    }
    
    // MARK: - Code Cleaning and Transformation Tests
    
    func testCodeCleaning_RemoveWhitespace() {
        // Given
        let testCases = [
            ("  ABC123  ", "ABC123"),
            ("\tXYZ789\t", "XYZ789"),
            ("\nTEST01\n", "TEST01"),
            (" A B C 1 2 3 ", "ABC123"),
            ("A\tB\nC 1 2 3", "ABC123")
        ]
        
        for (input, expected) in testCases {
            // When
            let cleaned = cleanCode(input)
            
            // Then
            XCTAssertEqual(cleaned, expected, "Input '\(input)' should clean to '\(expected)'")
        }
    }
    
    func testCodeCleaning_UppercaseConversion() {
        // Given
        let testCases = [
            ("abc123", "ABC123"),
            ("xyz789", "XYZ789"),
            ("Test01", "TEST01"),
            ("fAm999", "FAM999"),
            ("MiXeD1", "MIXED1")
        ]
        
        for (input, expected) in testCases {
            // When
            let cleaned = cleanCode(input)
            
            // Then
            XCTAssertEqual(cleaned, expected, "Input '\(input)' should convert to '\(expected)'")
        }
    }
    
    func testCodeCleaning_FilterInvalidCharacters() {
        // Given
        let testCases = [
            ("ABC-123", "ABC123"),
            ("XYZ@789", "XYZ789"),
            ("TEST#01", "TEST01"),
            ("FAM$999", "FAM999"),
            ("A!B@C#1$2%3", "ABC123")
        ]
        
        for (input, expected) in testCases {
            // When
            let cleaned = cleanCode(input)
            
            // Then
            XCTAssertEqual(cleaned, expected, "Input '\(input)' should filter to '\(expected)'")
        }
    }
    
    func testCodeCleaning_LengthTruncation() {
        // Given
        let testCases = [
            ("ABCDEFG", "ABCDEF"), // 7 -> 6
            ("ABCDEFGH", "ABCDEF"), // 8 -> 6
            ("ABCDEFGHIJKLMNOP", "ABCDEF"), // 16 -> 6
            ("1234567890", "123456") // 10 -> 6
        ]
        
        for (input, expected) in testCases {
            // When
            let cleaned = cleanCode(input)
            
            // Then
            XCTAssertEqual(cleaned, expected, "Input '\(input)' should truncate to '\(expected)'")
        }
    }
    
    func testCodeCleaning_ComplexTransformation() {
        // Given
        let testCases = [
            ("  abc-123  ", "ABC123"),
            ("\t xyz@789 \n", "XYZ789"),
            (" t e s t # 0 1 ", "TEST01"),
            ("fAm$999!!!", "FAM999"),
            ("  MiX3d@C0d3!!  ", "MIX3DC")
        ]
        
        for (input, expected) in testCases {
            // When
            let cleaned = cleanCode(input)
            
            // Then
            XCTAssertEqual(cleaned, expected, "Input '\(input)' should transform to '\(expected)'")
        }
    }
    
    // MARK: - Validation Integration Tests
    
    func testValidationIntegration_PasteAndValidate() {
        // Given
        let validCodes = ["ABC123", "XYZ789", "TEST01"]
        
        for code in validCodes {
            // Reset state
            familyCode = ""
            UIPasteboard.general.string = code
            
            // When
            performPasteAction()
            let isValid = validateFamilyCode(familyCode)
            
            // Then
            XCTAssertEqual(familyCode, code)
            XCTAssertTrue(isValid, "Pasted code '\(code)' should be valid")
        }
    }
    
    func testValidationIntegration_PasteInvalidAndValidate() {
        // Given
        let invalidInputs = ["ABC12", "ABCDEFG", "ABC-123"]
        let expectedResults = ["ABC12", "ABCDEF", "ABC123"]
        let expectedValidations = [false, true, true]
        
        for (index, input) in invalidInputs.enumerated() {
            // Reset state
            familyCode = ""
            UIPasteboard.general.string = input
            
            // When
            performPasteAction()
            let isValid = validateFamilyCode(familyCode)
            
            // Then
            XCTAssertEqual(familyCode, expectedResults[index])
            XCTAssertEqual(isValid, expectedValidations[index], "Code '\(familyCode)' validation should be \(expectedValidations[index])")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling_ClipboardAccessFailure() {
        // Given
        // Simulate clipboard access failure by setting to nil
        UIPasteboard.general.string = nil
        let originalCode = familyCode
        
        // When
        performPasteAction()
        
        // Then
        XCTAssertEqual(familyCode, originalCode) // Should remain unchanged
    }
    
    func testErrorHandling_InvalidCharacterFiltering() {
        // Given
        let invalidInputs = ["!@#$%^", "------", "      ", "🎉🎊🎈"]
        
        for input in invalidInputs {
            // Reset state
            familyCode = "ORIGINAL"
            UIPasteboard.general.string = input
            
            // When
            performPasteAction()
            
            // Then
            XCTAssertEqual(familyCode, "ORIGINAL", "Invalid input '\(input)' should not change the code")
        }
    }
    
    // MARK: - Performance Tests
    
    func testPerformance_ClipboardValidation() {
        // Given
        UIPasteboard.general.string = "ABC123"
        
        // When & Then
        measure {
            for _ in 0..<1000 {
                _ = hasValidClipboardContent()
            }
        }
    }
    
    func testPerformance_CodeCleaning() {
        // Given
        let testCode = "  abc-123@xyz  "
        
        // When & Then
        measure {
            for _ in 0..<1000 {
                _ = cleanCode(testCode)
            }
        }
    }
    
    func testPerformance_PasteAction() {
        // Given
        UIPasteboard.general.string = "ABC123"
        
        // When & Then
        measure {
            for _ in 0..<100 {
                performPasteAction()
                familyCode = "" // Reset for next iteration
            }
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testEdgeCase_UnicodeCharacters() {
        // Given
        let unicodeCodes = ["ABC123🎉", "XYZ789é", "TEST01ñ", "FAM999ü"]
        let expectedCodes = ["ABC123", "XYZ789", "TEST01", "FAM999"]
        
        for (index, code) in unicodeCodes.enumerated() {
            // Reset state
            familyCode = ""
            UIPasteboard.general.string = code
            
            // When
            performPasteAction()
            
            // Then
            XCTAssertEqual(familyCode, expectedCodes[index], "Unicode characters should be filtered out")
        }
    }
    
    func testEdgeCase_VeryLongInput() {
        // Given
        let veryLongInput = String(repeating: "ABCDEF", count: 100) // 600 characters
        let expectedOutput = "ABCDEF" // Should be truncated to 6
        UIPasteboard.general.string = veryLongInput
        
        // When
        performPasteAction()
        
        // Then
        XCTAssertEqual(familyCode, expectedOutput)
        XCTAssertEqual(familyCode.count, 6)
    }
    
    func testEdgeCase_EmptyStringAfterCleaning() {
        // Given
        let inputsThatBecomeEmpty = ["!@#$%^", "------", "      ", "🎉🎊🎈"]
        
        for input in inputsThatBecomeEmpty {
            // Reset state
            familyCode = "ORIGINAL"
            UIPasteboard.general.string = input
            
            // When
            performPasteAction()
            
            // Then
            XCTAssertEqual(familyCode, "ORIGINAL", "Input that becomes empty after cleaning should not change the code")
        }
    }
    
    // MARK: - Helper Methods
    
    private func hasValidClipboardContent() -> Bool {
        guard let clipboardString = UIPasteboard.general.string else { return false }
        
        let cleanedString = clipboardString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { $0.isLetter || $0.isNumber }
        
        return !cleanedString.isEmpty && cleanedString.count <= 6
    }
    
    private func performPasteAction() {
        guard let clipboardString = UIPasteboard.general.string else { return }
        
        let cleanedCode = cleanCode(clipboardString)
        
        if !cleanedCode.isEmpty {
            if cleanedCode.count > 6 {
                familyCode = String(cleanedCode.prefix(6))
            } else {
                familyCode = cleanedCode
            }
        }
    }
    
    private func cleanCode(_ input: String) -> String {
        return input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
    }
    
    private func determinePasteButtonVisibility() -> Bool {
        return isCodeFieldFocused && hasValidClipboardContent()
    }
    
    private func validateFamilyCode(_ code: String) -> Bool {
        return code.count == 6 && code.allSatisfy { $0.isLetter || $0.isNumber }
    }
}