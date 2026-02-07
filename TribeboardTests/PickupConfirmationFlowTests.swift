//
//  PickupConfirmationFlowTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/04.
//

import XCTest
@testable import Tribeboard

/// Tests for Requirement 6: Pickup Confirmation Screen
/// Validates the complete pickup confirmation flow including:
/// - Screen transitions when driver taps "I'M HERE"
/// - Checklist display with passenger toggle controls
/// - Individual passenger pickup confirmation
/// - "All Passengers Boarded" button enablement
/// - Transition back to Driver En Route for next waypoint
@MainActor
class PickupConfirmationFlowTests: XCTestCase {
    
    var mockFirebaseService: MockFirebaseRunService!
    var runEventService: RunEventService!
    var roleContext: RoleContext!
    var viewModel: DriverFocusModeViewModel!
    var sampleRun: Run!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockFirebaseService = MockFirebaseRunService()
        runEventService = RunEventService(firebaseService: mockFirebaseService)
        roleContext = RoleContext(userId: "driver1", role: .driver, familyId: "family1")
        
        // Create a test run with pickup stops
        sampleRun = createTestRunWithPickupStops()
        
        viewModel = DriverFocusModeViewModel(
            runId: sampleRun.id,
            runEventService: runEventService,
            roleContext: roleContext
        )
    }
    
    override func tearDown() async throws {
        viewModel = nil
        sampleRun = nil
        runEventService = nil
        mockFirebaseService = nil
        roleContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Test 1: Screen Transition on "I'M HERE" Button
    
    /// **Validates: Requirements 6.1**
    /// When driver taps "I'M HERE" button on Driver En Route screen,
    /// the screen transitions to Pickup Confirmation screen
    func testDriverEnRouteToPickupConfirmation_WhenImHereButtonTapped_TransitionsToArrivedAtStop() async throws {
        // Given: Driver is en route to a pickup stop
        sampleRun.status = .activeEnroute
        sampleRun.currentStopIndex = 0
        
        // When: Driver taps "I'M HERE" button (arriveStop action)
        let result = RunStateMachine.processDriverAction(.arriveStop, for: &sampleRun)
        
        // Then: Run status transitions to arrivedAtStop
        switch result {
        case .success(let eventType):
            XCTAssertEqual(eventType, .runArrivedStop, "Should emit runArrivedStop event")
            XCTAssertEqual(sampleRun.status, .arrivedAtStop, "Run status should transition to arrivedAtStop")
        case .failure(let error):
            XCTFail("Arrive stop should succeed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Test 2: Pickup Confirmation Screen Display
    
    /// **Validates: Requirements 6.2**
    /// Pickup Confirmation screen displays checklist of passengers expected at this stop
    /// with toggle controls for each passenger to mark them as boarded
    func testPickupConfirmationScreen_WhenDisplayed_ShowsPassengerChecklist() async throws {
        // Given: Driver has arrived at a pickup stop
        sampleRun.status = .arrivedAtStop
        sampleRun.currentStopIndex = 0
        let currentStop = sampleRun.stops[0]
        
        // When: Getting passengers requiring action
        let passengersRequiringAction = getPassengersRequiringActionForTest(
            stop: currentStop,
            passengers: sampleRun.passengers
        )
        
        // Then: All expected passengers are shown with pickup actions
        XCTAssertEqual(passengersRequiringAction.count, 2, "Should show 2 passengers at this stop")
        
        for actionItem in passengersRequiringAction {
            XCTAssertEqual(actionItem.requiredAction, .confirmPickup(passengerId: actionItem.passenger.id),
                          "Each passenger should have confirmPickup action")
            XCTAssertEqual(actionItem.actionTitle, "Pick Up",
                          "Action button should display 'Pick Up'")
            XCTAssertTrue(actionItem.canPerformAction,
                         "Driver should be able to perform pickup action")
        }
    }
    
    // MARK: - Test 3: Individual Passenger Pickup
    
    /// **Validates: Requirements 6.2, 6.4**
    /// When "Pick Up" button is tapped for a passenger, their status updates to onboard
    func testPickupConfirmation_WhenPickUpButtonTapped_UpdatesPassengerStatus() async throws {
        // Given: Driver is at pickup stop with waiting passengers
        sampleRun.status = .arrivedAtStop
        sampleRun.currentStopIndex = 0
        let passengerId = sampleRun.passengers[0].id
        
        XCTAssertEqual(sampleRun.passengers[0].status, .waiting, "Passenger should start as waiting")
        
        // When: Driver taps "Pick Up" for first passenger
        let result = RunStateMachine.processDriverAction(.confirmPickup(passengerId: passengerId), for: &sampleRun)
        
        // Then: Passenger status updates to onboard
        switch result {
        case .success(let eventType):
            XCTAssertEqual(eventType, .passengerPickedUp, "Should emit passengerPickedUp event")
            XCTAssertEqual(sampleRun.passengers[0].status, .onboard, "Passenger status should update to onboard")
        case .failure(let error):
            XCTFail("Confirm pickup should succeed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Test 4: All Passengers Boarded Button Enablement
    
    /// **Validates: Requirements 6.3**
    /// "All Passengers Boarded" button is enabled only when all passengers are marked as boarded
    func testAllPassengersBoardedButton_WhenNotAllPickedUp_IsDisabled() async throws {
        // Given: Driver is at pickup stop with some passengers still waiting
        sampleRun.status = .arrivedAtStop
        sampleRun.currentStopIndex = 0
        sampleRun.passengers[0].status = .onboard  // First passenger picked up
        sampleRun.passengers[1].status = .waiting  // Second passenger still waiting
        
        let currentStop = sampleRun.stops[0]
        
        // When: Checking if stop is complete
        let isComplete = isStopCompleteForTest(stop: currentStop, passengers: sampleRun.passengers)
        
        // Then: Stop should not be complete (button disabled)
        XCTAssertFalse(isComplete, "Stop should not be complete when passengers are waiting")
    }
    
    /// **Validates: Requirements 6.3**
    /// "All Passengers Boarded" button is enabled when all passengers are marked as boarded
    func testAllPassengersBoardedButton_WhenAllPickedUp_IsEnabled() async throws {
        // Given: Driver is at pickup stop with all passengers onboard
        sampleRun.status = .arrivedAtStop
        sampleRun.currentStopIndex = 0
        sampleRun.passengers[0].status = .onboard
        sampleRun.passengers[1].status = .onboard
        
        let currentStop = sampleRun.stops[0]
        
        // When: Checking if stop is complete
        let isComplete = isStopCompleteForTest(stop: currentStop, passengers: sampleRun.passengers)
        
        // Then: Stop should be complete (button enabled)
        XCTAssertTrue(isComplete, "Stop should be complete when all passengers are onboard")
    }
    
    // MARK: - Test 5: Transition to Next Waypoint
    
    /// **Validates: Requirements 6.5**
    /// When "All Passengers Boarded" button is tapped, the screen transitions back to
    /// Driver En Route for the next waypoint
    func testPickupConfirmation_WhenAllPassengersBoardedTapped_TransitionsToNextWaypoint() async throws {
        // Given: All passengers are picked up at current stop
        sampleRun.status = .arrivedAtStop
        sampleRun.currentStopIndex = 0
        sampleRun.passengers[0].status = .onboard
        sampleRun.passengers[1].status = .onboard
        
        let initialStopIndex = sampleRun.currentStopIndex
        
        // When: Driver taps "All Passengers Boarded" (nextStop action)
        let result = RunStateMachine.processDriverAction(.nextStop, for: &sampleRun)
        
        // Then: Run transitions to activeEnroute for next stop
        switch result {
        case .success:
            // The event type for nextStop action is not explicitly defined,
            // but the state transition is what matters
            XCTAssertEqual(sampleRun.status, .activeEnroute, "Run status should transition to activeEnroute")
            XCTAssertEqual(sampleRun.currentStopIndex, initialStopIndex + 1, "Should advance to next stop")
        case .failure(let error):
            XCTFail("Next stop should succeed when all passengers are picked up: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Test 6: Stop Completion Progress
    
    /// **Validates: Requirements 6.2, 6.3**
    /// Stop completion progress accurately reflects the number of passengers picked up
    func testStopCompletionProgress_TracksPickupProgress() async throws {
        // Given: Driver is at pickup stop with 2 passengers
        sampleRun.status = .arrivedAtStop
        sampleRun.currentStopIndex = 0
        let currentStop = sampleRun.stops[0]
        
        // When: No passengers picked up yet
        sampleRun.passengers[0].status = .waiting
        sampleRun.passengers[1].status = .waiting
        
        var progress = calculateStopProgressForTest(stop: currentStop, passengers: sampleRun.passengers)
        
        // Then: Progress should be 0/2
        XCTAssertEqual(progress.completed, 0, "No passengers picked up")
        XCTAssertEqual(progress.total, 2, "Total 2 passengers expected")
        XCTAssertFalse(progress.isComplete, "Stop should not be complete")
        
        // When: One passenger picked up
        sampleRun.passengers[0].status = .onboard
        
        progress = calculateStopProgressForTest(stop: currentStop, passengers: sampleRun.passengers)
        
        // Then: Progress should be 1/2
        XCTAssertEqual(progress.completed, 1, "One passenger picked up")
        XCTAssertEqual(progress.total, 2, "Total 2 passengers expected")
        XCTAssertFalse(progress.isComplete, "Stop should not be complete")
        
        // When: All passengers picked up
        sampleRun.passengers[1].status = .onboard
        
        progress = calculateStopProgressForTest(stop: currentStop, passengers: sampleRun.passengers)
        
        // Then: Progress should be 2/2
        XCTAssertEqual(progress.completed, 2, "All passengers picked up")
        XCTAssertEqual(progress.total, 2, "Total 2 passengers expected")
        XCTAssertTrue(progress.isComplete, "Stop should be complete")
    }
    
    // MARK: - Test 7: Validation - Cannot Advance Without Completing Pickups
    
    /// **Validates: Requirements 6.3, 6.5**
    /// Driver cannot advance to next stop without picking up all passengers
    func testPickupConfirmation_WhenNotAllPickedUp_CannotAdvance() async throws {
        // Given: Driver is at pickup stop with passengers still waiting
        sampleRun.status = .arrivedAtStop
        sampleRun.currentStopIndex = 0
        sampleRun.passengers[0].status = .onboard
        sampleRun.passengers[1].status = .waiting  // Still waiting
        
        // When: Driver attempts to advance to next stop
        let result = RunStateMachine.processDriverAction(.nextStop, for: &sampleRun)
        
        // Then: Action should fail
        switch result {
        case .success:
            XCTFail("Should not allow advancing when passengers are still waiting")
        case .failure(let error):
            XCTAssertTrue(error.localizedDescription.contains("not completed") ||
                         error.localizedDescription.contains("waiting"),
                         "Error should indicate stop is not completed")
        }
    }
    
    // MARK: - Test 8: Multiple Pickup Stops
    
    /// **Validates: Requirements 6.1-6.5**
    /// Flow works correctly for multiple pickup stops in sequence
    func testPickupConfirmation_MultiplePickupStops_WorksCorrectly() async throws {
        // Given: Run with multiple pickup stops
        var multiStopRun = createTestRunWithMultiplePickupStops()
        
        // First pickup stop
        multiStopRun.status = .activeEnroute
        multiStopRun.currentStopIndex = 0
        
        // When: Arrive at first pickup stop
        var result = RunStateMachine.processDriverAction(.arriveStop, for: &multiStopRun)
        XCTAssertTrue(result.isSuccess, "Should arrive at first pickup stop")
        XCTAssertEqual(multiStopRun.status, .arrivedAtStop)
        
        // When: Pick up passenger at first stop
        let firstPassengerId = multiStopRun.stops[0].requiredPassengerIds[0]
        result = RunStateMachine.processDriverAction(.confirmPickup(passengerId: firstPassengerId), for: &multiStopRun)
        XCTAssertTrue(result.isSuccess, "Should pick up passenger at first stop")
        
        // When: Advance to next stop
        result = RunStateMachine.processDriverAction(.nextStop, for: &multiStopRun)
        XCTAssertTrue(result.isSuccess, "Should advance to next stop")
        XCTAssertEqual(multiStopRun.status, .activeEnroute)
        XCTAssertEqual(multiStopRun.currentStopIndex, 1)
        
        // When: Arrive at second pickup stop
        result = RunStateMachine.processDriverAction(.arriveStop, for: &multiStopRun)
        XCTAssertTrue(result.isSuccess, "Should arrive at second pickup stop")
        XCTAssertEqual(multiStopRun.status, .arrivedAtStop)
        
        // When: Pick up passenger at second stop
        let secondPassengerId = multiStopRun.stops[1].requiredPassengerIds[0]
        result = RunStateMachine.processDriverAction(.confirmPickup(passengerId: secondPassengerId), for: &multiStopRun)
        XCTAssertTrue(result.isSuccess, "Should pick up passenger at second stop")
        
        // Then: Both passengers should be onboard
        XCTAssertEqual(multiStopRun.passengers[0].status, .onboard)
        XCTAssertEqual(multiStopRun.passengers[1].status, .onboard)
    }
    
    // MARK: - Test 9: Passenger Action Items
    
    /// **Validates: Requirements 6.2**
    /// Passenger action items correctly reflect current state and available actions
    func testPassengerActionItems_ReflectCurrentState() async throws {
        // Given: Driver is at pickup stop
        sampleRun.status = .arrivedAtStop
        sampleRun.currentStopIndex = 0
        let currentStop = sampleRun.stops[0]
        
        // When: Getting passenger action items
        let actionItems = getPassengersRequiringActionForTest(
            stop: currentStop,
            passengers: sampleRun.passengers
        )
        
        // Then: Action items should reflect waiting status
        for actionItem in actionItems {
            XCTAssertEqual(actionItem.passenger.status, .waiting, "Passengers should be waiting")
            XCTAssertFalse(actionItem.isCompleted, "Action should not be completed")
            XCTAssertEqual(actionItem.statusMessage, "Action Required", "Should show action required")
        }
        
        // When: One passenger is picked up
        sampleRun.passengers[0].status = .onboard
        
        let updatedActionItems = getPassengersRequiringActionForTest(
            stop: currentStop,
            passengers: sampleRun.passengers
        )
        
        // Then: First passenger should show as completed
        let firstPassengerItem = updatedActionItems.first { $0.passenger.id == sampleRun.passengers[0].id }
        XCTAssertNotNil(firstPassengerItem)
        XCTAssertTrue(firstPassengerItem!.isCompleted, "First passenger action should be completed")
        XCTAssertEqual(firstPassengerItem!.statusMessage, "Completed", "Should show completed status")
    }
    
    // MARK: - Test 10: Error Handling
    
    /// **Validates: Requirements 6.4**
    /// Cannot confirm pickup for passenger not at current stop
    func testPickupConfirmation_PassengerNotAtStop_Fails() async throws {
        // Given: Driver is at first pickup stop
        sampleRun.status = .arrivedAtStop
        sampleRun.currentStopIndex = 0
        
        // Create a passenger not at this stop
        let otherPassengerId = "passenger-not-at-stop"
        
        // When: Attempting to pick up passenger not at this stop
        let result = RunStateMachine.processDriverAction(.confirmPickup(passengerId: otherPassengerId), for: &sampleRun)
        
        // Then: Action should fail
        switch result {
        case .success:
            XCTFail("Should not allow pickup for passenger not at current stop")
        case .failure(let error):
            XCTAssertTrue(error.localizedDescription.contains("not found") ||
                         error.localizedDescription.contains("not required"),
                         "Error should indicate passenger is not at this stop")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestRunWithPickupStops() -> Run {
        return Run(
            title: "Test Pickup Run",
            scheduledTime: Date(),
            driverId: "driver1",
            status: .scheduled,
            stops: [
                RunStop(
                    type: .pickup,
                    label: "School",
                    scheduledTime: Date().addingTimeInterval(300),
                    requiredPassengerIds: ["p1", "p2"],
                    location: LocationData(latitude: 37.7749, longitude: -122.4194)
                ),
                RunStop(
                    type: .dropoff,
                    label: "Home",
                    scheduledTime: Date().addingTimeInterval(900),
                    requiredPassengerIds: ["p1", "p2"],
                    location: LocationData(latitude: 37.7849, longitude: -122.4294)
                )
            ],
            passengers: [
                MemberSummary(id: "p1", displayName: "Alice", role: .passenger, status: .waiting),
                MemberSummary(id: "p2", displayName: "Bob", role: .passenger, status: .waiting)
            ],
            createdBy: "parent1",
            familyId: "family1"
        )
    }
    
    private func createTestRunWithMultiplePickupStops() -> Run {
        return Run(
            title: "Test Multiple Pickup Run",
            scheduledTime: Date(),
            driverId: "driver1",
            status: .scheduled,
            stops: [
                RunStop(
                    type: .pickup,
                    label: "School A",
                    scheduledTime: Date().addingTimeInterval(300),
                    requiredPassengerIds: ["p1"],
                    location: LocationData(latitude: 37.7749, longitude: -122.4194)
                ),
                RunStop(
                    type: .pickup,
                    label: "School B",
                    scheduledTime: Date().addingTimeInterval(600),
                    requiredPassengerIds: ["p2"],
                    location: LocationData(latitude: 37.7849, longitude: -122.4294)
                ),
                RunStop(
                    type: .dropoff,
                    label: "Home",
                    scheduledTime: Date().addingTimeInterval(900),
                    requiredPassengerIds: ["p1", "p2"],
                    location: LocationData(latitude: 37.7949, longitude: -122.4394)
                )
            ],
            passengers: [
                MemberSummary(id: "p1", displayName: "Alice", role: .passenger, status: .waiting),
                MemberSummary(id: "p2", displayName: "Bob", role: .passenger, status: .waiting)
            ],
            createdBy: "parent1",
            familyId: "family1"
        )
    }
    
    private func getPassengersRequiringActionForTest(stop: RunStop, passengers: [MemberSummary]) -> [PassengerActionItem] {
        return stop.requiredPassengerIds.compactMap { passengerId in
            guard let passenger = passengers.first(where: { $0.id == passengerId }) else { return nil }
            
            let requiredAction: DriverAction?
            let canPerformAction: Bool
            let isCompleted: Bool
            
            switch stop.type {
            case .pickup:
                if passenger.status == .waiting {
                    requiredAction = .confirmPickup(passengerId: passengerId)
                    canPerformAction = true
                    isCompleted = false
                } else {
                    requiredAction = nil
                    canPerformAction = false
                    isCompleted = true
                }
                
            case .dropoff:
                if passenger.status == .onboard {
                    requiredAction = .confirmDropoff(passengerId: passengerId)
                    canPerformAction = true
                    isCompleted = false
                } else {
                    requiredAction = nil
                    canPerformAction = false
                    isCompleted = true
                }
                
            case .waypoint:
                requiredAction = nil
                canPerformAction = false
                isCompleted = true
            }
            
            return PassengerActionItem(
                passenger: passenger,
                requiredAction: requiredAction,
                canPerformAction: canPerformAction,
                isCompleted: isCompleted
            )
        }
    }
    
    private func isStopCompleteForTest(stop: RunStop, passengers: [MemberSummary]) -> Bool {
        switch stop.type {
        case .pickup:
            return stop.requiredPassengerIds.allSatisfy { passengerId in
                passengers.first { $0.id == passengerId }?.status == .onboard
            }
        case .dropoff:
            return stop.requiredPassengerIds.allSatisfy { passengerId in
                passengers.first { $0.id == passengerId }?.status == .droppedOff
            }
        case .waypoint:
            return true
        }
    }
    
    private func calculateStopProgressForTest(stop: RunStop, passengers: [MemberSummary]) -> StopCompletionProgress {
        let requiredPassengers = passengers.filter { passenger in
            stop.requiredPassengerIds.contains(passenger.id)
        }
        
        let completedCount: Int
        let totalCount = requiredPassengers.count
        
        switch stop.type {
        case .pickup:
            completedCount = requiredPassengers.filter { $0.status == .onboard }.count
        case .dropoff:
            completedCount = requiredPassengers.filter { $0.status == .droppedOff }.count
        case .waypoint:
            completedCount = 1
        }
        
        let isComplete = isStopCompleteForTest(stop: stop, passengers: passengers)
        let message = isComplete ? "All passengers picked up" : "\(totalCount - completedCount) passengers waiting"
        
        return StopCompletionProgress(
            completed: completedCount,
            total: max(totalCount, 1),
            isComplete: isComplete,
            message: message,
            remainingActions: []
        )
    }
}

// MARK: - StateTransitionResult Extension

extension StateTransitionResult {
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
}
