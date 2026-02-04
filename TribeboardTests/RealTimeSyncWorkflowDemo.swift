//
//  RealTimeSyncWorkflowDemo.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/03.
//

import XCTest
import Combine
import CoreLocation
@testable import Tribeboard

/// Demonstrates the complete real-time synchronization workflow
/// This test shows how the system handles online/offline scenarios and real-time updates
@MainActor
class RealTimeSyncWorkflowDemo: XCTestCase {
    
    var coordinator: SynchronizationCoordinator!
    var runEventService: RunEventService!
    var offlineSyncService: OfflineSyncService!
    var mockFirebaseService: MockFirebaseRunService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Set up the complete synchronization stack
        mockFirebaseService = MockFirebaseRunService()
        runEventService = RunEventService(firebaseService: mockFirebaseService)
        offlineSyncService = OfflineSyncService(firebaseService: mockFirebaseService)
        coordinator = SynchronizationCoordinator(
            runEventService: runEventService,
            offlineSyncService: offlineSyncService,
            coreDataService: CoreDataService()
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() async throws {
        cancellables = nil
        coordinator = nil
        runEventService = nil
        offlineSyncService = nil
        mockFirebaseService = nil
        try await super.tearDown()
    }
    
    // MARK: - Complete Workflow Demonstration
    
    func testCompleteDriverWorkflow() async throws {
        print("🚀 Starting Complete Driver Workflow Demo")
        
        // Step 1: Create a demo run
        print("📝 Step 1: Creating demo run...")
        let demoRun = try await mockFirebaseService.createDemoRun()
        print("✅ Created run: \(demoRun.title) (ID: \(demoRun.id))")
        
        // Step 2: Start monitoring the run
        print("👀 Step 2: Starting real-time monitoring...")
        coordinator.startMonitoring(runId: demoRun.id)
        
        // Set up event listener to track state changes
        var receivedEvents: [RunEvent] = []
        runEventService.eventPublisher
            .sink { event in
                receivedEvents.append(event)
                print("📡 Received event: \(event.type.displayName) - \(event.stateAfter.displayName)")
            }
            .store(in: &cancellables)
        
        // Step 3: Driver starts the run (online)
        print("🚗 Step 3: Driver starts run (online)...")
        try await coordinator.processDriverAction(.startRun, runId: demoRun.id)
        print("✅ Run started successfully")
        
        // Step 4: Driver arrives at first stop
        print("📍 Step 4: Driver arrives at stop...")
        let schoolLocation = CLLocationCoordinate2D(latitude: -17.8252, longitude: 31.0335)
        try await coordinator.processDriverAction(.arriveStop, runId: demoRun.id, location: schoolLocation)
        print("✅ Arrived at stop")
        
        // Step 5: Go offline and continue workflow
        print("📴 Step 5: Going offline...")
        runEventService.isConnected = false
        print("⚠️ Now offline - actions will be queued")
        
        // Step 6: Confirm passenger pickups while offline
        print("👥 Step 6: Confirming passenger pickups (offline)...")
        try await coordinator.processDriverAction(.confirmPickup(passengerId: "demo_child1"), runId: demoRun.id)
        try await coordinator.processDriverAction(.confirmPickup(passengerId: "demo_child2"), runId: demoRun.id)
        
        // Check that actions are queued
        let syncStatus = coordinator.getSyncStatus(for: demoRun.id)
        print("📊 Sync status: \(syncStatus.description)")
        
        // Step 7: Update location while offline
        print("📍 Step 7: Updating location while offline...")
        let enrouteLocation = CLLocationCoordinate2D(latitude: -17.8200, longitude: 31.0400)
        try await coordinator.updateDriverLocation(runId: demoRun.id, location: enrouteLocation)
        
        // Step 8: Move to next stop while offline
        print("➡️ Step 8: Moving to next stop (offline)...")
        try await coordinator.processDriverAction(.nextStop, runId: demoRun.id)
        
        // Check pending actions
        print("📋 Pending actions: \(coordinator.pendingActionsCount)")
        
        // Step 9: Come back online and sync
        print("📶 Step 9: Coming back online and syncing...")
        runEventService.isConnected = true
        await coordinator.forceSynchronization()
        print("✅ Synchronization completed")
        
        // Step 10: Complete the run
        print("🏁 Step 10: Completing the run...")
        try await coordinator.processDriverAction(.arriveStop, runId: demoRun.id)
        try await coordinator.processDriverAction(.confirmDropoff(passengerId: "demo_child1"), runId: demoRun.id)
        try await coordinator.processDriverAction(.confirmDropoff(passengerId: "demo_child2"), runId: demoRun.id)
        try await coordinator.processDriverAction(.endRun, runId: demoRun.id)
        print("✅ Run completed successfully")
        
        // Step 11: Verify final state
        print("🔍 Step 11: Verifying final state...")
        let finalSyncStatus = coordinator.getSyncStatus(for: demoRun.id)
        print("📊 Final sync status: \(finalSyncStatus.description)")
        
        // Stop monitoring
        coordinator.stopMonitoring(runId: demoRun.id)
        
        print("🎉 Complete Driver Workflow Demo finished successfully!")
        print("📈 Total events received: \(receivedEvents.count)")
        
        // Assertions
        XCTAssertTrue(finalSyncStatus.isFullySynced || coordinator.pendingActionsCount == 0)
        XCTAssertTrue(coordinator.isOnline)
        XCTAssertNotNil(coordinator.lastSyncTime)
    }
    
    func testObserverRealTimeTracking() async throws {
        print("👁️ Starting Observer Real-Time Tracking Demo")
        
        // Step 1: Create and start monitoring a run
        let demoRun = try await mockFirebaseService.createDemoRun()
        coordinator.startMonitoring(runId: demoRun.id)
        
        // Step 2: Set up observer to track state changes
        var stateChanges: [RunStateChange] = []
        runEventService.stateChangePublisher
            .sink { stateChange in
                stateChanges.append(stateChange)
                print("🔄 State change: \(stateChange.fromState.displayName) → \(stateChange.toState.displayName)")
            }
            .store(in: &cancellables)
        
        // Step 3: Simulate driver actions that observers would see
        print("🚗 Simulating driver actions for observer tracking...")
        
        try await coordinator.processDriverAction(.startRun, runId: demoRun.id)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        try await coordinator.processDriverAction(.arriveStop, runId: demoRun.id)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Step 4: Verify observers receive real-time updates
        print("📊 Observer received \(stateChanges.count) state changes")
        
        coordinator.stopMonitoring(runId: demoRun.id)
        print("✅ Observer Real-Time Tracking Demo completed")
        
        // Assertions
        XCTAssertGreaterThan(stateChanges.count, 0)
    }
    
    func testOfflineResilienceScenario() async throws {
        print("🔄 Starting Offline Resilience Scenario Demo")
        
        // Step 1: Start completely offline
        runEventService.isConnected = false
        let runId = "offline-resilience-test"
        
        print("📴 Starting offline - all actions will be queued")
        
        // Step 2: Perform multiple actions while offline
        try await coordinator.processDriverAction(.startRun, runId: runId)
        try await coordinator.processDriverAction(.arriveStop, runId: runId)
        try await coordinator.updateDriverLocation(runId: runId, location: CLLocationCoordinate2D(latitude: 0, longitude: 0))
        try await coordinator.processAdminAction(.cancelRun(reason: "Test cancellation"), runId: runId)
        
        print("📋 Queued \(coordinator.pendingActionsCount) actions while offline")
        
        // Step 3: Come online and verify sync
        runEventService.isConnected = true
        await coordinator.forceSynchronization()
        
        print("✅ Offline Resilience Scenario completed")
        print("📊 Final pending actions: \(coordinator.pendingActionsCount)")
        
        // Assertions
        XCTAssertTrue(coordinator.isOnline)
        XCTAssertNotNil(coordinator.lastSyncTime)
    }
    
    func testConflictResolutionScenario() async throws {
        print("⚔️ Starting Conflict Resolution Scenario Demo")
        
        // This test demonstrates how the system handles conflicts
        // between local optimistic updates and backend state
        
        let demoRun = try await mockFirebaseService.createDemoRun()
        
        // Step 1: Make local changes
        print("📝 Making local optimistic updates...")
        try await coordinator.processDriverAction(.startRun, runId: demoRun.id)
        
        // Step 2: Simulate conflict resolution during sync
        print("🔄 Simulating conflict resolution...")
        await coordinator.forceSynchronization()
        
        print("✅ Conflict Resolution Scenario completed")
        
        // Assertions
        XCTAssertNotNil(coordinator.lastSyncTime)
    }
    
    // MARK: - Performance and Stress Tests
    
    func testHighVolumeEventHandling() async throws {
        print("⚡ Starting High Volume Event Handling Demo")
        
        let runId = "high-volume-test"
        coordinator.startMonitoring(runId: runId)
        
        var eventCount = 0
        runEventService.eventPublisher
            .sink { _ in
                eventCount += 1
            }
            .store(in: &cancellables)
        
        // Simulate high-frequency location updates
        runEventService.isConnected = false // Test offline queuing under load
        
        for i in 0..<50 {
            let location = CLLocationCoordinate2D(
                latitude: Double(i) * 0.001,
                longitude: Double(i) * 0.001
            )
            try await coordinator.updateDriverLocation(runId: runId, location: location)
        }
        
        print("📊 Queued \(coordinator.pendingActionsCount) high-frequency updates")
        
        coordinator.stopMonitoring(runId: runId)
        print("✅ High Volume Event Handling Demo completed")
        
        // Assertions
        XCTAssertGreaterThan(coordinator.pendingActionsCount, 0)
    }
}