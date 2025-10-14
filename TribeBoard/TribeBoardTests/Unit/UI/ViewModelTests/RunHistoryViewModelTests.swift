import XCTest
import SwiftUI
import Combine
@testable import TribeBoard

/// Comprehensive unit tests for RunHistoryViewModel covering filtering, search, and sorting functionality
@MainActor
class RunHistoryViewModelTests: TestBase {
    
    // MARK: - Properties
    
    var viewModel: RunHistoryViewModel!
    var mockManager: SchoolRunManager!
    var mockStorage: UserDefaults!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Create mock UserDefaults for testing
        mockStorage = UserDefaults(suiteName: "RunHistoryViewModelTests")!
        mockStorage.removePersistentDomain(forName: "RunHistoryViewModelTests")
        
        // Create mock manager with test storage
        mockManager = SchoolRunManager(storage: mockStorage)
        
        // Create view model with mock manager
        viewModel = RunHistoryViewModel(manager: mockManager)
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
        XCTAssertEqual(viewModel.historicalRuns.count, 0)
        XCTAssertEqual(viewModel.filteredRuns.count, 0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertEqual(viewModel.selectedDateRange, .all)
        XCTAssertEqual(viewModel.selectedStatusFilter, .all)
        XCTAssertEqual(viewModel.sortOption, .dateDescending)
        XCTAssertFalse(viewModel.hasHistoricalRuns)
        XCTAssertFalse(viewModel.hasFilteredResults)
        XCTAssertEqual(viewModel.totalHistoricalRuns, 0)
        XCTAssertEqual(viewModel.filteredRunsCount, 0)
        XCTAssertFalse(viewModel.hasActiveFilters)
    }
    
    func testInitialization_WithCustomManager() async {
        // Given
        let customStorage = UserDefaults(suiteName: "CustomHistoryTest")!
        let customManager = SchoolRunManager(storage: customStorage)
        
        // When
        let customViewModel = RunHistoryViewModel(manager: customManager)
        
        // Then
        XCTAssertNotNil(customViewModel)
        XCTAssertEqual(customViewModel.historicalRuns.count, 0)
        
        // Cleanup
        customStorage.removePersistentDomain(forName: "CustomHistoryTest")
    }
    
    // MARK: - Historical Runs Loading Tests
    
    func testLoadHistoricalRuns_OnlyCompletedAndCancelled() async {
        // Given
        let scheduledRun = createMockRun(title: "Scheduled Run", status: .scheduled)
        let inProgressRun = createMockRun(title: "In Progress Run", status: .inProgress)
        let completedRun = createMockRun(title: "Completed Run", status: .completed)
        let cancelledRun = createMockRun(title: "Cancelled Run", status: .cancelled)
        
        try! mockManager.createRun(scheduledRun)
        try! mockManager.createRun(inProgressRun)
        try! mockManager.createRun(completedRun)
        try! mockManager.createRun(cancelledRun)
        
        // When
        viewModel.loadHistoricalRuns()
        
        // Wait for async loading
        let expectation = XCTestExpectation(description: "Loading completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertEqual(viewModel.historicalRuns.count, 2)
        XCTAssertEqual(viewModel.filteredRuns.count, 2)
        XCTAssertTrue(viewModel.historicalRuns.contains { $0.title == "Completed Run" })
        XCTAssertTrue(viewModel.historicalRuns.contains { $0.title == "Cancelled Run" })
        XCTAssertFalse(viewModel.historicalRuns.contains { $0.title == "Scheduled Run" })
        XCTAssertFalse(viewModel.historicalRuns.contains { $0.title == "In Progress Run" })
        XCTAssertTrue(viewModel.hasHistoricalRuns)
        XCTAssertTrue(viewModel.hasFilteredResults)
    }
    
    // MARK: - Date Filtering Tests
    
    func testDateRangeFilter_LastWeek() async {
        // Given
        let now = Date()
        let lastWeek = Calendar.current.date(byAdding: .day, value: -5, to: now)!
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: now)!
        
        let recentRun = createMockRun(title: "Recent Run", date: lastWeek, status: .completed)
        let oldRun = createMockRun(title: "Old Run", date: lastMonth, status: .completed)
        
        try! mockManager.createRun(recentRun)
        try! mockManager.createRun(oldRun)
        viewModel.loadHistoricalRuns()
        
        // Wait for loading
        await waitForAsyncOperation()
        
        // When
        viewModel.applyDateRangeFilter(.lastWeek)
        
        // Then
        XCTAssertEqual(viewModel.filteredRuns.count, 1)
        XCTAssertEqual(viewModel.filteredRuns.first?.title, "Recent Run")
        XCTAssertEqual(viewModel.selectedDateRange, .lastWeek)
    }
    
