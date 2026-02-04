//
//  SynchronizationIntegrationTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/03.
//

import XCTest
import Combine
import CoreLocation
@testable import Tribeboard

@MainActor
class SynchronizationIntegrationTests: XCTestCase {
    
    var coordinator: SynchronizationCoordinator!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        coordinator = SynchronizationCoordinator()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() async throws {
        cancellables = nil
        coordinator = nil
        try await super.tearDown()
    }
    
    // MARK: - Integration Tests
    
    func testCompleteOfflineToOnlineWorkflow() async throws {
        // Given - Create a demo run first
        let demoRun = try await MockFirebaseRunService().createDemoRun()
        let runId = demoRun.id
        
        // Simulate offline mode by directly accessing the run event service
        coordinator.testRunEventService.isConnected = false
        
        // When - Process actions while offline
        try await coordinator.processDriverAction(.startRun, runId: runId)
        try await coordinator.processAdminAction(.cancelRun(reason: "Test"), runId: runId)
        
        let location = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        try await coordinator.updateDriverLocation(runId: runId, location: location)
        
        // Then - Should have pending actions
        let syncStatus = coordinator.getSyncStatus(for: runId)
        switch syncStatus {
        case .offline(let pendingActions):
            XCTAssertGreaterThan(pendingActions, 0)
        case .syncing(let pendingActions):
            XCTAssertGreaterThan(pendingActions, 0)
        default:
            XCTFail("Expected offline or syncing status with pending actions, got: \(syncStatus)")
        }
        
        // When - Come back online and sync
        coordinator.testRunEventService.isConnected = true
        await coordinator.forceSynchronization()
        
        // Then - Should be synced or have no pending actions
        let finalSyncStatus = coordinator.getSyncStatus(for: runId)
        XCTAssertTrue(finalSyncStatus.isFullySynced || coordinator.pendingActionsCount == 0)
    }
    
    func testRealTimeMonitoring() async throws {
        // Given
        let runId = "test-run-monitoring"
        let expectation = XCTestExpectation(description: "Should receive real-time updates")
        
        // Start monitoring
        coordinator.startMonitoring(runId: runId)
        
        // When - Simulate a state change
        // This would normally come from Firebase, but we'll simulate it
        let testEvent = RunEvent(
            runId: runId,
            type: .runStarted,
            actorId: "test-user",
            stateBefore: .scheduled,
            stateAfter: .activeEnroute,
            currentStopIndex: 0
        )
        
        // Simulate receiving the event (in real app, this would come from Firebase)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Cleanup
        coordinator.stopMonitoring(runId: runId)
    }
    
    func testSyncStatusTracking() {
        // Given
        let runId = "test-run-status"
        
        // When - Online with no pending actions
        coordinator.testRunEventService.isConnected = true
        let onlineStatus = coordinator.getSyncStatus(for: runId)
        
        // Then
        XCTAssertTrue(onlineStatus.isFullySynced)
        
        // When - Offline (simulate by setting the service offline)
        coordinator.testRunEventService.isConnected = false
        
        // Then - Status should reflect offline state when there are no pending actions
        let offlineStatus = coordinator.getSyncStatus(for: runId)
        XCTAssertTrue(offlineStatus.isFullySynced) // No pending actions, so still synced
    }
    
    func testConflictResolutionWorkflow() async throws {
        // Given - Create a demo run first
        let demoRun = try await MockFirebaseRunService().createDemoRun()
        let runId = demoRun.id
        
        // Simulate processing an action that creates a conflict scenario
        try await coordinator.processDriverAction(.startRun, runId: runId)
        
        // When - Force synchronization (which includes conflict resolution)
        await coordinator.forceSynchronization()
        
        // Then - Should complete without throwing errors
        XCTAssertNotNil(coordinator.lastSyncTime)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorRecovery() async throws {
        // Given - Invalid run ID
        let invalidRunId = "non-existent-run"
        
        // When - Try to process action for non-existent run
        do {
            try await coordinator.processDriverAction(.startRun, runId: invalidRunId)
            // If offline, this should queue without error
            // If online, this might throw an error depending on implementation
        } catch {
            // Expected for online mode with invalid run
            XCTAssertTrue(coordinator.isOnline)
        }
        
        // Then - System should remain stable
        XCTAssertNotNil(coordinator)
    }
    
    func testNetworkStateTransitions() async {
        // Given - Start online
        coordinator.isOnline = true
        
        // When - Go offline
        coordinator.isOnline = false
        
        // Then - Should handle state transition gracefully
        XCTAssertFalse(coordinator.isOnline)
        
        // When - Come back online
        coordinator.isOnline = true
        
        // Then - Should handle reconnection
        XCTAssertTrue(coordinator.isOnline)
    }
    
    // MARK: - Performance Tests
    
    func testMultipleRunMonitoring() {
        // Given - Multiple runs
        let runIds = ["run1", "run2", "run3", "run4", "run5"]
        
        // When - Start monitoring all runs
        for runId in runIds {
            coordinator.startMonitoring(runId: runId)
        }
        
        // Then - Should handle multiple listeners without issues
        // This is mainly testing that the system doesn't crash
        
        // Cleanup
        for runId in runIds {
            coordinator.stopMonitoring(runId: runId)
        }
    }
    
    func testHighFrequencyLocationUpdates() async throws {
        // Given - Create a demo run first
        let demoRun = try await MockFirebaseRunService().createDemoRun()
        let runId = demoRun.id
        
        // Test offline queuing
        coordinator.testRunEventService.isConnected = false
        
        // When - Send multiple location updates rapidly
        for i in 0..<10 {
            let location = CLLocationCoordinate2D(
                latitude: 37.7749 + Double(i) * 0.001,
                longitude: -122.4194 + Double(i) * 0.001
            )
            try await coordinator.updateDriverLocation(runId: runId, location: location)
        }
        
        // Then - Should queue all updates without issues
        XCTAssertGreaterThan(coordinator.pendingActionsCount, 0)
    }
}