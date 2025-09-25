import XCTest
import SwiftUI
@testable import TribeBoard

/// Integration tests for school run views using SafeEnvironmentObject pattern
/// Tests that views can be created and used without crashes when environment objects are missing
@MainActor
final class SchoolRunViewsEnvironmentObjectIntegrationTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var mockRun: ScheduledSchoolRun!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create mock run for testing
        mockRun = createMockScheduledRun()
    }
    
    override func tearDown() async throws {
        mockRun = nil
        try await super.tearDown()
    }
    
    // MARK: - Integration Tests
    
    func testSchoolRunDashboardViewCreationWithoutEnvironmentObject() throws {
        // Given: No environment object provided
        // When: Creating SchoolRunDashboardView
        let view = SchoolRunDashboardView()
        
        // Then: View should be created successfully without crashes
        XCTAssertNotNil(view)
        
        // Verify that the view can be hosted without crashes
        let hostingController = UIHostingController(rootView: view)
        XCTAssertNotNil(hostingController.view)
    }
    
    func testRunDetailViewCreationWithoutEnvironmentObject() throws {
        // Given: No environment object provided
        // When: Creating RunDetailView
        let view = RunDetailView(run: mockRun)
        
        // Then: View should be created successfully without crashes
        XCTAssertNotNil(view)
        
        // Verify that the view can be hosted without crashes
        let hostingController = UIHostingController(rootView: view)
        XCTAssertNotNil(hostingController.view)
    }
    
    func testRunExecutionViewCreationWithoutEnvironmentObject() throws {
        // Given: No environment object provided
        // When: Creating RunExecutionView
        let view = RunExecutionView(run: mockRun)
        
        // Then: View should be created successfully without crashes
        XCTAssertNotNil(view)
        
        // Verify that the view can be hosted without crashes
        let hostingController = UIHostingController(rootView: view)
        XCTAssertNotNil(hostingController.view)
    }
    
    func testScheduleNewRunViewCreationWithoutEnvironmentObject() throws {
        // Given: No environment object provided
        // When: Creating ScheduleNewRunView
        let view = ScheduleNewRunView()
        
        // Then: View should be created successfully without crashes
        XCTAssertNotNil(view)
        
        // Verify that the view can be hosted without crashes
        let hostingController = UIHostingController(rootView: view)
        XCTAssertNotNil(hostingController.view)
    }
    
    func testAllSchoolRunViewsInNavigationStackWithoutEnvironmentObject() throws {
        // Given: All school run views without environment objects
        // When: Creating navigation stack with all views
        let navigationView = NavigationStack {
            VStack {
                SchoolRunDashboardView()
                RunDetailView(run: mockRun)
                RunExecutionView(run: mockRun)
                ScheduleNewRunView()
            }
        }
        
        // Then: Navigation stack should be created successfully
        XCTAssertNotNil(navigationView)
        
        let hostingController = UIHostingController(rootView: navigationView)
        XCTAssertNotNil(hostingController.view)
    }
    
    func testSchoolRunViewsWithValidEnvironmentObject() throws {
        // Given: Valid AppState environment object
        let appState = AppStateFactory.createTestAppState(scenario: .authenticated)
        
        // When: Creating views with environment object
        let dashboardView = SchoolRunDashboardView().environmentObject(appState)
        let detailView = RunDetailView(run: mockRun).environmentObject(appState)
        let executionView = RunExecutionView(run: mockRun).environmentObject(appState)
        let scheduleView = ScheduleNewRunView().environmentObject(appState)
        
        // Then: All views should be created successfully
        XCTAssertNotNil(dashboardView)
        XCTAssertNotNil(detailView)
        XCTAssertNotNil(executionView)
        XCTAssertNotNil(scheduleView)
        
        // Verify that views can be hosted
        let hostingController = UIHostingController(rootView: dashboardView)
        XCTAssertNotNil(hostingController.view)
    }
    
    func testSafeEnvironmentObjectFallbackBehavior() throws {
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
    
    func testNavigationWithFallbackAppState() throws {
        // Given: Fallback AppState
        let fallback = AppStateFactory.createFallbackAppState()
        
        // When: Performing navigation operations
        fallback.navigationPath.append(SchoolRunRoute.scheduleNew)
        fallback.navigationPath.append(SchoolRunRoute.runDetail(mockRun))
        
        // Then: Navigation should work without crashes
        XCTAssertEqual(fallback.navigationPath.count, 2)
        
        // Test navigation removal
        fallback.navigationPath.removeLast()
        XCTAssertEqual(fallback.navigationPath.count, 1)
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
}