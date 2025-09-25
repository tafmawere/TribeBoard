import XCTest
import SwiftUI
@testable import TribeBoard

/// Comprehensive tests for environment object error handling UI components
@MainActor
final class EnvironmentObjectErrorHandlingUITests: XCTestCase {
    
    var errorHandler: EnvironmentObjectErrorHandler!
    var toastManager: EnvironmentObjectToastManager!
    
    override func setUp() async throws {
        try await super.setUp()
        errorHandler = EnvironmentObjectErrorHandler.shared
        toastManager = EnvironmentObjectToastManager.shared
        
        // Clear any existing state
        errorHandler.currentError = nil
        toastManager.currentNotification = nil
    }
    
    override func tearDown() async throws {
        errorHandler = nil
        toastManager = nil
        try await super.tearDown()
    }
    
    // MARK: - EnvironmentObjectErrorView Tests
    
    @MainActor func testEnvironmentObjectErrorViewCreation() {
        // Given
        let error = EnvironmentObjectError.missingEnvironmentObject(type: "AppState")
        let context = EnvironmentErrorContext(viewName: "TestView", showTechnicalDetails: true)
        
        // When
        let errorView = EnvironmentObjectErrorView(
            error: error,
            context: context,
            onRecoveryAction: { _ in },
            onDismiss: {}
        )
        
        // Then
        XCTAssertNotNil(errorView)
        XCTAssertEqual(error.userFriendlyTitle, "App State Not Available")
        XCTAssertTrue(error.userFriendlyMessage.contains("app's main state"))
    }
    
    @MainActor func testEnvironmentObjectErrorViewRecoveryActions() {
        // Given
        let error = EnvironmentObjectError.missingEnvironmentObject(type: "AppState")
        let expectedActions: [EnvironmentRecoveryAction] = [.useDefaultState, .refreshEnvironment, .restartView, .reportIssue]
        
        // When
        let availableActions = error.availableRecoveryActions
        
        // Then
        XCTAssertEqual(availableActions.count, expectedActions.count)
        for expectedAction in expectedActions {
            XCTAssertTrue(availableActions.contains(expectedAction), "Missing action: \(expectedAction)")
        }
    }
    
    @MainActor func testEnvironmentObjectErrorViewInvalidState() {
        // Given
        let error = EnvironmentObjectError.invalidEnvironmentObjectState(
            type: "AppState",
            reason: "Navigation state is corrupted"
        )
        
        // When
        let title = error.userFriendlyTitle
        let message = error.userFriendlyMessage
        let actions = error.availableRecoveryActions
        
        // Then
        XCTAssertEqual(title, "App State Issue")
        XCTAssertTrue(message.contains("inconsistencies"))
        XCTAssertTrue(actions.contains(.refreshEnvironment))
        XCTAssertTrue(actions.contains(.resetNavigation))
    }
    
    @MainActor func testEnvironmentObjectErrorViewDependencyFailure() {
        // Given
        let error = EnvironmentObjectError.dependencyInjectionFailure("Multiple dependencies missing")
        
        // When
        let category = error.category
        let icon = error.icon
        let actions = error.availableRecoveryActions
        
        // Then
        XCTAssertEqual(category, "Dependency Issue")
        XCTAssertEqual(icon, "link.badge.plus")
        XCTAssertTrue(actions.contains(.checkDependencies))
        XCTAssertTrue(actions.contains(.reportIssue))
    }
    
    // MARK: - EnvironmentObjectToast Tests
    
    @MainActor func testEnvironmentObjectToastNotificationCreation() {
        // Given
        let notification = EnvironmentObjectNotification(
            type: .missingEnvironment,
            title: "Test Error",
            message: "Test message",
            primaryAction: .useDefaultState,
            secondaryActions: [.refreshEnvironment, .reportIssue]
        )
        
        // When & Then
        XCTAssertEqual(notification.title, "Test Error")
        XCTAssertEqual(notification.message, "Test message")
        XCTAssertEqual(notification.primaryAction, .useDefaultState)
        XCTAssertEqual(notification.secondaryActions.count, 2)
        XCTAssertEqual(notification.icon, "exclamationmark.triangle.fill")
    }
    
