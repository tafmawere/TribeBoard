import XCTest
import SwiftUI
@testable import TribeBoard

/// Comprehensive unit tests for environment object handling
/// Tests SafeEnvironmentObject property wrapper, validation, fallback behavior, navigation safety, and error handling
@MainActor
final class EnvironmentObjectHandlingTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var testAppState: AppState!
    var mockUser: UserProfile!
    var mockFamily: Family!
    var mockMembership: Membership!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create test data
        mockUser = UserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash_12345"
        )
        
        mockFamily = Family(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: UUID()
        )
        
        mockMembership = Membership(
            family: mockFamily,
            user: mockUser,
            role: .parentAdmin
        )
        
        // Create test AppState
        testAppState = AppStateFactory.createTestAppState(scenario: .authenticated)
        testAppState.currentUser = mockUser
        testAppState.currentFamily = mockFamily
        testAppState.currentMembership = mockMembership
    }
    
    override func tearDown() async throws {
        testAppState = nil
        mockUser = nil
        mockFamily = nil
        mockMembership = nil
        try await super.tearDown()
    }
    
    // MARK: - SafeEnvironmentObject Property Wrapper Tests
    
    /// Test SafeEnvironmentObject uses fallback when environment object is missing
    func testSafeEnvironmentObjectFallbackBehavior() throws {
        let testView = TestViewWithSafeEnvironmentObject()
        let hostingController = UIHostingController(rootView: testView)
        
        // View should not crash and should use fallback
        XCTAssertNotNil(hostingController.view)
        hostingController.loadViewIfNeeded()
        XCTAssertTrue(hostingController.isViewLoaded)
    }
    
    /// Test SafeEnvironmentObject uses provided environment object when available
    func testSafeEnvironmentObjectWithProvidedEnvironment() throws {
        let testView = TestViewWithSafeEnvironmentObject()
            .environmentObject(testAppState)
        
        let hostingController = UIHostingController(rootView: testView)
        
        // View should use provided environment object
        XCTAssertNotNil(hostingController.view)
        hostingController.loadViewIfNeeded()
        XCTAssertTrue(hostingController.isViewLoaded)
    }
    
    /// Test SafeEnvironmentObject projected value provides correct information
    func testSafeEnvironmentObjectProjectedValue() throws {
        let testView = TestViewWithProjectedValue()
        let hostingController = UIHostingController(rootView: testView)
        
        // Should not crash when accessing projected value
        XCTAssertNotNil(hostingController.view)
        hostingController.loadViewIfNeeded()
        XCTAssertTrue(hostingController.isViewLoaded)
    }
    
    /// Test SafeEnvironmentObject with custom observable object
    func testSafeEnvironmentObjectWithCustomType() throws {
        let testView = TestViewWithMockObject()
        let hostingController = UIHostingController(rootView: testView)
        
        // Should work with any ObservableObject type
        XCTAssertNotNil(hostingController.view)
        hostingController.loadViewIfNeeded()
        XCTAssertTrue(hostingController.isViewLoaded)
    }
    
    /// Test SafeEnvironmentObject fallback factory function
    func testSafeEnvironmentObjectFallbackFactory() throws {
        // Test that fallback factory is called when needed
        var factoryCalled = false
        
        let testView = TestViewWithCustomFallback {
            factoryCalled = true
            return AppState.createFallback()
        }
        
        let hostingController = UIHostingController(rootView: testView)
        hostingController.loadViewIfNeeded()
        
        // Factory should be called since no environment object is provided
        XCTAssertTrue(factoryCalled)
    }
    
    // MARK: - Environment Object Validation Tests
    
    /// Test EnvironmentValidator with valid AppState
    @MainActor func testEnvironmentValidatorWithValidAppState() {
        let result = EnvironmentValidator.validateAppState(testAppState)
        
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.objectType, "AppState")
        XCTAssertNil(result.error)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertTrue(result.fallbackAvailable)
    }
    
    /// Test EnvironmentValidator with nil AppState
    @MainActor func testEnvironmentValidatorWithNilAppState() {
        let result = EnvironmentValidator.validateAppState(nil)
        
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.objectType, "AppState")
        XCTAssertNotNil(result.error)
        XCTAssertFalse(result.issues.isEmpty)
        XCTAssertTrue(result.fallbackAvailable)
        
        if case .missingEnvironmentObject(let type) = result.error {
            XCTAssertEqual(type, "AppState")
        } else {
            XCTFail("Expected missingEnvironmentObject error")
        }
    }
    
    /// Test EnvironmentValidator with inconsistent AppState
    @MainActor func testEnvironmentValidatorWithInconsistentAppState() {
        // Create inconsistent state
        testAppState.isAuthenticated = true
        testAppState.currentUser = nil // Inconsistent
        
        let result = EnvironmentValidator.validateAppState(testAppState)
        
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.error)
        XCTAssertFalse(result.issues.isEmpty)
        XCTAssertFalse(result.recommendations.isEmpty)
        
        // Should contain specific issue about authentication inconsistency
        XCTAssertTrue(result.issues.contains { $0.contains("authenticated") && $0.contains("currentUser") })
    }
    
    /// Test EnvironmentValidator with invalid navigation state
    @MainActor func testEnvironmentValidatorWithInvalidNavigationState() {
        // Create state with deep navigation path
        for _ in 0..<15 {
            testAppState.navigationPath.append("test")
        }
        
        let result = EnvironmentValidator.validateAppState(testAppState)
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.issues.contains { $0.contains("Navigation path") })
        XCTAssertTrue(result.recommendations.contains { $0.contains("resetting navigation path") })
    }
    
    /// Test EnvironmentValidator with generic ObservableObject
    @MainActor func testEnvironmentValidatorWithGenericObservableObject() {
        let mockObject = MockObservableObject()
        let result = EnvironmentValidator.validateEnvironmentObject(mockObject)
        
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.objectType, "MockObservableObject")
        XCTAssertNil(result.error)
        XCTAssertFalse(result.fallbackAvailable)
    }
    
    /// Test EnvironmentValidator with nil generic object
    @MainActor func testEnvironmentValidatorWithNilGenericObject() {
        let result = EnvironmentValidator.validateEnvironmentObject(nil as MockObservableObject?)
        
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.objectType, "MockObservableObject")
        XCTAssertNotNil(result.error)
        XCTAssertFalse(result.fallbackAvailable)
    }
    
    /// Test EnvironmentValidator dependency chain validation
    @MainActor func testEnvironmentValidatorDependencyChain() {
        let dependencies: [Any?] = [testAppState, mockUser, mockFamily]
        let result = EnvironmentValidator.validateDependencyChain(dependencies)
        
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.objectType, "DependencyChain")
        XCTAssertNil(result.error)
        XCTAssertTrue(result.issues.isEmpty)
    }
    
    /// Test EnvironmentValidator with broken dependency chain
    @MainActor func testEnvironmentValidatorWithBrokenDependencyChain() {
        let dependencies: [Any?] = [testAppState, nil, mockFamily, nil]
        let result = EnvironmentValidator.validateDependencyChain(dependencies)
        
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.objectType, "DependencyChain")
        XCTAssertNotNil(result.error)
        XCTAssertEqual(result.issues.count, 2) // Two nil dependencies
        
        if case .dependencyInjectionFailure(let message) = result.error {
            XCTAssertTrue(message.contains("Multiple dependencies missing"))
        } else {
            XCTFail("Expected dependencyInjectionFailure error")
        }
    }
    
    /// Test EnvironmentValidator multiple objects validation
    @MainActor func testEnvironmentValidatorMultipleObjects() {
        let objects: [String: Any?] = [
            "AppState": testAppState,
            "UserProfile": mockUser,
            "Family": mockFamily,
            "Membership": mockMembership
        ]
        
        let results = EnvironmentValidator.validateMultiple(objects)
        
        XCTAssertEqual(results.count, 4)
        XCTAssertTrue(results["AppState"]?.isValid == true)
        XCTAssertTrue(results["UserProfile"]?.isValid == true)
        XCTAssertTrue(results["Family"]?.isValid == true)
        XCTAssertTrue(results["Membership"]?.isValid == true)
    }
    
    // MARK: - Fallback Behavior Tests
    
    /// Test AppStateFactory fallback creation
    @MainActor func testAppStateFactoryFallbackCreation() {
        let fallbackAppState = AppStateFactory.createFallbackAppState()
        
        XCTAssertNotNil(fallbackAppState)
        XCTAssertFalse(fallbackAppState.isAuthenticated)
        XCTAssertNil(fallbackAppState.currentUser)
        XCTAssertNil(fallbackAppState.currentFamily)
        XCTAssertNil(fallbackAppState.currentMembership)
        XCTAssertEqual(fallbackAppState.currentFlow, .onboarding)
        XCTAssertEqual(fallbackAppState.selectedNavigationTab, .dashboard)
        XCTAssertEqual(fallbackAppState.navigationPath.count, 0)
    }
    
    /// Test EnvironmentValidator fallback creation
    @MainActor func testEnvironmentValidatorFallbackCreation() {
        let fallbackAppState = EnvironmentValidator.createFallbackAppState()
        
        XCTAssertNotNil(fallbackAppState)
        XCTAssertFalse(fallbackAppState.isAuthenticated)
        XCTAssertEqual(fallbackAppState.currentFlow, .onboarding)
    }
    
    /// Test EnvironmentValidator context-specific fallback creation
    @MainActor func testEnvironmentValidatorContextSpecificFallback() {
        let previewAppState = EnvironmentValidator.createFallbackAppState(for: .preview)
        let testingAppState = EnvironmentValidator.createFallbackAppState(for: .testing)
        let productionAppState = EnvironmentValidator.createFallbackAppState(for: .production)
        let demoAppState = EnvironmentValidator.createFallbackAppState(for: .demo)
        
        // Preview should be authenticated with mock data
        XCTAssertTrue(previewAppState.isAuthenticated)
        XCTAssertNotNil(previewAppState.currentUser)
        
        // Testing should be authenticated
        XCTAssertTrue(testingAppState.isAuthenticated)
        
        // Production should be safe fallback
        XCTAssertFalse(productionAppState.isAuthenticated)
        
        // Demo should be configured for demo scenario
        XCTAssertTrue(demoAppState.isAuthenticated)
    }
    
    /// Test EnvironmentValidator generic fallback creation
    @MainActor func testEnvironmentValidatorGenericFallbackCreation() {
        // Test with AppState (should work)
        let appStateFallback = EnvironmentValidator.createFallback(for: AppState.self)
        XCTAssertNotNil(appStateFallback)
        
        // Test with unknown type (should return nil)
        let unknownFallback = EnvironmentValidator.createFallback(for: MockObservableObject.self)
        XCTAssertNil(unknownFallback)
    }
    
    // MARK: - Navigation Safety Tests
    
    /// Test safe navigation with valid AppState
    @MainActor func testSafeNavigationWithValidAppState() {
        testAppState.safeNavigate(to: .dashboard)
        
        XCTAssertEqual(testAppState.navigationPath.count, 1)
        XCTAssertNil(testAppState.getCurrentNavigationError())
    }
    
    /// Test safe navigation with invalid AppState
    @MainActor func testSafeNavigationWithInvalidAppState() {
        // Make AppState invalid
        testAppState.isAuthenticated = false
        testAppState.currentUser = nil
        
        testAppState.safeNavigate(to: .scheduleNew)
        
        // Should handle error gracefully
        XCTAssertNotNil(testAppState.getCurrentNavigationError())
    }
    
    /// Test navigation validation
    @MainActor func testNavigationValidation() {
        // Test with valid state
        let validResult = testAppState.validateNavigationState()
        if case .valid = validResult {
            XCTAssertTrue(true)
        } else {
            XCTFail("Navigation state should be valid")
        }
        
        // Test with invalid state
        testAppState.isAuthenticated = false
        let invalidResult = testAppState.validateNavigationState()
        if case .invalid(let reason) = invalidResult {
            XCTAssertEqual(reason, .notAuthenticated)
        } else {
            XCTFail("Navigation state should be invalid")
        }
    }
    
    /// Test route access control
    @MainActor func testRouteAccessControl() {
        // Test with parent admin (should have access to all routes)
        XCTAssertTrue(testAppState.canAccess(route: .dashboard))
        XCTAssertTrue(testAppState.canAccess(route: .scheduledList))
        XCTAssertTrue(testAppState.canAccess(route: .scheduleNew))
        
        // Test with kid role (limited access)
        testAppState.currentMembership = Membership(
            family: mockFamily,
            user: mockUser,
            role: .kid
        )
        
        XCTAssertTrue(testAppState.canAccess(route: .dashboard))
        XCTAssertTrue(testAppState.canAccess(route: .scheduledList))
        XCTAssertFalse(testAppState.canAccess(route: .scheduleNew))
        
        // Test Role extension permissions directly
        XCTAssertTrue(Role.parentAdmin.canCreateSchoolRuns)
        XCTAssertTrue(Role.parentAdmin.canExecuteSchoolRuns)
        XCTAssertTrue(Role.adult.canCreateSchoolRuns)
        XCTAssertTrue(Role.adult.canExecuteSchoolRuns)
        XCTAssertFalse(Role.kid.canCreateSchoolRuns)
        XCTAssertFalse(Role.kid.canExecuteSchoolRuns)
        XCTAssertFalse(Role.visitor.canCreateSchoolRuns)
        XCTAssertFalse(Role.visitor.canExecuteSchoolRuns)
    }
    
    /// Test navigation error handling
    @MainActor func testNavigationErrorHandling() {
        let error = NavigationError.insufficientPermissions
        testAppState.handleNavigationError(error)
        
        XCTAssertNotNil(testAppState.errorMessage)
        XCTAssertEqual(testAppState.currentFlow, .familyDashboard)
        XCTAssertEqual(testAppState.selectedNavigationTab, .dashboard)
    }
    
    /// Test navigation recovery
    @MainActor func testNavigationRecovery() {
        // Simulate navigation error
        testAppState.handleNavigationError(.navigationStackOverflow)
        
        // Attempt recovery
        testAppState.attemptNavigationRecovery()
        
        XCTAssertNil(testAppState.getCurrentNavigationError())
        XCTAssertTrue(testAppState.isAtNavigationRoot())
    }
    
    /// Test safe tab selection
    @MainActor func testSafeTabSelection() {
        testAppState.safeSelectTab(.schoolRun)
        
        XCTAssertEqual(testAppState.selectedNavigationTab, .schoolRun)
        XCTAssertNil(testAppState.getCurrentNavigationError())
    }
    
    /// Test NavigationStateManager integration
    @MainActor func testNavigationStateManagerIntegration() {
        let manager = testAppState.getNavigationStateManager()
        
        XCTAssertNotNil(manager)
        XCTAssertTrue(manager.isAtRoot)
        XCTAssertEqual(manager.navigationDepth, 0)
        
        // Test navigation through manager
        manager.navigate(to: .dashboard)
        
        XCTAssertEqual(manager.navigationDepth, 1)
        XCTAssertEqual(manager.currentRoute, .dashboard)
        XCTAssertNil(manager.navigationError)
    }
    
    // MARK: - Error Handling and Recovery Tests
    
    /// Test EnvironmentObjectError descriptions
    @MainActor func testEnvironmentObjectErrorDescriptions() {
        let missingError = EnvironmentObjectError.missingEnvironmentObject(type: "AppState")
        XCTAssertEqual(
            missingError.errorDescription,
            "Environment object of type AppState is not available in the view hierarchy"
        )
        
        let invalidStateError = EnvironmentObjectError.invalidEnvironmentObjectState(
            type: "AppState",
            reason: "Invalid authentication state"
        )
        XCTAssertEqual(
            invalidStateError.errorDescription,
            "Environment object of type AppState is in an invalid state: Invalid authentication state"
        )
        
        let fallbackError = EnvironmentObjectError.fallbackCreationFailed(
            type: "AppState",
            underlyingError: NSError(domain: "TestError", code: 1, userInfo: nil)
        )
        XCTAssertTrue(fallbackError.errorDescription?.contains("Failed to create fallback object") == true)
        
        let dependencyError = EnvironmentObjectError.dependencyInjectionFailure("Missing dependencies")
        XCTAssertEqual(
            dependencyError.errorDescription,
            "Dependency injection failed: Missing dependencies"
        )
    }
    
    /// Test EnvironmentObjectError recovery suggestions
    @MainActor func testEnvironmentObjectErrorRecoverySuggestions() {
        let missingError = EnvironmentObjectError.missingEnvironmentObject(type: "AppState")
        XCTAssertTrue(missingError.recoverySuggestion?.contains("environmentObject()") == true)
        
        let invalidStateError = EnvironmentObjectError.invalidEnvironmentObjectState(
            type: "AppState",
            reason: "Invalid state"
        )
        XCTAssertTrue(invalidStateError.recoverySuggestion?.contains("properly initialized") == true)
        
        let fallbackError = EnvironmentObjectError.fallbackCreationFailed(
            type: "AppState",
            underlyingError: NSError(domain: "TestError", code: 1, userInfo: nil)
        )
        XCTAssertTrue(fallbackError.recoverySuggestion?.contains("fallback factory") == true)
        
        let dependencyError = EnvironmentObjectError.dependencyInjectionFailure("Missing dependencies")
        XCTAssertTrue(dependencyError.recoverySuggestion?.contains("dependencies are properly configured") == true)
    }
    
    /// Test error reporting
    @MainActor func testErrorReporting() {
        let error = EnvironmentObjectError.missingEnvironmentObject(type: "AppState")
        let context: [String: Any] = ["viewName": "TestView", "timestamp": Date()]
        
        // Should not crash when reporting error
        XCTAssertNoThrow {
            EnvironmentValidator.reportError(error, context: context)
        }
    }
    
    /// Test validation failure reporting
    @MainActor func testValidationFailureReporting() {
        let result = EnvironmentValidationResult(
            isValid: false,
            objectType: "AppState",
            error: EnvironmentObjectError.missingEnvironmentObject(type: "AppState"),
            issues: ["AppState is missing"],
            recommendations: ["Inject AppState"],
            fallbackAvailable: true
        )
        
        // Should not crash when reporting validation failure
        XCTAssertNoThrow {
            EnvironmentValidator.reportValidationFailure(result, in: "TestView")
        }
    }
    
    /// Test AppState validation
    @MainActor func testAppStateValidation() {
        // Test valid state
        let validResult = testAppState.validateState()
        XCTAssertTrue(validResult.isValid)
        XCTAssertTrue(validResult.issues.isEmpty)
        XCTAssertTrue(validResult.recommendations.isEmpty)
        
        // Test invalid state
        testAppState.isAuthenticated = true
        testAppState.currentUser = nil
        
        let invalidResult = testAppState.validateState()
        XCTAssertFalse(invalidResult.isValid)
        XCTAssertFalse(invalidResult.issues.isEmpty)
        XCTAssertFalse(invalidResult.recommendations.isEmpty)
        XCTAssertTrue(invalidResult.hasCriticalIssues)
    }
    
    /// Test error recovery scenarios
    @MainActor func testErrorRecoveryScenarios() {
        // Test recovery from missing environment object
        let missingError = EnvironmentObjectError.missingEnvironmentObject(type: "AppState")
        testAppState.handleNavigationError(.insufficientPermissions)
        
        // Should recover gracefully
        testAppState.attemptNavigationRecovery()
        XCTAssertNil(testAppState.getCurrentNavigationError())
        
        // Test recovery from invalid state
        testAppState.isAuthenticated = true
        testAppState.currentUser = nil
        
        let validationResult = testAppState.validateState()
        XCTAssertFalse(validationResult.isValid)
        
        // Fix the state
        testAppState.currentUser = mockUser
        let fixedResult = testAppState.validateState()
        XCTAssertTrue(fixedResult.isValid)
    }
    
    // MARK: - Logging Tests
    
    /// Test EnvironmentObjectLogger fallback usage logging
    @MainActor func testEnvironmentObjectLoggerFallbackUsage() {
        XCTAssertNoThrow {
            EnvironmentObjectLogger.logFallbackUsage(for: AppState.self)
        }
    }
    
    /// Test EnvironmentObjectLogger validation issues logging
    @MainActor func testEnvironmentObjectLoggerValidationIssues() {
        let validationResult = EnvironmentObjectValidationResult(
            isValid: false,
            isUsingFallback: true,
            error: EnvironmentObjectError.missingEnvironmentObject(type: "AppState"),
            recommendations: ["Test recommendation"]
        )
        
        XCTAssertNoThrow {
            EnvironmentObjectLogger.logValidationIssues(for: AppState.self, result: validationResult)
        }
    }
    
    /// Test usage statistics logging
    @MainActor func testUsageStatisticsLogging() {
        let stats = EnvironmentUsageStatistics(
            totalValidations: 100,
            failedValidations: 5,
            fallbacksCreated: 3,
            mostCommonIssues: ["Missing AppState", "Invalid navigation state"]
        )
        
        XCTAssertEqual(stats.successRate, 95.0)
        XCTAssertTrue(stats.isHealthy)
        
        XCTAssertNoThrow {
            EnvironmentValidator.logUsageStatistics(stats)
        }
    }
    
    // MARK: - Integration Tests
    
    /// Test complete environment object handling workflow
    @MainActor func testCompleteEnvironmentObjectWorkflow() {
        // 1. Create view with SafeEnvironmentObject
        let testView = TestViewWithSafeEnvironmentObject()
        
        // 2. Test without environment object (should use fallback)
        let hostingController1 = UIHostingController(rootView: testView)
        XCTAssertNotNil(hostingController1.view)
        
        // 3. Test with environment object
        let testViewWithEnv = testView.environmentObject(testAppState)
        let hostingController2 = UIHostingController(rootView: testViewWithEnv)
        XCTAssertNotNil(hostingController2.view)
        
        // 4. Test validation
        let validationResult = EnvironmentValidator.validateAppState(testAppState)
        XCTAssertTrue(validationResult.isValid)
        
        // 5. Test navigation safety
        testAppState.safeNavigate(to: .dashboard)
        XCTAssertEqual(testAppState.navigationPath.count, 1)
        
        // 6. Test error handling
        testAppState.handleNavigationError(.insufficientPermissions)
        XCTAssertNotNil(testAppState.errorMessage)
        
        // 7. Test recovery
        testAppState.attemptNavigationRecovery()
        XCTAssertNil(testAppState.getCurrentNavigationError())
    }
    
    /// Test environment object handling under memory pressure
    @MainActor func testEnvironmentObjectHandlingMemoryBehavior() {
        var views: [UIHostingController<TestViewWithSafeEnvironmentObject>] = []
        
        // Create multiple views to test memory behavior
        for _ in 0..<10 {
            let testView = TestViewWithSafeEnvironmentObject()
            let hostingController = UIHostingController(rootView: testView)
            views.append(hostingController)
        }
        
        XCTAssertEqual(views.count, 10)
        
        // Clear references
        views.removeAll()
        XCTAssertTrue(views.isEmpty)
    }
    
    // MARK: - Performance Tests
    
    /// Test SafeEnvironmentObject performance
    @MainActor func testSafeEnvironmentObjectPerformance() {
        measure {
            for _ in 0..<100 {
                let testView = TestViewWithSafeEnvironmentObject()
                let hostingController = UIHostingController(rootView: testView)
                _ = hostingController.view
            }
        }
    }
    
    /// Test environment validation performance
    @MainActor func testEnvironmentValidationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = EnvironmentValidator.validateAppState(testAppState)
            }
        }
    }
    
    /// Test fallback creation performance
    @MainActor func testFallbackCreationPerformance() {
        measure {
            for _ in 0..<100 {
                _ = EnvironmentValidator.createFallbackAppState()
            }
        }
    }
    
    /// Test navigation safety performance
    @MainActor func testNavigationSafetyPerformance() {
        measure {
            for _ in 0..<100 {
                testAppState.safeNavigate(to: .dashboard)
                testAppState.safeNavigateBack()
            }
        }
    }
}

