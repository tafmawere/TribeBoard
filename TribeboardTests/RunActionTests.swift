//
//  RunActionTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/03.
//

import XCTest
@testable import Tribeboard

final class RunActionTests: XCTestCase {
    
    var sampleRun: Run!
    
    override func setUp() {
        super.setUp()
        
        // Create a sample run for testing
        sampleRun = Run(
            title: "Test Run",
            scheduledTime: Date(),
            driverId: "driver1",
            status: .scheduled,
            stops: [
                RunStop(
                    type: .pickup,
                    label: "School",
                    scheduledTime: Date().addingTimeInterval(300),
                    requiredPassengerIds: ["passenger1"],
                    location: LocationData(latitude: -17.8252, longitude: 31.0335)
                ),
                RunStop(
                    type: .dropoff,
                    label: "Home",
                    scheduledTime: Date().addingTimeInterval(600),
                    requiredPassengerIds: ["passenger1"],
                    location: LocationData(latitude: -17.8145, longitude: 31.0493)
                )
            ],
            passengers: [
                MemberSummary(id: "passenger1", displayName: "Test Child", role: .passenger)
            ],
            createdBy: "parent1",
            familyId: "family1"
        )
    }
    
    // MARK: - Driver Action Tests
    
    func testStartRunAction() {
        // Test valid start run transition
        let result = RunStateMachine.processDriverAction(.startRun, for: &sampleRun)
        
        switch result {
        case .success(let eventType):
            XCTAssertEqual(eventType, .runStarted)
            XCTAssertEqual(sampleRun.status, .activeEnroute)
            XCTAssertNotNil(sampleRun.startTime)
        case .failure:
            XCTFail("Start run should succeed from scheduled state")
        }
    }
    
    func testArriveStopAction() {
        // First start the run
        _ = RunStateMachine.processDriverAction(.startRun, for: &sampleRun)
        
        // Then test arrive at stop
        let result = RunStateMachine.processDriverAction(.arriveStop, for: &sampleRun)
        
        switch result {
        case .success(let eventType):
            XCTAssertEqual(eventType, .runArrivedStop)
            XCTAssertEqual(sampleRun.status, .arrivedAtStop)
        case .failure:
            XCTFail("Arrive stop should succeed from active enroute state")
        }
    }
    
    func testConfirmPickupAction() {
        // Setup: start run and arrive at stop
        _ = RunStateMachine.processDriverAction(.startRun, for: &sampleRun)
        _ = RunStateMachine.processDriverAction(.arriveStop, for: &sampleRun)
        
        // Test confirm pickup
        let result = RunStateMachine.processDriverAction(.confirmPickup(passengerId: "passenger1"), for: &sampleRun)
        
        switch result {
        case .success(let eventType):
            XCTAssertEqual(eventType, .passengerPickedUp)
            XCTAssertEqual(sampleRun.passengers[0].status, .onboard)
        case .failure:
            XCTFail("Confirm pickup should succeed when arrived at stop")
        }
    }
    
    func testInvalidTransition() {
        // Test invalid transition: arrive stop from scheduled state
        let result = RunStateMachine.processDriverAction(.arriveStop, for: &sampleRun)
        
        switch result {
        case .success:
            XCTFail("Should not allow arrive stop from scheduled state")
        case .failure(let error):
            XCTAssertTrue(error.localizedDescription.contains("Invalid transition"))
        }
    }
    
    // MARK: - Admin Action Tests
    
    func testCancelRunAction() {
        let result = RunStateMachine.processAdminAction(.cancelRun(reason: "Test cancellation"), for: &sampleRun)
        
        switch result {
        case .success(let eventType):
            XCTAssertEqual(eventType, .runCancelled)
            XCTAssertEqual(sampleRun.status, .cancelled)
            XCTAssertEqual(sampleRun.delayReason, "Test cancellation")
        case .failure:
            XCTFail("Cancel run should succeed from scheduled state")
        }
    }
    
    func testReassignDriverAction() {
        let result = RunStateMachine.processAdminAction(.reassignDriver(newDriverId: "driver2"), for: &sampleRun)
        
        switch result {
        case .success(let eventType):
            XCTAssertEqual(eventType, .driverReassigned)
            XCTAssertEqual(sampleRun.driverId, "driver2")
            XCTAssertEqual(sampleRun.status, .scheduled) // Should remain scheduled
        case .failure:
            XCTFail("Reassign driver should succeed from scheduled state")
        }
    }
    
    // MARK: - Action Availability Tests
    
    func testGetAvailableActionsForDriver() {
        let actions = RunStateMachine.getAvailableActions(for: sampleRun, userRole: .driver)
        
        // Should only have startRun action when scheduled
        XCTAssertEqual(actions.count, 1)
        if case .startRun = actions.first {
            // Expected
        } else {
            XCTFail("Expected startRun action for scheduled run")
        }
    }
    
    func testGetAvailableActionsForNonDriver() {
        let actions = RunStateMachine.getAvailableActions(for: sampleRun, userRole: .observer)
        
        // Non-drivers should have no actions
        XCTAssertTrue(actions.isEmpty)
    }
    
    // MARK: - State Transition Validation Tests
    
    func testCanTransitionDriverActions() {
        // Valid transitions
        XCTAssertTrue(RunStateMachine.canTransition(from: .scheduled, to: .activeEnroute, with: .startRun))
        XCTAssertTrue(RunStateMachine.canTransition(from: .activeEnroute, to: .arrivedAtStop, with: .arriveStop))
        XCTAssertTrue(RunStateMachine.canTransition(from: .arrivedAtStop, to: .activeEnroute, with: .nextStop))
        
        // Invalid transitions
        XCTAssertFalse(RunStateMachine.canTransition(from: .scheduled, to: .arrivedAtStop, with: .arriveStop))
        XCTAssertFalse(RunStateMachine.canTransition(from: .completed, to: .activeEnroute, with: .startRun))
    }
    
    func testCanTransitionAdminActions() {
        // Valid admin transitions
        XCTAssertTrue(RunStateMachine.canTransition(from: .scheduled, to: .cancelled, with: .cancelRun(reason: "Test")))
        XCTAssertTrue(RunStateMachine.canTransition(from: .activeEnroute, to: .cancelled, with: .cancelRun(reason: "Test")))
        XCTAssertTrue(RunStateMachine.canTransition(from: .scheduled, to: .scheduled, with: .reassignDriver(newDriverId: "driver2")))
        
        // Invalid admin transitions
        XCTAssertFalse(RunStateMachine.canTransition(from: .completed, to: .cancelled, with: .cancelRun(reason: "Test")))
        XCTAssertFalse(RunStateMachine.canTransition(from: .activeEnroute, to: .scheduled, with: .reassignDriver(newDriverId: "driver2")))
    }
}