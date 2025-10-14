import XCTest
@testable import TribeBoard

/// Performance tests for School Run optimizations
@MainActor
final class SchoolRunPerformanceTests: XCTestCase {
    
    var manager: SchoolRunManager!
    var viewModel: SchoolRunViewModel!
    var historyViewModel: RunHistoryViewModel!
    
    override func setUp() {
        super.setUp()
        manager = SchoolRunManager()
        viewModel = SchoolRunViewModel(manager: manager)
        historyViewModel = RunHistoryViewModel(manager: manager)
    }
    
    override func tearDown() {
        manager = nil
        viewModel = nil
        historyViewModel = nil
        super.tearDown()
    }
    
    // MARK: - Manager Performance Tests
    
    func testManagerCachePerformance() throws {
        // Create test data
        let runs = createTestRuns(count: 100)
        for run in runs {
            try manager.createRun(run)
        }
        
        // Measure cached property access performance
        measure {
            for _ in 0..<100 {
                _ = manager.todaysRuns
                _ = manager.upcomingRuns
                _ = manager.completedRuns
            }
        }
    }
    
    func testManagerMemoryUsage() throws {
        let initialMemory = getCurrentMemoryUsage()
        
        // Create large dataset
        let runs = createTestRuns(count: 1000)
        for run in runs {
            try manager.createRun(run)
        }
        
        let afterCreationMemory = getCurrentMemoryUsage()
        
        // Clear cache and measure memory
        manager.refreshCache()
        
        let afterClearMemory = getCurrentMemoryUsage()
        
        // Memory should not grow excessively
        let memoryGrowth = afterCreationMemory - initialMemory
        XCTAssertLessThan(memoryGrowth, 50.0, "Memory usage grew too much: \(memoryGrowth) MB")
        
        // Cache clearing should help with memory
        XCTAssertLessThanOrEqual(afterClearMemory, afterCreationMemory, "Cache clearing should not increase memory")
    }
    
    func testLargeDatasetFiltering() throws {
        // Create large dataset with mixed statuses and dates
        let runs = createTestRuns(count: 500)
        for run in runs {
            try manager.createRun(run)
        }
        
        // Measure filtering performance
        measure {
            _ = manager.todaysRuns
            _ = manager.upcomingRuns
            _ = manager.completedRuns
            _ = manager.scheduledRuns
        }
    }
    
    // MARK: - ViewModel Performance Tests
    
    func testViewModelLoadingPerformance() throws {
        // Create test data
        let runs = createTestRuns(count: 200)
        for run in runs {
            try manager.createRun(run)
        }
        
        // Measure loading performance
        measure {
            viewModel.loadRuns()
        }
    }
    
