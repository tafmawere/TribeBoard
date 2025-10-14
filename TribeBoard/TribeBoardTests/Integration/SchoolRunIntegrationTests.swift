import XCTest
import SwiftUI
@testable import TribeBoard

/// Comprehensive integration tests for the School Run scheduler feature
/// Tests complete user flows from run creation to completion
@MainActor
final class SchoolRunIntegrationTests: XCTestCase {
    
    var manager: SchoolRunManager!
    var viewModel: SchoolRunViewModel!
    var plannerViewModel: RunPlannerViewModel!
    var activeRunViewModel: ActiveRunViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize components
        manager = SchoolRunManager()
        viewModel = SchoolRunViewModel()
        plannerViewModel = RunPlannerViewModel()
        activeRunViewModel = ActiveRunViewModel()
        
        // Clear any existing data
        manager.clearAllRuns()
    }
    
    override func tearDown() async throws {
        // Clean up
        manager.clearAllRuns()
        manager = nil
        viewModel = nil
        plannerViewModel = nil
        activeRunViewModel = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Complete User Flow Tests
    
    /// Test complete user flow from run creation to completion
    func testCompleteUserFlowFromCreationToCompletion() async throws {
        // Step 1: Create a new run using RunPlannerViewModel
        plannerViewModel.title = "Morning School Run"
        plannerViewModel.selectedDate = Date().addingTimeInterval(3600) // 1 hour from now
        
        // Add stops
        let homeStop = RunStop(
            name: "Home",
            time: Date().addingTimeInterval(3600),
            note: "Pick up Emma",
            type: .pickup
        )
        
        let schoolStop = RunStop(
            name: "Elementary School",
            time: Date().addingTimeInterval(4200), // 70 minutes from now
            note: "Drop off Emma",
            type: .dropoff
        )
        
        plannerViewModel.stops = [homeStop, schoolStop]
        
        // Validate form
        plannerViewModel.validateForm()
        XCTAssertTrue(plannerViewModel.isValid, "Form should be valid with title and stops")
        
        // Save the run
        let savedRun = plannerViewModel.saveRun()
        XCTAssertNotNil(savedRun, "Run should be saved successfully")
        XCTAssertEqual(savedRun?.title, "Morning School Run")
        XCTAssertEqual(savedRun?.route.count, 2)
        XCTAssertEqual(savedRun?.status, .scheduled)
        
        // Step 2: Load runs in main view model
        await viewModel.loadRuns()
        XCTAssertEqual(viewModel.runs.count, 1, "Should have one run loaded")
        
        let loadedRun = viewModel.runs.first!
        XCTAssertEqual(loadedRun.title, "Morning School Run")
        XCTAssertEqual(loadedRun.status, .scheduled)
        
        // Step 3: Start the run
        await viewModel.startRun(loadedRun)
        
        // Verify run status changed to in progress
        await viewModel.loadRuns()
        let startedRun = viewModel.runs.first!
        XCTAssertEqual(startedRun.status, .inProgress)
        XCTAssertNotNil(viewModel.activeRun, "Should have an active run")
        
        // Step 4: Execute run using ActiveRunViewModel
        activeRunViewModel.currentRun = startedRun
        
        // Verify initial state
        XCTAssertEqual(activeRunViewModel.currentStopIndex, 0)
        XCTAssertEqual(activeRunViewModel.currentStop?.name, "Home")
        XCTAssertEqual(activeRunViewModel.progress, 0.0)
        
        // Complete first stop
        activeRunViewModel.moveToNextStop()
        XCTAssertEqual(activeRunViewModel.currentStopIndex, 1)
        XCTAssertEqual(activeRunViewModel.currentStop?.name, "Elementary School")
        XCTAssertEqual(activeRunViewModel.progress, 0.5)
        
        // Complete second stop
        activeRunViewModel.moveToNextStop()
        XCTAssertEqual(activeRunViewModel.currentStopIndex, 2)
        XCTAssertNil(activeRunViewModel.currentStop)
        XCTAssertEqual(activeRunViewModel.progress, 1.0)
        
        // Step 5: End the run
        activeRunViewModel.endRun()
        
        // Verify run completion
        await viewModel.loadRuns()
        let completedRun = viewModel.runs.first!
        XCTAssertEqual(completedRun.status, .completed)
        XCTAssertNil(viewModel.activeRun, "Should not have an active run")
        XCTAssertTrue(completedRun.allStopsCompleted, "All stops should be completed")
    }
    
    /// Test navigation integration with existing TribeBoard structure
    func testNavigationIntegration() async throws {
        // Test NavigationTab integration
        let schoolRunTab = NavigationTab.schoolRun
        XCTAssertEqual(schoolRunTab.displayName, "Run")
        XCTAssertEqual(schoolRunTab.icon, "car")
        XCTAssertEqual(schoolRunTab.activeIcon, "car.fill")
        
        // Test that school run tab is included in all cases
        let allTabs = NavigationTab.allCases
        XCTAssertTrue(allTabs.contains(.schoolRun), "School run tab should be included in navigation")
        XCTAssertEqual(allTabs.count, 5, "Should have exactly 5 navigation tabs")
        
        // Verify tab order
        let expectedOrder: [NavigationTab] = [.dashboard, .calendar, .schoolRun, .homeLife, .tasks]
        XCTAssertEqual(allTabs, expectedOrder, "Navigation tabs should be in correct order")
    }
    
    /// Test data persistence and state management
    func testDataPersistenceAndStateManagement() async throws {
        // Create test runs
        let run1 = SchoolRun(
            title: "Morning Run",
            date: Date().addingTimeInterval(3600),
            route: [
                RunStop(name: "Home", time: Date().addingTimeInterval(3600), type: .pickup),
                RunStop(name: "School", time: Date().addingTimeInterval(4200), type: .dropoff)
            ]
        )
        
        let run2 = SchoolRun(
            title: "Afternoon Run",
            date: Date().addingTimeInterval(7200),
            route: [
                RunStop(name: "School", time: Date().addingTimeInterval(7200), type: .pickup),
                RunStop(name: "Home", time: Date().addingTimeInterval(7800), type: .dropoff)
            ]
        )
        
        // Save runs
        manager.createRun(run1)
        manager.createRun(run2)
        
        // Verify persistence
        XCTAssertEqual(manager.runs.count, 2)
        
        // Test data loading after restart (simulate app restart)
        let newManager = SchoolRunManager()
        XCTAssertEqual(newManager.runs.count, 2, "Data should persist across manager instances")
        
        // Test run filtering
        await viewModel.loadRuns()
        XCTAssertEqual(viewModel.runs.count, 2)
        XCTAssertEqual(viewModel.upcomingRuns.count, 2)
        XCTAssertEqual(viewModel.todaysRuns.count, 0) // Runs are in the future
        XCTAssertEqual(viewModel.completedRuns.count, 0)
        
        // Test state management during run execution
        await viewModel.startRun(run1)
        XCTAssertNotNil(viewModel.activeRun)
        XCTAssertEqual(viewModel.activeRun?.id, run1.id)
        
        // Complete the run
        await viewModel.completeRun(run1)
        XCTAssertNil(viewModel.activeRun)
        
        // Verify state after completion
        await viewModel.loadRuns()
        let completedRun = viewModel.runs.first { $0.id == run1.id }!
        XCTAssertEqual(completedRun.status, .completed)
    }
    
    /// Test accessibility compliance
    func testAccessibilityCompliance() async throws {
        // Test that all models provide proper accessibility information
        let run = SchoolRun(
            title: "Test Run",
            date: Date(),
            route: [
                RunStop(name: "Home", time: Date(), type: .pickup),
                RunStop(name: "School", time: Date().addingTimeInterval(1200), type: .dropoff)
            ]
        )
        
        // Test accessibility properties
        XCTAssertFalse(run.title.isEmpty, "Run title should not be empty for accessibility")
        XCTAssertFalse(run.formattedDate.isEmpty, "Formatted date should not be empty for accessibility")
        
        // Test stop accessibility
        let stop = run.route.first!
        XCTAssertFalse(stop.name.isEmpty, "Stop name should not be empty for accessibility")
        XCTAssertFalse(stop.type.displayName.isEmpty, "Stop type display name should not be empty for accessibility")
        XCTAssertFalse(stop.formattedTime.isEmpty, "Stop formatted time should not be empty for accessibility")
        
        // Test status accessibility
        XCTAssertFalse(run.status.displayText.isEmpty, "Status display text should not be empty for accessibility")
        XCTAssertFalse(run.status.icon.isEmpty, "Status icon should not be empty for accessibility")
        
        // Test computed properties for accessibility
        XCTAssertGreaterThanOrEqual(run.progress, 0.0, "Progress should be valid for accessibility")
        XCTAssertLessThanOrEqual(run.progress, 1.0, "Progress should be valid for accessibility")
    }
    
    /// Test error handling and edge cases
    func testErrorHandlingAndEdgeCases() async throws {
        // Test empty run creation
        plannerViewModel.title = ""
        plannerViewModel.stops = []
        plannerViewModel.validateForm()
        XCTAssertFalse(plannerViewModel.isValid, "Empty run should not be valid")
        
        let emptyRun = plannerViewModel.saveRun()
        XCTAssertNil(emptyRun, "Empty run should not be saved")
        
        // Test run with only title
        plannerViewModel.title = "Test Run"
        plannerViewModel.validateForm()
        XCTAssertFalse(plannerViewModel.isValid, "Run without stops should not be valid")
        
        // Test run with past date
        plannerViewModel.selectedDate = Date().addingTimeInterval(-3600) // 1 hour ago
        plannerViewModel.stops = [
            RunStop(name: "Test Stop", time: Date().addingTimeInterval(-3600), type: .pickup)
        ]
        plannerViewModel.validateForm()
        XCTAssertFalse(plannerViewModel.isValid, "Run with past date should not be valid")
        
        // Test starting non-existent run
        let nonExistentRun = SchoolRun(title: "Non-existent", date: Date())
        await viewModel.startRun(nonExistentRun)
        XCTAssertNil(viewModel.activeRun, "Should not start non-existent run")
        
        // Test completing non-active run
        let scheduledRun = SchoolRun(title: "Scheduled", date: Date())
        manager.createRun(scheduledRun)
        await viewModel.completeRun(scheduledRun)
        
        // Verify run status didn't change inappropriately
        let loadedRun = manager.getRun(id: scheduledRun.id)
        XCTAssertEqual(loadedRun?.status, .scheduled, "Scheduled run should not be completed without starting")
        
        // Test deleting active run
        let activeRun = SchoolRun(title: "Active", date: Date(), status: .inProgress)
        manager.createRun(activeRun)
        manager.setActiveRun(activeRun)
        
        await viewModel.deleteRun(activeRun)
        XCTAssertNil(manager.activeRun, "Active run should be cleared when deleted")
        XCTAssertNil(manager.getRun(id: activeRun.id), "Run should be deleted")
    }
    
    /// Test consistent styling with existing app design
    func testConsistentStyling() async throws {
        // Test that status colors are consistent
        let statuses: [RunStatus] = [.scheduled, .inProgress, .completed, .cancelled]
        
        for status in statuses {
            XCTAssertNotNil(status.color, "Status should have a color defined")
            XCTAssertNotNil(status.backgroundColor, "Status should have a background color defined")
            XCTAssertNotNil(status.foregroundColor, "Status should have a foreground color defined")
            XCTAssertFalse(status.icon.isEmpty, "Status should have an icon defined")
        }
        
        // Test stop type colors
        let stopTypes: [RunStop.StopType] = [.pickup, .dropoff]
        
        for type in stopTypes {
            XCTAssertNotNil(type.color, "Stop type should have a color defined")
            XCTAssertFalse(type.icon.isEmpty, "Stop type should have an icon defined")
            XCTAssertFalse(type.displayName.isEmpty, "Stop type should have a display name")
        }
        
        // Test that computed properties provide consistent formatting
        let run = SchoolRun(
            title: "Test Run",
            date: Date(),
            route: [
                RunStop(name: "Home", time: Date(), type: .pickup),
                RunStop(name: "School", time: Date().addingTimeInterval(1200), type: .dropoff)
            ],
            estimatedDuration: 1800 // 30 minutes
        )
        
        XCTAssertFalse(run.formattedDate.isEmpty, "Formatted date should not be empty")
        XCTAssertFalse(run.formattedDuration.isEmpty, "Formatted duration should not be empty")
        XCTAssertEqual(run.formattedDuration, "30m", "Duration should be formatted correctly")
    }
    
    /// Test performance with large datasets
    func testPerformanceWithLargeDatasets() async throws {
        // Create a large number of runs
        let runCount = 100
        var runs: [SchoolRun] = []
        
        for i in 0..<runCount {
            let run = SchoolRun(
                title: "Run \(i)",
                date: Date().addingTimeInterval(TimeInterval(i * 3600)), // Spread over 100 hours
                route: [
                    RunStop(name: "Stop A", time: Date().addingTimeInterval(TimeInterval(i * 3600)), type: .pickup),
                    RunStop(name: "Stop B", time: Date().addingTimeInterval(TimeInterval(i * 3600 + 1200)), type: .dropoff)
                ],
                status: i % 3 == 0 ? .completed : .scheduled
            )
            runs.append(run)
        }
        
        // Measure performance of bulk operations
        measure {
            for run in runs {
                manager.createRun(run)
            }
        }
        
        XCTAssertEqual(manager.runs.count, runCount, "All runs should be created")
        
        // Measure performance of filtering operations
        await viewModel.loadRuns()
        
        measure {
            _ = viewModel.upcomingRuns
            _ = viewModel.completedRuns
            _ = viewModel.todaysRuns
        }
        
        // Test that filtering works correctly with large datasets
        XCTAssertGreaterThan(viewModel.upcomingRuns.count, 0, "Should have upcoming runs")
        XCTAssertGreaterThan(viewModel.completedRuns.count, 0, "Should have completed runs")
    }
    
    /// Test integration with existing TribeBoard components
    func testTribeBoardComponentIntegration() async throws {
        // Test that school run models work with existing design system
        let run = SchoolRun(
            title: "Integration Test Run",
            date: Date(),
            route: [
                RunStop(name: "Home", time: Date(), type: .pickup),
                RunStop(name: "School", time: Date().addingTimeInterval(1200), type: .dropoff)
            ]
        )
        
        // Test that run can be used with existing mock data patterns
        let mockRuns = MockDataGenerator.mockSchoolRuns()
        XCTAssertGreaterThan(mockRuns.count, 0, "Mock data generator should create school runs")
        
        // Test that runs integrate with existing error handling
        do {
            try SchoolRunValidation.validateRun(run)
        } catch {
            XCTFail("Valid run should not throw validation error: \(error)")
        }
        
        // Test invalid run validation
        let invalidRun = SchoolRun(title: "", date: Date().addingTimeInterval(-3600)) // Empty title, past date
        XCTAssertThrowsError(try SchoolRunValidation.validateRun(invalidRun), "Invalid run should throw validation error")
    }
    
    /// Test haptic feedback integration
    func testHapticFeedbackIntegration() async throws {
        // Test that haptic feedback methods exist and can be called
        // Note: We can't test actual haptic feedback in unit tests, but we can verify the methods exist
        
        // These should not crash
        SchoolRunHapticFeedback.navigationAction()
        SchoolRunHapticFeedback.runStarted()
        SchoolRunHapticFeedback.runCompleted()
        SchoolRunHapticFeedback.destructiveAction()
        
        // Test that haptic feedback respects accessibility settings
        // This is handled internally by the HapticManager
        XCTAssertTrue(true, "Haptic feedback methods should execute without errors")
    }
}

