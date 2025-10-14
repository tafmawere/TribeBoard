import XCTest
@testable import TribeBoard

/// Unit tests for ActiveRunViewModel
/// 
/// Tests cover:
/// - Run execution state management
/// - Stop progression logic
/// - Progress calculation
/// - Pause/resume functionality
/// 
/// Requirements: 2.1, 2.2, 2.3, 2.4
@MainActor
final class ActiveRunViewModelTests: XCTestCase {
    
    var viewModel: ActiveRunViewModel!
    var mockRunManager: MockSchoolRunManager!
    var mockHapticManager: MockHapticManager!
    var mockErrorHandler: SchoolRunErrorHandler!
    
    override func setUp() {
        super.setUp()
        
        mockRunManager = MockSchoolRunManager()
        mockHapticManager = MockHapticManager()
        mockErrorHandler = SchoolRunErrorHandler()
        
        viewModel = ActiveRunViewModel(
            runManager: mockRunManager,
            hapticManager: mockHapticManager,
            errorHandler: mockErrorHandler
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockRunManager = nil
        mockHapticManager = nil
        mockErrorHandler = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        // Given: Fresh view model
        // When: Initialized
        // Then: Should have default state
        XCTAssertNil(viewModel.currentRun)
        XCTAssertEqual(viewModel.currentStopIndex, 0)
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertFalse(viewModel.isPaused)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testLoadActiveRunWithNoActiveRun() {
        // Given: No active run in manager
        mockRunManager.activeRun = nil
        
        // When: Loading active run
        viewModel.loadActiveRun()
        
        // Then: Should have no active run
        XCTAssertNil(viewModel.currentRun)
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertEqual(viewModel.currentStopIndex, 0)
    }
    
    func testLoadActiveRunWithActiveRun() {
        // Given: Active run in manager
        let run = createMockRun(status: .inProgress)
        mockRunManager.activeRun = run
        
        // When: Loading active run
        viewModel.loadActiveRun()
        
        // Then: Should load the active run
        XCTAssertEqual(viewModel.currentRun?.id, run.id)
        XCTAssertTrue(viewModel.isRunning)
        XCTAssertEqual(viewModel.currentStopIndex, 0)
    }
    
    // MARK: - Computed Properties Tests
    
    func testCurrentStopWithValidIndex() {
        // Given: Run with multiple stops
        let run = createMockRun()
        viewModel.currentRun = run
        viewModel.currentStopIndex = 1
        
        // When: Getting current stop
        let currentStop = viewModel.currentStop
        
        // Then: Should return correct stop
        XCTAssertEqual(currentStop?.id, run.route[1].id)
    }
    
    func testCurrentStopWithInvalidIndex() {
        // Given: Run with stops but invalid index
        let run = createMockRun()
        viewModel.currentRun = run
        viewModel.currentStopIndex = 10 // Out of bounds
        
        // When: Getting current stop
        let currentStop = viewModel.currentStop
        
        // Then: Should return nil
        XCTAssertNil(currentStop)
    }
    
    func testNextStopWithValidIndex() {
        // Given: Run with multiple stops
        let run = createMockRun()
        viewModel.currentRun = run
        viewModel.currentStopIndex = 0
        
        // When: Getting next stop
        let nextStop = viewModel.nextStop
        
        // Then: Should return next stop
        XCTAssertEqual(nextStop?.id, run.route[1].id)
    }
    
    func testNextStopAtLastStop() {
        // Given: Run at last stop
        let run = createMockRun()
        viewModel.currentRun = run
        viewModel.currentStopIndex = run.route.count - 1
        
        // When: Getting next stop
        let nextStop = viewModel.nextStop
        
        // Then: Should return nil
        XCTAssertNil(nextStop)
    }
    
    func testProgressCalculation() {
        // Given: Run with 4 stops, currently at stop 2
        let run = createMockRun(stopCount: 4)
        viewModel.currentRun = run
        viewModel.currentStopIndex = 2
        
        // When: Getting progress
        let progress = viewModel.progress
        
        // Then: Should calculate correct progress
        XCTAssertEqual(progress, 0.5, accuracy: 0.01) // 2/4 = 0.5
    }
    
    func testProgressPercentage() {
        // Given: Run with progress
        let run = createMockRun(stopCount: 4)
        viewModel.currentRun = run
        viewModel.currentStopIndex = 1
        
        // When: Getting progress percentage
        let percentage = viewModel.progressPercentage
        
        // Then: Should return correct percentage
        XCTAssertEqual(percentage, 25) // 1/4 * 100 = 25%
    }
    
    func testIsLastStop() {
        // Given: Run with 3 stops
        let run = createMockRun(stopCount: 3)
        viewModel.currentRun = run
        
        // When: At last stop
        viewModel.currentStopIndex = 2
        
        // Then: Should be last stop
        XCTAssertTrue(viewModel.isLastStop)
        
        // When: Not at last stop
        viewModel.currentStopIndex = 1
        
        // Then: Should not be last stop
        XCTAssertFalse(viewModel.isLastStop)
    }
    
    func testHasNextStop() {
        // Given: Run with 3 stops
        let run = createMockRun(stopCount: 3)
        viewModel.currentRun = run
        
        // When: Not at last stop
        viewModel.currentStopIndex = 1
        
        // Then: Should have next stop
        XCTAssertTrue(viewModel.hasNextStop)
        
        // When: At last stop
        viewModel.currentStopIndex = 2
        
        // Then: Should not have next stop
        XCTAssertFalse(viewModel.hasNextStop)
    }
    
    // MARK: - Run Execution Tests
    
    func testStartRunSuccess() async {
        // Given: Valid run ID
        let runId = UUID()
        let run = createMockRun(id: runId, status: .inProgress)
        mockRunManager.startRunResult = .success(())
        mockRunManager.activeRun = run
        
        // When: Starting run
        await viewModel.startRun(id: runId)
        
        // Then: Should start successfully
        XCTAssertTrue(mockRunManager.startRunCalled)
        XCTAssertEqual(mockRunManager.startRunId, runId)
        XCTAssertTrue(mockHapticManager.mediumImpactCalled)
        XCTAssertTrue(mockHapticManager.successCalled)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testStartRunFailure() async {
        // Given: Run start will fail
        let runId = UUID()
        let error = SchoolRunError.runAlreadyActive
        mockRunManager.startRunResult = .failure(error)
        
        // When: Starting run
        await viewModel.startRun(id: runId)
        
        // Then: Should handle error
        XCTAssertTrue(mockRunManager.startRunCalled)
        XCTAssertTrue(mockHapticManager.mediumImpactCalled)
        XCTAssertTrue(mockHapticManager.errorCalled)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    func testNextStopSuccess() {
        // Given: Active run with stops
        let run = createMockRun()
        viewModel.currentRun = run
        viewModel.currentStopIndex = 0
        mockRunManager.completeStopResult = .success(())
        
        // When: Moving to next stop
        viewModel.nextStop()
        
        // Then: Should progress to next stop
        XCTAssertTrue(mockRunManager.completeStopCalled)
        XCTAssertEqual(mockRunManager.completeStopId, run.route[0].id)
        XCTAssertTrue(mockHapticManager.lightImpactCalled)
        XCTAssertTrue(mockHapticManager.selectionCalled)
        XCTAssertEqual(viewModel.currentStopIndex, 1)
    }
    
    func testNextStopFailure() {
        // Given: Active run and complete stop will fail
        let run = createMockRun()
        viewModel.currentRun = run
        viewModel.currentStopIndex = 0
        mockRunManager.completeStopResult = .failure(SchoolRunError.runNotFound)
        
        // When: Moving to next stop
        viewModel.nextStop()
        
        // Then: Should handle error
        XCTAssertTrue(mockRunManager.completeStopCalled)
        XCTAssertTrue(mockHapticManager.lightImpactCalled)
        XCTAssertTrue(mockHapticManager.errorCalled)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    func testCompleteRunConfirmation() {
        // Given: Active run
        let run = createMockRun()
        viewModel.currentRun = run
        
        // When: Completing run
        viewModel.completeRun()
        
        // Then: Should show confirmation
        XCTAssertTrue(viewModel.showingCompletionConfirmation)
    }
    
    func testConfirmCompleteRunSuccess() async {
        // Given: Active run and successful completion
        let run = createMockRun()
        viewModel.currentRun = run
        mockRunManager.completeRunResult = .success(())
        
        // When: Confirming completion
        await viewModel.confirmCompleteRun()
        
        // Then: Should complete successfully
        XCTAssertTrue(mockRunManager.completeRunCalled)
        XCTAssertEqual(mockRunManager.completeRunId, run.id)
        XCTAssertTrue(mockHapticManager.heavyImpactCalled)
        XCTAssertTrue(mockHapticManager.successCalled)
        XCTAssertNil(viewModel.currentRun)
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertFalse(viewModel.showingCompletionConfirmation)
    }
    
    // MARK: - Pause/Resume Tests
    
    func testPauseRunSuccess() async {
        // Given: Active running run
        let run = createMockRun(status: .inProgress)
        viewModel.currentRun = run
        viewModel.isRunning = true
        mockRunManager.pauseRunResult = .success(())
        
        // When: Pausing run
        await viewModel.pauseRun()
        
        // Then: Should pause successfully
        XCTAssertTrue(mockRunManager.pauseRunCalled)
        XCTAssertEqual(mockRunManager.pauseRunId, run.id)
        XCTAssertTrue(mockHapticManager.mediumImpactCalled)
        XCTAssertTrue(mockHapticManager.lightImpactCalled)
        XCTAssertTrue(viewModel.isPaused)
        XCTAssertFalse(viewModel.isRunning)
    }
    
    func testResumeRunSuccess() async {
        // Given: Paused run
        let run = createMockRun()
        viewModel.currentRun = run
        viewModel.isPaused = true
        mockRunManager.startRunResult = .success(())
        mockRunManager.activeRun = run
        
        // When: Resuming run
        await viewModel.resumeRun()
        
        // Then: Should resume successfully
        XCTAssertTrue(mockRunManager.startRunCalled)
        XCTAssertEqual(mockRunManager.startRunId, run.id)
        XCTAssertTrue(mockHapticManager.mediumImpactCalled)
        XCTAssertTrue(mockHapticManager.lightImpactCalled)
        XCTAssertFalse(viewModel.isPaused)
        XCTAssertTrue(viewModel.isRunning)
    }
    
    func testCanPauseLogic() {
        // Given: Running run
        viewModel.isRunning = true
        viewModel.isPaused = false
        
        // Then: Should be able to pause
        XCTAssertTrue(viewModel.canPause)
        
        // Given: Paused run
        viewModel.isPaused = true
        
        // Then: Should not be able to pause
        XCTAssertFalse(viewModel.canPause)
    }
    
    func testCanResumeLogic() {
        // Given: Paused run
        viewModel.isPaused = true
        
        // Then: Should be able to resume
        XCTAssertTrue(viewModel.canResume)
        
        // Given: Running run
        viewModel.isPaused = false
        
        // Then: Should not be able to resume
        XCTAssertFalse(viewModel.canResume)
    }
    
    // MARK: - Cancel Run Tests
    
    func testCancelRunConfirmation() {
        // Given: Active run
        let run = createMockRun()
        viewModel.currentRun = run
        
        // When: Cancelling run
        viewModel.cancelRun()
        
        // Then: Should show confirmation
        XCTAssertTrue(viewModel.showingCancellationConfirmation)
    }
    
    func testConfirmCancelRunSuccess() async {
        // Given: Active run and successful cancellation
        let run = createMockRun()
        viewModel.currentRun = run
        mockRunManager.cancelRunResult = .success(())
        
        // When: Confirming cancellation
        await viewModel.confirmCancelRun()
        
        // Then: Should cancel successfully
        XCTAssertTrue(mockRunManager.cancelRunCalled)
        XCTAssertEqual(mockRunManager.cancelRunId, run.id)
        XCTAssertTrue(mockHapticManager.heavyImpactCalled)
        XCTAssertTrue(mockHapticManager.warningCalled)
        XCTAssertNil(viewModel.currentRun)
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertFalse(viewModel.showingCancellationConfirmation)
    }
    
    // MARK: - Skip to Stop Tests
    
    func testSkipToStopSuccess() {
        // Given: Run with multiple stops
        let run = createMockRun(stopCount: 4)
        viewModel.currentRun = run
        mockRunManager.updateRunResult = .success(())
        
        // When: Skipping to stop 2
        viewModel.skipToStop(index: 2)
        
        // Then: Should skip successfully
        XCTAssertTrue(mockRunManager.updateRunCalled)
        XCTAssertTrue(mockHapticManager.lightImpactCalled)
        XCTAssertEqual(viewModel.currentStopIndex, 2)
    }
    
    func testSkipToStopInvalidIndex() {
        // Given: Run with 3 stops
        let run = createMockRun(stopCount: 3)
        viewModel.currentRun = run
        let originalIndex = viewModel.currentStopIndex
        
        // When: Skipping to invalid index
        viewModel.skipToStop(index: 10)
        
        // Then: Should not change anything
        XCTAssertFalse(mockRunManager.updateRunCalled)
        XCTAssertEqual(viewModel.currentStopIndex, originalIndex)
    }
    
    // MARK: - Utility Tests
    
    func testGetStopAtIndex() {
        // Given: Run with stops
        let run = createMockRun()
        viewModel.currentRun = run
        
        // When: Getting stop at valid index
        let stop = viewModel.getStop(at: 1)
        
        // Then: Should return correct stop
        XCTAssertEqual(stop?.id, run.route[1].id)
        
        // When: Getting stop at invalid index
        let invalidStop = viewModel.getStop(at: 10)
        
        // Then: Should return nil
        XCTAssertNil(invalidStop)
    }
    
    func testIsStopCompleted() {
        // Given: Run with completed and incomplete stops
        var run = createMockRun()
        run.route[0].isCompleted = true
        run.route[1].isCompleted = false
        viewModel.currentRun = run
        
        // When: Checking completion status
        let firstCompleted = viewModel.isStopCompleted(at: 0)
        let secondCompleted = viewModel.isStopCompleted(at: 1)
        
        // Then: Should return correct status
        XCTAssertTrue(firstCompleted)
        XCTAssertFalse(secondCompleted)
    }
    
    func testCompletedStops() {
        // Given: Run with some completed stops
        var run = createMockRun(stopCount: 4)
        run.route[0].isCompleted = true
        run.route[2].isCompleted = true
        viewModel.currentRun = run
        
        // When: Getting completed stops
        let completedStops = viewModel.completedStops
        
        // Then: Should return only completed stops
        XCTAssertEqual(completedStops.count, 2)
        XCTAssertTrue(completedStops.allSatisfy(\.isCompleted))
    }
    
    func testRemainingStops() {
        // Given: Run with current stop index
        let run = createMockRun(stopCount: 4)
        viewModel.currentRun = run
        viewModel.currentStopIndex = 1
        
        // When: Getting remaining stops
        let remainingStops = viewModel.remainingStops
        
        // Then: Should return stops from current index onwards
        XCTAssertEqual(remainingStops.count, 3) // Stops 1, 2, 3
        XCTAssertEqual(remainingStops[0].id, run.route[1].id)
    }
    
    // MARK: - Helper Methods
    
    private func createMockRun(
        id: UUID = UUID(),
        status: RunStatus = .scheduled,
        stopCount: Int = 3
    ) -> SchoolRun {
        let stops = (0..<stopCount).map { index in
            RunStop(
                name: "Stop \(index + 1)",
                time: Date().addingTimeInterval(TimeInterval(index * 300)), // 5 minutes apart
                type: index % 2 == 0 ? .pickup : .dropoff
            )
        }
        
        return SchoolRun(
            id: id,
            title: "Test Run",
            date: Date(),
            route: stops,
            status: status
        )
    }
}

// MARK: - Mock Classes

class MockSchoolRunManager: SchoolRunManager {
    var activeRun: SchoolRun?
    
    // Method call tracking
    var startRunCalled = false
    var startRunId: UUID?
    var startRunResult: Result<Void, Error> = .success(())
    
    var completeStopCalled = false
    var completeStopId: UUID?
    var completeStopResult: Result<Void, Error> = .success(())
    
    var completeRunCalled = false
    var completeRunId: UUID?
    var completeRunResult: Result<Void, Error> = .success(())
    
    var pauseRunCalled = false
    var pauseRunId: UUID?
    var pauseRunResult: Result<Void, Error> = .success(())
    
    var cancelRunCalled = false
    var cancelRunId: UUID?
    var cancelRunResult: Result<Void, Error> = .success(())
    
    var updateRunCalled = false
    var updateRunResult: Result<Void, Error> = .success(())
    
    override func startRunAsync(id: UUID) async throws {
        startRunCalled = true
        startRunId = id
        
        switch startRunResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
    
    override func completeStop(stopId: UUID) throws {
        completeStopCalled = true
        completeStopId = stopId
        
        switch completeStopResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
    
    override func completeRunAsync(id: UUID) async throws {
        completeRunCalled = true
        completeRunId = id
        
        switch completeRunResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
    
    override func pauseRunAsync(id: UUID) async throws {
        pauseRunCalled = true
        pauseRunId = id
        
        switch pauseRunResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
    
    override func cancelRunAsync(id: UUID) async throws {
        cancelRunCalled = true
        cancelRunId = id
        
        switch cancelRunResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
    
    override func updateRun(_ run: SchoolRun) throws {
        updateRunCalled = true
        
        switch updateRunResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
}

class MockHapticManager: HapticManager {
    var lightImpactCalled = false
    var mediumImpactCalled = false
    var heavyImpactCalled = false
    var successCalled = false
    var errorCalled = false
    var warningCalled = false
    var selectionCalled = false
    
    override func lightImpact() {
        lightImpactCalled = true
    }
    
    override func mediumImpact() {
        mediumImpactCalled = true
    }
    
    override func heavyImpact() {
        heavyImpactCalled = true
    }
    
    override func success() {
        successCalled = true
    }
    
    override func error() {
        errorCalled = true
    }
    
    override func warning() {
        warningCalled = true
    }
    
    override func selection() {
        selectionCalled = true
    }
}