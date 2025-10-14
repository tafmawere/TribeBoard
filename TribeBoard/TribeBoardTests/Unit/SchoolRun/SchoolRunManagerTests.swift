import XCTest
@testable import TribeBoard

/// Comprehensive unit tests for SchoolRunManager covering CRUD operations, data persistence, and state management
class SchoolRunManagerTests: TestBase {
    
    // MARK: - Properties
    
    var manager: SchoolRunManager!
    var testUserDefaults: UserDefaults!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Create a test UserDefaults instance
        testUserDefaults = UserDefaults(suiteName: "SchoolRunManagerTests")!
        testUserDefaults.removePersistentDomain(forName: "SchoolRunManagerTests")
        
        // Initialize manager with test storage
        manager = SchoolRunManager(storage: testUserDefaults)
    }
    
    override func tearDown() {
        // Clean up test data
        testUserDefaults.removePersistentDomain(forName: "SchoolRunManagerTests")
        manager = nil
        testUserDefaults = nil
        
        super.tearDown()
    }
    
    // MARK: - Test Data Helpers
    
    private func createTestRun(title: String = "Test Run",
                              date: Date = Date().addingTimeInterval(3600),
                              status: RunStatus = .scheduled) -> SchoolRun {
        let stops = [
            RunStop(name: "Home", time: date, type: .pickup),
            RunStop(name: "School", time: date.addingTimeInterval(1800), type: .dropoff)
        ]
        
        return SchoolRun(
            title: title,
            date: date,
            route: stops,
            status: status
        )
    }
    
    private func createTestRunWithMultipleStops() -> SchoolRun {
        let baseDate = Date().addingTimeInterval(3600)
        let stops = [
            RunStop(name: "Home", time: baseDate, type: .pickup),
            RunStop(name: "Friend's House", time: baseDate.addingTimeInterval(600), type: .pickup),
            RunStop(name: "School", time: baseDate.addingTimeInterval(1200), type: .dropoff),
            RunStop(name: "After School Club", time: baseDate.addingTimeInterval(1800), type: .dropoff)
        ]
        
        return SchoolRun(
            title: "Multi-Stop Run",
            date: baseDate,
            route: stops,
            status: .scheduled
        )
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization_EmptyState() {
        // Then
        XCTAssertTrue(manager.runs.isEmpty, "Manager should start with empty runs")
        XCTAssertNil(manager.activeRun, "Manager should start with no active run")
        XCTAssertFalse(manager.isLoading, "Manager should not be loading initially")
        XCTAssertNil(manager.errorMessage, "Manager should have no error message initially")
    }
    
    func testInitialization_LoadsExistingData() {
        // Given
        let testRun = createTestRun()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try! encoder.encode([testRun])
        testUserDefaults.set(data, forKey: "school_runs_data")
        
        // When
        let newManager = SchoolRunManager(storage: testUserDefaults)
        
        // Then
        XCTAssertEqual(newManager.runs.count, 1)
        XCTAssertEqual(newManager.runs.first?.title, testRun.title)
    }
    
    // MARK: - CRUD Operations Tests
    
    func testCreateRun_Success() throws {
        // Given
        let testRun = createTestRun()
        
        // When
        try manager.createRun(testRun)
        
        // Then
        XCTAssertEqual(manager.runs.count, 1)
        XCTAssertEqual(manager.runs.first?.id, testRun.id)
        XCTAssertEqual(manager.runs.first?.title, testRun.title)
        XCTAssertNil(manager.errorMessage)
    }
    
    func testCreateRun_InvalidData_EmptyTitle() {
        // Given
        var testRun = createTestRun()
        testRun.title = ""
        
        // When & Then
        XCTAssertThrowsError(try manager.createRun(testRun)) { error in
            XCTAssertEqual(error as? SchoolRunError, .invalidRunData)
        }
        
        XCTAssertTrue(manager.runs.isEmpty)
    }
    
    func testCreateRun_InvalidData_EmptyRoute() {
        // Given
        var testRun = createTestRun()
        testRun.route = []
        
        // When & Then
        XCTAssertThrowsError(try manager.createRun(testRun)) { error in
            XCTAssertEqual(error as? SchoolRunError, .invalidRunData)
        }
        
        XCTAssertTrue(manager.runs.isEmpty)
    }
    
    func testCreateRun_InvalidData_OldDate() {
        // Given
        let oldDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        let testRun = createTestRun(date: oldDate)
        
        // When & Then
        XCTAssertThrowsError(try manager.createRun(testRun)) { error in
            XCTAssertEqual(error as? SchoolRunError, .invalidRunData)
        }
        
        XCTAssertTrue(manager.runs.isEmpty)
    }
    
    func testCreateRun_DuplicateId() throws {
        // Given
        let testRun = createTestRun()
        try manager.createRun(testRun)
        
        // When & Then
        XCTAssertThrowsError(try manager.createRun(testRun)) { error in
            XCTAssertEqual(error as? SchoolRunError, .invalidRunData)
        }
        
        XCTAssertEqual(manager.runs.count, 1)
    }
    
    func testGetRun_ExistingRun() throws {
        // Given
        let testRun = createTestRun()
        try manager.createRun(testRun)
        
        // When
        let retrievedRun = manager.getRun(id: testRun.id)
        
        // Then
        XCTAssertNotNil(retrievedRun)
        XCTAssertEqual(retrievedRun?.id, testRun.id)
        XCTAssertEqual(retrievedRun?.title, testRun.title)
    }
    
    func testGetRun_NonExistentRun() {
        // Given
        let nonExistentId = UUID()
        
        // When
        let retrievedRun = manager.getRun(id: nonExistentId)
        
        // Then
        XCTAssertNil(retrievedRun)
    }
    
    func testUpdateRun_Success() throws {
        // Given
        let testRun = createTestRun()
        try manager.createRun(testRun)
        
        var updatedRun = testRun
        updatedRun.title = "Updated Title"
        
        // When
        try manager.updateRun(updatedRun)
        
        // Then
        XCTAssertEqual(manager.runs.count, 1)
        XCTAssertEqual(manager.runs.first?.title, "Updated Title")
        XCTAssertNil(manager.errorMessage)
    }
    
    func testUpdateRun_NonExistentRun() {
        // Given
        let nonExistentRun = createTestRun()
        
        // When & Then
        XCTAssertThrowsError(try manager.updateRun(nonExistentRun)) { error in
            XCTAssertEqual(error as? SchoolRunError, .runNotFound)
        }
    }
    
    func testUpdateRun_UpdatesActiveRun() throws {
        // Given
        let testRun = createTestRun()
        try manager.createRun(testRun)
        try manager.startRun(id: testRun.id)
        
        var updatedRun = testRun
        updatedRun.title = "Updated Active Run"
        
        // When
        try manager.updateRun(updatedRun)
        
        // Then
        XCTAssertEqual(manager.activeRun?.title, "Updated Active Run")
    }
    
    func testDeleteRun_Success() throws {
        // Given
        let testRun = createTestRun()
        try manager.createRun(testRun)
        
        // When
        try manager.deleteRun(id: testRun.id)
        
        // Then
        XCTAssertTrue(manager.runs.isEmpty)
        XCTAssertNil(manager.errorMessage)
    }
    
    func testDeleteRun_NonExistentRun() {
        // Given
        let nonExistentId = UUID()
        
        // When & Then
        XCTAssertThrowsError(try manager.deleteRun(id: nonExistentId)) { error in
            XCTAssertEqual(error as? SchoolRunError, .runNotFound)
        }
    }
    
    func testDeleteRun_InProgressRun() throws {
        // Given
        let testRun = createTestRun()
        try manager.createRun(testRun)
        try manager.startRun(id: testRun.id)
        
        // When & Then
        XCTAssertThrowsError(try manager.deleteRun(id: testRun.id)) { error in
            XCTAssertEqual(error as? SchoolRunError, .invalidRunState)
        }
        
        XCTAssertEqual(manager.runs.count, 1)
    }
    
    func testDeleteRun_ClearsActiveRun() throws {
        // Given
        let testRun = createTestRun(status: .completed)
        try manager.createRun(testRun)
        manager.activeRun = testRun
        
        // When
        try manager.deleteRun(id: testRun.id)
        
        // Then
        XCTAssertNil(manager.activeRun)
    }
    
    func testDeleteAllRuns() throws {
        // Given
        let run1 = createTestRun(title: "Run 1")
        let run2 = createTestRun(title: "Run 2")
        try manager.createRun(run1)
        try manager.createRun(run2)
        manager.activeRun = run1
        
        // When
        try manager.deleteAllRuns()
        
        // Then
        XCTAssertTrue(manager.runs.isEmpty)
        XCTAssertNil(manager.activeRun)
    }
    
    // MARK: - Run Execution State Management Tests
    
    func testStartRun_Success() throws {
        // Given
        let testRun = createTestRun()
        try manager.createRun(testRun)
        
        // When
        try manager.startRun(id: testRun.id)
        
        // Then
        XCTAssertEqual(manager.activeRun?.id, testRun.id)
        XCTAssertEqual(manager.activeRun?.status, .inProgress)
        XCTAssertTrue(manager.activeRun?.route.allSatisfy { !$0.isCompleted } ?? false)
        XCTAssertNil(manager.errorMessage)
    }
    
    func testStartRun_NonExistentRun() {
        // Given
        let nonExistentId = UUID()
        
        // When & Then
        XCTAssertThrowsError(try manager.startRun(id: nonExistentId)) { error in
            XCTAssertEqual(error as? SchoolRunError, .runNotFound)
        }
    }
    
    func testStartRun_AlreadyActiveRun() throws {
        // Given
        let run1 = createTestRun(title: "Run 1")
        let run2 = createTestRun(title: "Run 2")
        try manager.createRun(run1)
        try manager.createRun(run2)
        try manager.startRun(id: run1.id)
        
        // When & Then
        XCTAssertThrowsError(try manager.startRun(id: run2.id)) { error in
            XCTAssertEqual(error as? SchoolRunError, .runAlreadyActive)
        }
        
        XCTAssertEqual(manager.activeRun?.id, run1.id)
    }
    
    func testStartRun_InvalidStatus() throws {
        // Given
        let testRun = createTestRun(status: .completed)
        try manager.createRun(testRun)
        
        // When & Then
        XCTAssertThrowsError(try manager.startRun(id: testRun.id)) { error in
            XCTAssertEqual(error as? SchoolRunError, .invalidRunState)
        }
    }
    
    func testPauseRun_Success() throws {
        // Given
        let testRun = createTestRun()
        try manager.createRun(testRun)
        try manager.startRun(id: testRun.id)
        
        // When
        try manager.pauseRun(id: testRun.id)
        
        // Then
        XCTAssertNil(manager.activeRun)
        XCTAssertEqual(manager.runs.first?.status, .scheduled)
        XCTAssertNil(manager.errorMessage)
    }
    
    func testCompleteRun_Success() throws {
        // Given
        let testRun = createTestRun()
        try manager.createRun(testRun)
        try manager.startRun(id: testRun.id)
        
        // When
        try manager.completeRun(id: testRun.id)
        
        // Then
        XCTAssertNil(manager.activeRun)
        XCTAssertEqual(manager.runs.first?.status, .completed)
        XCTAssertTrue(manager.runs.first?.route.allSatisfy { $0.isCompleted } ?? false)
        XCTAssertNil(manager.errorMessage)
    }
    
    func testCancelRun_Success() throws {
        // Given
        let testRun = createTestRun()
        try manager.createRun(testRun)
        try manager.startRun(id: testRun.id)
        
        // When
        try manager.cancelRun(id: testRun.id)
        
        // Then
        XCTAssertNil(manager.activeRun)
        XCTAssertEqual(manager.runs.first?.status, .cancelled)
        XCTAssertNil(manager.errorMessage)
    }
    
    func testCompleteStop_Success() throws {
        // Given
        let testRun = createTestRunWithMultipleStops()
        try manager.createRun(testRun)
        try manager.startRun(id: testRun.id)
        
        let firstStopId = testRun.route.first!.id
        
        // When
        try manager.completeStop(stopId: firstStopId)
        
        // Then
        XCTAssertTrue(manager.activeRun?.route.first?.isCompleted ?? false)
        XCTAssertFalse(manager.activeRun?.route.last?.isCompleted ?? true)
        XCTAssertNil(manager.errorMessage)
    }
    
    func testCompleteStop_NoActiveRun() {
        // Given
        let stopId = UUID()
        
        // When & Then
        XCTAssertThrowsError(try manager.completeStop(stopId: stopId)) { error in
            XCTAssertEqual(error as? SchoolRunError, .noActiveRun)
        }
    }
    
    func testGetNextStop_WithActiveRun() throws {
        // Given
        let testRun = createTestRunWithMultipleStops()
        try manager.createRun(testRun)
        try manager.startRun(id: testRun.id)
        
        // When
        let nextStop = manager.getNextStop()
        
        // Then
        XCTAssertNotNil(nextStop)
        XCTAssertEqual(nextStop?.name, "Home")
    }
    
    func testGetNextStop_NoActiveRun() {
        // When
        let nextStop = manager.getNextStop()
        
        // Then
        XCTAssertNil(nextStop)
    }
    
    func testGetActiveRunProgress() throws {
        // Given
        let testRun = createTestRunWithMultipleStops()
        try manager.createRun(testRun)
        try manager.startRun(id: testRun.id)
        
        // Complete first stop
        try manager.completeStop(stopId: testRun.route[0].id)
        
        // When
        let progress = manager.getActiveRunProgress()
        
        // Then
        XCTAssertEqual(progress, 0.25, accuracy: 0.01) // 1 of 4 stops completed
    }
    
    // MARK: - Data Persistence Tests
    
    func testSaveToStorage_Success() throws {
        // Given
        let testRun = createTestRun()
        try manager.createRun(testRun)
        
        // When
        try manager.saveToStorage()
        
        // Then
        let data = testUserDefaults.data(forKey: "school_runs_data")
        XCTAssertNotNil(data)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let loadedRuns = try decoder.decode([SchoolRun].self, from: data!)
        XCTAssertEqual(loadedRuns.count, 1)
        XCTAssertEqual(loadedRuns.first?.title, testRun.title)
    }
    
    func testLoadFromStorage_Success() throws {
        // Given
        let testRun = createTestRun()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode([testRun])
        testUserDefaults.set(data, forKey: "school_runs_data")
        
        // When
        manager.loadFromStorage()
        
        // Then
        XCTAssertEqual(manager.runs.count, 1)
        XCTAssertEqual(manager.runs.first?.title, testRun.title)
    }
    
    func testLoadFromStorage_CorruptedData() {
        // Given
        testUserDefaults.set("corrupted data", forKey: "school_runs_data")
        
        // When
        manager.loadFromStorage()
        
        // Then
        XCTAssertTrue(manager.runs.isEmpty)
    }
    
    func testActiveRunPersistence() throws {
        // Given
        let testRun = createTestRun()
        try manager.createRun(testRun)
        try manager.startRun(id: testRun.id)
        
        // When
        let newManager = SchoolRunManager(storage: testUserDefaults)
        
        // Then
        XCTAssertNotNil(newManager.activeRun)
        XCTAssertEqual(newManager.activeRun?.id, testRun.id)
    }
    
    func testClearStorage() throws {
        // Given
        let testRun = createTestRun()
        try manager.createRun(testRun)
        try manager.startRun(id: testRun.id)
        
        // When
        manager.clearStorage()
        
        // Then
        XCTAssertTrue(manager.runs.isEmpty)
        XCTAssertNil(manager.activeRun)
        XCTAssertNil(testUserDefaults.data(forKey: "school_runs_data"))
        XCTAssertNil(testUserDefaults.data(forKey: "active_school_run"))
    }
    
    // MARK: - Computed Properties Tests
    
    func testTodaysRuns() throws {
        // Given
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        
        let todayRun = createTestRun(title: "Today", date: today)
        let tomorrowRun = createTestRun(title: "Tomorrow", date: tomorrow)
        let yesterdayRun = createTestRun(title: "Yesterday", date: yesterday)
        
        try manager.createRun(todayRun)
        try manager.createRun(tomorrowRun)
        try manager.createRun(yesterdayRun)
        
        // When
        let todaysRuns = manager.todaysRuns
        
        // Then
        XCTAssertEqual(todaysRuns.count, 1)
        XCTAssertEqual(todaysRuns.first?.title, "Today")
    }
    
    func testUpcomingRuns() throws {
        // Given
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: today)!
        
        let todayRun = createTestRun(title: "Today", date: today)
        let tomorrowRun = createTestRun(title: "Tomorrow", date: tomorrow)
        let nextWeekRun = createTestRun(title: "Next Week", date: nextWeek)
        
        try manager.createRun(todayRun)
        try manager.createRun(tomorrowRun)
        try manager.createRun(nextWeekRun)
        
        // When
        let upcomingRuns = manager.upcomingRuns
        
        // Then
        XCTAssertEqual(upcomingRuns.count, 2)
        XCTAssertEqual(upcomingRuns.first?.title, "Tomorrow")
        XCTAssertEqual(upcomingRuns.last?.title, "Next Week")
    }
    
    func testCompletedRuns() throws {
        // Given
        let scheduledRun = createTestRun(title: "Scheduled", status: .scheduled)
        let completedRun1 = createTestRun(title: "Completed 1", status: .completed)
        let completedRun2 = createTestRun(title: "Completed 2", status: .completed)
        
        try manager.createRun(scheduledRun)
        try manager.createRun(completedRun1)
        try manager.createRun(completedRun2)
        
        // When
        let completedRuns = manager.completedRuns
        
        // Then
        XCTAssertEqual(completedRuns.count, 2)
        XCTAssertTrue(completedRuns.contains { $0.title == "Completed 1" })
        XCTAssertTrue(completedRuns.contains { $0.title == "Completed 2" })
    }
    
    func testHasActiveRun() throws {
        // Given
        let testRun = createTestRun()
        try manager.createRun(testRun)
        
        // When & Then
        XCTAssertFalse(manager.hasActiveRun)
        
        try manager.startRun(id: testRun.id)
        XCTAssertTrue(manager.hasActiveRun)
        
        try manager.completeRun(id: testRun.id)
        XCTAssertFalse(manager.hasActiveRun)
    }
    
    // MARK: - Convenience Methods Tests
    
    func testGetRunsWithStatus() throws {
        // Given
        let scheduledRun = createTestRun(title: "Scheduled", status: .scheduled)
        let inProgressRun = createTestRun(title: "In Progress", status: .inProgress)
        let completedRun = createTestRun(title: "Completed", status: .completed)
        
        try manager.createRun(scheduledRun)
        try manager.createRun(inProgressRun)
        try manager.createRun(completedRun)
        
        // When
        let scheduledRuns = manager.getRuns(withStatus: .scheduled)
        let inProgressRuns = manager.getRuns(withStatus: .inProgress)
        let completedRuns = manager.getRuns(withStatus: .completed)
        
        // Then
        XCTAssertEqual(scheduledRuns.count, 1)
        XCTAssertEqual(scheduledRuns.first?.title, "Scheduled")
        
        XCTAssertEqual(inProgressRuns.count, 1)
        XCTAssertEqual(inProgressRuns.first?.title, "In Progress")
        
        XCTAssertEqual(completedRuns.count, 1)
        XCTAssertEqual(completedRuns.first?.title, "Completed")
    }
    
    func testGetRunsForDate() throws {
        // Given
        let targetDate = Date()
        let otherDate = Calendar.current.date(byAdding: .day, value: 1, to: targetDate)!
        
        let targetRun = createTestRun(title: "Target", date: targetDate)
        let otherRun = createTestRun(title: "Other", date: otherDate)
        
        try manager.createRun(targetRun)
        try manager.createRun(otherRun)
        
        // When
        let runsForDate = manager.getRuns(for: targetDate)
        
        // Then
        XCTAssertEqual(runsForDate.count, 1)
        XCTAssertEqual(runsForDate.first?.title, "Target")
    }
    
    func testRunExists() throws {
        // Given
        let testRun = createTestRun()
        let nonExistentId = UUID()
        
        // When & Then
        XCTAssertFalse(manager.runExists(id: testRun.id))
        XCTAssertFalse(manager.runExists(id: nonExistentId))
        
        try manager.createRun(testRun)
        XCTAssertTrue(manager.runExists(id: testRun.id))
        XCTAssertFalse(manager.runExists(id: nonExistentId))
    }
    
    func testMostRecentRun() throws {
        // Given
        let oldRun = createTestRun(title: "Old")
        Thread.sleep(forTimeInterval: 0.01) // Ensure different creation times
        let newRun = createTestRun(title: "New")
        
        try manager.createRun(oldRun)
        try manager.createRun(newRun)
        
        // When
        let mostRecent = manager.mostRecentRun
        
        // Then
        XCTAssertEqual(mostRecent?.title, "New")
    }
    
    func testNextScheduledRun() throws {
        // Given
        let futureDate1 = Date().addingTimeInterval(3600)
        let futureDate2 = Date().addingTimeInterval(7200)
        
        let laterRun = createTestRun(title: "Later", date: futureDate2)
        let earlierRun = createTestRun(title: "Earlier", date: futureDate1)
        
        try manager.createRun(laterRun)
        try manager.createRun(earlierRun)
        
        // When
        let nextRun = manager.nextScheduledRun
        
        // Then
        XCTAssertEqual(nextRun?.title, "Earlier")
    }
    
    // MARK: - Error Handling Tests
    
    func testShowError() {
        // Given
        let errorMessage = "Test error message"
        
        // When
        manager.showError(errorMessage)
        
        // Then
        XCTAssertEqual(manager.errorMessage, errorMessage)
    }
    
    func testShowSchoolRunError() {
        // Given
        let error = SchoolRunError.runNotFound
        
        // When
        manager.showError(error)
        
        // Then
        XCTAssertEqual(manager.errorMessage, error.localizedDescription)
    }
    
    func testClearError() {
        // Given
        manager.showError("Test error")
        
        // When
        manager.clearError()
        
        // Then
        XCTAssertNil(manager.errorMessage)
    }
    
    // MARK: - Async Methods Tests
    
    func testAsyncCreateRun() async throws {
        // Given
        let testRun = createTestRun()
        
        // When
        try await manager.createRunAsync(testRun)
        
        // Then
        XCTAssertEqual(manager.runs.count, 1)
        XCTAssertEqual(manager.runs.first?.title, testRun.title)
    }
    
    func testAsyncStartRun() async throws {
        // Given
        let testRun = createTestRun()
        try await manager.createRunAsync(testRun)
        
        // When
        try await manager.startRunAsync(id: testRun.id)
        
        // Then
        XCTAssertEqual(manager.activeRun?.id, testRun.id)
        XCTAssertEqual(manager.activeRun?.status, .inProgress)
    }
    
    func testAsyncCompleteRun() async throws {
        // Given
        let testRun = createTestRun()
        try await manager.createRunAsync(testRun)
        try await manager.startRunAsync(id: testRun.id)
        
        // When
        try await manager.completeRunAsync(id: testRun.id)
        
        // Then
        XCTAssertNil(manager.activeRun)
        XCTAssertEqual(manager.runs.first?.status, .completed)
    }
    
    // MARK: - Performance Tests
    
    func testCreateMultipleRuns_Performance() throws {
        // Given
        let numberOfRuns = 100
        let runs = (0..<numberOfRuns).map { index in
            createTestRun(title: "Run \(index)")
        }
        
        // When
        measure {
            for run in runs {
                try! manager.createRun(run)
            }
        }
        
        // Then
        XCTAssertEqual(manager.runs.count, numberOfRuns)
    }
    
    func testDataPersistence_Performance() throws {
        // Given
        let numberOfRuns = 50
        for i in 0..<numberOfRuns {
            let run = createTestRun(title: "Run \(i)")
            try manager.createRun(run)
        }
        
        // When
        measure {
            try! manager.saveToStorage()
        }
        
        // Then - Test passes if it completes within reasonable time
    }
    
    func testDataLoading_Performance() throws {
        // Given
        let numberOfRuns = 50
        for i in 0..<numberOfRuns {
            let run = createTestRun(title: "Run \(i)")
            try manager.createRun(run)
        }
        try manager.saveToStorage()
        
        // When
        measure {
            manager.loadFromStorage()
        }
        
        // Then - Test passes if it completes within reasonable time
    }
}