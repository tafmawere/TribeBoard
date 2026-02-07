//
//  TribeboardUITests.swift
//  TribeboardUITests
//
//  Created by Tafadzwa Mawere on 2026/02/03.
//

import XCTest

final class TribeboardUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    /// Test that My Runs screen displays correctly in demo flow mode
    /// Validates: Requirement 3.1 - My Runs screen shows three tabs
    @MainActor
    func testMyRunsScreenDisplays() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for the app to load
        let timeout: TimeInterval = 5.0
        
        // Verify user switcher is present (demo flow mode indicator)
        let userSwitcher = app.staticTexts["Switch User"]
        XCTAssertTrue(userSwitcher.waitForExistence(timeout: timeout), "User switcher should be visible in demo flow mode")
        
        // Verify the segmented control with user names exists
        let rueButton = app.buttons["Rue Mawere"]
        XCTAssertTrue(rueButton.exists, "Rue Mawere user option should exist")
        
        // Verify My Runs screen tabs are present
        let todayTab = app.buttons["Today"]
        let upcomingTab = app.buttons["Upcoming"]
        let historyTab = app.buttons["History"]
        
        XCTAssertTrue(todayTab.waitForExistence(timeout: timeout), "Today tab should be visible")
        XCTAssertTrue(upcomingTab.exists, "Upcoming tab should be visible")
        XCTAssertTrue(historyTab.exists, "History tab should be visible")
        
        print("✅ My Runs screen displays correctly with all three tabs")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
