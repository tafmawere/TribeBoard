import XCTest
import SwiftUI
@testable import TribeBoard

/// Unit tests for AppStateFactory and related functionality
@MainActor
final class AppStateFactoryTests: XCTestCase {
    
    // MARK: - AppStateFactory Tests
    
    /// Test creating fallback AppState with safe defaults
    func testCreateFallbackAppState() throws {
        let appState = AppStateFactory.createFallbackAppState()
        
        // Verify safe defaults
        XCTAssertFalse(appState.isAuthenticated)
        XCTAssertNil(appState.currentUser)
        XCTAssertNil(appState.currentFamily)
        XCTAssertNil(appState.currentMembership)
        XCTAssertEqual(appState.currentFlow, .onboarding)
        XCTAssertFalse(appState.isLoading)
        XCTAssertNil(appState.errorMessage)
        XCTAssertEqual(appState.selectedNavigationTab, .dashboard)
        XCTAssertTrue(appState.navigationPath.isEmpty)
    }
    
    /// Test creating preview AppState with realistic data
    func testCreatePreviewAppState() throws {
        let appState = AppStateFactory.createPreviewAppState()
        
        // Verify preview configuration
        XCTAssertTrue(appState.isAuthenticated)
        XCTAssertNotNil(appState.currentUser)
        XCTAssertNotNil(appState.currentFamily)
        XCTAssertNotNil(appState.currentMembership)
        XCTAssertEqual(appState.currentFlow, .familyDashboard)
        XCTAssertFalse(appState.isLoading)
        XCTAssertNil(appState.errorMessage)
        XCTAssertEqual(appState.selectedNavigationTab, .dashboard)
        XCTAssertTrue(appState.navigationPath.isEmpty)
        
        // Verify mock data quality
        XCTAssertEqual(appState.currentUser?.name, "Test User")
        XCTAssertEqual(appState.currentUser?.email, "test@example.com")
        XCTAssertEqual(appState.currentFamily?.name, "Test Family")
        XCTAssertEqual(appState.currentFamily?.code, "TEST123")
        XCTAssertEqual(appState.currentMembership?.role, .parentAdmin)
        XCTAssertEqual(appState.currentMembership?.status, .active)
    }
    
    /// Test creating test AppState with unauthenticated scenario
    func testCreateTestAppStateUnauthenticated() throws {
        let appState = AppStateFactory.createTestAppState(scenario: .unauthenticated)
        
        XCTAssertFalse(appState.isAuthenticated)
        XCTAssertNil(appState.currentUser)
        XCTAssertNil(appState.currentFamily)
        XCTAssertNil(appState.currentMembership)
        XCTAssertEqual(appState.currentFlow, .onboarding)
    }
    
    /// Test creating test AppState with authenticated scenario
    func testCreateTestAppStateAuthenticated() throws {
        let appState = AppStateFactory.createTestAppState(scenario: .authenticated)
        
        XCTAssertTrue(appState.isAuthenticated)
        XCTAssertNotNil(appState.currentUser)
        XCTAssertNotNil(appState.currentFamily)
        XCTAssertNotNil(appState.currentMembership)
        XCTAssertEqual(appState.currentFlow, .familyDashboard)
    }
    
    /// Test creating test AppState with loading scenario
    func testCreateTestAppStateLoading() throws {
        let appState = AppStateFactory.createTestAppState(scenario: .loading)
        
        XCTAssertFalse(appState.isAuthenticated)
        XCTAssertTrue(appState.isLoading)
        XCTAssertEqual(appState.currentFlow, .onboarding)
    }
    
    /// Test creating test AppState with error scenario
    func testCreateTestAppStateError() throws {
        let appState = AppStateFactory.createTestAppState(scenario: .error)
        
        XCTAssertFalse(appState.isAuthenticated)
        XCTAssertNotNil(appState.errorMessage)
        XCTAssertEqual(appState.errorMessage, "Test error message")
        XCTAssertEqual(appState.currentFlow, .onboarding)
    }
    
