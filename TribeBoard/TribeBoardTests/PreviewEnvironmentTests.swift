import XCTest
import SwiftUI
@testable import TribeBoard

/// Tests for the preview environment setup utilities
/// Ensures that all preview environments are properly configured and don't crash
@MainActor
final class PreviewEnvironmentTests: XCTestCase {
    
    // MARK: - PreviewEnvironmentModifier Tests
    
    func testPreviewEnvironmentModifierDefault() throws {
        // Test that default preview environment creates valid AppState
        let modifier = PreviewEnvironmentModifier()
        let testView = Text("Test")
        let modifiedView = testView.modifier(modifier)
        
        // The modifier should not crash when applied
        XCTAssertNotNil(modifiedView)
    }
    
    func testPreviewEnvironmentModifierTypes() throws {
        // Test all environment types
        let environmentTypes: [PreviewEnvironmentType] = [
            .default,
            .unauthenticated,
            .authenticated,
            .loading,
            .error,
            .familySelection,
            .parentAdmin,
            .parent,
            .child,
            .visitor
        ]
        
        for environmentType in environmentTypes {
            let modifier = PreviewEnvironmentModifier(environmentType: environmentType)
            let testView = Text("Test")
            let modifiedView = testView.modifier(modifier)
            
            // Each modifier should not crash when applied
            XCTAssertNotNil(modifiedView, "Environment type \(environmentType) should create valid modifier")
        }
    }
    
    func testPreviewEnvironmentModifierCustomAppState() throws {
        // Test custom AppState
        let customAppState = AppStateFactory.createPreviewAppState()
        let modifier = PreviewEnvironmentModifier(customAppState: customAppState)
        let testView = Text("Test")
        let modifiedView = testView.modifier(modifier)
        
        XCTAssertNotNil(modifiedView)
    }
    
    // MARK: - View Extension Tests
    
    func testPreviewEnvironmentExtensions() throws {
        let testView = Text("Test")
        
        // Test all extension methods
        XCTAssertNotNil(testView.previewEnvironment())
        XCTAssertNotNil(testView.previewEnvironment(.default))
        XCTAssertNotNil(testView.previewEnvironment(.authenticated))
        XCTAssertNotNil(testView.previewEnvironment(.unauthenticated))
        XCTAssertNotNil(testView.previewEnvironmentLoading())
        XCTAssertNotNil(testView.previewEnvironmentError())
        XCTAssertNotNil(testView.previewEnvironmentFamilySelection())
        
        // Test role-specific environments
        XCTAssertNotNil(testView.previewEnvironment(role: .parentAdmin))
        XCTAssertNotNil(testView.previewEnvironment(role: .adult))
        XCTAssertNotNil(testView.previewEnvironment(role: .kid))
        XCTAssertNotNil(testView.previewEnvironment(role: .visitor))
        
        // Test custom AppState
        let customAppState = AppStateFactory.createPreviewAppState()
        XCTAssertNotNil(testView.previewEnvironment(customAppState: customAppState))
    }
    
    // MARK: - AppState Factory Tests
    
    func testAppStateFactoryPreviewCreation() throws {
        let previewAppState = AppStateFactory.createPreviewAppState()
        
        // Verify preview AppState is properly configured
        XCTAssertTrue(previewAppState.isAuthenticated, "Preview AppState should be authenticated")
        XCTAssertNotNil(previewAppState.currentUser, "Preview AppState should have a current user")
        XCTAssertNotNil(previewAppState.currentFamily, "Preview AppState should have a current family")
        XCTAssertNotNil(previewAppState.currentMembership, "Preview AppState should have a current membership")
        XCTAssertEqual(previewAppState.currentFlow, .familyDashboard, "Preview AppState should be in family dashboard flow")
        XCTAssertFalse(previewAppState.isLoading, "Preview AppState should not be loading")
        XCTAssertNil(previewAppState.errorMessage, "Preview AppState should not have error message")
    }
    
