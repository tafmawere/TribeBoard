//
//  ActivityStreamTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/04.
//

import XCTest
@testable import Tribeboard

/// Tests for Activity Stream functionality
/// Validates Requirements 8.1, 8.2, 8.3, 8.4, 8.5
@MainActor
final class ActivityStreamTests: XCTestCase {
    
    var viewModel: ActivityStreamViewModel!
    var mockRunEventService: RunEventService!
    var mockFirebaseService: MockFirebaseRunService!
    let testRunId = "test-run-id"
    
    override func setUp() {
        super.setUp()
        mockFirebaseService = MockFirebaseRunService()
        mockRunEventService = RunEventService(firebaseService: mockFirebaseService)
        viewModel = ActivityStreamViewModel(runId: testRunId, runEventService: mockRunEventService)
    }
    
    override func tearDown() {
        viewModel = nil
        mockRunEventService = nil
        mockFirebaseService = nil
        super.tearDown()
    }
    
    // MARK: - Event Loading Tests
    
    func testLoadEvents() {
        // Given
        XCTAssertTrue(viewModel.events.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        
        // When
        viewModel.loadEvents()
        
        // Then
        XCTAssertTrue(viewModel.isLoading)
    }
    
    func testEventAcknowledgment() {
        // Given
        let eventId = "test-event-id"
        XCTAssertFalse(viewModel.isEventAcknowledged(eventId))
        
        // When
        viewModel.acknowledgeEvent(eventId)
        
        // Then
        XCTAssertTrue(viewModel.isEventAcknowledged(eventId))
        XCTAssertTrue(viewModel.acknowledgedEvents.contains(eventId))
    }
    
    func testAddComment() {
        // Given
        let eventId = "test-event-id"
        let comment = "This is a test comment"
        XCTAssertNil(viewModel.getComment(for: eventId))
        
        // When
        viewModel.addComment(to: eventId, comment: comment)
        
        // Then
        XCTAssertEqual(viewModel.getComment(for: eventId), comment)
        XCTAssertEqual(viewModel.eventComments[eventId], comment)
    }
    
    func testAddEmptyComment() {
        // Given
        let eventId = "test-event-id"
        let emptyComment = "   "
        
        // When
        viewModel.addComment(to: eventId, comment: emptyComment)
        
        // Then
        XCTAssertNil(viewModel.getComment(for: eventId))
    }
    
    // MARK: - Event Sorting Tests
    
    func testEventSorting() {
        // Given
        let now = Date()
        let event1 = RunEvent(
            runId: testRunId,
            type: .runStarted,
            timestamp: now.addingTimeInterval(-3600), // 1 hour ago
            actorId: "driver1",
            stateBefore: .scheduled,
            stateAfter: .activeEnroute,
            currentStopIndex: 0
        )
        
        let event2 = RunEvent(
            runId: testRunId,
            type: .runCompleted,
            timestamp: now, // now
            actorId: "driver1",
            stateBefore: .activeEnroute,
            stateAfter: .completed,
            currentStopIndex: 1
        )
        
        // When
        viewModel.events = [event1, event2]
        let sortedEvents = viewModel.sortedEvents
        
        // Then
        XCTAssertEqual(sortedEvents.count, 2)
        XCTAssertEqual(sortedEvents.first?.id, event2.id) // Most recent first
        XCTAssertEqual(sortedEvents.last?.id, event1.id)
    }
    
    // MARK: - Date Formatting Tests
    
    func testTimestampFormatting() {
        // Given
        let date = Date()
        
        // When
        let formattedTime = viewModel.formatTimestamp(date)
        let formattedDate = viewModel.formatDate(date)
        
        // Then
        XCTAssertFalse(formattedTime.isEmpty)
        XCTAssertFalse(formattedDate.isEmpty)
        
        // Verify time format doesn't include date
        XCTAssertFalse(formattedTime.contains("/"))
        
        // Verify date format doesn't include time
        XCTAssertFalse(formattedDate.contains(":"))
    }
    
    // MARK: - Events by Date Tests
    
    func testEventsByDate() {
        // Given
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        
        let todayEvent = RunEvent(
            runId: testRunId,
            type: .runStarted,
            timestamp: today,
            actorId: "driver1",
            stateBefore: .scheduled,
            stateAfter: .activeEnroute,
            currentStopIndex: 0
        )
        
        let yesterdayEvent = RunEvent(
            runId: testRunId,
            type: .runCompleted,
            timestamp: yesterday,
            actorId: "driver1",
            stateBefore: .activeEnroute,
            stateAfter: .completed,
            currentStopIndex: 1
        )
        
        // When
        viewModel.events = [todayEvent, yesterdayEvent]
        let eventsByDate = viewModel.eventsByDate
        
        // Then
        XCTAssertEqual(eventsByDate.keys.count, 2)
        
        let todayStart = Calendar.current.startOfDay(for: today)
        let yesterdayStart = Calendar.current.startOfDay(for: yesterday)
        
        XCTAssertNotNil(eventsByDate[todayStart])
        XCTAssertNotNil(eventsByDate[yesterdayStart])
        XCTAssertEqual(eventsByDate[todayStart]?.count, 1)
        XCTAssertEqual(eventsByDate[yesterdayStart]?.count, 1)
    }
}

// MARK: - Run Completion Summary Tests

final class RunCompletionSummaryTests: XCTestCase {
    
    func testRunCompletionSummaryCreation() {
        // Given
        let run = createSampleRun()
        let events = createSampleEvents(for: run.id)
        
        // When - Create the view (this tests that it can be instantiated)
        let summaryView = RunCompletionSummaryView(run: run, events: events)
        
        // Then - Verify the view was created successfully
        XCTAssertNotNil(summaryView)
    }
    
    // MARK: - Helper Methods
    
    private func createSampleRun() -> Run {
        return Run(
            title: "Test Run",
            scheduledTime: Date().addingTimeInterval(-3600),
            driverId: "driver1",
            status: .completed,
            stops: [
                RunStop(
                    type: .pickup,
                    label: "School",
                    scheduledTime: Date().addingTimeInterval(-3600),
                    requiredPassengerIds: ["child1"],
                    location: LocationData(latitude: 37.7749, longitude: -122.4194)
                )
            ],
            passengers: [
                MemberSummary(
                    id: "child1",
                    displayName: "Test Child",
                    role: .passenger,
                    status: .droppedOff
                )
            ],
            createdBy: "parent1",
            familyId: "family1",
            startTime: Date().addingTimeInterval(-3600)
        )
    }
    
    private func createSampleEvents(for runId: String) -> [RunEvent] {
        return [
            RunEvent(
                runId: runId,
                type: .runStarted,
                timestamp: Date().addingTimeInterval(-3600),
                actorId: "driver1",
                stateBefore: .scheduled,
                stateAfter: .activeEnroute,
                currentStopIndex: 0
            ),
            RunEvent(
                runId: runId,
                type: .runCompleted,
                timestamp: Date().addingTimeInterval(-1800),
                actorId: "driver1",
                stateBefore: .activeEnroute,
                stateAfter: .completed,
                currentStopIndex: 1
            )
        ]
    }
}