    /// Test creating test AppState with family selection scenario
    func testCreateTestAppStateFamilySelection() throws {
        let appState = AppStateFactory.createTestAppState(scenario: .familySelection)
        
        XCTAssertTrue(appState.isAuthenticated)
        XCTAssertNotNil(appState.currentUser)
        XCTAssertNil(appState.currentFamily)
        XCTAssertNil(appState.currentMembership)
        XCTAssertEqual(appState.currentFlow, .familySelection)
    }
    
    /// Test creating test AppState with specific roles
    func testCreateTestAppStateWithRoles() throws {
        let roles: [Role] = [.parentAdmin, .parent, .child, .visitor]
        
        for role in roles {
            let appState = AppStateFactory.createTestAppState(withRole: role)
            
            XCTAssertTrue(appState.isAuthenticated)
            XCTAssertNotNil(appState.currentMembership)
            XCTAssertEqual(appState.currentMembership?.role, role)
        }
    }
    
    // MARK: - AppState Extension Tests
    
    /// Test AppState.createFallback() convenience method
    func testAppStateCreateFallback() throws {
        let appState = AppState.createFallback()
        
        XCTAssertFalse(appState.isAuthenticated)
        XCTAssertNil(appState.currentUser)
        XCTAssertEqual(appState.currentFlow, .onboarding)
    }
    
    /// Test AppState.createPreview() convenience method
    func testAppStateCreatePreview() throws {
        let appState = AppState.createPreview()
        
        XCTAssertTrue(appState.isAuthenticated)
        XCTAssertNotNil(appState.currentUser)
        XCTAssertEqual(appState.currentFlow, .familyDashboard)
    }
    
    /// Test AppState.createTest() convenience methods
    func testAppStateCreateTest() throws {
        let defaultAppState = AppState.createTest()
        XCTAssertTrue(defaultAppState.isAuthenticated)
        
        let unauthenticatedAppState = AppState.createTest(scenario: .unauthenticated)
        XCTAssertFalse(unauthenticatedAppState.isAuthenticated)
        
        let adminAppState = AppState.createTest(withRole: .parentAdmin)
        XCTAssertEqual(adminAppState.currentMembership?.role, .parentAdmin)
    }
    
    // MARK: - AppState Validation Tests
    
    /// Test AppState validation with valid state
    func testAppStateValidationValid() throws {
        let appState = AppStateFactory.createTestAppState(scenario: .authenticated)
        let result = appState.validateState()
        
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertFalse(result.hasCriticalIssues)
    }
    
