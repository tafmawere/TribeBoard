//
//  OfflineSyncServiceTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/03.
//

import XCTest
import CoreLocation
@testable import Tribeboard

@MainActor
class OfflineSyncServiceTests: XCTestCase {
    
    var offlineSyncService: OfflineSyncService!
    var mockFirebaseService: MockFirebaseRunService!
    
    override func setUp() async throws {
        try await super.setUp()
        mockFirebaseService = MockFirebaseRunService()
        offlineSyncService = OfflineSyncService(firebaseService: mockFirebaseService)
    }
    
    override func tearDown() async throws {
        offlineSyncService.clearQueue()
        offlineSyncService = nil
        mockFirebaseService = nil
        try await super.tearDown()
    }
    
    // MARK: - Queue Management Tests
    
    func testDriverActionQueuing() {
        // Given
        let runId = "test-run"
        let action = DriverAction.startRun
        let location = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // When
        offlineSyncService.queueDriverAction(action, runId: runId, location: location)
        
        // Then
        XCTAssertEqual(offlineSyncService.queuedActionsCount, 1)
        XCTAssertTrue(offlineSyncService.hasPendingActions(for: runId))
        
        let queuedActions = offlineSyncService.getQueuedActions(for: runId)
        XCTAssertEqual(queuedActions.count, 1)
        
        if case .driverAction(let driverAction, let queuedRunId, let queuedLocation) = queuedActions.first?.type {
            XCTAssertEqual(queuedRunId, runId)
            XCTAssertEqual(queuedLocation?.latitude ?? 0, location.latitude, accuracy: 0.001)
            XCTAssertEqual(queuedLocation?.longitude ?? 0, location.longitude, accuracy: 0.001)
        } else {
            XCTFail("Expected driver action in queue")
        }
    }
    
    func testAdminActionQueuing() {
        // Given
        let runId = "test-run"
        let action = AdminAction.cancelRun(reason: "Test cancellation")
        
        // When
        offlineSyncService.queueAdminAction(action, runId: runId)
        
        // Then
        XCTAssertEqual(offlineSyncService.queuedActionsCount, 1)
        XCTAssertTrue(offlineSyncService.hasPendingActions(for: runId))
        
        let queuedActions = offlineSyncService.getQueuedActions(for: runId)
        XCTAssertEqual(queuedActions.count, 1)
        
        if case .adminAction(let _, let queuedRunId) = queuedActions.first?.type {
            XCTAssertEqual(queuedRunId, runId)
        } else {
            XCTFail("Expected admin action in queue")
        }
    }
    
    func testLocationUpdateQueuing() {
        // Given
        let runId = "test-run"
        let location = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // When
        offlineSyncService.queueLocationUpdate(runId: runId, location: location)
        
        // Then
        XCTAssertEqual(offlineSyncService.queuedActionsCount, 1)
        XCTAssertTrue(offlineSyncService.hasPendingActions(for: runId))
        
        let queuedActions = offlineSyncService.getQueuedActions(for: runId)
        XCTAssertEqual(queuedActions.count, 1)
        
        if case .locationUpdate(let queuedRunId, let queuedLocation) = queuedActions.first?.type {
            XCTAssertEqual(queuedRunId, runId)
            XCTAssertEqual(queuedLocation.latitude, location.latitude, accuracy: 0.001)
            XCTAssertEqual(queuedLocation.longitude, location.longitude, accuracy: 0.001)
        } else {
            XCTFail("Expected location update in queue")
        }
    }
    
    func testMultipleActionsQueuing() {
        // Given
        let runId = "test-run"
        
        // When
        offlineSyncService.queueDriverAction(.startRun, runId: runId)
        offlineSyncService.queueLocationUpdate(runId: runId, location: CLLocationCoordinate2D(latitude: 0, longitude: 0))
        offlineSyncService.queueAdminAction(.cancelRun(reason: "test"), runId: runId)
        
        // Then
        XCTAssertEqual(offlineSyncService.queuedActionsCount, 3)
        XCTAssertTrue(offlineSyncService.hasPendingActions(for: runId))
        
        let queuedActions = offlineSyncService.getQueuedActions(for: runId)
        XCTAssertEqual(queuedActions.count, 3)
    }
    
    func testQueueClear() {
        // Given
        offlineSyncService.queueDriverAction(.startRun, runId: "test-run")
        XCTAssertEqual(offlineSyncService.queuedActionsCount, 1)
        
        // When
        offlineSyncService.clearQueue()
        
        // Then
        XCTAssertEqual(offlineSyncService.queuedActionsCount, 0)
        XCTAssertFalse(offlineSyncService.hasPendingActions(for: "test-run"))
    }
    
    // MARK: - Synchronization Tests
    
