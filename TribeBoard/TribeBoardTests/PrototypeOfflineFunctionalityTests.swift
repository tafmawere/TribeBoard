import XCTest
import SwiftUI
@testable import TribeBoard

/// Tests to verify offline functionality works without any service dependencies
/// Ensures the prototype operates completely independently of backend services
@MainActor
final class PrototypeOfflineFunctionalityTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var appState: AppState!
    var mockServiceCoordinator: MockServiceCoordinator!
    
    // MARK: - Test Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize mock services for offline testing
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
    
    // MARK: - Core Offline Functionality Tests
    
    /// Test that app launches without any network dependencies
    func testAppLaunchOffline() async throws {
        // App should initialize successfully with mock services
        XCTAssertNotNil(mockServiceCoordinator)
        XCTAssertNotNil(appState)
        XCTAssertEqual(appState.currentFlow, .onboarding)
        
        // Mock services should be available
        XCTAssertNotNil(mockServiceCoordinator.authService)
        XCTAssertNotNil(mockServiceCoordinator.dataService)
        XCTAssertNotNil(mockServiceCoordinator.cloudKitService)
        XCTAssertNotNil(mockServiceCoordinator.syncManager)
    }
    
    /// Test authentication works offline with mock services
    func testOfflineAuthentication() async throws {
        // Should start unauthenticated
        XCTAssertFalse(appState.isAuthenticated)
        
        // Mock sign in should work without network
        await appState.signInWithMockAuth()
        
        // Should be authenticated with mock user
        XCTAssertTrue(appState.isAuthenticated)
        XCTAssertNotNil(appState.currentUser)
        XCTAssertEqual(appState.currentFlow, .familySelection)
        
        // Sign out should also work offline
        await appState.signOut()
        XCTAssertFalse(appState.isAuthenticated)
        XCTAssertNil(appState.currentUser)
        XCTAssertEqual(appState.currentFlow, .onboarding)
    }
    
    /// Test family creation works offline
    func testOfflineFamilyCreation() async throws {
        // Sign in first
        await appState.signInWithMockAuth()
        
        // Create family should work without network
        let success = await appState.createFamilyMock(name: "Offline Family", code: "OFF123")
        XCTAssertTrue(success)
        
        // Should have created family and membership
        XCTAssertNotNil(appState.currentFamily)
        XCTAssertNotNil(appState.currentMembership)
        XCTAssertEqual(appState.currentFamily?.name, "Offline Family")
        XCTAssertEqual(appState.currentFlow, .familyDashboard)
    }
    
    /// Test family joining works offline
    func testOfflineFamilyJoining() async throws {
        // Sign in first
        await appState.signInWithMockAuth()
        
        // Join family should work with mock data
        let success = await appState.joinFamilyMock(code: "DEMO123", role: .child)
        XCTAssertTrue(success)
        
        // Should have joined family
        XCTAssertNotNil(appState.currentFamily)
        XCTAssertNotNil(appState.currentMembership)
        XCTAssertEqual(appState.currentMembership?.role, .child)
        XCTAssertEqual(appState.currentFlow, .familyDashboard)
    }
    
    // MARK: - Mock Service Offline Tests
    
    /// Test mock authentication service works offline
    func testMockAuthServiceOffline() async throws {
        let authService = mockServiceCoordinator.authService
        
        // Should start unauthenticated
        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertNil(authService.currentUser)
        
        // Sign in with Apple should work
        let appleResult = await authService.signInWithApple()
        switch appleResult {
        case .success(let user):
            XCTAssertNotNil(user)
            XCTAssertTrue(authService.isAuthenticated)
        case .failure(let error):
            XCTFail("Mock Apple sign in should not fail: \(error)")
        }
        
        // Sign out should work
        try await authService.signOut()
        XCTAssertFalse(authService.isAuthenticated)
        
        // Sign in with Google should work
        let googleResult = await authService.signInWithGoogle()
        switch googleResult {
        case .success(let user):
            XCTAssertNotNil(user)
            XCTAssertTrue(authService.isAuthenticated)
        case .failure(let error):
            XCTFail("Mock Google sign in should not fail: \(error)")
        }
    }
    
    /// Test mock data service works offline
    func testMockDataServiceOffline() async throws {
        let dataService = mockServiceCoordinator.dataService
        
        // Should have mock data available
        let mockFamilies = dataService.getMockFamilies()
        XCTAssertFalse(mockFamilies.isEmpty)
        
        let mockUsers = dataService.getMockUsers()
        XCTAssertFalse(mockUsers.isEmpty)
        
        let mockMemberships = dataService.getMockMemberships()
        XCTAssertFalse(mockMemberships.isEmpty)
        
        // Create family should work
        let family = try await dataService.createFamily(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: mockUsers.first!.id
        )
        XCTAssertEqual(family.name, "Test Family")
        XCTAssertEqual(family.code, "TEST123")
        
        // Fetch family by code should work
        let fetchedFamily = try await dataService.fetchFamily(byCode: "TEST123")
        XCTAssertNotNil(fetchedFamily)
        XCTAssertEqual(fetchedFamily?.name, "Test Family")
    }
    
    /// Test mock CloudKit service works offline
    func testMockCloudKitServiceOffline() async throws {
        let cloudKitService = mockServiceCoordinator.cloudKitService
        
        // Initial setup should work
        try await cloudKitService.performInitialSetup()
        XCTAssertEqual(cloudKitService.syncStatus, .idle)
        
        // Sync operations should work
        let family = Family(name: "Test Family", code: "TEST123", createdByUserId: UUID())
        let syncResult = await cloudKitService.syncFamily(family)
        
        switch syncResult {
        case .success:
            XCTAssertTrue(true) // Success expected
        case .failure(let error):
            XCTFail("Mock sync should not fail: \(error)")
        }
        
        // QR code generation should work
        let qrCode = cloudKitService.generateQRCode(for: family)
        XCTAssertFalse(qrCode.isEmpty)
        XCTAssertTrue(qrCode.contains(family.code))
    }
    
    /// Test mock sync manager works offline
    func testMockSyncManagerOffline() async throws {
        let syncManager = mockServiceCoordinator.syncManager
        
        // Should start not syncing
        XCTAssertFalse(syncManager.isSyncing)
        XCTAssertNil(syncManager.lastSyncDate)
        
        // Sync all should work
        await syncManager.syncAll()
        XCTAssertFalse(syncManager.isSyncing)
        XCTAssertNotNil(syncManager.lastSyncDate)
        XCTAssertNil(syncManager.syncError)
        
        // Sync specific family should work
        let family = Family(name: "Test Family", code: "TEST123", createdByUserId: UUID())
        await syncManager.syncFamily(family)
        XCTAssertFalse(syncManager.isSyncing)
        XCTAssertTrue(syncManager.checkSyncStatus())
    }
    
    // MARK: - Data Persistence Tests (In-Memory)
    
    /// Test that mock data persists during app session
    func testMockDataPersistence() async throws {
        // Create family
        await appState.signInWithMockAuth()
        let success = await appState.createFamilyMock(name: "Persistent Family", code: "PERS123")
        XCTAssertTrue(success)
        
        let originalFamily = appState.currentFamily
        XCTAssertNotNil(originalFamily)
        
        // Navigate away and back
        appState.leaveFamily()
        XCTAssertNil(appState.currentFamily)
        
        // Join the same family again
        let joinSuccess = await appState.joinFamilyMock(code: "PERS123", role: .parent)
        XCTAssertTrue(joinSuccess)
        
        // Should have the same family
        XCTAssertNotNil(appState.currentFamily)
        XCTAssertEqual(appState.currentFamily?.name, "Persistent Family")
        XCTAssertEqual(appState.currentFamily?.code, "PERS123")
    }
    
    /// Test mock data reset functionality
    func testMockDataReset() async throws {
        // Create some state
        await appState.signInWithMockAuth()
        await appState.createFamilyMock(name: "Test Family", code: "TEST123")
        XCTAssertNotNil(appState.currentFamily)
        
        // Reset should clear everything
        appState.resetToInitialState()
        
        // Should be back to initial state
        XCTAssertFalse(appState.isAuthenticated)
        XCTAssertNil(appState.currentUser)
        XCTAssertNil(appState.currentFamily)
        XCTAssertNil(appState.currentMembership)
        XCTAssertEqual(appState.currentFlow, .onboarding)
    }
    
    // MARK: - Error Simulation Tests
    
    /// Test error simulation works offline
    func testOfflineErrorSimulation() async throws {
        // Test network error simulation
        appState.simulateErrorScenario(.networkError)
        XCTAssertNotNil(appState.errorMessage)
        XCTAssertTrue(appState.errorMessage!.contains("Network"))
        
        appState.clearError()
        
        // Test sync conflict simulation
        appState.simulateErrorScenario(.syncConflict)
        XCTAssertNotNil(appState.errorMessage)
        XCTAssertTrue(appState.errorMessage!.contains("Sync"))
        
        appState.clearError()
        
        // Test authentication error simulation
        appState.simulateErrorScenario(.authenticationError)
        XCTAssertNotNil(appState.errorMessage)
        XCTAssertTrue(appState.errorMessage!.contains("Authentication"))
    }
    
    // MARK: - Demo Scenario Tests
    
    /// Test all demo scenarios work offline
    func testDemoScenariosOffline() async throws {
        let scenarios: [UserJourneyScenario] = [.newUser, .existingUser, .familyAdmin, .childUser, .visitorUser]
        
        for scenario in scenarios {
            // Reset and configure scenario
            appState.resetToInitialState()
            appState.configureDemoScenario(scenario)
            
            // Verify scenario is configured correctly
            switch scenario {
            case .newUser:
                XCTAssertFalse(appState.isAuthenticated)
                XCTAssertEqual(appState.currentFlow, .onboarding)
            case .existingUser, .familyAdmin, .childUser, .visitorUser:
                XCTAssertTrue(appState.isAuthenticated)
                XCTAssertNotNil(appState.currentUser)
                XCTAssertEqual(appState.currentFlow, .familyDashboard)
            }
            
            // Execute journey should work offline
            await appState.executeUserJourney(scenario)
            
            // Should reach appropriate end state
            switch scenario {
            case .newUser:
                XCTAssertEqual(appState.currentFlow, .familySelection)
            case .existingUser, .familyAdmin, .childUser, .visitorUser:
                XCTAssertEqual(appState.currentFlow, .familyDashboard)
            }
        }
    }
    
    // MARK: - Performance Tests
    
    /// Test offline performance is acceptable
    func testOfflinePerformance() async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Perform multiple offline operations
        for i in 0..<10 {
            appState.resetToInitialState()
            await appState.signInWithMockAuth()
            await appState.createFamilyMock(name: "Family \(i)", code: "FAM\(i)")
            await appState.signOut()
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should complete within reasonable time (5 seconds for 10 iterations)
        XCTAssertLessThan(timeElapsed, 5.0, "Offline operations should be fast")
    }
    
    /// Test memory usage during offline operations
    func testOfflineMemoryUsage() async throws {
        // Perform many operations to test for memory leaks
        for i in 0..<100 {
            appState.resetToInitialState()
            appState.configureDemoScenario(.existingUser)
            
            // Get mock data
            let mockData = appState.getMockDataForCurrentUser()
            XCTAssertFalse(mockData.calendarEvents.isEmpty)
            
            // Simulate error
            appState.simulateErrorScenario(.networkError)
            appState.clearError()
            
            if i % 10 == 0 {
                // Periodically check that we can still perform operations
                await appState.signInWithMockAuth()
                XCTAssertTrue(appState.isAuthenticated)
            }
        }
        
        // Final state should still be functional
        appState.resetToInitialState()
        await appState.signInWithMockAuth()
        XCTAssertTrue(appState.isAuthenticated)
    }
    
    // MARK: - Validation Tests
    
    /// Test validation works offline
    func testOfflineValidation() async throws {
        // Family code validation should work
        XCTAssertTrue(appState.validateFamilyCode("VALID1"))
        XCTAssertFalse(appState.validateFamilyCode(""))
        XCTAssertFalse(appState.validateFamilyCode("TOOLONG123456"))
        
        // QR code generation should work
        let family = Family(name: "Test", code: "TEST123", createdByUserId: UUID())
        let qrCode = appState.generateMockQRCode(for: family)
        XCTAssertFalse(qrCode.isEmpty)
        XCTAssertTrue(qrCode.contains("TEST123"))
    }
    
    /// Test mock data generation works offline
    func testMockDataGenerationOffline() async throws {
        // Test mock data for different roles
        let roles: [Role] = [.parentAdmin, .parent, .child, .guardian, .visitor]
        
        for role in roles {
            let mockData = MockDataGenerator.mockDataForRole(role)
            
            // Should have data for all categories
            XCTAssertFalse(mockData.calendarEvents.isEmpty)
            XCTAssertFalse(mockData.tasks.isEmpty)
            XCTAssertFalse(mockData.messages.isEmpty)
            XCTAssertFalse(mockData.schoolRuns.isEmpty)
            
            // Data should be appropriate for role
            switch role {
            case .child:
                // Child should have age-appropriate tasks
                XCTAssertTrue(mockData.tasks.contains { $0.title.contains("homework") || $0.title.contains("chores") })
            case .parentAdmin, .parent:
                // Parents should have admin tasks
                XCTAssertTrue(mockData.tasks.contains { $0.title.contains("family") || $0.title.contains("manage") })
            default:
                // Other roles should have basic tasks
                XCTAssertFalse(mockData.tasks.isEmpty)
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    /// Test edge cases work offline
    func testOfflineEdgeCases() async throws {
        // Test rapid state changes
        for _ in 0..<20 {
            appState.navigateTo(.onboarding)
            appState.navigateTo(.familySelection)
            appState.navigateTo(.familyDashboard)
        }
        
        // Should still be functional
        XCTAssertEqual(appState.currentFlow, .familyDashboard)
        
        // Test multiple error scenarios
        appState.simulateErrorScenario(.networkError)
        appState.simulateErrorScenario(.syncConflict)
        appState.simulateErrorScenario(.authenticationError)
        
        // Should handle multiple errors gracefully
        XCTAssertNotNil(appState.errorMessage)
        
        // Clear and continue
        appState.clearError()
        await appState.signInWithMockAuth()
        XCTAssertTrue(appState.isAuthenticated)
    }
    
    /// Test concurrent operations offline
    func testConcurrentOfflineOperations() async throws {
        // Start multiple async operations
        async let signIn = appState.signInWithMockAuth()
        async let createFamily = appState.createFamilyMock(name: "Concurrent Family", code: "CONC123")
        
        // Wait for completion
        await signIn
        let familyCreated = await createFamily
        
        // One should succeed (the sign in), family creation might fail due to state
        XCTAssertTrue(appState.isAuthenticated)
        
        // Reset and try sequential operations
        appState.resetToInitialState()
        await appState.signInWithMockAuth()
        let success = await appState.createFamilyMock(name: "Sequential Family", code: "SEQ123")
        XCTAssertTrue(success)
    }
}