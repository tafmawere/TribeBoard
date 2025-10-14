import XCTest
import SwiftUI
@testable import TribeBoard

/// Comprehensive unit tests for SchoolRunViewModel covering all functionality
@MainActor
class SchoolRunViewModelTests: TestBase {
    
    // MARK: - Properties
    
    var viewModel: SchoolRunViewModel!
    var mockManager: SchoolRunManager!
    var mockStorage: UserDefaults!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Create mock UserDefaults for testing
        mockStorage = UserDefaults(suiteName: "SchoolRunViewModelTests")!
        mockStorage.removePersistentDomain(forName: "SchoolRunViewModelTests")
        
        // Create mock manager with test storage
        mockManager = SchoolRunManager(storage: mockStorage)
        
        // Create view model with mock manager
        viewModel = SchoolRunViewModel(manager: mockManager)
    }
    
    override func tearDown() {
        mockManager.clearStorage()
        viewModel = nil
        mockManager = nil
        mockStorage = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization_DefaultState() {
        // Then
        XCTAssertEqual(viewModel.runs.count, 0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.todaysRuns.count, 0)
        XCTAssertEqual(viewModel.upcomingRuns.count, 0)
        XCTAssertEqual(viewModel.completedRuns.count, 0)
        XCTAssertNil(viewModel.activeRun)
        XCTAssertFalse(viewModel.hasActiveRun)
        XCTAssertEqual(viewModel.totalRuns, 0)
    }
    
    func testInitialization_WithCustomManager() async {
        // Given
        let customStorage = UserDefaults(suiteName: "CustomTest")!
        let customManager = SchoolRunManager(storage: customStorage)
        
        // When
        let customViewModel = SchoolRunViewModel(manager: customManager)
        
        // Then
        XCTAssertNotNil(customViewModel)
        XCTAssertEqual(customViewModel.runs.count, 0)
        
        // Cleanup
        customStorage.removePersistentDomain(forName: "CustomTest")
    }
    
    // MARK: - Run Filtering Tests
    
    func testTodaysRuns_FilteringLogic() async {
        // Given
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let todayRun = createMockRun(title: "Today's Run", date: today)
        let yesterdayRun = createMockRun(title: "Yesterday's Run", date: yesterday)
        let tomorrowRun = createMockRun(title: "Tomorrow's Run", date: tomorrow)
        
        // When
        await viewModel.createRun(todayRun)
        await viewModel.createRun(yesterdayRun)
        await viewModel.createRun(tomorrowRun)
        
        // Then
        XCTAssertEqual(viewModel.todaysRuns.count, 1)
        XCTAssertEqual(viewModel.todaysRuns.first?.title, "Today's Run")
    }
    
    func testUpcomingRuns_FilteringLogic() async {
        // Given
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: today)!
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        
        let todayRun = createMockRun(title: "Today's Run", date: today)
        let tomorrowRun = createMockRun(title: "Tomorrow's Run", date: tomorrow)
        let nextWeekRun = createMockRun(title: "Next Week's Run", date: nextWeek)
        let yesterdayRun = createMockRun(title: "Yesterday's Run", date: yesterday)
        
        // When
        await viewModel.createRun(todayRun)
        await viewModel.createRun(tomorrowRun)
        await viewModel.createRun(nextWeekRun)
        await viewModel.createRun(yesterdayRun)
        
        // Then
        let upcomingRuns = viewModel.upcomingRuns
        XCTAssertEqual(upcomingRuns.count, 2)
        XCTAssertTrue(upcomingRuns.contains { $0.title == "Tomorrow's Run" })
        XCTAssertTrue(upcomingRuns.contains { $0.title == "Next Week's Run" })
        XCTAssertFalse(upcomingRuns.contains { $0.title == "Today's Run" })
        XCTAssertFalse(upcomingRuns.contains { $0.title == "Yesterday's Run" })
    }
    
    func testCompletedRuns_FilteringLogic() async {
        // Given
        let scheduledRun = createMockRun(title: "Scheduled Run", status: .scheduled)
        let inProgressRun = createMockRun(title: "In Progress Run", status: .inProgress)
        let completedRun = createMockRun(title: "Completed Run", status: .completed)
        let cancelledRun = createMockRun(title: "Cancelled Run", status: .cancelled)
        
        // When
        await viewModel.createRun(scheduledRun)
        await viewModel.createRun(inProgressRun)
        await viewModel.createRun(completedRun)
        await viewModel.createRun(cancelledRun)
        
        // Then
        let completedRuns = viewModel.completedRuns
        XCTAssertEqual(completedRuns.count, 1)
        XCTAssertEqual(completedRuns.first?.title, "Completed Run")
    }
    
    func testScheduledRuns_FilteringLogic() async {
        // Given
        let scheduledRun1 = createMockRun(title: "Scheduled Run 1", status: .scheduled)
        let scheduledRun2 = createMockRun(title: "Scheduled Run 2", status: .scheduled)
        let completedRun = createMockRun(title: "Completed Run", status: .completed)
        let inProgressRun = createMockRun(title: "In Progress Run", status: .inProgress)
        
        // When
        await viewModel.createRun(scheduledRun1)
        await viewModel.createRun(scheduledRun2)
        await viewModel.createRun(completedRun)
        await viewModel.createRun(inProgressRun)
        
        // Then
        let scheduledRuns = viewModel.scheduledRuns
        XCTAssertEqual(scheduledRuns.count, 2)
        XCTAssertTrue(scheduledRuns.contains { $0.title == "Scheduled Run 1" })
        XCTAssertTrue(scheduledRuns.contains { $0.title == "Scheduled Run 2" })
    }
    
    // MARK: - CRUD Operations Tests
    
    func testCreateRun_Success() async {
        // Given
        let newRun = createMockRun(title: "New Test Run")
        
        // When
        await viewModel.createRun(newRun)
        
        // Then
        XCTAssertEqual(viewModel.runs.count, 1)
        XCTAssertEqual(viewModel.runs.first?.title, "New Test Run")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testCreateRun_InvalidData() async {
        // Given
        let invalidRun = SchoolRun(
            title: "", // Invalid empty title
            date: Date(),
            route: [] // Invalid empty route
        )
        
        // When
        await viewModel.createRun(invalidRun)
        
        // Then
        XCTAssertEqual(viewModel.runs.count, 0)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testDeleteRun_Success() async {
        // Given
        let run1 = createMockRun(title: "Run 1")
        let run2 = createMockRun(title: "Run 2")
        
        await viewModel.createRun(run1)
        await viewModel.createRun(run2)
        XCTAssertEqual(viewModel.runs.count, 2)
        
        // When
        await viewModel.deleteRun(run1)
        
        // Then
        XCTAssertEqual(viewModel.runs.count, 1)
        XCTAssertEqual(viewModel.runs.first?.title, "Run 2")
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testDeleteRun_ById() async {
        // Given
        let run = createMockRun(title: "Test Run")
        await viewModel.createRun(run)
        XCTAssertEqual(viewModel.runs.count, 1)
        
        // When
        await viewModel.deleteRun(id: run.id)
        
        // Then
        XCTAssertEqual(viewModel.runs.count, 0)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testDeleteRun_NonExistent() async {
        // Given
        let nonExistentId = UUID()
        
        // When
        await viewModel.deleteRun(id: nonExistentId)
        
        // Then
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("not found") == true)
    }
    
    func testStartRun_Success() async {
        // Given
        let run = createMockRun(title: "Test Run", status: .scheduled)
        await viewModel.createRun(run)
        
        // When
        await viewModel.startRun(run)
        
        // Then
        XCTAssertNotNil(viewModel.activeRun)
        XCTAssertEqual(viewModel.activeRun?.status, .inProgress)
        XCTAssertTrue(viewModel.hasActiveRun)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testCompleteRun_Success() async {
        // Given
        let run = createMockRun(title: "Test Run", status: .scheduled)
        await viewModel.createRun(run)
        await viewModel.startRun(run)
        
        // When
        await viewModel.completeRun(run)
        
        // Then
        XCTAssertNil(viewModel.activeRun)
        XCTAssertFalse(viewModel.hasActiveRun)
        
        let completedRun = viewModel.runs.first { $0.id == run.id }
        XCTAssertEqual(completedRun?.status, .completed)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testCancelRun_Success() async {
        // Given
        let run = createMockRun(title: "Test Run", status: .scheduled)
        await viewModel.createRun(run)
        
        // When
        await viewModel.cancelRun(run)
        
        // Then
        let cancelledRun = viewModel.runs.first { $0.id == run.id }
        XCTAssertEqual(cancelledRun?.status, .cancelled)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Error State Management Tests
    
    func testErrorHandling_CreateRunError() async {
        // Given
        let invalidRun = SchoolRun(title: "", date: Date(), route: [])
        
        // When
        await viewModel.createRun(invalidRun)
        
        // Then
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testErrorHandling_ClearError() {
        // Given
        viewModel.errorMessage = "Test error"
        
        // When
        viewModel.clearError()
        
        // Then
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testErrorHandling_MultipleOperations() async {
        // Given
        let validRun = createMockRun(title: "Valid Run")
        let invalidRun = SchoolRun(title: "", date: Date(), route: [])
        
        // When - First operation succeeds
        await viewModel.createRun(validRun)
        XCTAssertNil(viewModel.errorMessage)
        
        // When - Second operation fails
        await viewModel.createRun(invalidRun)
        XCTAssertNotNil(viewModel.errorMessage)
        
        // When - Clear error and try valid operation
        viewModel.clearError()
        let anotherValidRun = createMockRun(title: "Another Valid Run")
        await viewModel.createRun(anotherValidRun)
        
        // Then
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.runs.count, 2)
    }
    
    // MARK: - Loading State Tests
    
    func testLoadingState_LoadRuns() {
        // Given
        XCTAssertFalse(viewModel.isLoading)
        
        // When
        viewModel.loadRuns()
        
        // Then - Loading state should be managed properly
        // Note: Due to async nature, we test that loading eventually completes
        let expectation = XCTestExpectation(description: "Loading completes")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.viewModel.isLoading)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testLoadingState_CreateRun() async {
        // Given
        let run = createMockRun(title: "Test Run")
        
        // When
        await viewModel.createRun(run)
        
        // Then - Loading should be false after completion
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - Data Retrieval Tests
    
    func testGetRun_ById() async {
        // Given
        let run = createMockRun(title: "Test Run")
        await viewModel.createRun(run)
        
        // When
        let retrievedRun = viewModel.getRun(id: run.id)
        
        // Then
        XCTAssertNotNil(retrievedRun)
        XCTAssertEqual(retrievedRun?.title, "Test Run")
        XCTAssertEqual(retrievedRun?.id, run.id)
    }
    
    func testGetRun_NonExistent() {
        // Given
        let nonExistentId = UUID()
        
        // When
        let retrievedRun = viewModel.getRun(id: nonExistentId)
        
        // Then
        XCTAssertNil(retrievedRun)
    }
    
    func testGetRuns_ForDate() async {
        // Given
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let todayRun = createMockRun(title: "Today's Run", date: today)
        let tomorrowRun = createMockRun(title: "Tomorrow's Run", date: tomorrow)
        
        await viewModel.createRun(todayRun)
        await viewModel.createRun(tomorrowRun)
        
        // When
        let todayRuns = viewModel.getRuns(for: today)
        
        // Then
        XCTAssertEqual(todayRuns.count, 1)
        XCTAssertEqual(todayRuns.first?.title, "Today's Run")
    }
    
    func testGetRuns_DateRange() async {
        // Given
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: today)!
        
        let yesterdayRun = createMockRun(title: "Yesterday's Run", date: yesterday)
        let todayRun = createMockRun(title: "Today's Run", date: today)
        let tomorrowRun = createMockRun(title: "Tomorrow's Run", date: tomorrow)
        let nextWeekRun = createMockRun(title: "Next Week's Run", date: nextWeek)
        
        await viewModel.createRun(yesterdayRun)
        await viewModel.createRun(todayRun)
        await viewModel.createRun(tomorrowRun)
        await viewModel.createRun(nextWeekRun)
        
        // When
        let rangeRuns = viewModel.getRuns(from: today, to: tomorrow)
        
        // Then
        XCTAssertEqual(rangeRuns.count, 2)
        XCTAssertTrue(rangeRuns.contains { $0.title == "Today's Run" })
        XCTAssertTrue(rangeRuns.contains { $0.title == "Tomorrow's Run" })
    }
    
    // MARK: - Refresh Tests
    
    func testRefresh() async {
        // Given
        let run = createMockRun(title: "Test Run")
        await viewModel.createRun(run)
        XCTAssertEqual(viewModel.runs.count, 1)
        
        // When
        viewModel.refresh()
        
        // Then - Should reload data from manager
        let expectation = XCTestExpectation(description: "Refresh completes")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.viewModel.runs.count, 1)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func createMockRun(
        title: String,
        date: Date = Date(),
        status: RunStatus = .scheduled
    ) -> SchoolRun {
        let stop = RunStop(
            name: "Test Stop",
            time: date,
            note: "Test note",
            type: .pickup
        )
        
        return SchoolRun(
            title: title,
            date: date,
            route: [stop],
            status: status
        )
    }
}

// MARK: - String Extension for Testing
private extension String {
    func repeated(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}