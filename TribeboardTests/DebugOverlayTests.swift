//
//  DebugOverlayTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/04.
//

import XCTest
import SwiftUI
@testable import Tribeboard

final class DebugOverlayTests: XCTestCase {
    
    var debugStateManager: DebugStateManager!
    
    override func setUp() {
        super.setUp()
        debugStateManager = DebugStateManager.shared
    }
    
    override func tearDown() {
        super.tearDown()
        debugStateManager = nil
    }
    
    // MARK: - DebugStateManager Tests
    
    @MainActor
    func testDebugStateManagerInitialization() {
        // Test that DebugStateManager initializes with expected default values
        XCTAssertEqual(debugStateManager.launchMode, AppConfig.launchMode)
        XCTAssertEqual(debugStateManager.isDemoPlaybackEnabled, AppConfig.isDemoPlaybackEnabled)
        XCTAssertNil(debugStateManager.currentUserId)
        XCTAssertEqual(debugStateManager.userMode, "Unknown")
        XCTAssertNil(debugStateManager.activeRunId)
        XCTAssertNil(debugStateManager.activeRunState)
        XCTAssertNil(debugStateManager.currentStopIndex)
        XCTAssertNil(debugStateManager.lastLocationUpdate)
        XCTAssertFalse(debugStateManager.isPlaybackRunning)
        XCTAssertNil(debugStateManager.lastPlaybackTick)
        XCTAssertEqual(debugStateManager.playbackTickCount, 0)
    }
    
    @MainActor
    func testUpdatePlaybackTick() {
        // Test that updatePlaybackTick updates the tick count and timestamp
        let initialTickCount = debugStateManager.playbackTickCount
        let initialLastTick = debugStateManager.lastPlaybackTick
        
        debugStateManager.updatePlaybackTick()
        
        XCTAssertEqual(debugStateManager.playbackTickCount, initialTickCount + 1)
        XCTAssertNotNil(debugStateManager.lastPlaybackTick)
        XCTAssertNotEqual(debugStateManager.lastPlaybackTick, initialLastTick)
    }
    
    @MainActor
    func testUpdateActiveRun() {
        // Test updating active run information
        let testRun = Run(
            title: "Test Run",
            scheduledTime: Date(),
            driverId: "test-driver",
            status: .activeEnroute,
            stops: [],
            passengers: [],
            createdBy: "test-user",
            familyId: "test-family"
        )
        
        debugStateManager.updateActiveRun(testRun)
        
        XCTAssertEqual(debugStateManager.activeRunId, testRun.id)
        XCTAssertEqual(debugStateManager.activeRunState, testRun.status)
        XCTAssertEqual(debugStateManager.currentStopIndex, testRun.currentStopIndex)
    }
    
    @MainActor
    func testUpdateActiveRunWithNil() {
        // Test updating with nil run
        debugStateManager.updateActiveRun(nil)
        
        XCTAssertNil(debugStateManager.activeRunId)
        XCTAssertNil(debugStateManager.activeRunState)
        XCTAssertNil(debugStateManager.currentStopIndex)
    }
    
    @MainActor
    func testUpdateLocationInfo() {
        // Test updating location information
        let testDate = Date()
        
        debugStateManager.updateLocationInfo(testDate)
        
        XCTAssertEqual(debugStateManager.lastLocationUpdate, testDate)
    }
    
    @MainActor
    func testUpdatePlaybackStatus() {
        // Test updating playback status
        debugStateManager.updatePlaybackStatus(true)
        XCTAssertTrue(debugStateManager.isPlaybackRunning)
        
        debugStateManager.updatePlaybackStatus(false)
        XCTAssertFalse(debugStateManager.isPlaybackRunning)
    }
    
    @MainActor
    func testUpdateCurrentUser() {
        // Test updating current user information
        let testUserId = "test-user-123"
        let testMode = "Driver"
        
        debugStateManager.updateCurrentUser(id: testUserId, mode: testMode)
        
        XCTAssertEqual(debugStateManager.currentUserId, testUserId)
        XCTAssertEqual(debugStateManager.userMode, testMode)
    }
    
    // MARK: - Debug User Mode Tests
    
    func testDebugUserModeToggle() {
        #if DEBUG
        // Test that debug user mode can be toggled
        AppConfig.demoCurrentUserMode = .driver
        let driverUser = AppConfig.currentDemoUser
        XCTAssertEqual(driverUser.role, .driver)
        XCTAssertEqual(driverUser.id, "demo_driver_user_id")
        
        AppConfig.demoCurrentUserMode = .observer
        let observerUser = AppConfig.currentDemoUser
        XCTAssertEqual(observerUser.role, .observer)
        XCTAssertEqual(observerUser.id, "demo_observer_user_id")
        
        // Reset to driver for other tests
        AppConfig.demoCurrentUserMode = .driver
        #endif
    }
    
    func testCurrentDemoUserConsistency() {
        // Test that currentDemoUser returns consistent user data
        let user1 = AppConfig.currentDemoUser
        let user2 = AppConfig.currentDemoUser
        
        XCTAssertEqual(user1.id, user2.id)
        XCTAssertEqual(user1.role, user2.role)
        XCTAssertEqual(user1.familyId, user2.familyId)
        XCTAssertEqual(user1.displayName, user2.displayName)
    }
    
    // MARK: - Debug Assertions Tests
    
    func testDebugAssertWithTrueCondition() {
        // Test that debug assert doesn't log when condition is true
        debugAssert(true, "This should not log")
        
        // Since condition is true, no assertion should be logged
        // This is a basic test - in a real scenario we'd need to capture log output
    }
    
    func testDebugAssertWithFalseCondition() {
        // Test that debug assert logs when condition is false
        debugAssert(false, "Test assertion failure")
        
        // In a real scenario, we'd verify the log output
        // For now, we just ensure it doesn't crash
    }
    
    // MARK: - LaunchMode Extension Tests
    
    func testLaunchModeDisplayNames() {
        XCTAssertEqual(LaunchMode.activeRunOnly.displayName, "ActiveOnly")
        XCTAssertEqual(LaunchMode.fullApp.displayName, "FullApp")
    }
    
    // MARK: - RunStatus Extension Tests
    
    func testRunStatusDisplayNames() {
        XCTAssertEqual(RunStatus.scheduled.displayName, "Scheduled")
        XCTAssertEqual(RunStatus.activeEnroute.displayName, "En Route")
        XCTAssertEqual(RunStatus.arrivedAtStop.displayName, "Arrived at Stop")
        XCTAssertEqual(RunStatus.paused.displayName, "Paused")
        XCTAssertEqual(RunStatus.completed.displayName, "Completed")
        XCTAssertEqual(RunStatus.cancelled.displayName, "Cancelled")
    }
}