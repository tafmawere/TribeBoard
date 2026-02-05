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
    
    // MARK: - Enhanced Demo Data Tests
    
    func testEnhancedDemoSeedDataGeneration() async throws {
        // Given - Demo family ID
        let demoFamilyId = "demo_family_id"
        
        // When - Get current active run for demo family
        let activeRun = try await mockFirebaseService.getCurrentActiveRun(for: demoFamilyId)
        
        // Then - Should return enhanced demo data that meets requirements
        XCTAssertNotNil(activeRun, "getCurrentActiveRun should return non-nil for demo family (Requirement 4.1)")
        
        guard let run = activeRun else { return }
        
        // Requirement 4.2: Run state should be activeEnroute or arrivedAtStop
        XCTAssertTrue(run.status == .activeEnroute || run.status == .arrivedAtStop, 
                     "Run state should be activeEnroute or arrivedAtStop, got \(run.status)")
        
        // Requirement 4.3: Exactly 2 passengers and 3 stops
        XCTAssertEqual(run.passengers.count, 2, "Run should have exactly 2 passengers")
        XCTAssertEqual(run.stops.count, 3, "Run should have exactly 3 stops")
        
        // Requirement 4.4: currentStopIndex between 0 and stops.count-1
        XCTAssertGreaterThanOrEqual(run.currentStopIndex, 0, "currentStopIndex should be >= 0")
        XCTAssertLessThan(run.currentStopIndex, run.stops.count, "currentStopIndex should be < stops.count")
        
        // Requirement 4.5: driverId should match demo driver user id
        XCTAssertEqual(run.driverId, "demo_driver_user_id", "driverId should match demo driver user id")
        
        // Additional validation: Run should have proper family ID
        XCTAssertEqual(run.familyId, demoFamilyId, "Run should belong to demo family")
        
        // Validate that demo observer user can be created (Requirement 4.6)
        let demoObserver = mockFirebaseService.createDemoObserverUser()
        XCTAssertEqual(demoObserver.id, "demo_observer_user_id", "Demo observer user should have correct ID")
        XCTAssertEqual(demoObserver.role, .observer, "Demo observer should have observer role")
    }
}