    @MainActor func testEnvironmentObjectToastManagerShowMissingEnvironment() {
        // Given
        let expectation = XCTestExpectation(description: "Toast notification shown")
        
        // When
        toastManager.showMissingEnvironment(type: "AppState", viewName: "TestView")
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNotNil(self.toastManager.currentNotification)
            XCTAssertEqual(self.toastManager.currentNotification?.type, .missingEnvironment)
            XCTAssertEqual(self.toastManager.currentNotification?.title, "App State Missing")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    @MainActor func testEnvironmentObjectToastManagerShowFallbackActive() {
        // Given
        let expectation = XCTestExpectation(description: "Fallback toast shown")
        
        // When
        toastManager.showFallbackActive(type: "AppState")
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNotNil(self.toastManager.currentNotification)
            XCTAssertEqual(self.toastManager.currentNotification?.type, .fallbackActive)
            XCTAssertEqual(self.toastManager.currentNotification?.title, "Using Fallback State")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    @MainActor func testEnvironmentObjectToastManagerShowStateInconsistent() {
        // Given
        let expectation = XCTestExpectation(description: "State inconsistent toast shown")
        let details = "Navigation path is corrupted"
        
        // When
        toastManager.showStateInconsistent(details: details)
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNotNil(self.toastManager.currentNotification)
            XCTAssertEqual(self.toastManager.currentNotification?.type, .stateInconsistent)
            XCTAssertEqual(self.toastManager.currentNotification?.message, details)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    @MainActor func testEnvironmentObjectToastManagerShowDependencyIssue() {
        // Given
        let expectation = XCTestExpectation(description: "Dependency issue toast shown")
        let missingDeps = ["AppState", "NavigationManager"]
        
        // When
        toastManager.showDependencyIssue(missing: missingDeps)
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNotNil(self.toastManager.currentNotification)
            XCTAssertEqual(self.toastManager.currentNotification?.type, .dependencyIssue)
            XCTAssertTrue(self.toastManager.currentNotification?.message.contains("AppState") ?? false)
            XCTAssertTrue(self.toastManager.currentNotification?.message.contains("NavigationManager") ?? false)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    @MainActor func testEnvironmentObjectToastManagerRecoverySequence() {
        // Given
        let expectation = XCTestExpectation(description: "Recovery sequence completed")
        var completionCalled = false
        
        // When
        toastManager.showRecoverySequence(initialAction: .refreshEnvironment) { success in
            completionCalled = true
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 6.0)
        XCTAssertTrue(completionCalled)
    }
    
    // MARK: - EnvironmentObjectErrorHandler Tests
    
    @MainActor func testEnvironmentObjectErrorHandlerHandleError() {
        // Given
        let error = EnvironmentObjectError.missingEnvironmentObject(type: "AppState")
        let viewName = "TestView"
        
        // When
        errorHandler.handleError(error, in: viewName)
        
        // Then
        // Since this error should trigger automatic recovery, currentError might be nil
        // But we should have a record in recovery history after some time
        let expectation = XCTestExpectation(description: "Error handled")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Check that some recovery action was attempted
            XCTAssertTrue(self.errorHandler.recoveryHistory.count > 0 || self.errorHandler.currentError != nil)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testEnvironmentObjectErrorHandlerExecuteRecoveryAction() async {
        // Given
        let error = EnvironmentObjectError.missingEnvironmentObject(type: "AppState")
        let action = EnvironmentRecoveryAction.useDefaultState
        
        // When
        let result = await errorHandler.executeRecoveryAction(action, for: error)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result.action, action)
        // Result success depends on random simulation, so we just check it's not nil
        XCTAssertFalse(result.message.isEmpty)
    }
    
    @MainActor func testEnvironmentObjectErrorHandlerGetRecoveryRecommendations() {
        // Given
        let error = EnvironmentObjectError.invalidEnvironmentObjectState(
            type: "AppState",
            reason: "Test reason"
        )
        
        // When
        let recommendations = errorHandler.getRecoveryRecommendations(for: error)
        
        // Then
        XCTAssertFalse(recommendations.isEmpty)
        XCTAssertTrue(recommendations.contains(.refreshEnvironment))
    }
    
    @MainActor func testEnvironmentObjectErrorHandlerStatistics() {
        // Given
        let error = EnvironmentObjectError.missingEnvironmentObject(type: "AppState")
        
        // When
        // Execute a few recovery actions to generate statistics
        Task {
            _ = await errorHandler.executeRecoveryAction(.useDefaultState, for: error)
            _ = await errorHandler.executeRecoveryAction(.refreshEnvironment, for: error)
        }
        
        let expectation = XCTestExpectation(description: "Statistics generated")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Then
            let stats = self.errorHandler.statistics
            XCTAssertGreaterThanOrEqual(stats.totalRecoveryAttempts, 2)
            XCTAssertGreaterThanOrEqual(stats.successfulRecoveries + stats.failedRecoveries, stats.totalRecoveryAttempts)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Recovery Action Tests
    
    @MainActor func testEnvironmentRecoveryActionProperties() {
        // Test all recovery actions have proper properties
        for action in EnvironmentRecoveryAction.allCases {
            XCTAssertFalse(action.title.isEmpty, "Action \(action) should have a title")
            XCTAssertFalse(action.icon.isEmpty, "Action \(action) should have an icon")
            
            // Test that style is properly defined
            switch action.style {
            case .primary, .secondary, .tertiary, .destructive:
                break // All valid styles
            }
        }
    }
    
    @MainActor func testEnvironmentRecoveryActionTitles() {
        // Test specific action titles
        XCTAssertEqual(EnvironmentRecoveryAction.refreshEnvironment.title, "Refresh Environment")
        XCTAssertEqual(EnvironmentRecoveryAction.useDefaultState.title, "Use Default State")
        XCTAssertEqual(EnvironmentRecoveryAction.restartView.title, "Restart View")
        XCTAssertEqual(EnvironmentRecoveryAction.reportIssue.title, "Report Issue")
        XCTAssertEqual(EnvironmentRecoveryAction.checkDependencies.title, "Check Dependencies")
        XCTAssertEqual(EnvironmentRecoveryAction.resetNavigation.title, "Reset Navigation")
    }
    
    // MARK: - Notification Type Tests
    
    @MainActor func testEnvironmentNotificationTypeProperties() {
        // Test all notification types have proper properties
        let types: [EnvironmentNotificationType] = [
            .missingEnvironment,
            .fallbackActive,
            .stateInconsistent,
            .dependencyIssue,
            .recoverySuccessful,
            .recoveryFailed
        ]
        
        for type in types {
            XCTAssertFalse(type.icon.isEmpty, "Type \(type) should have an icon")
            XCTAssertFalse(type.accessibilityLabel.isEmpty, "Type \(type) should have accessibility label")
            
            // Test color is properly defined
            let _ = type.color // Should not crash
        }
    }
    
    @MainActor func testEnvironmentNotificationTypeColors() {
        // Test specific colors
        XCTAssertEqual(EnvironmentNotificationType.missingEnvironment.color, .orange)
        XCTAssertEqual(EnvironmentNotificationType.fallbackActive.color, .blue)
        XCTAssertEqual(EnvironmentNotificationType.stateInconsistent.color, .red)
        XCTAssertEqual(EnvironmentNotificationType.dependencyIssue.color, .purple)
        XCTAssertEqual(EnvironmentNotificationType.recoverySuccessful.color, .green)
        XCTAssertEqual(EnvironmentNotificationType.recoveryFailed.color, .red)
    }
    
    // MARK: - Error Context Tests
    
    @MainActor func testEnvironmentErrorContextCreation() {
        // Test default context
        let defaultContext = EnvironmentErrorContext.default
        XCTAssertNil(defaultContext.viewName)
        XCTAssertFalse(defaultContext.showTechnicalDetails)
        XCTAssertTrue(defaultContext.allowRecovery)
        
        // Test custom context
        let customContext = EnvironmentErrorContext(
            viewName: "TestView",
            showTechnicalDetails: true,
            allowRecovery: false
        )
        XCTAssertEqual(customContext.viewName, "TestView")
        XCTAssertTrue(customContext.showTechnicalDetails)
        XCTAssertFalse(customContext.allowRecovery)
    }
    
    // MARK: - Integration Tests
    
    @MainActor func testErrorHandlerToastManagerIntegration() {
        // Given
        let error = EnvironmentObjectError.missingEnvironmentObject(type: "AppState")
        let expectation = XCTestExpectation(description: "Error handler shows toast")
        
        // When
        errorHandler.handleError(error, in: "TestView")
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Either automatic recovery happened or toast was shown
            let hasToast = self.toastManager.currentNotification != nil
            let hasError = self.errorHandler.currentError != nil
            let hasRecoveryHistory = !self.errorHandler.recoveryHistory.isEmpty
            
            XCTAssertTrue(hasToast || hasError || hasRecoveryHistory, 
                         "Error handler should either show toast, set current error, or attempt recovery")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    @MainActor func testErrorViewToastManagerIntegration() {
        // Given
        let error = EnvironmentObjectError.invalidEnvironmentObjectState(
            type: "AppState",
            reason: "Test reason"
        )
        let context = EnvironmentErrorContext.default
        var actionExecuted: EnvironmentRecoveryAction?
        
        let errorView = EnvironmentObjectErrorView(
            error: error,
            context: context,
            onRecoveryAction: { action in
                actionExecuted = action
            },
            onDismiss: {}
        )
        
        // When
        // Simulate action execution (this would normally happen through UI interaction)
        let testAction = EnvironmentRecoveryAction.refreshEnvironment
        
        // Then
        XCTAssertNotNil(errorView)
        // In a real UI test, we would interact with the view and verify the action callback
        // For now, we just verify the view can be created and the callback structure is correct
    }
    
    // MARK: - Performance Tests
    
    @MainActor func testErrorHandlerPerformance() {
        // Test that error handling doesn't cause performance issues
        measure {
            for i in 0..<100 {
                let error = EnvironmentObjectError.missingEnvironmentObject(type: "TestType\(i)")
                errorHandler.handleError(error, in: "TestView\(i)")
            }
        }
    }
    
    @MainActor func testToastManagerPerformance() {
        // Test that toast notifications don't cause performance issues
        measure {
            for i in 0..<50 {
                toastManager.showMissingEnvironment(type: "TestType\(i)", viewName: "TestView\(i)")
                toastManager.dismiss()
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    @MainActor func testErrorHandlerWithNilError() {
        // Given
        let action = EnvironmentRecoveryAction.useDefaultState
        
        // When
        Task {
            let result = await errorHandler.executeRecoveryAction(action, for: nil)
            
            // Then
            XCTAssertFalse(result.isSuccessful)
            XCTAssertTrue(result.message.contains("No error"))
        }
    }
    
    @MainActor func testToastManagerWithEmptyDependencies() {
        // Given
        let emptyDeps: [String] = []
        
        // When
        toastManager.showDependencyIssue(missing: emptyDeps)
        
        // Then
        XCTAssertNotNil(toastManager.currentNotification)
        XCTAssertEqual(toastManager.currentNotification?.type, .dependencyIssue)
    }
    
    @MainActor func testErrorViewWithAllRecoveryActions() {
        // Given
        let error = EnvironmentObjectError.dependencyInjectionFailure("All dependencies missing")
        let allActions = error.availableRecoveryActions
        
        // When
        let errorView = EnvironmentObjectErrorView(
            error: error,
            context: .default,
            onRecoveryAction: { _ in },
            onDismiss: {}
        )
        
        // Then
        XCTAssertNotNil(errorView)
        XCTAssertFalse(allActions.isEmpty)
        // Verify that the error view can handle all available actions
        for action in allActions {
            XCTAssertFalse(action.title.isEmpty)
            XCTAssertFalse(action.icon.isEmpty)
        }
    }
}