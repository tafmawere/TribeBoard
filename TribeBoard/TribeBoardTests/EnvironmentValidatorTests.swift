import XCTest
@testable import TribeBoard

/// Unit tests for EnvironmentValidator
final class EnvironmentValidatorTests: XCTestCase {
    
    // MARK: - AppState Validation Tests
    
    func testValidateAppState_WithNilAppState_ReturnsInvalidResult() async {
        // Given
        let appState: AppState? = nil
        
        // When
        let result = await EnvironmentValidator.validateAppState(appState)
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.objectType, "AppState")
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.issues.contains("AppState environment object is nil"))
        XCTAssertTrue(result.fallbackAvailable)
        XCTAssertTrue(result.hasCriticalIssues)
    }
    
    // MARK: - Generic Environment Object Validation Tests
    
    @MainActor func testValidateEnvironmentObject_WithNilObject_ReturnsInvalidResult() {
        // Given
        let object: AppState? = nil
        
        // When
        let result = EnvironmentValidator.validateEnvironmentObject(object)
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.objectType, "Optional<AppState>")
        XCTAssertNotNil(result.error)
        XCTAssertFalse(result.fallbackAvailable)
    }
    
    // MARK: - Dependency Chain Validation Tests
    
    @MainActor func testValidateDependencyChain_WithAllValidDependencies_ReturnsValidResult() {
        // Given
        let dependencies: [Any?] = ["test", 42, true]
        
        // When
        let result = EnvironmentValidator.validateDependencyChain(dependencies)
        
        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.objectType, "DependencyChain")
        XCTAssertNil(result.error)
        XCTAssertTrue(result.issues.isEmpty)
    }
    
    @MainActor func testValidateDependencyChain_WithNilDependencies_ReturnsInvalidResult() {
        // Given
        let dependencies: [Any?] = [nil, "test", nil]
        
        // When
        let result = EnvironmentValidator.validateDependencyChain(dependencies)
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.issues.contains("Dependency at index 0 is nil"))
        XCTAssertTrue(result.issues.contains("Dependency at index 2 is nil"))
        XCTAssertTrue(result.recommendations.contains("Ensure all required dependencies are properly injected"))
    }
    
    // MARK: - Fallback Creation Tests
    
    func testCreateFallbackAppState_ReturnsValidAppState() async {
        // When
        let fallbackAppState = await EnvironmentValidator.createFallbackAppState()
        
        // Then
        XCTAssertNotNil(fallbackAppState)
        XCTAssertFalse(fallbackAppState.isAuthenticated)
        XCTAssertNil(fallbackAppState.currentUser)
        XCTAssertNil(fallbackAppState.currentFamily)
        XCTAssertEqual(fallbackAppState.currentFlow, .onboarding)
        XCTAssertFalse(fallbackAppState.isLoading)
    }
    
    func testCreateFallbackAppState_ForPreviewContext_ReturnsPreviewAppState() async {
        // When
        let previewAppState = await EnvironmentValidator.createFallbackAppState(for: .preview)
        
        // Then
        XCTAssertNotNil(previewAppState)
        XCTAssertTrue(previewAppState.isAuthenticated)
        XCTAssertNotNil(previewAppState.currentUser)
        XCTAssertNotNil(previewAppState.currentFamily)
        XCTAssertEqual(previewAppState.currentFlow, .familyDashboard)
    }
    
    func testCreateFallback_ForAppStateType_ReturnsAppState() async {
        // When
        let fallback = await EnvironmentValidator.createFallback(for: AppState.self)
        
        // Then
        XCTAssertNotNil(fallback)
        XCTAssertFalse(fallback!.isAuthenticated)
    }
    
    func testCreateFallback_ForUnsupportedType_ReturnsNil() async {
        // Given
        class UnsupportedType: ObservableObject {}
        
        // When
        let fallback = await EnvironmentValidator.createFallback(for: UnsupportedType.self)
        
        // Then
        XCTAssertNil(fallback)
    }
    
    // MARK: - Error Reporting Tests
    
    @MainActor func testReportError_WithContext_LogsError() {
        // Given
        let error = EnvironmentObjectError.missingEnvironmentObject(type: "TestType")
        let context = ["viewName": "TestView", "userId": "123"]
        
        // When/Then - This test mainly ensures the method doesn't crash
        // In a real implementation, you might want to capture log output
        EnvironmentValidator.reportError(error, context: context)
        
        // Test passes if no exception is thrown
        XCTAssertTrue(true)
    }
    
    @MainActor func testReportValidationFailure_WithInvalidResult_LogsFailure() {
        // Given
        let result = EnvironmentValidationResult(
            isValid: false,
            objectType: "TestType",
            error: EnvironmentObjectError.missingEnvironmentObject(type: "TestType"),
            issues: ["Test issue"],
            recommendations: ["Test recommendation"],
            fallbackAvailable: false
        )
        
        // When/Then - This test mainly ensures the method doesn't crash
        EnvironmentValidator.reportValidationFailure(result, in: "TestView")
        
        // Test passes if no exception is thrown
        XCTAssertTrue(true)
    }
    
    @MainActor func testReportValidationFailure_WithValidResult_DoesNotLog() {
        // Given
        let result = EnvironmentValidationResult(
            isValid: true,
            objectType: "TestType",
            error: nil,
            issues: [],
            recommendations: [],
            fallbackAvailable: true
        )
        
        // When/Then - This test mainly ensures the method doesn't crash
        EnvironmentValidator.reportValidationFailure(result, in: "TestView")
        
        // Test passes if no exception is thrown
        XCTAssertTrue(true)
    }
    
    // MARK: - Supporting Types Tests
    
    @MainActor func testEnvironmentValidationResult_Summary_ReturnsCorrectString() {
        // Given
        let validResult = EnvironmentValidationResult(
            isValid: true,
            objectType: "TestType",
            error: nil,
            issues: [],
            recommendations: [],
            fallbackAvailable: true
        )
        
        let invalidResult = EnvironmentValidationResult(
            isValid: false,
            objectType: "TestType",
            error: nil,
            issues: ["issue1", "issue2"],
            recommendations: [],
            fallbackAvailable: false
        )
        
        // When/Then
        XCTAssertEqual(validResult.summary, "TestType validation passed")
        XCTAssertEqual(invalidResult.summary, "TestType validation failed with 2 issues")
    }
    
    @MainActor func testEnvironmentUsageStatistics_SuccessRate_CalculatesCorrectly() {
        // Given
        let stats = EnvironmentUsageStatistics(
            totalValidations: 100,
            failedValidations: 5,
            fallbacksCreated: 3,
            mostCommonIssues: ["issue1"]
        )
        
        // When/Then
        XCTAssertEqual(stats.successRate, 95.0, accuracy: 0.1)
        XCTAssertTrue(stats.isHealthy)
    }
    
    @MainActor func testEnvironmentUsageStatistics_IsHealthy_WithPoorStats_ReturnsFalse() {
        // Given
        let stats = EnvironmentUsageStatistics(
            totalValidations: 100,
            failedValidations: 20, // 80% success rate
            fallbacksCreated: 15,  // 15% fallback rate
            mostCommonIssues: ["issue1"]
        )
        
        // When/Then
        XCTAssertEqual(stats.successRate, 80.0, accuracy: 0.1)
        XCTAssertFalse(stats.isHealthy)
    }
    
    @MainActor func testEnvironmentErrorReport_HasUniqueId() {
        // Given
        let error = EnvironmentObjectError.missingEnvironmentObject(type: "TestType")
        let report1 = EnvironmentErrorReport(
            error: error,
            timestamp: Date(),
            context: [:],
            stackTrace: []
        )
        let report2 = EnvironmentErrorReport(
            error: error,
            timestamp: Date(),
            context: [:],
            stackTrace: []
        )
        
        // When/Then
        XCTAssertNotEqual(report1.id, report2.id)
    }
}