// MARK: - Test Helper Views

/// Test view that uses SafeEnvironmentObject for testing purposes
private struct TestViewWithSafeEnvironmentObject: View {
    @SafeEnvironmentObject(fallback: { AppState.createFallback() })
    var appState: AppState
    
    var body: some View {
        VStack {
            Text("Test View")
            Text("Authenticated: \(appState.isAuthenticated ? "Yes" : "No")")
            Text("Current Flow: \(appState.currentFlow.displayName)")
        }
    }
}

/// Test view that demonstrates SafeEnvironmentObject projected value usage
private struct TestViewWithProjectedValue: View {
    @SafeEnvironmentObject(fallback: { AppState.createFallback() })
    var appState: AppState
    
    var body: some View {
        VStack {
            Text("Using Fallback: \($appState.isUsingFallback ? "Yes" : "No")")
            Text("Environment Available: \($appState.isEnvironmentObjectAvailable ? "Yes" : "No")")
            
            if !$appState.validationResult.isValid {
                Text("Validation Issues:")
                    .foregroundColor(.red)
                ForEach($appState.validationResult.recommendations, id: \.self) { recommendation in
                    Text("• \(recommendation)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }
}

/// Test view with custom fallback factory
private struct TestViewWithCustomFallback: View {
    @SafeEnvironmentObject var appState: AppState
    
    init(fallback: @escaping () -> AppState) {
        self._appState = SafeEnvironmentObject(fallback: fallback)
    }
    
    var body: some View {
        VStack {
            Text("Custom Fallback Test")
            Text("Authenticated: \(appState.isAuthenticated ? "Yes" : "No")")
        }
    }
}

/// Mock observable object for testing SafeEnvironmentObject with different types
private class MockObservableObject: ObservableObject {
    @Published var value: String = "test"
    @Published var isActive: Bool = true
    
    init(value: String = "test", isActive: Bool = true) {
        self.value = value
        self.isActive = isActive
    }
}

/// Test SafeEnvironmentObject with custom observable object
private struct TestViewWithMockObject: View {
    @SafeEnvironmentObject(fallback: { MockObservableObject() })
    var mockObject: MockObservableObject
    
    var body: some View {
        VStack {
            Text("Value: \(mockObject.value)")
            Text("Active: \(mockObject.isActive ? "Yes" : "No")")
        }
    }
}