    func testDateRangeFilter_LastMonth() async {
        // Given
        let now = Date()
        let lastWeek = Calendar.current.date(byAdding: .day, value: -5, to: now)!
        let lastMonth = Calendar.current.date(byAdding: .day, value: -20, to: now)!
        let lastYear = Calendar.current.date(byAdding: .year, value: -1, to: now)!
        
        let recentRun = createMockRun(title: "Recent Run", date: lastWeek, status: .completed)
        let monthRun = createMockRun(title: "Month Run", date: lastMonth, status: .completed)
        let yearRun = createMockRun(title: "Year Run", date: lastYear, status: .completed)
        
        try! mockManager.createRun(recentRun)
        try! mockManager.createRun(monthRun)
        try! mockManager.createRun(yearRun)
        viewModel.loadHistoricalRuns()
        
        await waitForAsyncOperation()
        
        // When
        viewModel.applyDateRangeFilter(.lastMonth)
        
        // Then
        XCTAssertEqual(viewModel.filteredRuns.count, 2)
        XCTAssertTrue(viewModel.filteredRuns.contains { $0.title == "Recent Run" })
        XCTAssertTrue(viewModel.filteredRuns.contains { $0.title == "Month Run" })
        XCTAssertFalse(viewModel.filteredRuns.contains { $0.title == "Year Run" })
    }
    
    func testDateRangeFilter_CustomRange() async {
        // Given
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -10, to: now)!
        let endDate = Calendar.current.date(byAdding: .day, value: -5, to: now)!
        let withinRange = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let outsideRange = Calendar.current.date(byAdding: .day, value: -15, to: now)!
        
        let withinRun = createMockRun(title: "Within Range", date: withinRange, status: .completed)
        let outsideRun = createMockRun(title: "Outside Range", date: outsideRange, status: .completed)
        
        try! mockManager.createRun(withinRun)
        try! mockManager.createRun(outsideRun)
        viewModel.loadHistoricalRuns()
        
        await waitForAsyncOperation()
        
        // When
        viewModel.setCustomDateRange(start: startDate, end: endDate)
        
