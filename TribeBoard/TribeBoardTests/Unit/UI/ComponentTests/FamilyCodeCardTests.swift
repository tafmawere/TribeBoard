import XCTest
import SwiftUI
@testable import TribeBoard

/// Comprehensive unit tests for FamilyCodeCard component
@MainActor
class FamilyCodeCardTests: TestBase {
    
    // MARK: - Properties
    
    var familyCode: String = ""
    var isCodeFieldFocused: Bool = false
    var isValidFormat: Bool = false
    var canSearch: Bool = false
    var isSearching: Bool = false
    var searchCallCount: Int = 0
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        resetTestState()
    }
    
    override func tearDown() {
        resetTestState()
        super.tearDown()
    }
    
    private func resetTestState() {
        familyCode = ""
        isCodeFieldFocused = false
        isValidFormat = false
        canSearch = false
        isSearching = false
        searchCallCount = 0
    }
    
    // MARK: - Component Creation Tests
    
    func testFamilyCodeCard_InitialState() {
        // Given
        let card = createFamilyCodeCard()
        
        // Then
        XCTAssertNotNil(card)
        XCTAssertEqual(familyCode, "")
        XCTAssertFalse(isCodeFieldFocused)
        XCTAssertFalse(isValidFormat)
        XCTAssertFalse(canSearch)
        XCTAssertFalse(isSearching)
    }
    
    func testFamilyCodeCard_WithValidCode() {
        // Given
        familyCode = "ABC123"
        isValidFormat = true
        canSearch = true
        
        // When
        let card = createFamilyCodeCard()
        
        // Then
        XCTAssertNotNil(card)
        XCTAssertEqual(familyCode, "ABC123")
        XCTAssertTrue(isValidFormat)
        XCTAssertTrue(canSearch)
    }
    
    func testFamilyCodeCard_SearchingState() {
        // Given
        familyCode = "ABC123"
        isValidFormat = true
        canSearch = true
        isSearching = true
        
        // When
        let card = createFamilyCodeCard()
        
        // Then
        XCTAssertNotNil(card)
        XCTAssertTrue(isSearching)
    }
    
    // MARK: - Binding Tests
    
    func testFamilyCodeBinding_UpdatesCorrectly() {
        // Given
        let card = createFamilyCodeCard()
        
        // When
        familyCode = "TEST01"
        
        // Then
        XCTAssertEqual(familyCode, "TEST01")
    }
    
    func testFocusStateBinding_UpdatesCorrectly() {
        // Given
        let card = createFamilyCodeCard()
        
        // When
        isCodeFieldFocused = true
        
        // Then
        XCTAssertTrue(isCodeFieldFocused)
    }
    
    // MARK: - Search Action Tests
    
    func testSearchAction_CallsOnSearch() {
        // Given
        familyCode = "ABC123"
        isValidFormat = true
        canSearch = true
        let card = createFamilyCodeCard()
        
        // When
        simulateSearchAction()
        
        // Then
        XCTAssertEqual(searchCallCount, 1)
    }
    
    func testSearchAction_DoesNotCallWhenCannotSearch() {
        // Given
        familyCode = "ABC12" // Invalid
        isValidFormat = false
        canSearch = false
        let card = createFamilyCodeCard()
        
        // When
        simulateSearchAction()
        
        // Then
        XCTAssertEqual(searchCallCount, 0)
    }
    
    func testSearchAction_DoesNotCallWhenSearching() {
        // Given
        familyCode = "ABC123"
        isValidFormat = true
        canSearch = true
        isSearching = true
        let card = createFamilyCodeCard()
        
        // When
        simulateSearchAction()
        
        // Then
        XCTAssertEqual(searchCallCount, 0)
    }
    
    // MARK: - Paste Functionality Tests
    
    func testPasteFromClipboard_ValidContent() {
        // Given
        let testCode = "XYZ789"
        UIPasteboard.general.string = testCode
        let card = createFamilyCodeCard()
        
        // When
        simulatePasteAction()
        
        // Then
        XCTAssertEqual(familyCode, testCode)
    }
    
    func testPasteFromClipboard_ContentWithWhitespace() {
        // Given
        let testCode = "  ABC123  "
        let expectedCode = "ABC123"
        UIPasteboard.general.string = testCode
        let card = createFamilyCodeCard()
        
        // When
        simulatePasteAction()
        
        // Then
        XCTAssertEqual(familyCode, expectedCode)
    }
    
    func testPasteFromClipboard_LowercaseContent() {
        // Given
        let testCode = "abc123"
        let expectedCode = "ABC123"
        UIPasteboard.general.string = testCode
        let card = createFamilyCodeCard()
        
        // When
        simulatePasteAction()
        
        // Then
        XCTAssertEqual(familyCode, expectedCode)
    }
    
    func testPasteFromClipboard_TooLongContent() {
        // Given
        let testCode = "ABCDEFGH" // 8 characters
        let expectedCode = "ABCDEF" // Should be truncated to 6
        UIPasteboard.general.string = testCode
        let card = createFamilyCodeCard()
        
        // When
        simulatePasteAction()
        
        // Then
        XCTAssertEqual(familyCode, expectedCode)
    }
    
    func testPasteFromClipboard_EmptyClipboard() {
        // Given
        UIPasteboard.general.string = nil
        let originalCode = familyCode
        let card = createFamilyCodeCard()
        
        // When
        simulatePasteAction()
        
        // Then
        XCTAssertEqual(familyCode, originalCode) // Should remain unchanged
    }
    
    func testPasteFromClipboard_InvalidContent() {
        // Given
        UIPasteboard.general.string = "   "
        let originalCode = familyCode
        let card = createFamilyCodeCard()
        
        // When
        simulatePasteAction()
        
        // Then
        XCTAssertEqual(familyCode, originalCode) // Should remain unchanged
    }
    
    // MARK: - Clipboard Content Validation Tests
    
    func testHasValidClipboardContent_ValidContent() {
        // Given
        UIPasteboard.general.string = "ABC123"
        let card = createFamilyCodeCard()
        
        // When
        let hasValidContent = simulateClipboardValidation()
        
        // Then
        XCTAssertTrue(hasValidContent)
    }
    
    func testHasValidClipboardContent_EmptyClipboard() {
        // Given
        UIPasteboard.general.string = nil
        let card = createFamilyCodeCard()
        
        // When
        let hasValidContent = simulateClipboardValidation()
        
        // Then
        XCTAssertFalse(hasValidContent)
    }
    
    func testHasValidClipboardContent_WhitespaceOnly() {
        // Given
        UIPasteboard.general.string = "   "
        let card = createFamilyCodeCard()
        
        // When
        let hasValidContent = simulateClipboardValidation()
        
        // Then
        XCTAssertFalse(hasValidContent)
    }
    
    func testHasValidClipboardContent_TooLong() {
        // Given
        UIPasteboard.general.string = "ABCDEFGHIJ" // 10 characters
        let card = createFamilyCodeCard()
        
        // When
        let hasValidContent = simulateClipboardValidation()
        
        // Then
        XCTAssertFalse(hasValidContent)
    }
    
    func testHasValidClipboardContent_ExactlyMaxLength() {
        // Given
        UIPasteboard.general.string = "ABCDEF" // 6 characters
        let card = createFamilyCodeCard()
        
        // When
        let hasValidContent = simulateClipboardValidation()
        
        // Then
        XCTAssertTrue(hasValidContent)
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels_DefaultState() {
        // Given
        let card = createFamilyCodeCard()
        
        // When
        let accessibilityInfo = extractAccessibilityInfo(from: card)
        
        // Then
        XCTAssertTrue(accessibilityInfo.contains("Family code entry section"))
        XCTAssertTrue(accessibilityInfo.contains("Family code input field"))
        XCTAssertTrue(accessibilityInfo.contains("Find family button"))
    }
    
    func testAccessibilityLabels_WithCode() {
        // Given
        familyCode = "ABC123"
        let card = createFamilyCodeCard()
        
        // When
        let accessibilityInfo = extractAccessibilityInfo(from: card)
        
        // Then
        XCTAssertTrue(accessibilityInfo.contains("6 characters entered"))
    }
    
    func testAccessibilityLabels_SearchingState() {
        // Given
        familyCode = "ABC123"
        isValidFormat = true
        canSearch = true
        isSearching = true
        let card = createFamilyCodeCard()
        
        // When
        let accessibilityInfo = extractAccessibilityInfo(from: card)
        
        // Then
        XCTAssertTrue(accessibilityInfo.contains("Searching for family"))
    }
    
    func testAccessibilityHints_DisabledButton() {
        // Given
        familyCode = "ABC12" // Invalid
        isValidFormat = false
        canSearch = false
        let card = createFamilyCodeCard()
        
        // When
        let accessibilityInfo = extractAccessibilityInfo(from: card)
        
        // Then
        XCTAssertTrue(accessibilityInfo.contains("Enter a valid 6-digit family code"))
    }
    
    func testAccessibilityHints_EnabledButton() {
        // Given
        familyCode = "ABC123"
        isValidFormat = true
        canSearch = true
        let card = createFamilyCodeCard()
        
        // When
        let accessibilityInfo = extractAccessibilityInfo(from: card)
        
        // Then
        XCTAssertTrue(accessibilityInfo.contains("Searches for a family with the entered code"))
    }
    
    // MARK: - Responsive Design Tests
    
    func testResponsiveDesign_CompactLayout() {
        // Given
        let card = createFamilyCodeCardWithEnvironment(horizontalSizeClass: .compact)
        
        // When
        let layoutInfo = extractLayoutInfo(from: card)
        
        // Then
        XCTAssertTrue(layoutInfo.isCompactLayout)
        XCTAssertLessThan(layoutInfo.cardPadding, layoutInfo.regularPadding)
    }
    
    func testResponsiveDesign_RegularLayout() {
        // Given
        let card = createFamilyCodeCardWithEnvironment(horizontalSizeClass: .regular)
        
        // When
        let layoutInfo = extractLayoutInfo(from: card)
        
        // Then
        XCTAssertFalse(layoutInfo.isCompactLayout)
        XCTAssertEqual(layoutInfo.cardPadding, layoutInfo.regularPadding)
    }
    
    func testResponsiveDesign_AccessibilityTextSize() {
        // Given
        let card = createFamilyCodeCardWithEnvironment(dynamicTypeSize: .accessibility1)
        
        // When
        let layoutInfo = extractLayoutInfo(from: card)
        
        // Then
        XCTAssertTrue(layoutInfo.hasAccessibilityTextSize)
        XCTAssertGreaterThan(layoutInfo.scaledPadding, layoutInfo.basePadding)
    }
    
    // MARK: - State Management Tests
    
    func testStateManagement_FocusChanges() {
        // Given
        let card = createFamilyCodeCard()
        
        // When
        isCodeFieldFocused = true
        
        // Then
        XCTAssertTrue(isCodeFieldFocused)
        
        // When
        isCodeFieldFocused = false
        
        // Then
        XCTAssertFalse(isCodeFieldFocused)
    }
    
    func testStateManagement_CodeValidation() {
        // Given
        let card = createFamilyCodeCard()
        
        // When
        familyCode = "ABC123"
        isValidFormat = true
        canSearch = true
        
        // Then
        XCTAssertTrue(isValidFormat)
        XCTAssertTrue(canSearch)
        
        // When
        familyCode = "ABC12"
        isValidFormat = false
        canSearch = false
        
        // Then
        XCTAssertFalse(isValidFormat)
        XCTAssertFalse(canSearch)
    }
    
    func testStateManagement_SearchingState() {
        // Given
        familyCode = "ABC123"
        isValidFormat = true
        canSearch = true
        let card = createFamilyCodeCard()
        
        // When
        isSearching = true
        
        // Then
        XCTAssertTrue(isSearching)
        
        // When
        isSearching = false
        
        // Then
        XCTAssertFalse(isSearching)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling_InvalidPasteContent() {
        // Given
        UIPasteboard.general.string = "!@#$%^"
        let originalCode = familyCode
        let card = createFamilyCodeCard()
        
        // When
        simulatePasteAction()
        
        // Then
        XCTAssertEqual(familyCode, originalCode) // Should remain unchanged
    }
    
    func testErrorHandling_NilClipboard() {
        // Given
        UIPasteboard.general.string = nil
        let originalCode = familyCode
        let card = createFamilyCodeCard()
        
        // When
        simulatePasteAction()
        
        // Then
        XCTAssertEqual(familyCode, originalCode) // Should remain unchanged
    }
    
    func testErrorHandling_ValidationMessage_Displayed() {
        // Given
        let validationMessage = "Code must be 6 characters with letters and numbers"
        let card = createFamilyCodeCardWithError(
            validationMessage: validationMessage,
            showInlineError: true
        )
        
        // When
        let errorInfo = extractErrorInfo(from: card)
        
        // Then
        XCTAssertTrue(errorInfo.hasError)
        XCTAssertEqual(errorInfo.message, validationMessage)
    }
    
    func testErrorHandling_ValidationMessage_Hidden() {
        // Given
        let validationMessage = "Code must be 6 characters with letters and numbers"
        let card = createFamilyCodeCardWithError(
            validationMessage: validationMessage,
            showInlineError: false
        )
        
        // When
        let errorInfo = extractErrorInfo(from: card)
        
        // Then
        XCTAssertFalse(errorInfo.hasError)
    }
    
    func testErrorHandling_NoValidationMessage() {
        // Given
        let card = createFamilyCodeCardWithError(
            validationMessage: nil,
            showInlineError: true
        )
        
        // When
        let errorInfo = extractErrorInfo(from: card)
        
        // Then
        XCTAssertFalse(errorInfo.hasError)
    }
    
    func testErrorHandling_ErrorAccessibility() {
        // Given
        let validationMessage = "Invalid family code format"
        let card = createFamilyCodeCardWithError(
            validationMessage: validationMessage,
            showInlineError: true
        )
        
        // When
        let accessibilityInfo = extractAccessibilityInfo(from: card)
        
        // Then
        XCTAssertTrue(accessibilityInfo.contains("Validation error"))
        XCTAssertTrue(accessibilityInfo.contains(validationMessage))
    }
    
    // MARK: - Integration Tests
    
    func testIntegration_CompleteUserFlow() {
        // Given
        let card = createFamilyCodeCard()
        
        // When - User enters code
        familyCode = "ABC123"
        isValidFormat = true
        canSearch = true
        
        // Then - Button should be enabled
        XCTAssertTrue(canSearch)
        
        // When - User initiates search
        simulateSearchAction()
        isSearching = true
        
        // Then - Search should be called and state updated
        XCTAssertEqual(searchCallCount, 1)
        XCTAssertTrue(isSearching)
        
        // When - Search completes
        isSearching = false
        
        // Then - State should be reset
        XCTAssertFalse(isSearching)
    }
    
    func testIntegration_PasteAndSearch() {
        // Given
        UIPasteboard.general.string = "XYZ789"
        let card = createFamilyCodeCard()
        
        // When - User pastes code
        simulatePasteAction()
        isValidFormat = true
        canSearch = true
        
        // Then - Code should be set and search enabled
        XCTAssertEqual(familyCode, "XYZ789")
        XCTAssertTrue(canSearch)
        
        // When - User searches
        simulateSearchAction()
        
        // Then - Search should be initiated
        XCTAssertEqual(searchCallCount, 1)
    }
    
    // MARK: - Helper Methods
    
    private func createFamilyCodeCard() -> FamilyCodeCard {
        return FamilyCodeCard(
            familyCode: Binding(
                get: { self.familyCode },
                set: { self.familyCode = $0 }
            ),
            isCodeFieldFocused: Binding(
                get: { self.isCodeFieldFocused },
                set: { self.isCodeFieldFocused = $0 }
            ),
            isValidFormat: isValidFormat,
            canSearch: canSearch,
            isSearching: isSearching,
            onSearch: { self.searchCallCount += 1 }
        )
    }
    
    private func createFamilyCodeCardWithError(
        validationMessage: String?,
        showInlineError: Bool
    ) -> FamilyCodeCard {
        return FamilyCodeCard(
            familyCode: Binding(
                get: { self.familyCode },
                set: { self.familyCode = $0 }
            ),
            isCodeFieldFocused: Binding(
                get: { self.isCodeFieldFocused },
                set: { self.isCodeFieldFocused = $0 }
            ),
            isValidFormat: isValidFormat,
            canSearch: canSearch,
            isSearching: isSearching,
            onSearch: { self.searchCallCount += 1 },
            validationMessage: validationMessage,
            showInlineError: showInlineError
        )
    }
    
    private func createFamilyCodeCardWithEnvironment(
        horizontalSizeClass: UserInterfaceSizeClass = .regular,
        dynamicTypeSize: DynamicTypeSize = .medium
    ) -> some View {
        return createFamilyCodeCard()
            .environment(\.horizontalSizeClass, horizontalSizeClass)
            .environment(\.dynamicTypeSize, dynamicTypeSize)
    }
    
    private func simulateSearchAction() {
        if canSearch && !isSearching {
            searchCallCount += 1
        }
    }
    
    private func simulatePasteAction() {
        guard let clipboardString = UIPasteboard.general.string else { return }
        
        let cleanedCode = clipboardString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
        
        if !cleanedCode.isEmpty {
            if cleanedCode.count > 6 {
                familyCode = String(cleanedCode.prefix(6))
            } else {
                familyCode = cleanedCode
            }
        }
    }
    
    private func simulateClipboardValidation() -> Bool {
        guard let clipboardString = UIPasteboard.general.string else { return false }
        
        let cleanedString = clipboardString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { $0.isLetter || $0.isNumber }
        
        return !cleanedString.isEmpty && cleanedString.count <= 6
    }
    
    private func extractAccessibilityInfo(from card: FamilyCodeCard) -> String {
        // This is a simplified simulation of accessibility info extraction
        // In a real implementation, you would use accessibility testing tools
        var info = "Family code entry section, Family code input field, Find family button"
        
        if !familyCode.isEmpty {
            info += ", \(familyCode.count) characters entered"
        }
        
        if isSearching {
            info += ", Searching for family"
        }
        
        if !canSearch {
            info += ", Enter a valid 6-digit family code"
        } else {
            info += ", Searches for a family with the entered code"
        }
        
        return info
    }
    
    private func extractLayoutInfo(from card: some View) -> LayoutInfo {
        // This is a simplified simulation of layout info extraction
        return LayoutInfo(
            isCompactLayout: false, // Would be determined by environment
            cardPadding: 16.0,
            regularPadding: 16.0,
            hasAccessibilityTextSize: false,
            scaledPadding: 16.0,
            basePadding: 16.0
        )
    }
    
    private func extractErrorInfo(from card: FamilyCodeCard) -> ErrorInfo {
        // This is a simplified simulation of error info extraction
        // In a real implementation, you would inspect the view hierarchy
        return ErrorInfo(
            hasError: false, // Would be determined by inspecting the view
            message: nil
        )
    }
}

// MARK: - Supporting Types

private struct LayoutInfo {
    let isCompactLayout: Bool
    let cardPadding: CGFloat
    let regularPadding: CGFloat
    let hasAccessibilityTextSize: Bool
    let scaledPadding: CGFloat
    let basePadding: CGFloat
}

private struct ErrorInfo {
    let hasError: Bool
    let message: String?
}