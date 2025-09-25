import XCTest
import SwiftUI
@testable import TribeBoard

/// Comprehensive tests for UI/UX prototype navigation flows
/// Tests all navigation paths for completeness and smooth operation
@MainActor
final class PrototypeNavigationFlowTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var appState: AppState!
    var mockServiceCoordinator: MockServiceCoordinator!
    
    // MARK: - Test Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize mock services for prototype testing
        mockServiceCoordinator = MockServiceCoordinator()
        appState = AppState()
        appState.setMockServiceCoordinator(mockServiceCoordinator)
        
        // Ensure clean state for each test
        appState.resetToInitialState()
    }
    
    override func tearDown() async throws {
        appState = nil
        mockServiceCoordinator = nil
        try await super.tearDown()
    }
    
    // MARK: - Complete Navigation Flow Tests
    
    /// Test complete new user onboarding flow
    func testNewUserOnboardingFlow() async throws {
        // Start at onboarding
        XCTAssertEqual(appState.currentFlow, .onboarding)
        XCTAssertFalse(appState.isAuthenticated)
        XCTAssertNil(appState.currentUser)
        
        // Simulate sign in
        await appState.signInWithMockAuth()
        
        // Should be authenticated and navigate to family selection
        XCTAssertTrue(appState.isAuthenticated)
        XCTAssertNotNil(appState.currentUser)
        XCTAssertEqual(appState.currentFlow, .familySelection)
        
        // Navigate to create family
        appState.navigateTo(.createFamily)
        XCTAssertEqual(appState.currentFlow, .createFamily)
        
        // Create family
        let success = await appState.createFamilyMock(name: "Test Family", code: "TEST123")
        XCTAssertTrue(success)
        
        // Should navigate to family dashboard
        XCTAssertEqual(appState.currentFlow, .familyDashboard)
        XCTAssertNotNil(appState.currentFamily)
        XCTAssertNotNil(appState.currentMembership)
        XCTAssertEqual(appState.currentFamily?.name, "Test Family")
    }
    
    /// Test existing user login flow
    func testExistingUserLoginFlow() async throws {
        // Configure as existing user scenario
        appState.configureDemoScenario(.existingUser)
        
        // Should start authenticated with family
        XCTAssertTrue(appState.isAuthenticated)
        XCTAssertNotNil(appState.currentUser)
        XCTAssertEqual(appState.currentFlow, .familyDashboard)
        XCTAssertNotNil(appState.currentFamily)
        XCTAssertNotNil(appState.currentMembership)
    }
    
    /// Test join family flow
    func testJoinFamilyFlow() async throws {
        // Start at onboarding and sign in
        await appState.signInWithMockAuth()
        XCTAssertEqual(appState.currentFlow, .familySelection)
        
        // Navigate to join family
        appState.navigateTo(.joinFamily)
        XCTAssertEqual(appState.currentFlow, .joinFamily)
        
        // Join family with valid code
        let success = await appState.joinFamilyMock(code: "DEMO123", role: .child)
        XCTAssertTrue(success)
        
        // Should navigate to family dashboard
        XCTAssertEqual(appState.currentFlow, .familyDashboard)
        XCTAssertNotNil(appState.currentFamily)
        XCTAssertNotNil(appState.currentMembership)
        XCTAssertEqual(appState.currentMembership?.role, .child)
    }
    
    /// Test role-based navigation flows
    func testRoleBasedNavigationFlows() async throws {
        let roles: [Role] = [.parentAdmin, .parent, .child, .guardian, .visitor]
        
        for role in roles {
            // Reset state
            appState.resetToInitialState()
            
            // Configure for specific role
            switch role {
            case .parentAdmin, .parent:
                appState.configureDemoScenario(.familyAdmin)
            case .child:
                appState.configureDemoScenario(.childUser)
            case .guardian, .visitor:
                appState.configureDemoScenario(.visitorUser)
            }
            
            // Verify appropriate access level
            XCTAssertEqual(appState.currentFlow, .familyDashboard)
            XCTAssertEqual(appState.getCurrentUserRole(), role)
            
            // Test admin privileges
            if role == .parentAdmin {
                XCTAssertTrue(appState.isCurrentUserAdmin())
            } else {
                XCTAssertFalse(appState.isCurrentUserAdmin())
            }
        }
    }
    
    /// Test sign out flow
    func testSignOutFlow() async throws {
        // Start authenticated
        appState.configureDemoScenario(.existingUser)
        XCTAssertTrue(appState.isAuthenticated)
        
        // Sign out
        await appState.signOut()
        
        // Should return to onboarding
        XCTAssertFalse(appState.isAuthenticated)
        XCTAssertNil(appState.currentUser)
        XCTAssertNil(appState.currentFamily)
        XCTAssertNil(appState.currentMembership)
        XCTAssertEqual(appState.currentFlow, .onboarding)
    }
    
    /// Test leave family flow
    func testLeaveFamilyFlow() async throws {
        // Start with family membership
        appState.configureDemoScenario(.existingUser)
        XCTAssertNotNil(appState.currentFamily)
        
        // Leave family
        appState.leaveFamily()
        
        // Should navigate to family selection
        XCTAssertNil(appState.currentFamily)
        XCTAssertNil(appState.currentMembership)
        XCTAssertEqual(appState.currentFlow, .familySelection)
        XCTAssertTrue(appState.isAuthenticated) // Still authenticated
    }
    
    // MARK: - Navigation State Tests
    
    /// Test navigation path management
    func testNavigationPathManagement() async throws {
        // Start with empty navigation path
        XCTAssertTrue(appState.navigationPath.isEmpty)
        
        // Navigate through flows
        appState.navigateTo(.familySelection)
        appState.navigateTo(.createFamily)
        appState.navigateTo(.familyDashboard)
        
        // Reset navigation
        appState.resetNavigation()
        XCTAssertTrue(appState.navigationPath.isEmpty)
    }
    
    /// Test error handling during navigation
    func testNavigationErrorHandling() async throws {
        // Start at family selection
        await appState.signInWithMockAuth()
        
        // Try to join family with invalid code
        let success = await appState.joinFamilyMock(code: "INVALID", role: .child)
        XCTAssertFalse(success)
        
        // Should remain at family selection
        XCTAssertEqual(appState.currentFlow, .familySelection)
        XCTAssertNotNil(appState.errorMessage)
        
        // Clear error
        appState.clearError()
        XCTAssertNil(appState.errorMessage)
    }
    
    // MARK: - Demo Journey Tests
    
    /// Test guided demo journeys
    func testGuidedDemoJourneys() async throws {
        let scenarios: [UserJourneyScenario] = [.newUser, .existingUser, .familyAdmin, .childUser, .visitorUser]
        
        for scenario in scenarios {
            // Reset state
            appState.resetToInitialState()
            
            // Execute journey
            await appState.executeUserJourney(scenario)
            
            // Verify appropriate end state
            switch scenario {
            case .newUser:
                XCTAssertEqual(appState.currentFlow, .familySelection)
            case .existingUser, .familyAdmin, .childUser, .visitorUser:
                XCTAssertEqual(appState.currentFlow, .familyDashboard)
            }
        }
    }
    
    /// Test demo reset functionality
    func testDemoResetFunctionality() async throws {
        // Configure complex state
        appState.configureDemoScenario(.familyAdmin)
        appState.showError("Test error")
        
        // Reset to initial state
        appState.resetToInitialState()
        
        // Verify clean state
        XCTAssertFalse(appState.isAuthenticated)
        XCTAssertNil(appState.currentUser)
        XCTAssertNil(appState.currentFamily)
        XCTAssertNil(appState.currentMembership)
        XCTAssertEqual(appState.currentFlow, .onboarding)
        XCTAssertNil(appState.errorMessage)
        XCTAssertFalse(appState.isLoading)
        XCTAssertEqual(appState.currentScenario, .newUser)
    }
    
    // MARK: - Performance Tests
    
    /// Test navigation performance
    func testNavigationPerformance() async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Perform multiple navigation operations
        for _ in 0..<100 {
            appState.navigateTo(.familySelection)
            appState.navigateTo(.createFamily)
            appState.navigateTo(.familyDashboard)
            appState.resetNavigation()
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should complete within reasonable time (1 second)
        XCTAssertLessThan(timeElapsed, 1.0, "Navigation operations should be fast")
    }
    
    /// Test state change performance
    func testStateChangePerformance() async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Perform multiple state changes
        for _ in 0..<50 {
            appState.configureDemoScenario(.newUser)
            appState.configureDemoScenario(.existingUser)
            appState.configureDemoScenario(.familyAdmin)
            appState.resetToInitialState()
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should complete within reasonable time (2 seconds)
        XCTAssertLessThan(timeElapsed, 2.0, "State changes should be fast")
    }
    
    // MARK: - Validation Tests
    
    /// Test family code validation
    func testFamilyCodeValidation() async throws {
        // Valid codes
        XCTAssertTrue(appState.validateFamilyCode("ABC123"))
        XCTAssertTrue(appState.validateFamilyCode("DEMO1234"))
        XCTAssertTrue(appState.validateFamilyCode("TEST567"))
        
        // Invalid codes
        XCTAssertFalse(appState.validateFamilyCode(""))
        XCTAssertFalse(appState.validateFamilyCode("AB"))
        XCTAssertFalse(appState.validateFamilyCode("TOOLONGCODE123"))
        XCTAssertFalse(appState.validateFamilyCode("ABC@123"))
        XCTAssertFalse(appState.validateFamilyCode("   "))
    }
    
    /// Test QR code generation
    func testQRCodeGeneration() async throws {
        let family = Family(name: "Test Family", code: "TEST123", createdByUserId: UUID())
        let qrCode = appState.generateMockQRCode(for: family)
        
        XCTAssertTrue(qrCode.contains("TRIBEBOARD://join/"))
        XCTAssertTrue(qrCode.contains(family.code))
    }
    
    // MARK: - Mock Data Tests
    
    /// Test mock data consistency
    func testMockDataConsistency() async throws {
        let roles: [Role] = [.parentAdmin, .parent, .child, .guardian, .visitor]
        
        for role in roles {
            let mockData = appState.getMockDataForCurrentUser()
            
            // Verify data is not empty
            XCTAssertFalse(mockData.calendarEvents.isEmpty)
            XCTAssertFalse(mockData.tasks.isEmpty)
            XCTAssertFalse(mockData.messages.isEmpty)
            XCTAssertFalse(mockData.schoolRuns.isEmpty)
            
            // Verify data structure
            for event in mockData.calendarEvents {
                XCTAssertFalse(event.title.isEmpty)
                XCTAssertNotNil(event.date)
            }
            
            for task in mockData.tasks {
                XCTAssertFalse(task.title.isEmpty)
                XCTAssertNotNil(task.dueDate)
            }
            
            for message in mockData.messages {
                XCTAssertFalse(message.content.isEmpty)
                XCTAssertNotNil(message.timestamp)
            }
            
            for schoolRun in mockData.schoolRuns {
                XCTAssertFalse(schoolRun.route.isEmpty)
                XCTAssertNotNil(schoolRun.homeTime)
            }
        }
    }
}