    /// Test AppState validation with authentication inconsistency
    func testAppStateValidationAuthenticationInconsistency() throws {
        let appState = AppStateFactory.createTestAppState(scenario: .authenticated)
        
        // Create inconsistent state
        appState.isAuthenticated = false // But currentUser is still set
        
        let result = appState.validateState()
        
        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.issues.isEmpty)
        XCTAssertTrue(result.hasCriticalIssues)
        XCTAssertTrue(result.issues.contains { $0.contains("not authenticated but currentUser is set") })
    }
    
    /// Test AppState validation with family membership inconsistency
    func testAppStateValidationFamilyMembershipInconsistency() throws {
        let appState = AppStateFactory.createTestAppState(scenario: .authenticated)
        
        // Create inconsistent state
        appState.currentFamily = nil // But membership is still set
        
        let result = appState.validateState()
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.issues.contains { $0.contains("membership but no family") })
        XCTAssertTrue(result.recommendations.contains { $0.contains("family membership") })
    }
    
    /// Test AppState validation with flow inconsistency
    func testAppStateValidationFlowInconsistency() throws {
        let appState = AppStateFactory.createTestAppState(scenario: .unauthenticated)
        
        // Create inconsistent state
        appState.currentFlow = .familyDashboard // But user is not authenticated
        
        let result = appState.validateState()
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.issues.contains { $0.contains("family dashboard but user is not authenticated") })
        XCTAssertTrue(result.recommendations.contains { $0.contains("app flow") })
    }
    
    // MARK: - AppStateValidationResult Tests
    
    /// Test AppStateValidationResult properties
    func testAppStateValidationResult() throws {
        let validResult = AppStateValidationResult(
            isValid: true,
            issues: [],
            recommendations: []
        )
        
        XCTAssertTrue(validResult.isValid)
        XCTAssertTrue(validResult.issues.isEmpty)
        XCTAssertTrue(validResult.recommendations.isEmpty)
        XCTAssertFalse(validResult.hasCriticalIssues)
        
        let invalidResult = AppStateValidationResult(
            isValid: false,
            issues: ["Test issue"],
            recommendations: ["Test recommendation"]
        )
        
        XCTAssertFalse(invalidResult.isValid)
        XCTAssertFalse(invalidResult.issues.isEmpty)
        XCTAssertFalse(invalidResult.recommendations.isEmpty)
        XCTAssertTrue(invalidResult.hasCriticalIssues)
    }
    
    // MARK: - TestScenario Tests
    
    /// Test all TestScenario cases
    func testAllTestScenarios() throws {
        let scenarios: [TestScenario] = [
            .unauthenticated,
            .authenticated,
            .loading,
            .error,
            .familySelection
        ]
        
        for scenario in scenarios {
            let appState = AppStateFactory.createTestAppState(scenario: scenario)
            
            // Each scenario should create a valid AppState
            XCTAssertNotNil(appState)
            
            // Verify scenario-specific properties
            switch scenario {
            case .unauthenticated:
                XCTAssertFalse(appState.isAuthenticated)
                XCTAssertNil(appState.currentUser)
                
            case .authenticated:
                XCTAssertTrue(appState.isAuthenticated)
                XCTAssertNotNil(appState.currentUser)
                
            case .loading:
                XCTAssertTrue(appState.isLoading)
                
            case .error:
                XCTAssertNotNil(appState.errorMessage)
                
            case .familySelection:
                XCTAssertTrue(appState.isAuthenticated)
                XCTAssertEqual(appState.currentFlow, .familySelection)
            }
        }
    }
    
    // MARK: - Performance Tests
    
    /// Test AppStateFactory performance
    func testAppStateFactoryPerformance() throws {
        measure {
            for _ in 0..<100 {
                _ = AppStateFactory.createFallbackAppState()
                _ = AppStateFactory.createPreviewAppState()
                _ = AppStateFactory.createTestAppState(scenario: .authenticated)
            }
        }
    }
    
    /// Test AppState validation performance
    func testAppStateValidationPerformance() throws {
        let appState = AppStateFactory.createTestAppState(scenario: .authenticated)
        
        measure {
            for _ in 0..<1000 {
                _ = appState.validateState()
            }
        }
    }
    
    // MARK: - Memory Tests
    
    /// Test AppStateFactory memory usage
    func testAppStateFactoryMemoryUsage() throws {
        var appStates: [AppState] = []
        
        // Create many AppState instances
        for _ in 0..<100 {
            appStates.append(AppStateFactory.createFallbackAppState())
            appStates.append(AppStateFactory.createPreviewAppState())
            appStates.append(AppStateFactory.createTestAppState(scenario: .authenticated))
        }
        
        XCTAssertEqual(appStates.count, 300)
        
        // Clear references
        appStates.removeAll()
        
        // This should not cause memory issues
        XCTAssertTrue(appStates.isEmpty)
    }
    
    // MARK: - Integration Tests
    
    /// Test AppStateFactory integration with SafeEnvironmentObject
    func testAppStateFactoryIntegrationWithSafeEnvironmentObject() throws {
        // Create a view that uses SafeEnvironmentObject with AppStateFactory
        let testView = VStack {
            TestViewWithFactoryFallback()
        }
        
        let hostingController = UIHostingController(rootView: testView)
        
        // The view should render without crashing
        XCTAssertNotNil(hostingController.view)
        hostingController.loadViewIfNeeded()
        XCTAssertTrue(hostingController.isViewLoaded)
    }
}

// MARK: - Test Helper Views

/// Test view that uses AppStateFactory for SafeEnvironmentObject fallback
private struct TestViewWithFactoryFallback: View {
    @SafeEnvironmentObject(fallback: AppStateFactory.createFallbackAppState)
    var appState: AppState
    
    var body: some View {
        VStack {
            Text("Factory Fallback Test")
            Text("Authenticated: \(appState.isAuthenticated ? "Yes" : "No")")
            Text("Flow: \(appState.currentFlow.displayName)")
        }
    }
}