        // Then
        XCTAssertEqual(viewModel.filteredRuns.count, 1)
        XCTAssertEqual(viewModel.filteredRuns.first?.title, "Within Range")
        XCTAssertEqual(viewModel.selectedDateRange, .custom)
    }
    
    // MARK: - Status Filtering Tests
    
    func testStatusFilter_CompletedOnly() async {
        // Given
        let completedRun = createMockRun(title: "Completed Run", status: .completed)
        let cancelledRun = createMockRun(title: "Cancelled Run", status: .cancelled)
        
        try! mockManager.createRun(completedRun)
        try! mockManager.createRun(cancelledRun)
        viewModel.loadHistoricalRuns()
        
        await waitForAsyncOperation()
        
        // When
        viewModel.applyStatusFilter(.completed)
        
        // Then
        XCTAssertEqual(viewModel.filteredRuns.count, 1)
        XCTAssertEqual(viewModel.filteredRuns.first?.title, "Completed Run")
        XCTAssertEqual(viewModel.selectedStatusFilter, .completed)
    }
    
    func testStatusFilter_CancelledOnly() async {
        // Given
        let completedRun = createMockRun(title: "Completed Run", status: .completed)
        let cancelledRun = createMockRun(title: "Cancelled Run", status: .cancelled)
        
        try! mockManager.createRun(completedRun)
        try! mockManager.createRun(cancelledRun)
        viewModel.loadHistoricalRuns()
        
        await waitForAsyncOperation()
        
        // When
        viewModel.applyStatusFilter(.cancelled)
        
        // Then
        XCTAssertEqual(viewModel.filteredRuns.count, 1)
        XCTAssertEqual(viewModel.filteredRuns.first?.title, "Cancelled Run")
        XCTAssertEqual(viewModel.selectedStatusFilter, .cancelled)
    }
    
    func testStatusFilter_All() async {
        // Given
        let completedRun = createMockRun(title: "Completed Run", status: .completed)
        let cancelledRun = createMockRun(title: "Cancelled Run", status: .cancelled)
        
        try! mockManager.createRun(completedRun)
        try! mockManager.createRun(cancelledRun)
        viewModel.loadHistoricalRuns()
        
        await waitForAsyncOperation()
        
        // When
        viewModel.applyStatusFilter(.all)
        
        // Then
        XCTAssertEqual(viewModel.filteredRuns.count, 2)
        XCTAssertEqual(viewModel.selectedStatusFilter, .all)
    }
    
    // MARK: - Search Functionality Tests
    
    func testSearchRuns_ByTitle() async {
        // Given
        let morningRun = createMockRun(title: "Morning School Run", status: .completed)
        let afternoonRun = createMockRun(title: "Afternoon Pickup", status: .completed)
        let eveningRun = createMockRun(title: "Evening Activities", status: .completed)
        
        try! mockManager.createRun(morningRun)
        try! mockManager.createRun(afternoonRun)
        try! mockManager.createRun(eveningRun)
        viewModel.loadHistoricalRuns()
        
        await waitForAsyncOperation()
        
        // When
        viewModel.searchRuns(query: "Morning")
        
        // Then
        XCTAssertEqual(viewModel.filteredRuns.count, 1)
        XCTAssertEqual(viewModel.filteredRuns.first?.title, "Morning School Run")
        XCTAssertEqual(viewModel.searchText, "Morning")
        XCTAssertTrue(viewModel.hasActiveFilters)
    }
    
    func testSearchRuns_ByStopName() async {
        // Given
        let homeStop = RunStop(name: "Home", time: Date(), note: "", type: .pickup)
        let schoolStop = RunStop(name: "Elementary School", time: Date(), note: "", type: .dropoff)
        let parkStop = RunStop(name: "City Park", time: Date(), note: "", type: .pickup)
        
        let schoolRun = SchoolRun(title: "School Run", date: Date(), route: [homeStop, schoolStop], status: .completed)
        let parkRun = SchoolRun(title: "Park Run", date: Date(), route: [homeStop, parkStop], status: .completed)
        
        try! mockManager.createRun(schoolRun)
        try! mockManager.createRun(parkRun)
        viewModel.loadHistoricalRuns()
        
        await waitForAsyncOperation()
        
        // When
        viewModel.searchRuns(query: "School")
        
        // Then
        XCTAssertEqual(viewModel.filteredRuns.count, 1)
        XCTAssertEqual(viewModel.filteredRuns.first?.title, "School Run")
    }
    
    func testSearchRuns_ByStopNote() async {
        // Given
        let stopWithNote = RunStop(name: "Stop 1", time: Date(), note: "Pick up Emma", type: .pickup)
        let stopWithoutNote = RunStop(name: "Stop 2", time: Date(), note: "", type: .dropoff)
        
        let runWithNote = SchoolRun(title: "Run 1", date: Date(), route: [stopWithNote], status: .completed)
        let runWithoutNote = SchoolRun(title: "Run 2", date: Date(), route: [stopWithoutNote], status: .completed)
        
        try! mockManager.createRun(runWithNote)
        try! mockManager.createRun(runWithoutNote)
        viewModel.loadHistoricalRuns()
        
        await waitForAsyncOperation()
        
        // When
        viewModel.searchRuns(query: "Emma")
        
        // Then
        XCTAssertEqual(viewModel.filteredRuns.count, 1)
        XCTAssertEqual(viewModel.filteredRuns.first?.title, "Run 1")
    }
    
    func testSearchRuns_CaseInsensitive() async {
        // Given
        let run = createMockRun(title: "Morning School Run", status: .completed)
        try! mockManager.createRun(run)
        viewModel.loadHistoricalRuns()
        
        await waitForAsyncOperation()
        
        // When
        viewModel.searchRuns(query: "MORNING")
        
        // Then
        XCTAssertEqual(viewModel.filteredRuns.count, 1)
        XCTAssertEqual(viewModel.filteredRuns.first?.title, "Morning School Run")
    }
    
    func testSearchRuns_NoResults() async {
        // Given
        let run = createMockRun(title: "Morning School Run", status: .completed)
        try! mockManager.createRun(run)
        viewModel.loadHistoricalRuns()
        
        await waitForAsyncOperation()
        
        // When
        viewModel.searchRuns(query: "Nonexistent")
        
        // Then
        XCTAssertEqual(viewModel.filteredRuns.count, 0)
        XCTAssertFalse(viewModel.hasFilteredResults)
    }
    
    // MARK: - Sorting Tests
    
    func testSortRuns_DateDescending() async {
        // Given
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let todayRun = createMockRun(title: "Today", date: today, status: .completed)
        let yesterdayRun = createMockRun(title: "Yesterday", date: yesterday, status: .completed)
        let tomorrowRun = createMockRun(title: "Tomorrow", date: tomorrow, status: .completed)
        
        try! mockManager.createRun(yesterdayRun)
        try! mockManager.createRun(tomorrowRun)
        try! mockManager.createRun(todayRun)
        viewModel.loadHistoricalRuns()
        
        await waitForAsyncOperation()
        
        // When
        viewModel.applySortOption(.dateDescending)
        
        // Then
        XCTAssertEqual(viewModel.filteredRuns.count, 3)
        XCTAssertEqual(viewModel.filteredRuns[0].title, "Tomorrow")
        XCTAssertEqual(viewModel.filteredRuns[1].title, "Today")
        XCTAssertEqual(viewModel.filteredRuns[2].title, "Yesterday")
    }
    
    func testSortRuns_DateAscending() async {
        // Given
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let todayRun = createMockRun(title: "Today", date: today, status: .completed)
        let yesterdayRun = createMockRun(title: "Yesterday", date: yesterday, status: .completed)
        let tomorrowRun = createMockRun(title: "Tomorrow", date: tomorrow, status: .completed)
        
        try! mockManager.createRun(tomorrowRun)
        try! mockManager.createRun(todayRun)
        try! mockManager.createRun(yesterdayRun)
        viewModel.loadHistoricalRuns()
        
        await waitForAsyncOperation()
        
        // When
        viewModel.applySortOption(.dateAscending)
        
        // Then
        XCTAssertEqual(viewModel.filteredRuns.count, 3)
        XCTAssertEqual(viewModel.filteredRuns[0].title, "Yesterday")
        XCTAssertEqual(viewModel.filteredRuns[1].title, "Today")
        XCTAssertEqual(viewModel.filteredRuns[2].title, "Tomorrow")
    }
    
    func testSortRuns_TitleAscending() async {
        // Given
        let runC = createMockRun(title: "Charlie Run", status: .completed)
        let runA = createMockRun(title: "Alpha Run", status: .completed)
        let runB = createMockRun(title: "Beta Run", status: .completed)
        
        try! mockManager.createRun(runC)
        try! mockManager.createRun(runA)
        try! mockManager.createRun(runB)
        viewModel.loadHistoricalRuns()
        
        await waitForAsyncOperation()
        
        // When
        viewModel.applySortOption(.titleAscending)
        
        // Then
        XCTAssertEqual(viewModel.filteredRuns.count, 3)
        XCTAssertEqual(viewModel.filteredRuns[0].title, "Alpha Run")
        XCTAssertEqual(viewModel.filteredRuns[1].title, "Beta Run")
        XCTAssertEqual(viewModel.filteredRuns[2].title, "Charlie Run")
    }
    
    func testSortRuns_TitleDescending() async {
        // Given
        let runA = createMockRun(title: "Alpha Run", status: .completed)
        let runB = createMockRun(title: "Beta Run", status: .completed)
        let runC = createMockRun(title: "Charlie Run", status: .completed)
        
        try! mockManager.createRun(runA)
        try! mockManager.createRun(runB)
        try! mockManager.createRun(runC)
        viewModel.loadHistoricalRuns()
        
        await waitForAsyncOperation()
        
        // When
        viewModel.applySortOption(.titleDescending)
        
        // Then
        XCTAssertEqual(viewModel.filteredRuns.count, 3)
        XCTAssertEqual(viewModel.filteredRuns[0].title, "Charlie Run")
        XCTAssertEqual(viewModel.filteredRuns[1].title, "Beta Run")
        XCTAssertEqual(viewModel.filteredRuns[2].title, "Alpha Run")
    }
    
    func testSortRuns_DurationAscending() async {
        // Given
        let shortRun = createMockRun(title: "Short Run", status: .completed, duration: 1800) // 30 minutes
        let longRun = createMockRun(title: "Long Run", status: .completed, duration: 3600) // 60 minutes
        let mediumRun = createMockRun(title: "Medium Run", status: .completed, duration: 2700) // 45 minutes
        
        try! mockManager.createRun(longRun)
        try! mockManager.createRun(shortRun)
        try! mockManager.createRun(mediumRun)
        viewModel.loadHistoricalRuns()
        
        await waitForAsyncOperation()
        
        // When
        viewModel.applySortOption(.durationAscending)
        
        // Then
        XCTAssertEqual(viewModel.filteredRuns.count, 3)
        XCTAssertEqual(viewModel.filteredRuns[0].title, "Short Run")
        XCTAssertEqual(viewModel.filteredRuns[1].title, "Medium Run")
        XCTAssertEqual(viewModel.filteredRuns[2].title, "Long Run")
    }
    
    func testSortRuns_DurationDescending() async {
        // Given
        let shortRun = createMockRun(title: "Short Run", status: .completed, duration: 1800) // 30 minutes
        let longRun = createMockRun(title: "Long Run", status: .completed, duration: 3600) // 60 minutes
        let mediumRun = createMockRun(title: "Medium Run", status: .completed, duration: 2700) // 45 minutes
        
        try! mockManager.createRun(shortRun)
        try! mockManager.createRun(mediumRun)
        try! mockManager.createRun(longRun)
        viewModel.loadHistoricalRuns()
        
        await waitForAsyncOperation()
        
        // When
        viewModel.applySortOption(.durationDescending)
        
        // Then
        XCTAssertEqual(viewModel.filteredRuns.count, 3)
        XCTAssertEqual(viewModel.filteredRuns[0].title, "Long Run")
        XCTAssertEqual(viewModel.filteredRuns[1].title, "Medium Run")
        XCTAssertEqual(viewModel.filteredRuns[2].title, "Short Run")
    }
    
    // MARK: - Run Detail Retrieval Tests
    
    func testGetRunDetail_Success() async {
        // Given
        let run = createMockRun(title: "Test Run", status: .completed)
        try! mockManager.createRun(run)
        viewModel.loadHistoricalRuns()
        
        await waitForAsyncOperation()
        
        // When
        let retrievedRun = viewModel.getRunDetail(id: run.id)
        
        // Then
        XCTAssertNotNil(retrievedRun)
        XCTAssertEqual(retrievedRun?.title, "Test Run")
        XCTAssertEqual(retrievedRun?.id, run.id)
    }
    
    func testGetRunDetail_NonExistent() {
        // Given
        let nonExistentId = UUID()
        
        // When
        let retrievedRun = viewModel.getRunDetail(id: nonExistentId)
        
        // Then
        XCTAssertNil(retrievedRun)
    }
    
    // MARK: - Combined Filtering Tests
    
    func testCombinedFilters_SearchAndDateRange() async {
        // Given
        let now = Date()
        let lastWeek = Calendar.current.date(byAdding: .day, value: -5, to: now)!
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: now)!
        
        let recentMorningRun = createMockRun(title: "Morning Run", date: lastWeek, status: .completed)
        let recentAfternoonRun = createMockRun(title: "Afternoon Run", date: lastWeek, status: .completed)
        let oldMorningRun = createMockRun(title: "Morning Run", date: lastMonth, status: .completed)
        
        try! mockManager.createRun(recentMorningRun)
        try! mockManager.createRun(recentAfternoonRun)
        try! mockManager.createRun(oldMorningRun)
        viewModel.loadHistoricalRuns()
        
        await waitForAsyncOperation()
        
        // When
        viewModel.searchRuns(query: "Morning")
        viewModel.applyDateRangeFilter(.lastWeek)
        
        // Then
        XCTAssertEqual(viewModel.filteredRuns.count, 1)
        XCTAssertEqual(viewModel.filteredRuns.first?.title, "Morning Run")
        XCTAssertEqual(viewModel.filteredRuns.first?.date, lastWeek)
        XCTAssertTrue(viewModel.hasActiveFilters)
    }
    
    func testCombinedFilters_SearchAndStatus() async {
        // Given
        let completedMorningRun = createMockRun(title: "Morning Run", status: .completed)
        let cancelledMorningRun = createMockRun(title: "Morning Run", status: .cancelled)
        let completedAfternoonRun = createMockRun(title: "Afternoon Run", status: .completed)
        
        try! mockManager.createRun(completedMorningRun)
        try! mockManager.createRun(cancelledMorningRun)
        try! mockManager.createRun(completedAfternoonRun)
        viewModel.loadHistoricalRuns()
        
        await waitForAsyncOperation()
        
        // When
        viewModel.searchRuns(query: "Morning")
        viewModel.applyStatusFilter(.completed)
        
        // Then
        XCTAssertEqual(viewModel.filteredRuns.count, 1)
        XCTAssertEqual(viewModel.filteredRuns.first?.title, "Morning Run")
        XCTAssertEqual(viewModel.filteredRuns.first?.status, .completed)
    }
    
    // MARK: - Clear Filters Tests
    
    func testClearFilters() async {
        // Given
        let run = createMockRun(title: "Test Run", status: .completed)
        try! mockManager.createRun(run)
        viewModel.loadHistoricalRuns()
        
        await waitForAsyncOperation()
        
        // Apply some filters
        viewModel.searchRuns(query: "Test")
        viewModel.applyDateRangeFilter(.lastWeek)
        viewModel.applyStatusFilter(.completed)
        viewModel.applySortOption(.titleAscending)
        
        XCTAssertTrue(viewModel.hasActiveFilters)
        
        // When
        viewModel.clearFilters()
        
        // Then
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertEqual(viewModel.selectedDateRange, .all)
        XCTAssertEqual(viewModel.selectedStatusFilter, .all)
        XCTAssertEqual(viewModel.sortOption, .dateDescending)
        XCTAssertFalse(viewModel.hasActiveFilters)
    }
    
    // MARK: - Statistics Tests
    
    func testRunStatistics() async {
        // Given
        let completedRun1 = createMockRun(title: "Completed 1", status: .completed, duration: 1800)
        let completedRun2 = createMockRun(title: "Completed 2", status: .completed, duration: 2700)
        let cancelledRun = createMockRun(title: "Cancelled", status: .cancelled, duration: 1200)
        
        try! mockManager.createRun(completedRun1)
        try! mockManager.createRun(completedRun2)
        try! mockManager.createRun(cancelledRun)
        viewModel.loadHistoricalRuns()
        
        await waitForAsyncOperation()
        
        // When
        let statistics = viewModel.runStatistics
        
        // Then
        XCTAssertEqual(statistics.totalRuns, 3)
        XCTAssertEqual(statistics.completedRuns, 2)
        XCTAssertEqual(statistics.cancelledRuns, 1)
        XCTAssertEqual(statistics.totalDuration, 5700) // 1800 + 2700 + 1200
        XCTAssertEqual(statistics.averageDuration, 1900) // 5700 / 3
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling_ClearError() {
        // Given
        viewModel.errorMessage = "Test error"
        
        // When
        viewModel.clearError()
        
        // Then
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Refresh Tests
    
    func testRefresh() async {
        // Given
        let run = createMockRun(title: "Test Run", status: .completed)
        try! mockManager.createRun(run)
        
        // When
        viewModel.refresh()
        
        // Wait for async loading
        await waitForAsyncOperation()
        
        // Then
        XCTAssertEqual(viewModel.historicalRuns.count, 1)
        XCTAssertEqual(viewModel.filteredRuns.count, 1)
    }
    
    // MARK: - Helper Methods
    
    private func createMockRun(
        title: String,
        date: Date = Date(),
        status: RunStatus = .scheduled,
        duration: TimeInterval = 1800
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
            status: status,
            estimatedDuration: duration
        )
    }
    
    private func waitForAsyncOperation() async {
        let expectation = XCTestExpectation(description: "Async operation completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}