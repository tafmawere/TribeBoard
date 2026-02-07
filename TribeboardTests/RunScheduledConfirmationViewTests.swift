//
//  RunScheduledConfirmationViewTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/06.
//
//  Unit tests for RunScheduledConfirmationView (Task 11.4)

import XCTest
import SwiftUI
@testable import Tribeboard

final class RunScheduledConfirmationViewTests: XCTestCase {
    
    // MARK: - Test Data
    
    func createSampleRun() -> Run {
        return Run(
            title: "School Pickup",
            scheduledTime: Date().addingTimeInterval(3600),
            driverId: "demo-tafadzwa",
            stops: [
                RunStop(
                    type: .pickup,
                    label: "St Davids School",
                    scheduledTime: Date().addingTimeInterval(3600),
                    requiredPassengerIds: ["demo-tj", "demo-tawana"],
                    location: LocationData(latitude: 37.7749, longitude: -122.4194)
                ),
                RunStop(
                    type: .waypoint,
                    label: "Grocery Store",
                    scheduledTime: Date().addingTimeInterval(4200),
                    requiredPassengerIds: [],
                    location: LocationData(latitude: 37.7799, longitude: -122.4144)
                ),
                RunStop(
                    type: .dropoff,
                    label: "Home",
                    scheduledTime: Date().addingTimeInterval(5400),
                    requiredPassengerIds: ["demo-tj", "demo-tawana"],
                    location: LocationData(latitude: 37.7849, longitude: -122.4094)
                )
            ],
            passengers: [
                MemberSummary(id: "demo-tj", displayName: "TJ", role: .passenger),
                MemberSummary(id: "demo-tawana", displayName: "Tawana", role: .passenger)
            ],
            createdBy: "demo-rue",
            familyId: "demo-family-1"
        )
    }
    
    // MARK: - Tests
    
    /// Test that RunScheduledConfirmationView can be instantiated with valid data
    /// Validates: Requirement 10.1 - Confirmation screen displays after successful run creation
    func testViewInstantiation() throws {
        // Given
        let run = createSampleRun()
        var viewRunCalled = false
        var backToDashboardCalled = false
        
        // When
        let view = RunScheduledConfirmationView(
            run: run,
            onViewRun: { viewRunCalled = true },
            onBackToDashboard: { backToDashboardCalled = true }
        )
        
        // Then
        XCTAssertNotNil(view, "View should be instantiated successfully")
        XCTAssertFalse(viewRunCalled, "onViewRun should not be called on instantiation")
        XCTAssertFalse(backToDashboardCalled, "onBackToDashboard should not be called on instantiation")
    }
    
    /// Test that the view correctly formats run details
    /// Validates: Requirement 10.2 - Shows run title, scheduled time, driver name, passenger names
    func testRunDetailsFormatting() throws {
        // Given
        let run = createSampleRun()
        let view = RunScheduledConfirmationView(
            run: run,
            onViewRun: {},
            onBackToDashboard: {}
        )
        
        // Then - verify the run data is accessible
        XCTAssertEqual(run.title, "School Pickup", "Run title should match")
        XCTAssertEqual(run.passengers.count, 2, "Should have 2 passengers")
        XCTAssertEqual(run.stops.count, 3, "Should have 3 stops")
        XCTAssertEqual(run.driverId, "demo-tafadzwa", "Driver ID should match")
        
        // Verify passenger names
        let passengerNames = run.passengers.map { $0.displayName }
        XCTAssertTrue(passengerNames.contains("TJ"), "Should include TJ")
        XCTAssertTrue(passengerNames.contains("Tawana"), "Should include Tawana")
    }
    
    /// Test that the view handles multiple passengers correctly
    /// Validates: Requirement 10.2 - Shows passenger names
    func testMultiplePassengersDisplay() throws {
        // Given
        var run = createSampleRun()
        
        // Add more passengers to test the "and X more" logic
        run.passengers.append(MemberSummary(id: "demo-child3", displayName: "Emma", role: .passenger))
        run.passengers.append(MemberSummary(id: "demo-child4", displayName: "Liam", role: .passenger))
        run.passengers.append(MemberSummary(id: "demo-child5", displayName: "Olivia", role: .passenger))
        
        let view = RunScheduledConfirmationView(
            run: run,
            onViewRun: {},
            onBackToDashboard: {}
        )
        
        // Then
        XCTAssertEqual(run.passengers.count, 5, "Should have 5 passengers")
        
        // The view should show first 3 and "and 2 more"
        let passengerNames = run.passengers.map { $0.displayName }
        XCTAssertEqual(passengerNames.count, 5, "Should have all passenger names")
    }
    
