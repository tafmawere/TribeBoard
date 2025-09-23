import XCTest
import SwiftUI
@testable import TribeBoard

/// Performance tests for UI/UX prototype to ensure smooth operation
/// Tests app performance and eliminates any crashes or broken states
@MainActor
final class PrototypePerformanceTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var appState: AppState!
    var mockServiceCoordinator: MockServiceCoordinator!
    
    // MARK: - Test Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize mock services for performance testing
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
    
    // MARK: - App Launch Performance Tests
    
    /// Test app initialization performance
    func testAppInitializationPerformance() async throws {
        measure {
            // Measure time to initialize mock services
            let coordinator = MockServiceCoordinator()
            let state = AppState()
            state.setMockServiceCoordinator(coordinator)
            state.resetToInitialState()
        }
    }
    
    /// Test service initialization performance
    func testServiceInitializationPerformance() async throws {
        let coordinator = MockServiceCoordinator()
        
        measure {
            Task {
                await coordinator.initializeServices()
            }
        }
    }
    
    // MARK: - Navigation Performance Tests
    
    /// Test navigation flow performance
    func testNavigationFlowPerformance() async throws {
        measure {
            // Rapid navigation through all flows
            appState.navigateTo(.onboarding)
            appState.navigateTo(.familySelection)
            appState.navigateTo(.createFamily)
            appState.navigateTo(.joinFamily)
            appState.navigateTo(.roleSelection)
            appState.navigateTo(.familyDashboard)
            appState.resetNavigation()
        }
    }
    
    /// Test state change performance
    func testStateChangePerformance() async throws {
        measure {
            // Rapid state changes
            appState.configureDemoScenario(.newUser)
            appState.configureDemoScenario(.existingUser)
            appState.configureDemoScenario(.familyAdmin)
            appState.configureDemoScenario(.childUser)
            appState.configureDemoScenario(.visitorUser)
            appState.resetToInitialState()
        }
    }
    
    // MARK: - Authentication Performance Tests
    
    /// Test authentication performance
    func testAuthenticationPerformance() async throws {
        await measure {
            await appState.signInWithMockAuth()
            await appState.signOut()
        }
    }
    
    /// Test multiple authentication cycles
    func testMultipleAuthenticationCycles() async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<10 {
            await appState.signInWithMockAuth()
            await appState.signOut()
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should complete 10 auth cycles within 5 seconds
        XCTAssertLessThan(timeElapsed, 5.0, "Authentication cycles should be fast")
    }
    
    // MARK: - Family Management Performance Tests
    
    /// Test family creation performance
    func testFamilyCreationPerformance() async throws {
        await appState.signInWithMockAuth()
        
        await measure {
            await appState.createFamilyMock(name: "Performance Test Family", code: "PERF123")
            appState.leaveFamily()
        }
    }
    
    /// Test family joining performance
    func testFamilyJoiningPerformance() async throws {
        await appState.signInWithMockAuth()
        
        await measure {
            await appState.joinFamilyMock(code: "DEMO123", role: .child)
            appState.leaveFamily()
        }
    }
    
    /// Test multiple family operations
    func testMultipleFamilyOperations() async throws {
        await appState.signInWithMockAuth()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<5 {
            let success = await appState.createFamilyMock(name: "Family \(i)", code: "FAM\(i)")
            XCTAssertTrue(success)
            appState.leaveFamily()
            
            let joinSuccess = await appState.joinFamilyMock(code: "DEMO123", role: .child)
            XCTAssertTrue(joinSuccess)
            appState.leaveFamily()
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should complete 5 create/join cycles within 10 seconds
        XCTAssertLessThan(timeElapsed, 10.0, "Family operations should be fast")
    }
    
    // MARK: - Mock Data Performance Tests
    
    /// Test mock data generation performance
    func testMockDataGenerationPerformance() async throws {
        measure {
            let _ = MockDataGenerator.mockFamilyWithMembers()
            let _ = MockDataGenerator.mockCalendarEvents()
            let _ = MockDataGenerator.mockFamilyTasks()
            let _ = MockDataGenerator.mockFamilyMessages()
            let _ = MockDataGenerator.mockSchoolRuns()
        }
    }
    
    /// Test role-based mock data performance
    func testRoleBasedMockDataPerformance() async throws {
        let roles: [Role] = [.parentAdmin, .parent, .child, .guardian, .visitor]
        
        measure {
            for role in roles {
                let _ = MockDataGenerator.mockDataForRole(role)
            }
        }
    }
    
    /// Test large mock data sets
    func testLargeMockDataSets() async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Generate large amounts of mock data
        for _ in 0..<100 {
            let _ = MockDataGenerator.mockCalendarEvents()
            let _ = MockDataGenerator.mockFamilyTasks()
            let _ = MockDataGenerator.mockFamilyMessages()
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should generate 300 data sets within 2 seconds
        XCTAssertLessThan(timeElapsed, 2.0, "Large mock data generation should be fast")
    }
    
    // MARK: - Memory Performance Tests
    
    /// Test memory usage during normal operations
    func testMemoryUsageDuringOperations() async throws {
        // Perform many operations to check for memory leaks
        for i in 0..<50 {
            appState.resetToInitialState()
            await appState.signInWithMockAuth()
            await appState.createFamilyMock(name: "Memory Test \(i)", code: "MEM\(i)")
            
            // Get mock data
            let mockData = appState.getMockDataForCurrentUser()
            XCTAssertFalse(mockData.calendarEvents.isEmpty)
            
            // Simulate errors
            appState.simulateErrorScenario(.networkError)
            appState.clearError()
            
            await appState.signOut()
        }
        
        // Final operations should still work
        await appState.signInWithMockAuth()
        XCTAssertTrue(appState.isAuthenticated)
    }
    
    /// Test memory usage with concurrent operations
    func testConcurrentMemoryUsage() async throws {
        let tasks = (0..<10).map { i in
            Task {
                let localAppState = AppState()
                let localCoordinator = MockServiceCoordinator()
                localAppState.setMockServiceCoordinator(localCoordinator)
                
                await localAppState.signInWithMockAuth()
                await localAppState.createFamilyMock(name: "Concurrent \(i)", code: "CON\(i)")
                
                return localAppState.isAuthenticated
            }
        }
        
        let results = await withTaskGroup(of: Bool.self) { group in
            for task in tasks {
                group.addTask {
                    await task.value
                }
            }
            
            var results: [Bool] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        
        // All concurrent operations should succeed
        XCTAssertTrue(results.allSatisfy { $0 })
    }
    
    // MARK: - UI Performance Tests
    
    /// Test demo journey performance
    func testDemoJourneyPerformance() async throws {
        let scenarios: [UserJourneyScenario] = [.newUser, .existingUser, .familyAdmin, .childUser, .visitorUser]
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for scenario in scenarios {
            appState.resetToInitialState()
            await appState.executeUserJourney(scenario)
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should complete all 5 journeys within 15 seconds
        XCTAssertLessThan(timeElapsed, 15.0, "Demo journeys should be fast")
    }
    
    /// Test error simulation performance
    func testErrorSimulationPerformance() async throws {
        let errorTypes: [MockErrorScenario] = [.networkError, .syncConflict, .authenticationError]
        
        measure {
            for errorType in errorTypes {
                appState.simulateErrorScenario(errorType)
                appState.clearError()
            }
        }
    }
    
    // MARK: - Stress Tests
    
    /// Test rapid user interactions
    func testRapidUserInteractions() async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate rapid user interactions
        for _ in 0..<100 {
            appState.navigateTo(.familySelection)
            appState.navigateTo(.createFamily)
            appState.navigateTo(.familyDashboard)
            appState.resetNavigation()
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should handle 400 navigation operations within 2 seconds
        XCTAssertLessThan(timeElapsed, 2.0, "Rapid interactions should be handled smoothly")
    }
    
    /// Test sustained operations
    func testSustainedOperations() async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Run sustained operations for a longer period
        while CFAbsoluteTimeGetCurrent() - startTime < 5.0 { // Run for 5 seconds
            appState.configureDemoScenario(.newUser)
            await appState.signInWithMockAuth()
            await appState.createFamilyMock(name: "Sustained Test", code: "SUST123")
            appState.resetToInitialState()
        }
        
        // App should still be functional after sustained operations
        await appState.signInWithMockAuth()
        XCTAssertTrue(appState.isAuthenticated)
    }
    
    // MARK: - Crash Prevention Tests
    
    /// Test nil safety
    func testNilSafety() async throws {
        // Test operations with nil states
        appState.currentUser = nil
        appState.currentFamily = nil
        appState.currentMembership = nil
        
        // These should not crash
        XCTAssertFalse(appState.isCurrentUserAdmin())
        XCTAssertNil(appState.getCurrentUserRole())
        
        let mockData = appState.getMockDataForCurrentUser()
        XCTAssertFalse(mockData.calendarEvents.isEmpty) // Should provide default data
        
        // Navigation should still work
        appState.navigateTo(.onboarding)
        XCTAssertEqual(appState.currentFlow, .onboarding)
    }
    
    /// Test invalid input handling
    func testInvalidInputHandling() async throws {
        await appState.signInWithMockAuth()
        
        // Test invalid family codes
        let invalidCodes = ["", "   ", "TOOLONGCODE123456", "ABC@123", "12"]
        
        for code in invalidCodes {
            let success = await appState.joinFamilyMock(code: code, role: .child)
            XCTAssertFalse(success, "Invalid code '\(code)' should not succeed")
        }
        
        // Test invalid family names
        let invalidNames = ["", "   "]
        
        for name in invalidNames {
            let success = await appState.createFamilyMock(name: name, code: "VALID123")
            XCTAssertFalse(success, "Invalid name '\(name)' should not succeed")
        }
    }
    
    /// Test boundary conditions
    func testBoundaryConditions() async throws {
        // Test with maximum length inputs
        let maxLengthName = String(repeating: "A", count: 100)
        let maxLengthCode = String(repeating: "B", count: 50)
        
        await appState.signInWithMockAuth()
        
        // Should handle long inputs gracefully
        let success = await appState.createFamilyMock(name: maxLengthName, code: maxLengthCode)
        // May succeed or fail, but should not crash
        
        // Test with minimum length inputs
        let minLengthName = "A"
        let minLengthCode = "123456"
        
        let minSuccess = await appState.createFamilyMock(name: minLengthName, code: minLengthCode)
        // Should succeed with valid minimum inputs
        XCTAssertTrue(minSuccess)
    }
    
    // MARK: - Resource Management Tests
    
    /// Test resource cleanup
    func testResourceCleanup() async throws {
        // Create multiple app states to test cleanup
        var appStates: [AppState] = []
        
        for i in 0..<10 {
            let state = AppState()
            let coordinator = MockServiceCoordinator()
            state.setMockServiceCoordinator(coordinator)
            await state.signInWithMockAuth()
            await state.createFamilyMock(name: "Cleanup Test \(i)", code: "CLN\(i)")
            appStates.append(state)
        }
        
        // Clear references
        appStates.removeAll()
        
        // Original app state should still work
        await appState.signInWithMockAuth()
        XCTAssertTrue(appState.isAuthenticated)
    }
    
    /// Test timer and async task cleanup
    func testAsyncTaskCleanup() async throws {
        // Start multiple async operations
        let tasks = (0..<20).map { i in
            Task {
                await appState.signInWithMockAuth()
                await appState.createFamilyMock(name: "Async \(i)", code: "ASY\(i)")
                appState.resetToInitialState()
            }
        }
        
        // Cancel half of them
        for i in 0..<10 {
            tasks[i].cancel()
        }
        
        // Wait for remaining tasks
        for i in 10..<20 {
            await tasks[i].value
        }
        
        // App should still be functional
        await appState.signInWithMockAuth()
        XCTAssertTrue(appState.isAuthenticated)
    }
    
    // MARK: - Performance Benchmarks
    
    /// Benchmark authentication flow
    func testAuthenticationBenchmark() async throws {
        let iterations = 20
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            await appState.signInWithMockAuth()
            await appState.signOut()
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        let averageTime = timeElapsed / Double(iterations)
        
        print("Average authentication cycle time: \(averageTime) seconds")
        
        // Should average less than 0.25 seconds per cycle
        XCTAssertLessThan(averageTime, 0.25, "Authentication should be fast")
    }
    
    /// Benchmark family operations
    func testFamilyOperationsBenchmark() async throws {
        await appState.signInWithMockAuth()
        
        let iterations = 10
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<iterations {
            await appState.createFamilyMock(name: "Benchmark \(i)", code: "BEN\(i)")
            appState.leaveFamily()
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        let averageTime = timeElapsed / Double(iterations)
        
        print("Average family creation time: \(averageTime) seconds")
        
        // Should average less than 0.5 seconds per operation
        XCTAssertLessThan(averageTime, 0.5, "Family operations should be fast")
    }
    
    /// Benchmark mock data generation
    func testMockDataBenchmark() async throws {
        let iterations = 100
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            let _ = MockDataGenerator.mockFamilyWithMembers()
            let _ = MockDataGenerator.mockCalendarEvents()
            let _ = MockDataGenerator.mockFamilyTasks()
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        let averageTime = timeElapsed / Double(iterations)
        
        print("Average mock data generation time: \(averageTime) seconds")
        
        // Should average less than 0.01 seconds per generation
        XCTAssertLessThan(averageTime, 0.01, "Mock data generation should be very fast")
    }
}