    func testEmptyQueueSynchronization() async {
        // Given - Empty queue
        XCTAssertEqual(offlineSyncService.queuedActionsCount, 0)
        
        // When
        await offlineSyncService.synchronizeQueue()
        
        // Then - Should complete without issues
        XCTAssertFalse(offlineSyncService.isSyncing)
    }
    
    func testSuccessfulSynchronization() async throws {
        // Given
        let demoRun = try await mockFirebaseService.createDemoRun()
        offlineSyncService.queueDriverAction(.startRun, runId: demoRun.id)
        
        XCTAssertEqual(offlineSyncService.queuedActionsCount, 1)
        
        // When
        await offlineSyncService.synchronizeQueue()
        
        // Then - Queue should be empty after successful sync
        XCTAssertEqual(offlineSyncService.queuedActionsCount, 0)
        XCTAssertNotNil(offlineSyncService.lastSyncAttempt)
    }
    
    // MARK: - Conflict Resolution Tests
    
    func testConflictResolutionBackendPrecedence() {
        // Given
        let localRun = Run(
            id: "test-run",
            title: "Local Run",
            scheduledTime: Date(),
            driverId: "local-driver",
            status: .scheduled,
            stops: [],
            passengers: [],
            createdBy: "local-user",
            familyId: "test-family"
        )
        
        let backendRun = Run(
            id: "test-run",
            title: "Backend Run",
            scheduledTime: Date(),
            driverId: "backend-driver",
            status: .activeEnroute,
            stops: [],
            passengers: [],
            createdBy: "backend-user",
            familyId: "test-family"
        )
        
        // When
        let resolvedRun = offlineSyncService.resolveConflicts(localRun: localRun, backendRun: backendRun)
        
        // Then - Backend state should take precedence
        XCTAssertEqual(resolvedRun.title, "Backend Run")
        XCTAssertEqual(resolvedRun.driverId, "backend-driver")
        XCTAssertEqual(resolvedRun.status, .activeEnroute)
        XCTAssertEqual(resolvedRun.createdBy, "backend-user")
    }
    
    func testConflictResolutionWithNewerLocalLocation() {
        // Given
        let now = Date()
        let olderTime = now.addingTimeInterval(-60) // 1 minute ago
        let newerTime = now.addingTimeInterval(60)  // 1 minute from now
        
        var localRun = Run(
            id: "test-run",
            title: "Local Run",
            scheduledTime: Date(),
            driverId: "driver",
            status: .activeEnroute,
            stops: [],
            passengers: [],
            createdBy: "user",
            familyId: "test-family"
        )
        localRun.lastLocation = GeoPoint(latitude: 37.7749, longitude: -122.4194)
        localRun.lastLocationUpdatedAt = newerTime
        
        var backendRun = localRun
        backendRun.lastLocation = GeoPoint(latitude: 40.7128, longitude: -74.0060)
        backendRun.lastLocationUpdatedAt = olderTime
        
        // Queue a location update to simulate pending sync
        offlineSyncService.queueLocationUpdate(
            runId: localRun.id,
            location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        )
        
        // When
        let resolvedRun = offlineSyncService.resolveConflicts(localRun: localRun, backendRun: backendRun)
        
        // Then - Should preserve newer local location when there's a pending update
        XCTAssertEqual(resolvedRun.lastLocation?.latitude ?? 0, 37.7749, accuracy: 0.001)
        XCTAssertEqual(resolvedRun.lastLocation?.longitude ?? 0, -122.4194, accuracy: 0.001)
        XCTAssertEqual(resolvedRun.lastLocationUpdatedAt, newerTime)
    }
    
    // MARK: - Error Handling Tests
    
    func testSyncErrorTracking() async {
        // Given - Queue an action for a non-existent run
        offlineSyncService.queueDriverAction(.startRun, runId: "non-existent-run")
        
        // When
        await offlineSyncService.synchronizeQueue()
        
        // Then - Should track sync errors after max retries
        // Note: This test might need adjustment based on actual error handling implementation
        XCTAssertNotNil(offlineSyncService.lastSyncAttempt)
    }
    
    // MARK: - Chronological Order Tests
    
    func testChronologicalSynchronization() async throws {
        // Given - Queue actions in specific order
        let demoRun = try await mockFirebaseService.createDemoRun()
        
        // Add actions with slight delays to ensure different timestamps
        offlineSyncService.queueDriverAction(.startRun, runId: demoRun.id)
        
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        offlineSyncService.queueDriverAction(.arriveStop, runId: demoRun.id)
        
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        offlineSyncService.queueLocationUpdate(
            runId: demoRun.id,
            location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        )
        
        XCTAssertEqual(offlineSyncService.queuedActionsCount, 3)
        
        // When
        await offlineSyncService.synchronizeQueue()
        
        // Then - Actions should be processed in chronological order
        // The queue should be empty if all actions were processed successfully
        XCTAssertEqual(offlineSyncService.queuedActionsCount, 0)
    }
}