    func testAppStateFactoryFallbackCreation() throws {
        let fallbackAppState = AppStateFactory.createFallbackAppState()
        
        // Verify fallback AppState has safe defaults
        XCTAssertFalse(fallbackAppState.isAuthenticated, "Fallback AppState should not be authenticated")
        XCTAssertNil(fallbackAppState.currentUser, "Fallback AppState should not have a current user")
        XCTAssertNil(fallbackAppState.currentFamily, "Fallback AppState should not have a current family")
        XCTAssertNil(fallbackAppState.currentMembership, "Fallback AppState should not have a current membership")
        XCTAssertEqual(fallbackAppState.currentFlow, .onboarding, "Fallback AppState should be in onboarding flow")
        XCTAssertFalse(fallbackAppState.isLoading, "Fallback AppState should not be loading")
        XCTAssertNil(fallbackAppState.errorMessage, "Fallback AppState should not have error message")
    }
    
    func testAppStateFactoryTestScenarios() throws {
        // Test all test scenarios
        let scenarios: [TestScenario] = [.unauthenticated, .authenticated, .loading, .error, .familySelection]
        
        for scenario in scenarios {
            let testAppState = AppStateFactory.createTestAppState(scenario: scenario)
            XCTAssertNotNil(testAppState, "Test scenario \(scenario) should create valid AppState")
            
            // Verify scenario-specific configuration
            switch scenario {
            case .unauthenticated:
                XCTAssertFalse(testAppState.isAuthenticated)
                XCTAssertEqual(testAppState.currentFlow, .onboarding)
            case .authenticated:
                XCTAssertTrue(testAppState.isAuthenticated)
                XCTAssertNotNil(testAppState.currentUser)
                XCTAssertEqual(testAppState.currentFlow, .familyDashboard)
            case .loading:
                XCTAssertTrue(testAppState.isLoading)
            case .error:
                XCTAssertNotNil(testAppState.errorMessage)
            case .familySelection:
                XCTAssertTrue(testAppState.isAuthenticated)
                XCTAssertEqual(testAppState.currentFlow, .familySelection)
            }
        }
    }
    
    func testAppStateFactoryRoleSpecificCreation() throws {
        let roles: [Role] = [.parentAdmin, .adult, .kid, .visitor]
        
        for role in roles {
            let roleAppState = AppStateFactory.createTestAppState(withRole: role)
            XCTAssertNotNil(roleAppState, "Role \(role) should create valid AppState")
            XCTAssertTrue(roleAppState.isAuthenticated, "Role-specific AppState should be authenticated")
            XCTAssertEqual(roleAppState.currentMembership?.role, role, "AppState should have correct role")
        }
    }
    
    // MARK: - Preview Environment Validation Tests
    
    func testPreviewEnvironmentValidation() throws {
        // Test validation of valid preview environment
        let validAppState = AppStateFactory.createPreviewAppState()
        let validationResult = PreviewEnvironmentValidator.validatePreviewEnvironment(validAppState)
        
        XCTAssertTrue(validationResult.isValid, "Valid preview environment should pass validation")
        XCTAssertTrue(validationResult.previewSpecificIssues.isEmpty, "Valid preview should have no preview-specific issues")
    }
    
    func testPreviewEnvironmentValidationWithIssues() throws {
        // Test validation of problematic preview environment
        let problematicAppState = AppState()
        problematicAppState.currentFlow = .familyDashboard
        problematicAppState.currentFamily = nil // This should cause a validation issue
        
        let validationResult = PreviewEnvironmentValidator.validatePreviewEnvironment(problematicAppState)
        
        XCTAssertFalse(validationResult.isValid, "Problematic preview environment should fail validation")
        XCTAssertFalse(validationResult.previewSpecificIssues.isEmpty, "Problematic preview should have issues")
    }
    
    // MARK: - SchoolRunPreviewProvider Tests
    
