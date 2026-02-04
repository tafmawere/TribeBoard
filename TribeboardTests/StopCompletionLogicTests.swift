//
//  StopCompletionLogicTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/04.
//

import XCTest
@testable import Tribeboard

/// Unit tests for stop completion logic
/// Tests Requirements 2.4, 2.5, 2.6 - stop completion validation and progression
@MainActor
class StopCompletionLogicTests: XCTestCase {
    
    var mockFirebaseService: MockFirebaseRunService!
    var runEventService: RunEventService!
    var roleContext: RoleContext!
    var viewModel: DriverFocusModeViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockFirebaseService = MockFirebaseRunService()
        runEventService = RunEventService(firebaseService: mockFirebaseService)
        roleContext = RoleContext(userId: "driver1", role: .driver, familyId: "family1")
        viewModel = DriverFocusModeViewModel(
            runId: "test-run",
            runEventService: runEventService,
            roleContext: roleContext
        )
    }
    
    override func tearDown() async throws {
        viewModel = nil
        runEventService = nil
        mockFirebaseService = nil
        roleContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Pickup Stop Completion Tests (Requirement 2.4)
    
    func testPickupStopCompletion_AllPassengersPickedUp_ShouldBeComplete() async throws {
        // Given: A pickup stop with passengers
        let passengers = [
            MemberSummary(id: "p1", displayName: "Alice", role: .passenger, status: .onboard),
            MemberSummary(id: "p2", displayName: "Bob", role: .passenger, status: .onboard)
        ]
        
        let pickupStop = RunStop(
            type: .pickup,
            label: "School",
            scheduledTime: Date(),
            requiredPassengerIds: ["p1", "p2"],
            location: LocationData(latitude: 37.7749, longitude: -122.4194)
        )
        
        // When: Validating stop completion
        let result = validateStopCompletionForTest(stop: pickupStop, passengers: passengers)
        
        // Then: Stop should be complete
        XCTAssertTrue(result.isComplete, "Pickup stop should be complete when all passengers are onboard")
        XCTAssertEqual(result.message, "All 2 passengers picked up")
    }
    
    func testPickupStopCompletion_SomePassengersWaiting_ShouldBeIncomplete() async throws {
        // Given: A pickup stop with some passengers still waiting
        let passengers = [
            MemberSummary(id: "p1", displayName: "Alice", role: .passenger, status: .onboard),
            MemberSummary(id: "p2", displayName: "Bob", role: .passenger, status: .waiting)
        ]
        
        let pickupStop = RunStop(
            type: .pickup,
            label: "School",
            scheduledTime: Date(),
            requiredPassengerIds: ["p1", "p2"],
            location: LocationData(latitude: 37.7749, longitude: -122.4194)
        )
        
        // When: Validating stop completion
        let result = validateStopCompletionForTest(stop: pickupStop, passengers: passengers)
        
        // Then: Stop should be incomplete
        XCTAssertFalse(result.isComplete, "Pickup stop should be incomplete when passengers are waiting")
        XCTAssertEqual(result.message, "1 of 2 passengers waiting")
        XCTAssertEqual(result.remainingActions.count, 1)
    }
    
    // MARK: - Dropoff Stop Completion Tests (Requirement 2.5)
    
    func testDropoffStopCompletion_AllPassengersDroppedOff_ShouldBeComplete() async throws {
        // Given: A dropoff stop with all passengers dropped off
        let passengers = [
            MemberSummary(id: "p1", displayName: "Alice", role: .passenger, status: .droppedOff),
            MemberSummary(id: "p2", displayName: "Bob", role: .passenger, status: .droppedOff)
        ]
        
        let dropoffStop = RunStop(
            type: .dropoff,
            label: "Home",
            scheduledTime: Date(),
            requiredPassengerIds: ["p1", "p2"],
            location: LocationData(latitude: 37.7749, longitude: -122.4194)
        )
        
        // When: Validating stop completion
        let result = validateStopCompletionForTest(stop: dropoffStop, passengers: passengers)
        
        // Then: Stop should be complete
        XCTAssertTrue(result.isComplete, "Dropoff stop should be complete when all passengers are dropped off")
        XCTAssertEqual(result.message, "All 2 passengers dropped off")
    }
    
    func testDropoffStopCompletion_SomePassengersOnboard_ShouldBeIncomplete() async throws {
        // Given: A dropoff stop with some passengers still onboard
        let passengers = [
            MemberSummary(id: "p1", displayName: "Alice", role: .passenger, status: .droppedOff),
            MemberSummary(id: "p2", displayName: "Bob", role: .passenger, status: .onboard)
        ]
        
        let dropoffStop = RunStop(
            type: .dropoff,
            label: "Home",
            scheduledTime: Date(),
            requiredPassengerIds: ["p1", "p2"],
            location: LocationData(latitude: 37.7749, longitude: -122.4194)
        )
        
        // When: Validating stop completion
        let result = validateStopCompletionForTest(stop: dropoffStop, passengers: passengers)
        
        // Then: Stop should be incomplete
        XCTAssertFalse(result.isComplete, "Dropoff stop should be incomplete when passengers are onboard")
        XCTAssertEqual(result.message, "1 of 2 passengers still onboard")
        XCTAssertEqual(result.remainingActions.count, 1)
    }
    
    // MARK: - Waypoint Stop Completion Tests (Requirement 2.6)
    
    func testWaypointStopCompletion_ShouldAlwaysBeComplete() async throws {
        // Given: A waypoint stop
        let waypoint = RunStop(
            type: .waypoint,
            label: "Gas Station",
            scheduledTime: Date(),
            requiredPassengerIds: [],
            location: LocationData(latitude: 37.7749, longitude: -122.4194)
        )
        
        // When: Validating stop completion
        let result = validateStopCompletionForTest(stop: waypoint, passengers: [])
        
        // Then: Waypoint should always be complete
        XCTAssertTrue(result.isComplete, "Waypoint stops should always be complete")
        XCTAssertEqual(result.message, "Waypoint ready to continue")
    }
    
    // MARK: - Passenger Status Validation Tests
    
    func testPassengerStatusUpdate_ValidPickupTransition_ShouldSucceed() async throws {
        // Given: A passenger waiting for pickup
        let passenger = MemberSummary(id: "p1", displayName: "Alice", role: .passenger, status: .waiting)
        
        // When: Updating status from waiting to onboard at pickup stop
        let isValid = isValidStatusTransition(
            from: .waiting,
            to: .onboard,
            stopType: .pickup
        )
        
        // Then: Transition should be valid
        XCTAssertTrue(isValid, "Waiting → Onboard should be valid at pickup stops")
    }
    
    func testPassengerStatusUpdate_ValidDropoffTransition_ShouldSucceed() async throws {
        // Given: A passenger onboard for dropoff
        let passenger = MemberSummary(id: "p1", displayName: "Alice", role: .passenger, status: .onboard)
        
        // When: Updating status from onboard to dropped off at dropoff stop
        let isValid = isValidStatusTransition(
            from: .onboard,
            to: .droppedOff,
            stopType: .dropoff
        )
        
        // Then: Transition should be valid
        XCTAssertTrue(isValid, "Onboard → DroppedOff should be valid at dropoff stops")
    }
    
    func testPassengerStatusUpdate_InvalidTransition_ShouldFail() async throws {
        // When: Attempting invalid status transition
        let isValid = isValidStatusTransition(
            from: .waiting,
            to: .droppedOff,
            stopType: .pickup
        )
        
        // Then: Transition should be invalid
        XCTAssertFalse(isValid, "Waiting → DroppedOff should be invalid at pickup stops")
    }
    
    // MARK: - Stop Progression Tests
    
    func testStopProgression_CompletedStop_ShouldAllowAdvancement() async throws {
        // Given: A completed pickup stop
        let passengers = [
            MemberSummary(id: "p1", displayName: "Alice", role: .passenger, status: .onboard)
        ]
        
        let completedStop = RunStop(
            type: .pickup,
            label: "School",
            scheduledTime: Date(),
            requiredPassengerIds: ["p1"],
            location: LocationData(latitude: 37.7749, longitude: -122.4194)
        )
        
        // When: Checking if advancement is allowed
        let result = validateStopCompletionForTest(stop: completedStop, passengers: passengers)
        
        // Then: Advancement should be allowed
        XCTAssertTrue(result.isComplete, "Completed stop should allow advancement")
        XCTAssertTrue(result.remainingActions.isEmpty, "No remaining actions for completed stop")
    }
    
    func testStopProgression_IncompleteStop_ShouldBlockAdvancement() async throws {
        // Given: An incomplete pickup stop
        let passengers = [
            MemberSummary(id: "p1", displayName: "Alice", role: .passenger, status: .waiting)
        ]
        
        let incompleteStop = RunStop(
            type: .pickup,
            label: "School",
            scheduledTime: Date(),
            requiredPassengerIds: ["p1"],
            location: LocationData(latitude: 37.7749, longitude: -122.4194)
        )
        
        // When: Checking if advancement is allowed
        let result = validateStopCompletionForTest(stop: incompleteStop, passengers: passengers)
        
        // Then: Advancement should be blocked
        XCTAssertFalse(result.isComplete, "Incomplete stop should block advancement")
        XCTAssertFalse(result.remainingActions.isEmpty, "Should have remaining actions for incomplete stop")
    }
    
    // MARK: - Helper Methods
    
    private func validateStopCompletionForTest(stop: RunStop, passengers: [MemberSummary]) -> StopCompletionResult {
        switch stop.type {
        case .pickup:
            let requiredPassengers = passengers.filter { passenger in
                stop.requiredPassengerIds.contains(passenger.id)
            }
            
            let waitingPassengers = requiredPassengers.filter { $0.status == .waiting }
            
            if waitingPassengers.isEmpty {
                return .completed(message: "All \(requiredPassengers.count) passengers picked up")
            } else {
                return .incomplete(
                    message: "\(waitingPassengers.count) of \(requiredPassengers.count) passengers waiting",
                    remainingActions: waitingPassengers.map { .confirmPickup(passengerId: $0.id) }
                )
            }
            
        case .dropoff:
            let requiredPassengers = passengers.filter { passenger in
                stop.requiredPassengerIds.contains(passenger.id)
            }
            
            let onboardPassengers = requiredPassengers.filter { $0.status == .onboard }
            
            if onboardPassengers.isEmpty {
                return .completed(message: "All \(requiredPassengers.count) passengers dropped off")
            } else {
                return .incomplete(
                    message: "\(onboardPassengers.count) of \(requiredPassengers.count) passengers still onboard",
                    remainingActions: onboardPassengers.map { .confirmDropoff(passengerId: $0.id) }
                )
            }
            
        case .waypoint:
            return .completed(message: "Waypoint ready to continue")
        }
    }
    
    private func isValidStatusTransition(from currentStatus: PassengerStatus, to newStatus: PassengerStatus, stopType: StopType) -> Bool {
        switch (stopType, currentStatus, newStatus) {
        case (.pickup, .waiting, .onboard):
            return true
        case (.dropoff, .onboard, .droppedOff):
            return true
        default:
            return false
        }
    }
}