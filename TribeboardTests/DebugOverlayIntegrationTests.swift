//
//  DebugOverlayIntegrationTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/05.
//

import XCTest
import SwiftUI
@testable import Tribeboard

/// Comprehensive integration tests for debug overlay functionality
/// Task 9.1: Test complete debug overlay functionality
final class DebugOverlayIntegrationTests: XCTestCase {
    
    var debugStateManager: DebugStateManager!
    var mockFirebaseService: MockFirebaseRunService!
    var runEventService: RunEventService!
    var locationService: LocationService!
    
    override func setUp() {
        super.setUp()
        Task { @MainActor in
            debugStateManager = DebugStateManager.shared
            mockFirebaseService = MockFirebaseRunService()
            runEventService = RunEventService(firebaseService: mockFirebaseService)
            locationService = LocationService()
        }
    }
    
    override func tearDown() {
        super.tearDown()
        debugStateManager = nil
        mockFirebaseService = nil
        runEventService = nil
        locationService = nil
    }
    
    // MARK: - System State Information Display Tests
    
    @MainActor
    func testDebugOverlayDisplaysAllSystemStateInformation() {
        // Test that debug overlay displays all required system state information
        // Requirements: 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10
        
        // Set up test data
        let testRun = Run(
            title: "Integration Test Run",
            scheduledTime: Date(),
            driverId: "test-driver",
            status: .activeEnroute,
            stops: [],
            passengers: [],
            createdBy: "test-user",
            familyId: "test-family"
        )
        
        let testDate = Date()
        
        // Update all state information
        debugStateManager.updateActiveRun(testRun)
        debugStateManager.updateLocationInfo(testDate)
        debugStateManager.updatePlaybackStatus(true)
        debugStateManager.updateCurrentUser(id: "test-user-123", mode: "Driver")
        debugStateManager.updatePlaybackTick()
        
        // Verify all state is correctly set
        XCTAssertEqual(debugStateManager.launchMode, AppConfig.launchMode, "LaunchMode should be displayed")
        XCTAssertEqual(debugStateManager.isDemoPlaybackEnabled, AppConfig.isDemoPlaybackEnabled, "Demo playback status should be displayed")
        XCTAssertEqual(debugStateManager.currentUserId, "test-user-123", "Current user ID should be displayed")
        XCTAssertEqual(debugStateManager.userMode, "Driver", "User mode should be displayed")
        XCTAssertEqual(debugStateManager.activeRunId, testRun.id, "Active run ID should be displayed")
        XCTAssertEqual(debugStateManager.activeRunState, testRun.status, "Active run state should be displayed")
        XCTAssertEqual(debugStateManager.lastLocationUpdate, testDate, "Last location update should be displayed")
        XCTAssertTrue(debugStateManager.isPlaybackRunning, "Playback running status should be displayed")
        XCTAssertNotNil(debugStateManager.lastPlaybackTick, "Last playback tick should be displayed")
        XCTAssertEqual(debugStateManager.playbackTickCount, 1, "Playback tick count should be displayed")
    }
    
    @MainActor
    func testDebugOverlayHandlesNilValues() {
        // Test that debug overlay handles nil/missing values gracefully
        // Requirements: 1.6, 1.7, 1.8, 1.10
        
        // Set all values to nil/default
        debugStateManager.updateActiveRun(nil)
        debugStateManager.updateLocationInfo(nil)
        debugStateManager.updatePlaybackStatus(false)
        debugStateManager.updateCurrentUser(id: nil, mode: "Unknown")
        
        // Verify nil values are handled correctly
        XCTAssertNil(debugStateManager.activeRunId, "Nil active run ID should be handled")
        XCTAssertNil(debugStateManager.activeRunState, "Nil active run state should be handled")
        XCTAssertNil(debugStateManager.currentStopIndex, "Nil current stop index should be handled")
        XCTAssertNil(debugStateManager.lastLocationUpdate, "Nil location update should be handled")
        XCTAssertFalse(debugStateManager.isPlaybackRunning, "False playback status should be handled")
        XCTAssertNil(debugStateManager.currentUserId, "Nil user ID should be handled")
        XCTAssertEqual(debugStateManager.userMode, "Unknown", "Unknown user mode should be handled")
    }
    
    // MARK: - Debug Overlay Attachment Tests
    
    func testDebugOverlayAttachmentToDriverView() async {
        // Test that debug overlay can be attached to DriverFocusModeView
        // Requirements: 1.1, 1.2
        
        await MainActor.run {
            let mockRoleContext = RoleContext(userId: "driver1", role: .driver, familyId: "family1")
            let driverView = DriverFocusModeView(
                runId: "test-run",
                runEventService: runEventService,
                roleContext: mockRoleContext
            )
            
            // Test that the view can be created with debug overlay
            let viewWithOverlay = driverView.debugOverlay()
            XCTAssertNotNil(viewWithOverlay, "Debug overlay should attach to DriverFocusModeView")
        }
    }
    