    func testViewModelBindingPerformance() throws {
        // Create test data
        let runs = createTestRuns(count: 100)
        for run in runs {
            try manager.createRun(run)
        }
        
        // Measure binding update performance
        let expectation = XCTestExpectation(description: "Binding updates")
        
        var updateCount = 0
        let cancellable = viewModel.$runs.sink { _ in
            updateCount += 1
            if updateCount >= 10 {
                expectation.fulfill()
            }
        }
        
        // Trigger multiple updates
        measure {
            for i in 0..<10 {
                let newRun = createTestRun(title: "Performance Test \(i)")
                try! manager.createRun(newRun)
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        cancellable.cancel()
    }
    
    // MARK: - History ViewModel Performance Tests
    
    func testHistoryViewModelPaginationPerformance() throws {
        // Create large historical dataset
        let runs = createTestRuns(count: 1000, status: .completed)
        for run in runs {
            try manager.createRun(run)
        }
        
        historyViewModel.loadHistoricalRuns()
        
        // Measure pagination performance
        measure {
            for _ in 0..<10 {
                historyViewModel.loadMoreRuns()
            }
        }
    }
    
    func testHistoryViewModelFilteringPerformance() throws {
        // Create large dataset
        let runs = createTestRuns(count: 500, status: .completed)
        for run in runs {
            try manager.createRun(run)
        }
        
        historyViewModel.loadHistoricalRuns()
        
        // Measure filtering performance
        measure {
            historyViewModel.searchText = "Test"
            historyViewModel.selectedDateRange = .lastMonth
            historyViewModel.selectedStatusFilter = .completed
            historyViewModel.searchText = ""
            historyViewModel.clearFilters()
        }
    }
    
    // MARK: - Timer Performance Tests
    
    func testTimerManagerPerformance() {
        let timerManager = OptimizedTimerManager.shared
        
        // Measure timer creation and cleanup performance
        measure {
            for i in 0..<100 {
                timerManager.createTimer(identifier: "test_\(i)", interval: 1.0) {
                    // Empty action
                }
            }
            
            for i in 0..<100 {
                timerManager.cancelTimer(identifier: "test_\(i)")
            }
        }
    }
    
    func testDebouncedTimerPerformance() {
        let timerManager = OptimizedTimerManager.shared
        
        // Measure debounced timer performance
        measure {
            for i in 0..<50 {
                timerManager.createDebouncedTimer(identifier: "debounce_\(i)", delay: 0.1) {
                    // Empty action
                }
            }
        }
        
        // Cleanup
        for i in 0..<50 {
            timerManager.cancelTimer(identifier: "debounce_\(i)")
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryPressureHandling() throws {
        // Create large dataset
        let runs = createTestRuns(count: 200)
        for run in runs {
            try manager.createRun(run)
        }
        
        let initialMemory = getCurrentMemoryUsage()
        
        // Simulate memory pressure
        NotificationCenter.default.post(name: .memoryPressureHigh, object: nil)
        
        // Allow time for cleanup
        let expectation = XCTestExpectation(description: "Memory cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        let afterCleanupMemory = getCurrentMemoryUsage()
        
        // Memory should not have increased significantly
        XCTAssertLessThanOrEqual(afterCleanupMemory, initialMemory + 10.0, "Memory cleanup should be effective")
    }
    
    // MARK: - Helper Methods
    
    private func createTestRuns(count: Int, status: RunStatus = .scheduled) -> [SchoolRun] {
        var runs: [SchoolRun] = []
        
        for i in 0..<count {
            let run = createTestRun(
                title: "Test Run \(i)",
                status: status,
                dayOffset: i % 30 - 15 // Spread across 30 days
            )
            runs.append(run)
        }
        
        return runs
    }
    
    private func createTestRun(
        title: String = "Test Run",
        status: RunStatus = .scheduled,
        dayOffset: Int = 0
    ) -> SchoolRun {
        let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
        
        let stops = [
            RunStop(name: "Home", time: date, type: .pickup),
            RunStop(name: "School", time: date.addingTimeInterval(900), type: .dropoff)
        ]
        
        return SchoolRun(
            title: title,
            date: date,
            route: stops,
            status: status,
            estimatedDuration: 1800
        )
    }
    
    private func getCurrentMemoryUsage() -> Double {
        let memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(memoryInfo.resident_size) / (1024 * 1024) // Convert to MB
        }
        
        return 0
    }
}

// MARK: - Performance Benchmarks

extension SchoolRunPerformanceTests {
    
    func testBenchmarkRunCardRendering() {
        let runs = createTestRuns(count: 50)
        
        // This would typically be tested with UI testing framework
        // For now, we'll measure the data preparation performance
        measure {
            for run in runs {
                // Simulate the expensive operations that OptimizedRunCard pre-computes
                _ = run.route.filter { $0.type == .pickup }.count
                _ = run.route.filter { $0.type == .dropoff }.count
                _ = run.formattedDate
                _ = run.formattedDuration
                _ = run.status.color
                _ = run.status.icon
            }
        }
    }
    
    func testBenchmarkHistoryCardRendering() {
        let runs = createTestRuns(count: 100, status: .completed)
        
        measure {
            for run in runs {
                // Simulate OptimizedHistoryRunCard pre-computations
                _ = run.formattedDate
                _ = run.formattedDuration
                _ = run.route.count
                _ = Array(run.route.prefix(3))
                _ = run.route.count > 3
            }
        }
    }
}