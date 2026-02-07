//
//  MyRunsViewTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/06.
//

import XCTest
@testable import Tribeboard

/// Tests for My Runs screen display
/// Validates: Requirement 3.1 - My Runs screen shows three tabs
final class MyRunsViewTests: XCTestCase {
    
    func testMyRunsViewTabsExist() {
        // Verify that all three tab cases exist
        let allTabs = MyRunsView.RunTab.allCases
        
        XCTAssertEqual(allTabs.count, 3, "My Runs should have exactly 3 tabs")
        
        let tabNames = allTabs.map { $0.rawValue }
        XCTAssertTrue(tabNames.contains("Today"), "Today tab should exist")
        XCTAssertTrue(tabNames.contains("Upcoming"), "Upcoming tab should exist")
        XCTAssertTrue(tabNames.contains("History"), "History tab should exist")
        
        print("✅ My Runs screen has all three required tabs: Today, Upcoming, History")
    }
    
    func testDemoFlowModeEnabled() {
        // Verify that demo flow mode is enabled in DEBUG builds
        #if DEBUG
        XCTAssertTrue(AppConfig.isDemoFlowEnabled, "Demo flow mode should be enabled in DEBUG builds")
        XCTAssertEqual(AppConfig.launchMode, .demoFlow, "Launch mode should be .demoFlow")
        print("✅ Demo flow mode is enabled")
        #endif
    }
    
    func testDemoFamilyConstants() {
        // Verify demo family constants are defined
        XCTAssertEqual(DemoSeedDataService.demoFamilyId, "demo-family-tribeboard")
        XCTAssertEqual(DemoSeedDataService.rueId, "demo-rue")
        XCTAssertEqual(DemoSeedDataService.tafadzwaId, "demo-tafadzwa")
        XCTAssertEqual(DemoSeedDataService.tjId, "demo-tj")
        XCTAssertEqual(DemoSeedDataService.tawanaId, "demo-tawana")
        
        print("✅ Demo family constants are correctly defined")
    }
}
