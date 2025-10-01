import XCTest

class UIPerformanceTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "PERFORMANCE_TESTING"]
        app.launchEnvironment = [
            "ANIMATION_SPEED": "1.0",
            "PERFORMANCE_MODE": "enabled"
        ]
        app.launch()
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    // MARK: - Screen Transition Performance Tests
    
    func testMainTabNavigationPerformance() {
        // Test performance of navigation between main tabs
        measure(metrics: [XCTOSSignpostMetric.navigationTransitionMetric]) {
            // Navigate through all main tabs
            let tabBar = app.tabBars.firstMatch
            
            // Family tab
            tabBar.buttons["Family"].tap()
            XCTAssertTrue(app.navigationBars["Family"].waitForExistence(timeout: 2.0))
            
            // Tasks tab
            tabBar.buttons["Tasks"].tap()
            XCTAssertTrue(app.navigationBars["Tasks"].waitForExistence(timeout: 2.0))
            
            // School Run tab
            tabBar.buttons["School Run"].tap()
            XCTAssertTrue(app.navigationBars["School Run"].waitForExistence(timeout: 2.0))
            
            // Meal Plan tab
            tabBar.buttons["Meal Plan"].tap()
            XCTAssertTrue(app.navigationBars["Meal Plan"].waitForExistence(timeout: 2.0))
            
            // Settings tab
            tabBar.buttons["Settings"].tap()
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2.0))
        }
    }
    
    func testModalPresentationPerformance() {
        // Test performance of modal presentation and dismissal
        measure(metrics: [XCTOSSignpostMetric.navigationTransitionMetric]) {
            // Navigate to Tasks tab
            app.tabBars.buttons["Tasks"].tap()
            
            // Present add task modal
            app.navigationBars.buttons["Add"].tap()
            XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 2.0))
            
            // Dismiss modal
            app.navigationBars.buttons["Cancel"].tap()
            XCTAssertTrue(app.navigationBars["Tasks"].waitForExistence(timeout: 2.0))
        }
    }
    
    func testDeepNavigationPerformance() {
        // Test performance of deep navigation flows
        measure(metrics: [XCTOSSignpostMetric.navigationTransitionMetric]) {
            // Navigate to Family tab
            app.tabBars.buttons["Family"].tap()
            
            // Navigate to family settings
            app.buttons["Family Settings"].tap()
            XCTAssertTrue(app.navigationBars["Family Settings"].waitForExistence(timeout: 2.0))
            
            // Navigate to member management
            app.buttons["Manage Members"].tap()
            XCTAssertTrue(app.navigationBars["Members"].waitForExistence(timeout: 2.0))
            
            // Navigate back
            app.navigationBars.buttons.element(boundBy: 0).tap()
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.navigationBars["Family"].waitForExistence(timeout: 2.0))
        }
    }
    
    func testNavigationStackPerformance() {
        // Test performance with deep navigation stack
        let navigationDepth = 5
        
        measure(metrics: [XCTOSSignpostMetric.navigationTransitionMetric]) {
            app.tabBars.buttons["Settings"].tap()
            
            // Build navigation stack
            for i in 0..<navigationDepth {
                if i == 0 {
                    app.buttons["Privacy Settings"].tap()
                } else if i == 1 {
                    app.buttons["Data Management"].tap()
                } else if i == 2 {
                    app.buttons["Export Data"].tap()
                } else if i == 3 {
                    app.buttons["Export Options"].tap()
                } else {
                    app.buttons["Advanced Options"].tap()
                }
                
                // Wait for navigation to complete
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            // Navigate back through entire stack
            for _ in 0..<navigationDepth {
                app.navigationBars.buttons.element(boundBy: 0).tap()
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }
    
    // MARK: - Animation Performance Tests
    
    func testLoadingAnimationPerformance() {
        // Test loading animation performance and frame rate
        measure(metrics: [XCTOSSignpostMetric.animationMetric]) {
            // Trigger loading state
            app.tabBars.buttons["Family"].tap()
            app.buttons["Refresh Family Data"].tap()
            
            // Wait for loading animation
            let loadingIndicator = app.activityIndicators.firstMatch
            XCTAssertTrue(loadingIndicator.waitForExistence(timeout: 1.0))
            
            // Wait for animation to complete
            XCTAssertTrue(loadingIndicator.waitForNonExistence(timeout: 5.0))
        }
    }
    
    func testTransitionAnimationPerformance() {
        // Test transition animation smoothness
        measure(metrics: [XCTOSSignpostMetric.animationMetric]) {
            let tabBar = app.tabBars.firstMatch
            
            // Perform rapid tab switches to test animation performance
            for _ in 0..<10 {
                tabBar.buttons["Family"].tap()
                Thread.sleep(forTimeInterval: 0.1)
                tabBar.buttons["Tasks"].tap()
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }
    
    func testCustomAnimationPerformance() {
        // Test custom animation performance
        measure(metrics: [XCTOSSignpostMetric.animationMetric]) {
            app.tabBars.buttons["Tasks"].tap()
            
            // Trigger task completion animation
            let firstTask = app.tables.cells.element(boundBy: 0)
            if firstTask.exists {
                firstTask.buttons["Complete"].tap()
                
                // Wait for completion animation
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
    }
    
    func testScrollAnimationPerformance() {
        // Test scroll animation performance
        measure(metrics: [XCTOSSignpostMetric.animationMetric]) {
            app.tabBars.buttons["Tasks"].tap()
            
            let tasksList = app.tables.firstMatch
            if tasksList.exists {
                // Perform smooth scrolling
                tasksList.swipeUp()
                Thread.sleep(forTimeInterval: 0.2)
                tasksList.swipeDown()
                Thread.sleep(forTimeInterval: 0.2)
                tasksList.swipeUp()
                Thread.sleep(forTimeInterval: 0.2)
            }
        }
    }
    
    // MARK: - Large Data Set Performance Tests
    
    func testLargeTaskListPerformance() {
        // Test performance with large task list
        app.launchEnvironment["LARGE_DATASET"] = "tasks_100"
        app.terminate()
        app.launch()
        
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            app.tabBars.buttons["Tasks"].tap()
            
            let tasksList = app.tables.firstMatch
            XCTAssertTrue(tasksList.waitForExistence(timeout: 3.0))
            
            // Scroll through large list
            for _ in 0..<20 {
                tasksList.swipeUp()
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }
    
    func testLargeFamilyMemberListPerformance() {
        // Test performance with large family member list
        app.launchEnvironment["LARGE_DATASET"] = "family_members_50"
        app.terminate()
        app.launch()
        
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            app.tabBars.buttons["Family"].tap()
            app.buttons["View All Members"].tap()
            
            let membersList = app.tables.firstMatch
            XCTAssertTrue(membersList.waitForExistence(timeout: 3.0))
            
            // Scroll through large member list
            for _ in 0..<15 {
                membersList.swipeUp()
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }
    
    func testLargeSchoolRunListPerformance() {
        // Test performance with large school run list
        app.launchEnvironment["LARGE_DATASET"] = "school_runs_75"
        app.terminate()
        app.launch()
        
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            app.tabBars.buttons["School Run"].tap()
            
            let runsList = app.tables.firstMatch
            XCTAssertTrue(runsList.waitForExistence(timeout: 3.0))
            
            // Scroll through large runs list
            for _ in 0..<25 {
                runsList.swipeUp()
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }
    
    // MARK: - Scroll Performance Tests
    
    func testFastScrollPerformance() {
        // Test fast scrolling performance
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            app.tabBars.buttons["Tasks"].tap()
            
            let tasksList = app.tables.firstMatch
            if tasksList.exists {
                // Perform fast scrolling
                tasksList.swipeUp(velocity: .fast)
                Thread.sleep(forTimeInterval: 0.5)
                tasksList.swipeDown(velocity: .fast)
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }
    
    func testContinuousScrollPerformance() {
        // Test continuous scrolling performance
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            app.tabBars.buttons["Tasks"].tap()
            
            let tasksList = app.tables.firstMatch
            if tasksList.exists {
                // Continuous scrolling for extended period
                for _ in 0..<30 {
                    tasksList.swipeUp()
                    Thread.sleep(forTimeInterval: 0.05)
                }
            }
        }
    }
    
    func testScrollWithComplexCellsPerformance() {
        // Test scrolling performance with complex table cells
        app.launchEnvironment["COMPLEX_CELLS"] = "enabled"
        app.terminate()
        app.launch()
        
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            app.tabBars.buttons["Family"].tap()
            
            let familyList = app.tables.firstMatch
            if familyList.exists {
                // Scroll through complex cells
                for _ in 0..<20 {
                    familyList.swipeUp()
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
        }
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryUsageDuringNavigation() {
        // Test memory usage during extensive navigation
        measure(metrics: [XCTMemoryMetric()]) {
            let tabBar = app.tabBars.firstMatch
            
            // Extensive navigation to test memory usage
            for _ in 0..<50 {
                tabBar.buttons["Family"].tap()
                Thread.sleep(forTimeInterval: 0.1)
                tabBar.buttons["Tasks"].tap()
                Thread.sleep(forTimeInterval: 0.1)
                tabBar.buttons["School Run"].tap()
                Thread.sleep(forTimeInterval: 0.1)
                tabBar.buttons["Settings"].tap()
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }
    
    func testMemoryUsageWithLargeDataSets() {
        // Test memory usage with large data sets
        app.launchEnvironment["LARGE_DATASET"] = "all_large"
        app.terminate()
        app.launch()
        
        measure(metrics: [XCTMemoryMetric()]) {
            let tabBar = app.tabBars.firstMatch
            
            // Navigate through all tabs with large data sets
            tabBar.buttons["Family"].tap()
            Thread.sleep(forTimeInterval: 1.0)
            
            tabBar.buttons["Tasks"].tap()
            Thread.sleep(forTimeInterval: 1.0)
            
            tabBar.buttons["School Run"].tap()
            Thread.sleep(forTimeInterval: 1.0)
            
            tabBar.buttons["Meal Plan"].tap()
            Thread.sleep(forTimeInterval: 1.0)
        }
    }
    
    // MARK: - Form Performance Tests
    
    func testFormInputPerformance() {
        // Test form input performance
        measure(metrics: [XCTOSSignpostMetric.customNavigationActionMetric]) {
            app.tabBars.buttons["Tasks"].tap()
            app.navigationBars.buttons["Add"].tap()
            
            // Fill out form quickly
            let titleField = app.textFields["Task Title"]
            titleField.tap()
            titleField.typeText("Performance Test Task")
            
            let descriptionField = app.textViews["Task Description"]
            descriptionField.tap()
            descriptionField.typeText("This is a performance test task description")
            
            // Select due date
            app.buttons["Due Date"].tap()
            app.datePickers.firstMatch.adjust(toPickerWheelValue: "Tomorrow")
            app.buttons["Done"].tap()
            
            // Save task
            app.navigationBars.buttons["Save"].tap()
        }
    }
    
    func testFormValidationPerformance() {
        // Test form validation performance
        measure {
            app.tabBars.buttons["Tasks"].tap()
            app.navigationBars.buttons["Add"].tap()
            
            // Trigger validation multiple times
            let titleField = app.textFields["Task Title"]
            for i in 0..<10 {
                titleField.tap()
                titleField.clearAndEnterText("Test \(i)")
                
                // Trigger validation by tapping elsewhere
                app.textViews["Task Description"].tap()
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            app.navigationBars.buttons["Cancel"].tap()
        }
    }
    
    // MARK: - Search Performance Tests
    
    func testSearchPerformance() {
        // Test search functionality performance
        app.launchEnvironment["LARGE_DATASET"] = "tasks_200"
        app.terminate()
        app.launch()
        
        measure {
            app.tabBars.buttons["Tasks"].tap()
            
            let searchField = app.searchFields.firstMatch
            searchField.tap()
            
            // Perform multiple searches
            let searchTerms = ["meeting", "grocery", "school", "family", "urgent"]
            
            for term in searchTerms {
                searchField.clearAndEnterText(term)
                Thread.sleep(forTimeInterval: 0.5)
                
                // Wait for search results
                let resultsList = app.tables.firstMatch
                XCTAssertTrue(resultsList.waitForExistence(timeout: 2.0))
            }
            
            // Clear search
            searchField.buttons["Clear text"].tap()
        }
    }
    
    // MARK: - Performance Benchmarks
    
    func testOverallAppPerformanceBenchmark() {
        // Comprehensive app performance benchmark
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        
        measure(options: options, metrics: [
            XCTOSSignpostMetric.navigationTransitionMetric,
            XCTMemoryMetric()
        ]) {
            // Simulate typical user journey
            let tabBar = app.tabBars.firstMatch
            
            // Family management
            tabBar.buttons["Family"].tap()
            Thread.sleep(forTimeInterval: 0.5)
            
            // Task management
            tabBar.buttons["Tasks"].tap()
            app.navigationBars.buttons["Add"].tap()
            app.navigationBars.buttons["Cancel"].tap()
            Thread.sleep(forTimeInterval: 0.5)
            
            // School run scheduling
            tabBar.buttons["School Run"].tap()
            Thread.sleep(forTimeInterval: 0.5)
            
            // Settings
            tabBar.buttons["Settings"].tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
    }
}

// MARK: - Performance Test Extensions

extension XCUIElement {
    func clearAndEnterText(_ text: String) {
        guard let stringValue = self.value as? String else {
            XCTFail("Tried to clear and enter text into a non-string value")
            return
        }
        
        self.tap()
        
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
        self.typeText(text)
    }
}

extension XCTOSSignpostMetric {
    static let navigationTransitionMetric = XCTOSSignpostMetric(
        subsystem: "com.tribeboard.app",
        category: "Navigation",
        name: "Transition"
    )
    
    static let animationMetric = XCTOSSignpostMetric(
        subsystem: "com.tribeboard.app",
        category: "Animation",
        name: "Performance"
    )
    
    static let scrollDecelerationMetric = XCTOSSignpostMetric(
        subsystem: "com.tribeboard.app",
        category: "Scroll",
        name: "Deceleration"
    )
    
    static let customNavigationActionMetric = XCTOSSignpostMetric(
        subsystem: "com.tribeboard.app",
        category: "Navigation",
        name: "Action"
    )
}