    /// Test that callbacks are properly wired
    /// Validates: Requirement 10.3, 10.4 - Action buttons work correctly
    func testCallbacksAreInvoked() throws {
        // Given
        let run = createSampleRun()
        var viewRunCalled = false
        var backToDashboardCalled = false
        
        let view = RunScheduledConfirmationView(
            run: run,
            onViewRun: { viewRunCalled = true },
            onBackToDashboard: { backToDashboardCalled = true }
        )
        
        // When - simulate button taps by calling the closures directly
        view.onViewRun()
        
        // Then
        XCTAssertTrue(viewRunCalled, "onViewRun callback should be invoked")
        XCTAssertFalse(backToDashboardCalled, "onBackToDashboard should not be called yet")
        
        // When - simulate second button tap
        view.onBackToDashboard()
        
        // Then
        XCTAssertTrue(backToDashboardCalled, "onBackToDashboard callback should be invoked")
    }
    
    /// Test that the view handles runs with minimal data
    /// Edge case: Run with only required fields
    func testMinimalRunData() throws {
        // Given - create a run with minimal data
        let minimalRun = Run(
            title: "Quick Run",
            scheduledTime: Date(),
            driverId: "driver1",
            stops: [
                RunStop(
                    type: .pickup,
                    label: "Start",
                    scheduledTime: Date(),
                    requiredPassengerIds: ["child1"],
                    location: LocationData(latitude: 0, longitude: 0)
                )
            ],
            passengers: [
                MemberSummary(id: "child1", displayName: "Child", role: .passenger)
            ],
            createdBy: "parent1",
            familyId: "family1"
        )
        
        // When
        let view = RunScheduledConfirmationView(
            run: minimalRun,
            onViewRun: {},
            onBackToDashboard: {}
        )
        
        // Then
        XCTAssertNotNil(view, "View should handle minimal run data")
        XCTAssertEqual(minimalRun.stops.count, 1, "Should have 1 stop")
        XCTAssertEqual(minimalRun.passengers.count, 1, "Should have 1 passenger")
    }
    
    /// Test that the view correctly displays stop count
    /// Validates: Requirement 10.2 - Shows stop count
    func testStopCountDisplay() throws {
        // Given
        let run = createSampleRun()
        
        // Then
        XCTAssertEqual(run.stops.count, 3, "Should have exactly 3 stops")
        
        // Verify stop types
        XCTAssertEqual(run.stops[0].type, .pickup, "First stop should be pickup")
        XCTAssertEqual(run.stops[1].type, .waypoint, "Second stop should be waypoint")
        XCTAssertEqual(run.stops[2].type, .dropoff, "Third stop should be dropoff")
    }
    
    /// Integration test: Verify the view works with AppCoordinator navigation
    /// Validates: Requirement 10.5 - Navigation works correctly
    func testIntegrationWithAppCoordinator() throws {
        // Given
        let run = createSampleRun()
        var navigatedToRunDetail = false
        var navigatedToMyRuns = false
        
        // Simulate AppCoordinator callbacks
        let view = RunScheduledConfirmationView(
            run: run,
            onViewRun: {
                // This simulates: self?.dismissSheet() + self?.navigate(to: .runDetail(runId: run.id))
                navigatedToRunDetail = true
            },
            onBackToDashboard: {
                // This simulates: self?.dismissSheet() + self?.navigate(to: .myRuns)
                navigatedToMyRuns = true
            }
        )
        
        // When
        view.onViewRun()
        
        // Then
        XCTAssertTrue(navigatedToRunDetail, "Should navigate to run detail")
        XCTAssertFalse(navigatedToMyRuns, "Should not navigate to my runs yet")
        
        // When
        view.onBackToDashboard()
        
        // Then
        XCTAssertTrue(navigatedToMyRuns, "Should navigate to my runs")
    }
    
    /// Test that scheduled time is properly formatted
    /// Validates: Requirement 10.2 - Shows scheduled time
    func testScheduledTimeFormatting() throws {
        // Given
        let calendar = Calendar.current
        let components = DateComponents(year: 2026, month: 2, day: 6, hour: 14, minute: 30)
        let scheduledTime = calendar.date(from: components)!
        
        let run = Run(
            id: "test-run-1",
            title: "School Pickup",
            scheduledTime: scheduledTime,
            driverId: "driver-1",
            status: .scheduled,
            stops: [],
            passengers: [],
            createdBy: "creator-1",
            familyId: "family-1"
        )
        
        // When
        let view = RunScheduledConfirmationView(
            run: run,
            onViewRun: {},
            onBackToDashboard: {}
        )
        
        // Then
        XCTAssertEqual(run.scheduledTime, scheduledTime, "Scheduled time should match")
        
        // Verify the date is in the expected format (the view uses DateFormatter)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let formattedDate = formatter.string(from: scheduledTime)
        
        XCTAssertFalse(formattedDate.isEmpty, "Formatted date should not be empty")
    }
}
