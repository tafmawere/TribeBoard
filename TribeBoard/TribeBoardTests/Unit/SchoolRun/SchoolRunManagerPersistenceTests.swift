import XCTest
@testable import TribeBoard

/// Tests for SchoolRunManager data persistence and state management
@MainActor
final class SchoolRunManagerPersistenceTests: XCTestCase {
    
    var manager: SchoolRunManager!
    var testStorage: UserDefaults!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create test UserDefaults instance
        testStorage = UserDefaults(suiteName: "SchoolRunManagerPersistenceTests")!
        testStorage.removePersistentDomain(forName: "SchoolRunManagerPersistenceTests")
        
        // Create manager with test storage
        manager = SchoolRunManager(storage: testStorage)
    }
    
    override func tearDown() async throws {
        // Clean up test storage
        testStorage.removePersistentDomain(forName: "SchoolRunManagerPersistenceTests")
        manager = nil
        testStorage = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Data Persistence Tests
    
    func testSaveAndLoadRuns() throws {
        // Given: A run to save
        let run = createTestRun(title: "Test Run", date: Date())
        
        // When: Creating and saving the run
        try manager.createRun(run)
        
        // Then: Data should be saved
        XCTAssertEqual(manager.runs.count, 1)
        XCTAssertEqual(manager.runs.first?.title, "Test Run")
        
        // When: Creating a new manager instance (simulating app restart)
        let newManager = SchoolRunManager(storage: testStorage)
        
        // Then: Data should be loaded
        XCTAssertEqual(newManager.runs.count, 1)
        XCTAssertEqual(newManager.runs.first?.title, "Test Run")
        XCTAssertEqual(newManager.runs.first?.id, run.id)
    }
    
    func testSaveAndLoadActiveRun() throws {
        // Given: A run to make active
        let run = createTestRun(title: "Active Run", date: Date())
        try manager.createRun(run)
        
        // When: Starting the run
        try manager.startRun(id: run.id)
        
        // Then: Active run should be set
        XCTAssertNotNil(manager.activeRun)
        XCTAssertEqual(manager.activeRun?.id, run.id)
        XCTAssertEqual(manager.activeRun?.status, .inProgress)
        
        // When: Creating a new manager instance (simulating app restart)
        let newManager = SchoolRunManager(storage: testStorage)
        
        // Then: Active run should be loaded
        XCTAssertNotNil(newManager.activeRun)
        XCTAssertEqual(newManager.activeRun?.id, run.id)
        XCTAssertEqual(newManager.activeRun?.status, .inProgress)
    }
    
    func testDataPersistenceAcrossAppLaunches() throws {
        // Given: Multiple runs with different statuses
        let scheduledRun = createTestRun(title: "Scheduled Run", date: Date().addingTimeInterval(3600))
        let completedRun = createTestRun(title: "Completed Run", date: Date().addingTimeInterval(-3600))
        var completedRunCopy = completedRun
        completedRunCopy.status = .completed
        
        try manager.createRun(scheduledRun)
        try manager.createRun(completedRunCopy)
        
        // When: Simulating app launch multiple times
        for i in 1...3 {
            let newManager = SchoolRunManager(storage: testStorage)
            
            // Then: All data should persist
            XCTAssertEqual(newManager.runs.count, 2, "Failed on launch \(i)")
            
            let titles = newManager.runs.map { $0.title }.sorted()
            XCTAssertEqual(titles, ["Completed Run", "Scheduled Run"], "Failed on launch \(i)")
            
            // Verify statuses
            let scheduledRuns = newManager.runs.filter { $0.status == .scheduled }
            let completedRuns = newManager.runs.filter { $0.status == .completed }
            XCTAssertEqual(scheduledRuns.count, 1, "Failed on launch \(i)")
            XCTAssertEqual(completedRuns.count, 1, "Failed on launch \(i)")
        }
    }
    
    func testBackgroundSave() throws {
        // Given: A run to save
        let run = createTestRun(title: "Background Save Test", date: Date())
        try manager.createRun(run)
        
        // When: Simulating app going to background
        manager.simulateAppBackground()
        
        // Then: Data should be saved and loadable
        let newManager = SchoolRunManager(storage: testStorage)
        XCTAssertEqual(newManager.runs.count, 1)
        XCTAssertEqual(newManager.runs.first?.title, "Background Save Test")
    }
    
    // MARK: - Data Migration Tests
    
    func testDataMigrationFromVersion0ToVersion1() throws {
        // Given: Legacy data without version (simulating version 0)
        let legacyRun = createTestRun(title: "Legacy Run", date: Date())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let legacyData = try encoder.encode([legacyRun])
        testStorage.set(legacyData, forKey: "school_runs_data")
        // Don't set version key to simulate version 0
        
        // When: Creating manager (should trigger migration)
        let migratedManager = SchoolRunManager(storage: testStorage)
        
        // Then: Data should be migrated and version updated
        XCTAssertEqual(migratedManager.runs.count, 1)
        XCTAssertEqual(migratedManager.runs.first?.title, "Legacy Run")
        XCTAssertEqual(migratedManager.dataVersion, 1)
    }
    
    func testDataMigrationWithCorruptedData() throws {
        // Given: Corrupted data in storage
        let corruptedData = "invalid json data".data(using: .utf8)!
        testStorage.set(corruptedData, forKey: "school_runs_data")
        
        // When: Creating manager (should handle corruption gracefully)
        let recoveredManager = SchoolRunManager(storage: testStorage)
        
        // Then: Should start with empty data
        XCTAssertEqual(recoveredManager.runs.count, 0)
        XCTAssertNil(recoveredManager.activeRun)
    }
    
    // MARK: - Data Validation Tests
    
    func testDataValidationOnLoad() throws {
        // Given: Invalid run data (empty title)
        var invalidRun = createTestRun(title: "", date: Date())
        let validRun = createTestRun(title: "Valid Run", date: Date())
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let invalidData = try encoder.encode([invalidRun, validRun])
        testStorage.set(invalidData, forKey: "school_runs_data")
        testStorage.set(1, forKey: "school_runs_data_version")
        
        // When: Loading data (should validate and clean)
        let cleanedManager = SchoolRunManager(storage: testStorage)
        
        // Then: Only valid runs should be loaded
        XCTAssertEqual(cleanedManager.runs.count, 1)
        XCTAssertEqual(cleanedManager.runs.first?.title, "Valid Run")
    }
    
    func testActiveRunValidationOnLoad() throws {
        // Given: Active run that doesn't exist in runs array
        let run = createTestRun(title: "Test Run", date: Date())
        let orphanedActiveRun = createTestRun(title: "Orphaned Active", date: Date())
        var orphanedActiveRunCopy = orphanedActiveRun
        orphanedActiveRunCopy.status = .inProgress
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let runsData = try encoder.encode([run])
        let activeRunData = try encoder.encode(orphanedActiveRunCopy)
        
        testStorage.set(runsData, forKey: "school_runs_data")
        testStorage.set(activeRunData, forKey: "active_school_run")
        testStorage.set(1, forKey: "school_runs_data_version")
        
        // When: Loading data
        let validatedManager = SchoolRunManager(storage: testStorage)
        
        // Then: Orphaned active run should be cleared
        XCTAssertEqual(validatedManager.runs.count, 1)
        XCTAssertNil(validatedManager.activeRun)
    }
    
    // MARK: - Data Cleanup Tests
    
    func testCleanupOldCompletedRuns() throws {
        // Given: Old completed runs and recent runs
        let oldDate = Calendar.current.date(byAdding: .day, value: -35, to: Date())!
        let recentDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        
        var oldCompletedRun = createTestRun(title: "Old Completed", date: oldDate)
        oldCompletedRun.status = .completed
        
        var recentCompletedRun = createTestRun(title: "Recent Completed", date: recentDate)
        recentCompletedRun.status = .completed
        
        let scheduledRun = createTestRun(title: "Scheduled", date: Date().addingTimeInterval(3600))
        
        try manager.createRun(oldCompletedRun)
        try manager.createRun(recentCompletedRun)
        try manager.createRun(scheduledRun)
        
        XCTAssertEqual(manager.runs.count, 3)
        
        // When: Triggering cleanup
        manager.triggerCleanup()
        
        // Then: Old completed run should be removed
        XCTAssertEqual(manager.runs.count, 2)
        
        let remainingTitles = manager.runs.map { $0.title }.sorted()
        XCTAssertEqual(remainingTitles, ["Recent Completed", "Scheduled"])
    }
    
    func testCleanupOldCancelledRuns() throws {
        // Given: Old cancelled runs and recent runs
        let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let recentDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        
        var oldCancelledRun = createTestRun(title: "Old Cancelled", date: oldDate)
        oldCancelledRun.status = .cancelled
        
        var recentCancelledRun = createTestRun(title: "Recent Cancelled", date: recentDate)
        recentCancelledRun.status = .cancelled
        
        try manager.createRun(oldCancelledRun)
        try manager.createRun(recentCancelledRun)
        
        XCTAssertEqual(manager.runs.count, 2)
        
        // When: Triggering cleanup
        manager.triggerCleanup()
        
        // Then: Old cancelled run should be removed
        XCTAssertEqual(manager.runs.count, 1)
        XCTAssertEqual(manager.runs.first?.title, "Recent Cancelled")
    }
    
    // MARK: - Error Recovery Tests
    
    func testDataRecoveryFromPartialCorruption() throws {
        // Given: Partially corrupted data with some valid runs
        let validRun = createTestRun(title: "Valid Run", date: Date())
        var invalidRun = createTestRun(title: "", date: Date()) // Invalid empty title
        
        // Manually encode mixed data
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let mixedData = try encoder.encode([validRun, invalidRun])
        
        testStorage.set(mixedData, forKey: "school_runs_data")
        testStorage.set(1, forKey: "school_runs_data_version")
        
        // When: Loading data (should recover valid runs)
        let recoveredManager = SchoolRunManager(storage: testStorage)
        
        // Then: Should recover valid runs only
        XCTAssertEqual(recoveredManager.runs.count, 1)
        XCTAssertEqual(recoveredManager.runs.first?.title, "Valid Run")
    }
    
    func testDataIntegrityValidation() throws {
        // Given: Manager with valid data
        let run1 = createTestRun(title: "Run 1", date: Date())
        let run2 = createTestRun(title: "Run 2", date: Date().addingTimeInterval(3600))
        
        try manager.createRun(run1)
        try manager.createRun(run2)
        
        // When: Validating current data
        // Then: Should not throw
        XCTAssertNoThrow(try manager.validateCurrentData())
        
        // When: Manually corrupting data (duplicate IDs)
        var corruptedRun = run2
        corruptedRun.id = run1.id // Create duplicate ID
        manager.runs[1] = corruptedRun
        
        // Then: Validation should detect corruption
        XCTAssertThrowsError(try manager.validateCurrentData()) { error in
            if case SchoolRunError.dataCorruption(let message) = error {
                XCTAssertTrue(message.contains("Duplicate run IDs"))
            } else {
                XCTFail("Expected dataCorruption error, got \(error)")
            }
        }
    }
    
    // MARK: - Storage Size and Performance Tests
    
    func testStorageSize() throws {
        // Given: Empty manager
        XCTAssertEqual(manager.storageSize, 0)
        
        // When: Adding runs
        let run1 = createTestRun(title: "Run 1", date: Date())
        let run2 = createTestRun(title: "Run 2", date: Date().addingTimeInterval(3600))
        
        try manager.createRun(run1)
        try manager.createRun(run2)
        
        // Then: Storage size should increase
        XCTAssertGreaterThan(manager.storageSize, 0)
        
        let sizeWithTwoRuns = manager.storageSize
        
        // When: Adding more runs
        let run3 = createTestRun(title: "Run 3", date: Date().addingTimeInterval(7200))
        try manager.createRun(run3)
        
        // Then: Storage size should increase further
        XCTAssertGreaterThan(manager.storageSize, sizeWithTwoRuns)
    }
    
    func testForceSave() throws {
        // Given: A run that needs saving
        let run = createTestRun(title: "Force Save Test", date: Date())
        try manager.createRun(run)
        
        // When: Force saving
        XCTAssertNoThrow(try manager.forceSave())
        
        // Then: Data should be saved and loadable
        let newManager = SchoolRunManager(storage: testStorage)
        XCTAssertEqual(newManager.runs.count, 1)
        XCTAssertEqual(newManager.runs.first?.title, "Force Save Test")
    }
    
    // MARK: - Helper Methods
    
    private func createTestRun(title: String, date: Date) -> SchoolRun {
        let stop1 = RunStop(
            id: UUID(),
            name: "Home",
            time: date,
            note: "Pick up",
            type: .pickup,
            isCompleted: false
        )
        
        let stop2 = RunStop(
            id: UUID(),
            name: "School",
            time: date.addingTimeInterval(1200), // 20 minutes later
            note: "Drop off",
            type: .dropoff,
            isCompleted: false
        )
        
        return SchoolRun(
            id: UUID(),
            title: title,
            date: date,
            route: [stop1, stop2],
            status: .scheduled,
            createdAt: Date(),
            estimatedDuration: 1200
        )
    }
}