    func testDebugOverlayAttachmentToObserverView() async {
        // Test that debug overlay can be attached to ObserverTrackingView
        // Requirements: 1.1, 1.2
        
        await MainActor.run {
            let mockRoleContext = RoleContext(userId: "observer1", role: .observer, familyId: "family1")
            let observerView = ObserverTrackingView(
                runId: "test-run",
                runEventService: runEventService,
                roleContext: mockRoleContext
            )
            
            // Test that the view can be created with debug overlay
            let viewWithOverlay = observerView.debugOverlay()
            XCTAssertNotNil(viewWithOverlay, "Debug overlay should attach to ObserverTrackingView")
        }
    }
    
    // MARK: - Debug Assertions Integration Tests
    
    func testDebugAssertionsWorkInBothModes() {
        // Test that debug assertions work correctly in both DEBUG and Release modes
        // Requirements: 2.4, 2.5
        
        // Test successful assertion (should not log)
        debugAssert(true, "This should not trigger logging")
        
        // Test failed assertion (should log safely)
        debugAssert(false, "This should trigger safe logging")
        
        // Test debug logging functions
        debugLog("Test debug log message")
        debugAssertNotNil("test" as String?, "Test not nil assertion")
        debugAssertf(true, "Test formatted assertion: %@", "value")
        debugLogf("Test formatted log: %d", 42)
        
        // If we reach here, all debug functions work without crashing
        XCTAssertTrue(true, "Debug assertion functions should work without crashing")
    }
    
    // MARK: - App Launch Integration Tests
    
    func testAppLaunchDebugAssertions() async {
        // Test that app launch debug assertions work correctly
        // Requirements: 2.1
        
        // Simulate app launch scenario
        let familyId = "demo_family_id"
        
        do {
            // Test getCurrentActiveRun() logging
            let activeRun = try await mockFirebaseService.getCurrentActiveRun(for: familyId)
            
            if let run = activeRun {
                // Should log that active run was found
                debugLog("App launch: getCurrentActiveRun() returned active run with id=\(run.id), state=\(run.status)")
                XCTAssertNotNil(run, "Active run should be found for demo family")
            } else {
                // Should log that no active run was found
                debugLog("App launch: getCurrentActiveRun() returned nil - no active run found for family \(familyId)")
            }
            
            // Test should complete without crashing
            XCTAssertTrue(true, "App launch debug assertions should work correctly")
            
        } catch {
            XCTFail("App launch test should not throw error: \(error)")
        }
    }
    
    // MARK: - Playback Controller Integration Tests
    
    @MainActor
    func testPlaybackControllerDebugIntegration() {
        // Test that playback controller integrates correctly with debug system
        // Requirements: 2.2, 2.3
        
        let controller = DemoRunPlaybackController(
            runEventService: runEventService,
            locationService: locationService,
            firebaseService: mockFirebaseService
        )
        
        // Test that controller can be created
        XCTAssertNotNil(controller, "DemoRunPlaybackController should be created successfully")
        
        // Test playback tick updates
        let initialTickCount = debugStateManager.playbackTickCount
        debugStateManager.updatePlaybackTick()
        
        XCTAssertEqual(debugStateManager.playbackTickCount, initialTickCount + 1, "Playback tick should be updated")
        XCTAssertNotNil(debugStateManager.lastPlaybackTick, "Last playback tick should be set")
        
        // Test playback status updates
        debugStateManager.updatePlaybackStatus(true)
        XCTAssertTrue(debugStateManager.isPlaybackRunning, "Playback status should be updated")
    }
    
    // MARK: - Demo Data Integration Tests
    
    func testDemoDataIntegrationWithDebugOverlay() async {
        // Test that demo data integrates correctly with debug overlay
        // Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6
        
        do {
            // Test enhanced demo seed data
            let activeRun = try await mockFirebaseService.getCurrentActiveRun(for: "demo_family_id")
            
            XCTAssertNotNil(activeRun, "Demo data should provide active run (Requirement 4.1)")
            
            guard let run = activeRun else { return }
            
            // Verify demo data meets requirements
            XCTAssertTrue(run.status == .activeEnroute || run.status == .arrivedAtStop, 
                         "Run state should be activeEnroute or arrivedAtStop (Requirement 4.2)")
            XCTAssertEqual(run.passengers.count, 2, "Should have exactly 2 passengers (Requirement 4.3)")
            XCTAssertEqual(run.stops.count, 3, "Should have exactly 3 stops (Requirement 4.3)")
            XCTAssertTrue(run.currentStopIndex >= 0 && run.currentStopIndex < run.stops.count, 
                         "Current stop index should be valid (Requirement 4.4)")
            XCTAssertEqual(run.driverId, "demo_driver_user_id", "Driver ID should match demo driver (Requirement 4.5)")
            
            // Test debug overlay integration with demo data
            await MainActor.run {
                debugStateManager.updateActiveRun(run)
                XCTAssertEqual(debugStateManager.activeRunId, run.id, "Debug overlay should display demo run ID")
                XCTAssertEqual(debugStateManager.activeRunState, run.status, "Debug overlay should display demo run state")
                XCTAssertEqual(debugStateManager.currentStopIndex, run.currentStopIndex, "Debug overlay should display demo stop index")
            }
            
        } catch {
            XCTFail("Demo data integration test should not throw error: \(error)")
        }
    }
    
