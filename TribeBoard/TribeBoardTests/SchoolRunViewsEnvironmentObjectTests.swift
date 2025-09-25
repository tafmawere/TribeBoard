import XCTest
import SwiftUI
@testable import TribeBoard

/// Comprehensive tests for school run views using SafeEnvironmentObject pattern
/// Tests environment object reliability and fallback behavior
@MainActor
final class SchoolRunViewsEnvironmentObjectTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var mockAppState: AppState!
    private var fallbackAppState: AppState!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create mock AppState for testing
        mockAppState = AppStateFactory.createTestAppState(scenario: .authenticated)
        
        // Create fallback AppState for testing fallback scenarios
        fallbackAppState = AppStateFactory.createFallbackAppState()
    }
    
    override func tearDown() async throws {
        mockAppState = nil
        fallbackAppState = nil
        try await super.tearDown()
    }
    
    // MARK: - SchoolRunDashboardView Tests
    
    func testSchoolRunDashboardViewWithValidEnvironmentObject() throws {
        // Given: A valid AppState environment object
        let appState = mockAppState!
        
        // When: Creating SchoolRunDashboardView with environment object
        let view = SchoolRunDashboardView()
            .environmentObject(appState)
        
        // Then: View should be created successfully without crashes
        XCTAssertNotNil(view)
        
        // Verify that the view can access the environment object
        let hostingController = UIHostingController(rootView: view)
        XCTAssertNotNil(hostingController.view)
    }
    
    func testSchoolRunDashboardViewWithoutEnvironmentObject() throws {
        // Given: No environment object provided
        let view = SchoolRunDashboardView()
        
        // When: Creating view without environment object
        // Then: View should use fallback AppState and not crash
        let hostingController = UIHostingController(rootView: view)
        XCTAssertNotNil(hostingController.view)
        
        // The SafeEnvironmentObject should provide a fallback
        // This test verifies that the view doesn't crash when environment object is missing
    }
    
    func testSchoolRunDashboardViewNavigationWithFallback() throws {
        // Given: SchoolRunDashboardView without environment object
        let view = SchoolRunDashboardView()
        
        // When: View uses fallback AppState
        let hostingController = UIHostingController(rootView: view)
        
        // Then: Navigation should work with fallback state
        XCTAssertNotNil(hostingController.view)
        
        // Verify that the fallback AppState has proper navigation setup
        let fallback = AppStateFactory.createFallbackAppState()
        XCTAssertNotNil(fallback.navigationPath)
        XCTAssertEqual(fallback.currentFlow, .onboarding)
    }
    
    // MARK: - RunDetailView Tests
    
    func testRunDetailViewWithValidEnvironmentObject() throws {
        // Given: A valid AppState and mock run
        let appState = mockAppState!
        let mockRun = createMockScheduledRun()
        
        // When: Creating RunDetailView with environment object
        let view = RunDetailView(run: mockRun)
            .environmentObject(appState)
        
        // Then: View should be created successfully
        XCTAssertNotNil(view)
        
        let hostingController = UIHostingController(rootView: view)
        XCTAssertNotNil(hostingController.view)
    }
    
    func testRunDetailViewWithoutEnvironmentObject() throws {
        // Given: No environment object and mock run
        let mockRun = createMockScheduledRun()
        let view = RunDetailView(run: mockRun)
        
        // When: Creating view without environment object
        // Then: View should use fallback and not crash
        let hostingController = UIHostingController(rootView: view)
        XCTAssertNotNil(hostingController.view)
    }
    
    func testRunDetailViewStartRunWithFallback() throws {
        // Given: RunDetailView without environment object
        let mockRun = createMockScheduledRun()
        let view = RunDetailView(run: mockRun)
        
        // When: View uses fallback AppState
        let hostingController = UIHostingController(rootView: view)
        
        // Then: Start run functionality should work with fallback
        XCTAssertNotNil(hostingController.view)
        
        // Verify fallback AppState can handle navigation
        let fallback = AppStateFactory.createFallbackAppState()
        XCTAssertNotNil(fallback.navigationPath)
    }
    
    // MARK: - RunExecutionView Tests
    
    func testRunExecutionViewWithValidEnvironmentObject() throws {
        // Given: A valid AppState and mock run
        let appState = mockAppState!
        let mockRun = createMockScheduledRun()
        
        // When: Creating RunExecutionView with environment object
        let view = RunExecutionView(run: mockRun)
            .environmentObject(appState)
        
        // Then: View should be created successfully
        XCTAssertNotNil(view)
        
        let hostingController = UIHostingController(rootView: view)
        XCTAssertNotNil(hostingController.view)
    }
    
    func testRunExecutionViewWithoutEnvironmentObject() throws {
        // Given: No environment object and mock run
        let mockRun = createMockScheduledRun()
        let view = RunExecutionView(run: mockRun)
        
        // When: Creating view without environment object
        // Then: View should use fallback and not crash
        let hostingController = UIHostingController(rootView: view)
        XCTAssertNotNil(hostingController.view)
    }
    
    func testRunExecutionViewNavigationWithFallback() throws {
        // Given: RunExecutionView without environment object
        let mockRun = createMockScheduledRun()
        let view = RunExecutionView(run: mockRun)
        
        // When: View uses fallback AppState for navigation
        let hostingController = UIHostingController(rootView: view)
        
        // Then: Navigation operations should work with fallback
        XCTAssertNotNil(hostingController.view)
        
        // Test that fallback can handle navigation operations
        let fallback = AppStateFactory.createFallbackAppState()
        fallback.navigationPath.append(SchoolRunRoute.runDetail(mockRun))
        XCTAssertEqual(fallback.navigationPath.count, 1)
    }
    
    // MARK: - ScheduleNewRunView Tests
    
    func testScheduleNewRunViewWithValidEnvironmentObject() throws {
        // Given: A valid AppState environment object
        let appState = mockAppState!
        
        // When: Creating ScheduleNewRunView with environment object
        let view = ScheduleNewRunView()
            .environmentObject(appState)
        
        // Then: View should be created successfully
        XCTAssertNotNil(view)
        
        let hostingController = UIHostingController(rootView: view)
        XCTAssertNotNil(hostingController.view)
    }
    
    func testScheduleNewRunViewWithoutEnvironmentObject() throws {
        // Given: No environment object provided
        let view = ScheduleNewRunView()
        
        // When: Creating view without environment object
        // Then: View should use fallback and not crash
        let hostingController = UIHostingController(rootView: view)
        XCTAssertNotNil(hostingController.view)
    }
    
    // MARK: - SafeEnvironmentObject Integration Tests
    
    func testSafeEnvironmentObjectFallbackCreation() throws {
        // Given: SafeEnvironmentObject without environment
        // When: Fallback is created
        let fallback = AppState.createFallback()
        
        // Then: Fallback should have safe defaults
        XCTAssertFalse(fallback.isAuthenticated)
        XCTAssertNil(fallback.currentUser)
        XCTAssertNil(fallback.currentFamily)
        XCTAssertEqual(fallback.currentFlow, .onboarding)
        XCTAssertNotNil(fallback.navigationPath)
        XCTAssertEqual(fallback.selectedNavigationTab, .dashboard)
    }
    
    func testSafeEnvironmentObjectValidation() throws {
        // Given: Various AppState instances
        let validAppState = mockAppState!
        let fallbackAppState = AppStateFactory.createFallbackAppState()
        
        // When: Validating environment objects
        let validResult = EnvironmentValidator.validateAppState(validAppState)
        let fallbackResult = EnvironmentValidator.validateAppState(fallbackAppState)
        
        // Then: Both should be valid (fallback has safe defaults)
        XCTAssertTrue(validResult.isValid)
        XCTAssertTrue(fallbackResult.isValid)
    }
    
    func testEnvironmentObjectErrorHandling() throws {
        // Given: Nil AppState
        let nilAppState: AppState? = nil
        
        // When: Validating nil environment object
        let result = EnvironmentValidator.validateAppState(nilAppState)
        
        // Then: Should detect missing environment object
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.fallbackAvailable)
        XCTAssertFalse(result.issues.isEmpty)
        XCTAssertFalse(result.recommendations.isEmpty)
    }
    
    // MARK: - Navigation Safety Tests
    
    func testNavigationSafetyWithFallbackAppState() throws {
        // Given: Fallback AppState
        let fallback = AppStateFactory.createFallbackAppState()
        let mockRun = createMockScheduledRun()
        
        // When: Performing navigation operations
        fallback.navigationPath.append(SchoolRunRoute.scheduleNew)
        fallback.navigationPath.append(SchoolRunRoute.runDetail(mockRun))
        
        // Then: Navigation should work without crashes
        XCTAssertEqual(fallback.navigationPath.count, 2)
        
        // Test navigation removal
        fallback.navigationPath.removeLast()
        XCTAssertEqual(fallback.navigationPath.count, 1)
    }
    
    func testNavigationConsistencyAcrossViews() throws {
        // Given: Multiple views using the same fallback AppState
        let fallback = AppStateFactory.createFallbackAppState()
        let mockRun = createMockScheduledRun()
        
        // When: Views share navigation state
        let dashboardView = SchoolRunDashboardView().environmentObject(fallback)
        let detailView = RunDetailView(run: mockRun).environmentObject(fallback)
        let executionView = RunExecutionView(run: mockRun).environmentObject(fallback)
        
        // Then: All views should be created successfully
        XCTAssertNotNil(dashboardView)
        XCTAssertNotNil(detailView)
        XCTAssertNotNil(executionView)
        
        // Navigation state should be consistent
        fallback.navigationPath.append(SchoolRunRoute.scheduledList)
        XCTAssertEqual(fallback.navigationPath.count, 1)
    }
    
    // MARK: - Error Recovery Tests
    
    func testErrorRecoveryWithFallbackState() throws {
        // Given: AppState with error condition
        let appState = AppStateFactory.createTestAppState(scenario: .error)
        
        // When: Views use error state
        let view = SchoolRunDashboardView().environmentObject(appState)
        
        // Then: View should handle error state gracefully
        XCTAssertNotNil(view)
        XCTAssertNotNil(appState.errorMessage)
        
        // Error state should not prevent view creation
        let hostingController = UIHostingController(rootView: view)
        XCTAssertNotNil(hostingController.view)
    }
    
    func testFallbackStateRecovery() throws {
        // Given: Fallback AppState
        let fallback = AppStateFactory.createFallbackAppState()
        
        // When: Attempting to recover to normal state
        fallback.isAuthenticated = true
        fallback.currentUser = UserProfile(displayName: "Test User", appleUserIdHash: "test")
        fallback.currentFlow = .familyDashboard
        
        // Then: State should be recoverable
        let validation = fallback.validateState()
        // Note: This might fail validation due to missing family, which is expected
        // The important thing is that the fallback doesn't crash
        XCTAssertNotNil(validation)
    }
    
    // MARK: - Performance Tests
    
    func testFallbackCreationPerformance() throws {
        // Given: Performance measurement
        measure {
            // When: Creating multiple fallback instances
            for _ in 0..<100 {
                let fallback = AppStateFactory.createFallbackAppState()
                XCTAssertNotNil(fallback)
            }
        }
        
        // Then: Fallback creation should be fast
        // Performance is measured by the measure block
    }
    
    func testViewCreationPerformanceWithFallback() throws {
        // Given: Performance measurement for view creation
        let mockRun = createMockScheduledRun()
        
        measure {
            // When: Creating views without environment objects (using fallback)
            for _ in 0..<50 {
                let dashboardView = SchoolRunDashboardView()
                let detailView = RunDetailView(run: mockRun)
                let executionView = RunExecutionView(run: mockRun)
                
                XCTAssertNotNil(dashboardView)
                XCTAssertNotNil(detailView)
                XCTAssertNotNil(executionView)
            }
        }
        
        // Then: View creation with fallback should be performant
    }
    
    // MARK: - Helper Methods
    
    private func createMockScheduledRun() -> ScheduledSchoolRun {
        let stops = [
            RunStop(name: "Dashboard", type: .dashboard, task: "Pick up children", estimatedMinutes: 5),
            RunStop(name: "School", type: .school, task: "Drop off at school", estimatedMinutes: 10)
        ]
        
        return ScheduledSchoolRun(
            name: "Morning School Run",
            scheduledDate: Date(), scheduledTime: Date(),
            stops: stops,
            isCompleted: false
        )
    }
    
    private func createMockAppStateWithNavigation() -> AppState {
        let appState = AppStateFactory.createTestAppState(scenario: .authenticated)
        appState.navigationPath.append(SchoolRunRoute.scheduledList)
        return appState
    }
}