    func testSchoolRunPreviewProviderUpdatedMethods() throws {
        // Test that SchoolRunPreviewProvider methods work with new preview system
        let testView = Text("Test")
        
        // Test updated preview methods
        let previewWithSampleData = SchoolRunPreviewProvider.previewWithSampleData {
            testView
        }
        XCTAssertNotNil(previewWithSampleData)
        
        let previewWithEnvironment = SchoolRunPreviewProvider.previewWithEnvironment(.authenticated) {
            testView
        }
        XCTAssertNotNil(previewWithEnvironment)
        
        let previewWithRole = SchoolRunPreviewProvider.previewWithRole(.parentAdmin) {
            testView
        }
        XCTAssertNotNil(previewWithRole)
    }
    
    // MARK: - Integration Tests
    
    func testScheduledRunsListViewPreviewsDoNotCrash() throws {
        // Test that ScheduledRunsListView previews can be created without crashing
        let view = ScheduledRunsListView()
        
        // Test different preview environments
        XCTAssertNotNil(view.previewEnvironment())
        XCTAssertNotNil(view.previewEnvironment(.authenticated))
        XCTAssertNotNil(view.previewEnvironment(role: .parentAdmin))
        XCTAssertNotNil(view.previewEnvironment(role: .adult))
        XCTAssertNotNil(view.previewEnvironmentLoading())
        XCTAssertNotNil(view.previewEnvironmentError())
    }
    
    func testSafeEnvironmentObjectWithPreviewEnvironment() throws {
        // Test that SafeEnvironmentObject works properly with preview environments
        let appState = AppStateFactory.createPreviewAppState()
        let safeWrapper = SafeEnvironmentObject<AppState>(fallback: { AppState.createFallback() })
        
        // The wrapper should be able to provide an AppState
        XCTAssertNotNil(safeWrapper.wrappedValue)
        
        // The projected value should provide validation information
        let projectedValue = safeWrapper.projectedValue
        XCTAssertNotNil(projectedValue)
        XCTAssertNotNil(projectedValue.validationResult)
    }
    
    // MARK: - Performance Tests
    
    func testPreviewEnvironmentCreationPerformance() throws {
        // Test that preview environment creation is reasonably fast
        measure {
            for _ in 0..<100 {
                let _ = AppStateFactory.createPreviewAppState()
            }
        }
    }
    
    func testPreviewModifierApplicationPerformance() throws {
        // Test that applying preview modifiers is reasonably fast
        let testView = Text("Test")
        
        measure {
            for _ in 0..<100 {
                let _ = testView.previewEnvironment()
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testPreviewEnvironmentErrorHandling() throws {
        // Test that preview environment handles edge cases gracefully
        
        // Test with nil custom AppState (should not happen in practice, but test defensive coding)
        let modifier = PreviewEnvironmentModifier(environmentType: .custom)
        let testView = Text("Test")
        let modifiedView = testView.modifier(modifier)
        
        // Should not crash even with edge case
        XCTAssertNotNil(modifiedView)
    }
    
    // MARK: - Accessibility Tests
    
    func testPreviewEnvironmentAccessibilitySupport() throws {
        // Test that preview environments work with accessibility features
        let testView = Text("Test")
        
        let accessiblePreview = testView
            .previewEnvironment()
            .environment(\.dynamicTypeSize, .accessibility1)
            .environment(\.colorSchemeContrast, .increased)
        
        XCTAssertNotNil(accessiblePreview)
    }
}

// MARK: - Test Utilities

extension PreviewEnvironmentTests {
    
    /// Helper method to create a test view with preview environment
    private func createTestViewWithPreviewEnvironment() -> some View {
        Text("Test View")
            .previewEnvironment()
    }
    
    /// Helper method to validate that a view can be created without crashing
    private func assertViewCanBeCreated<V: View>(_ view: V, file: StaticString = #file, line: UInt = #line) {
        XCTAssertNotNil(view, "View should be creatable without crashing", file: file, line: line)
    }
}