// MARK: - Test Utilities

extension SchoolRunIntegrationTests {
    
    /// Create a sample run for testing
    private func createSampleRun(title: String = "Test Run", futureDate: Bool = true) -> SchoolRun {
        let date = futureDate ? Date().addingTimeInterval(3600) : Date().addingTimeInterval(-3600)
        return SchoolRun(
            title: title,
            date: date,
            route: [
                RunStop(name: "Home", time: date, type: .pickup),
                RunStop(name: "School", time: date.addingTimeInterval(1200), type: .dropoff)
            ]
        )
    }
    
    /// Verify run state consistency
    private func verifyRunStateConsistency(_ run: SchoolRun) {
        XCTAssertGreaterThanOrEqual(run.progress, 0.0, "Progress should not be negative")
        XCTAssertLessThanOrEqual(run.progress, 1.0, "Progress should not exceed 1.0")
        XCTAssertEqual(run.completedStops, run.route.filter(\.isCompleted).count, "Completed stops count should match filtered count")
        XCTAssertEqual(run.totalStops, run.route.count, "Total stops should match route count")
        
        if run.status == .completed {
            XCTAssertTrue(run.allStopsCompleted, "Completed run should have all stops completed")
        }
        
        if run.status == .inProgress {
            XCTAssertNotNil(run.nextStop, "In-progress run should have a next stop (unless all completed)")
        }
    }
}