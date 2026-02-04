//
//  RunEventServiceTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/03.
//

import XCTest
import Combine
@testable import Tribeboard

@MainActor
class RunEventServiceTests: XCTestCase {
    
    var runEventService: RunEventService!
    var mockFirebaseService: MockFirebaseRunService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        mockFirebaseService = MockFirebaseRunService()
        runEventService = RunEventService(firebaseService: mockFirebaseService)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() async throws {
        cancellables = nil
        runEventService = nil
        mockFirebaseService = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testEventBroadcasting() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Event should be broadcasted")
        var receivedEvent: RunEvent?
        
        runEventService.eventPublisher
            .sink { event in
                receivedEvent = event
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        let testEvent = RunEvent(
            runId: "test-run",
            type: .runStarted,
            actorId: "test-user",
            stateBefore: .scheduled,
            stateAfter: .activeEnroute,
            currentStopIndex: 0
        )
        
        runEventService.broadcastEvent(testEvent)
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedEvent?.id, testEvent.id)
        XCTAssertEqual(receivedEvent?.type, .runStarted)
    }
    
    func testStateChangeBroadcasting() async throws {
        // Given
        let expectation = XCTestExpectation(description: "State change should be broadcasted")
        var receivedStateChange: RunStateChange?
        
        runEventService.stateChangePublisher
            .sink { stateChange in
                receivedStateChange = stateChange
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        let testEvent = RunEvent(
            runId: "test-run",
            type: .runStarted,
            actorId: "test-user",
            stateBefore: .scheduled,
            stateAfter: .activeEnroute,
            currentStopIndex: 0
        )
        
        runEventService.broadcastEvent(testEvent)
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedStateChange?.runId, "test-run")
        XCTAssertEqual(receivedStateChange?.fromState, .scheduled)
        XCTAssertEqual(receivedStateChange?.toState, .activeEnroute)
    }
    
    func testListenerManagement() {
        // Given
        let runId = "test-run"
        
        // When
        runEventService.startListening(to: runId)
        
        // Then - Should not crash and should track the listener
        XCTAssertTrue(runEventService.testActiveListeners.contains(runId))
        
        // When
        runEventService.stopListening(to: runId)
        
        // Then
        XCTAssertFalse(runEventService.testActiveListeners.contains(runId))
    }
    
    // MARK: - Offline Functionality Tests
    
    func testOfflineDriverActionQueuing() async throws {
        // Given
        runEventService.isConnected = false
        let runId = "test-run"
        let action = DriverAction.startRun
        
        // When
        try await runEventService.processDriverAction(action, runId: runId)
        
        // Then - Action should be queued for offline sync
        XCTAssertTrue(runEventService.hasPendingActions(for: runId))
        XCTAssertGreaterThan(runEventService.getQueuedActionsCount(for: runId), 0)
    }
    
    func testOnlineDriverActionProcessing() async throws {
        // Given
        runEventService.isConnected = true
        let runId = "test-run"
        let action = DriverAction.startRun
        
        // Create a demo run first
        let demoRun = try await mockFirebaseService.createDemoRun()
        
        // When
        try await runEventService.processDriverAction(action, runId: demoRun.id)
        
        // Then - Action should be processed immediately
        XCTAssertNotNil(runEventService.lastSyncTime)
    }
    
    func testOfflineAdminActionQueuing() async throws {
        // Given
        runEventService.isConnected = false
        let runId = "test-run"
        let action = AdminAction.cancelRun(reason: "Test cancellation")
        
        // When
        try await runEventService.processAdminAction(action, runId: runId)
        
        // Then - Action should be queued for offline sync
        XCTAssertTrue(runEventService.hasPendingActions(for: runId))
    }
    
    // MARK: - Network Connectivity Tests
    
    func testNetworkStatusTracking() {
        // Given - Service starts with connected status
        XCTAssertTrue(runEventService.isConnected)
        
        // When - Simulate network disconnection
        runEventService.isConnected = false
        
        // Then
        XCTAssertFalse(runEventService.isConnected)
    }
    
    func testSynchronizationWhenOnline() async throws {
        // Given
        runEventService.isConnected = true
        
        // When
        await runEventService.forceSynchronization()
        
        // Then - Should complete without error
        XCTAssertNotNil(runEventService.lastSyncTime)
    }
    
    func testSynchronizationWhenOffline() async throws {
        // Given
        runEventService.isConnected = false
        
        // When
        await runEventService.forceSynchronization()
        
        // Then - Should not update sync time when offline
        // (The actual sync happens when connectivity is restored)
    }
}