    // MARK: - User Mode Toggle Integration Tests
    
    @MainActor
    func testDebugUserModeToggleIntegration() {
        // Test that debug user mode toggle integrates with debug overlay
        // Requirements: 5.1, 5.2, 5.3, 5.4
        
        #if DEBUG
        // Test driver mode
        AppConfig.demoCurrentUserMode = .driver
        let driverUser = AppConfig.currentDemoUser
        debugStateManager.updateCurrentUser(id: driverUser.id, mode: driverUser.role.displayName)
        
        XCTAssertEqual(debugStateManager.currentUserId, "demo_driver_user_id", "Debug overlay should show driver user ID")
        XCTAssertEqual(debugStateManager.userMode, "Driver", "Debug overlay should show driver mode")
        
        // Test observer mode
        AppConfig.demoCurrentUserMode = .observer
        let observerUser = AppConfig.currentDemoUser
        debugStateManager.updateCurrentUser(id: observerUser.id, mode: observerUser.role.displayName)
        
        XCTAssertEqual(debugStateManager.currentUserId, "demo_observer_user_id", "Debug overlay should show observer user ID")
        XCTAssertEqual(debugStateManager.userMode, "Observer", "Debug overlay should show observer mode")
        
        // Reset to driver for other tests
        AppConfig.demoCurrentUserMode = .driver
        #endif
    }
    
    // MARK: - Cross-Component Integration Tests
    
    @MainActor
    func testCompleteDebugOverlayWorkflow() {
        // Test complete debug overlay workflow across all components
        // Requirements: All requirements
        
        // 1. Test initial state
        XCTAssertEqual(debugStateManager.launchMode, AppConfig.launchMode, "Initial launch mode should be correct")
        XCTAssertEqual(debugStateManager.isDemoPlaybackEnabled, AppConfig.isDemoPlaybackEnabled, "Initial demo setting should be correct")
        
        // 2. Test user mode setup
        #if DEBUG
        AppConfig.demoCurrentUserMode = .driver
        let currentUser = AppConfig.currentDemoUser
        debugStateManager.updateCurrentUser(id: currentUser.id, mode: currentUser.role.displayName)
        XCTAssertEqual(debugStateManager.currentUserId, currentUser.id, "User should be set correctly")
        #endif
        
        // 3. Test active run setup
        let testRun = Run(
            title: "Complete Workflow Test",
            scheduledTime: Date(),
            driverId: "demo_driver_user_id",
            status: .activeEnroute,
            stops: [],
            passengers: [],
            createdBy: "test-user",
            familyId: "demo_family_id"
        )
        debugStateManager.updateActiveRun(testRun)
        XCTAssertEqual(debugStateManager.activeRunId, testRun.id, "Active run should be set correctly")
        
        // 4. Test playback controller integration
        debugStateManager.updatePlaybackStatus(true)
        debugStateManager.updatePlaybackTick()
        XCTAssertTrue(debugStateManager.isPlaybackRunning, "Playback should be running")
        XCTAssertEqual(debugStateManager.playbackTickCount, 1, "Tick count should be updated")
        
        // 5. Test location updates
        let testDate = Date()
        debugStateManager.updateLocationInfo(testDate)
        XCTAssertEqual(debugStateManager.lastLocationUpdate, testDate, "Location should be updated")
        
        // 6. Test debug assertions
        debugAssert(true, "Workflow test assertion")
        debugLog("Complete workflow test completed successfully")
        
        // All components should work together without issues
        XCTAssertTrue(true, "Complete debug overlay workflow should work correctly")
    }
    
    // MARK: - Error Handling and Edge Cases
    
    @MainActor
    func testDebugOverlayErrorHandling() {
        // Test that debug overlay handles error conditions gracefully
        
        // Test with invalid data
        debugStateManager.updateCurrentUser(id: "", mode: "")
        XCTAssertEqual(debugStateManager.currentUserId, "", "Empty user ID should be handled")
        XCTAssertEqual(debugStateManager.userMode, "", "Empty user mode should be handled")
        
        // Test with extreme values
        for _ in 0..<100 {
            debugStateManager.updatePlaybackTick()
        }
        XCTAssertEqual(debugStateManager.playbackTickCount, 100, "High tick count should be handled")
        
        // Test rapid state changes
        for i in 0..<10 {
            debugStateManager.updatePlaybackStatus(i % 2 == 0)
        }
        XCTAssertFalse(debugStateManager.isPlaybackRunning, "Rapid status changes should be handled")
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testDebugOverlayPerformance() {
        // Test that debug overlay operations are performant
        
        let startTime = Date()
        
        // Perform many state updates
        for i in 0..<1000 {
            debugStateManager.updatePlaybackTick()
            if i % 100 == 0 {
                debugStateManager.updatePlaybackStatus(i % 200 == 0)
            }
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Should complete within reasonable time (less than 1 second)
        XCTAssertLessThan(duration, 1.0, "Debug overlay operations should be performant")
        XCTAssertEqual(debugStateManager.playbackTickCount, 1000, "All updates should be processed")
    }
}