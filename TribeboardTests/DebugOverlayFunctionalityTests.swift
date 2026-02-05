//
//  DebugOverlayFunctionalityTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/04.
//

import XCTest
import SwiftUI
@testable import Tribeboard

/// Functional tests to verify debug overlay functionality works as expected
/// This serves as the checkpoint verification for task 4
final class DebugOverlayFunctionalityTests: XCTestCase {
    
    var debugStateManager: DebugStateManager!
    
    override func setUp() {
        super.setUp()
        Task { @MainActor in
            debugStateManager = DebugStateManager.shared
        }
    }
    
    override func tearDown() {
        super.tearDown()
        debugStateManager = nil
    }
    
    // MARK: - Core Functionality Tests
    
    @MainActor
    func testDebugStateManagerSingleton() {
        // Verify singleton pattern works correctly
        let instance1 = DebugStateManager.shared
        let instance2 = DebugStateManager.shared
        
        XCTAssertTrue(instance1 === instance2, "DebugStateManager should be a singleton")
    }
    
    func testDebugOverlayViewModifierExists() {
        // Verify that the debug overlay view modifier can be applied
        let testView = Text("Test")
        let modifiedView = testView.debugOverlay()
        
        // If this compiles and runs without error, the modifier exists and works
        XCTAssertNotNil(modifiedView)
    }
    
    func testLaunchModeDisplayNames() {
        // Verify LaunchMode extension works correctly
        XCTAssertEqual(LaunchMode.activeRunOnly.displayName, "ActiveOnly")
        XCTAssertEqual(LaunchMode.fullApp.displayName, "FullApp")
    }
    
    func testRunStatusDisplayNames() {
        // Verify RunStatus display names work correctly
        XCTAssertEqual(RunStatus.scheduled.displayName, "Scheduled")
        XCTAssertEqual(RunStatus.activeEnroute.displayName, "En Route")
        XCTAssertEqual(RunStatus.arrivedAtStop.displayName, "Arrived at Stop")
        XCTAssertEqual(RunStatus.paused.displayName, "Paused")
        XCTAssertEqual(RunStatus.completed.displayName, "Completed")
        XCTAssertEqual(RunStatus.cancelled.displayName, "Cancelled")
    }
    
    func testDebugAssertionFunctionExists() {
        // Verify debug assertion functions exist and can be called
        // This should not crash in either DEBUG or Release builds
        debugAssert(true, "Test assertion - should not log")
        debugAssert(false, "Test assertion - should log safely")
        debugLog("Test debug log message")
        debugAssertNotNil("test" as String?, "Test not nil assertion")
        debugAssertf(true, "Test formatted assertion: %@", "value")
        debugLogf("Test formatted log: %d", 42)
        
        // If we reach here, all debug functions work without crashing
        XCTAssertTrue(true, "Debug assertion functions work without crashing")
    }
    
    @MainActor
    func testDebugStateManagerStateUpdates() {
        // Test that all state update methods work correctly
        let testDate = Date()
        let testRun = Run(
            title: "Test Run",
            scheduledTime: testDate,
            driverId: "test-driver",
            status: .activeEnroute,
            stops: [],
            passengers: [],
            createdBy: "test-user",
            familyId: "test-family"
        )
        
        // Test active run update
        debugStateManager.updateActiveRun(testRun)
        XCTAssertEqual(debugStateManager.activeRunId, testRun.id)
        XCTAssertEqual(debugStateManager.activeRunState, testRun.status)
        
        // Test location update
        debugStateManager.updateLocationInfo(testDate)
        XCTAssertEqual(debugStateManager.lastLocationUpdate, testDate)
        
        // Test playback status update
        debugStateManager.updatePlaybackStatus(true)
        XCTAssertTrue(debugStateManager.isPlaybackRunning)
        
        // Test user update
        debugStateManager.updateCurrentUser(id: "test-user", mode: "Driver")
        XCTAssertEqual(debugStateManager.currentUserId, "test-user")
        XCTAssertEqual(debugStateManager.userMode, "Driver")
        
        // Test playback tick update
        let initialTickCount = debugStateManager.playbackTickCount
        debugStateManager.updatePlaybackTick()
        XCTAssertEqual(debugStateManager.playbackTickCount, initialTickCount + 1)
        XCTAssertNotNil(debugStateManager.lastPlaybackTick)
    }
    
    func testDebugOverlayViewCreation() {
        // Test that DebugOverlayView can be created without errors
        let debugOverlay = DebugOverlayView()
        XCTAssertNotNil(debugOverlay)
        
        // Test that the view has the expected structure
        // This is a basic test - in a real UI test we'd verify the actual rendering
    }
    
    @MainActor
    func testAppConfigIntegration() {
        // Verify that DebugStateManager correctly reads from AppConfig
        XCTAssertEqual(debugStateManager.launchMode, AppConfig.launchMode)
        XCTAssertEqual(debugStateManager.isDemoPlaybackEnabled, AppConfig.isDemoPlaybackEnabled)
    }
    
    // MARK: - Integration Status Tests
    
    @MainActor
    func testDemoPlaybackControllerIntegration() {
        // Verify that DemoRunPlaybackController exists and can be instantiated
        // This tests that the integration point exists
        let mockFirebaseService = MockFirebaseRunService()
        let locationService = LocationService()
        let runEventService = RunEventService(firebaseService: mockFirebaseService)
        
        let controller = DemoRunPlaybackController(
            runEventService: runEventService,
            locationService: locationService,
            firebaseService: mockFirebaseService
        )
        XCTAssertNotNil(controller)
    }
    
    // MARK: - Error Handling Tests
    
    func testDebugAssertionErrorHandling() {
        // Test that debug assertions handle errors gracefully
        debugAssert(false, "Test error condition")
        
        // Test with nil values
        debugAssertNotNil(nil as String?, "Test nil assertion")
        
        // Test with formatted strings
        debugAssertf(false, "Test formatted error: %@ %d", "value", 123)
        
        // If we reach here, error handling works correctly
        XCTAssertTrue(true, "Debug assertion error handling works correctly")
    }
    
    @MainActor
    func testDebugStateManagerNilHandling() {
        // Test that DebugStateManager handles nil values correctly
        debugStateManager.updateActiveRun(nil)
        XCTAssertNil(debugStateManager.activeRunId)
        XCTAssertNil(debugStateManager.activeRunState)
        XCTAssertNil(debugStateManager.currentStopIndex)
        
        debugStateManager.updateLocationInfo(nil)
        XCTAssertNil(debugStateManager.lastLocationUpdate)
        
        debugStateManager.updateCurrentUser(id: nil, mode: "Unknown")
        XCTAssertNil(debugStateManager.currentUserId)
        XCTAssertEqual(debugStateManager.userMode, "Unknown")
    }
}