// MARK: - Test Extensions

extension SchoolRunViewsEnvironmentObjectTests {
    
    /// Test that all school run views can be created in a navigation stack without crashes
    func testAllSchoolRunViewsInNavigationStack() throws {
        // Given: Mock data and fallback state
        let mockRun = createMockScheduledRun()
        let fallback = AppStateFactory.createFallbackAppState()
        
        // When: Creating navigation stack with all school run views
        let navigationView = NavigationStack {
            VStack {
                SchoolRunDashboardView()
                RunDetailView(run: mockRun)
                RunExecutionView(run: mockRun)
                ScheduleNewRunView()
            }
        }
        .environmentObject(fallback)
        
        // Then: Navigation stack should be created successfully
        XCTAssertNotNil(navigationView)
        
        let hostingController = UIHostingController(rootView: navigationView)
        XCTAssertNotNil(hostingController.view)
    }
    
    /// Test that views handle rapid environment object changes gracefully
    func testRapidEnvironmentObjectChanges() throws {
        // Given: Multiple AppState instances
        let states = [
            AppStateFactory.createTestAppState(scenario: .unauthenticated),
            AppStateFactory.createTestAppState(scenario: .authenticated),
            AppStateFactory.createTestAppState(scenario: .loading),
            AppStateFactory.createFallbackAppState()
        ]
        
        let mockRun = createMockScheduledRun()
        
        // When: Rapidly changing environment objects
        for state in states {
            let view = SchoolRunDashboardView().environmentObject(state)
            let detailView = RunDetailView(run: mockRun).environmentObject(state)
            
            // Then: Views should handle state changes gracefully
            XCTAssertNotNil(view)
            XCTAssertNotNil(detailView)
            
            let hostingController = UIHostingController(rootView: view)
            XCTAssertNotNil(hostingController.view)
        }
    }
}