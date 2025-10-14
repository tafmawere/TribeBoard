import XCTest
import SwiftUI
@testable import TribeBoard

/// Basic integration test for School Run core functionality
@MainActor
final class SchoolRunBasicIntegrationTest: XCTestCase {
    
    func testSchoolRunBasicIntegration() async throws {
        // Test 1: Navigation Tab Integration
        let schoolRunTab = NavigationTab.schoolRun
        XCTAssertEqual(schoolRunTab.displayName, "Run")
        XCTAssertEqual(schoolRunTab.icon, "car")
        XCTAssertEqual(schoolRunTab.activeIcon, "car.fill")
        
        // Test 2: Model Creation and Properties
        let run = SchoolRun(
            title: "Test Run",
            date: Date().addingTimeInterval(3600),
            route: [
                RunStop(name: "Home", time: Date().addingTimeInterval(3600), type: .pickup),
                RunStop(name: "School", time: Date().addingTimeInterval(4200), type: .dropoff)
            ]
        )
        
        XCTAssertEqual(run.title, "Test Run")
        XCTAssertEqual(run.totalStops, 2)
        XCTAssertEqual(run.completedStops, 0)
        XCTAssertEqual(run.progress, 0.0)
        XCTAssertEqual(run.status, .scheduled)
        XCTAssertTrue(run.isUpcoming)
        
        // Test 3: Manager Integration
        let manager = SchoolRunManager()
        manager.createRun(run)
        
        XCTAssertEqual(manager.runs.count, 1)
        XCTAssertEqual(manager.runs.first?.id, run.id)
        
        // Test 4: Status Transitions
        manager.startRun(id: run.id)
        let activeRun = manager.getRun(id: run.id)
        XCTAssertEqual(activeRun?.status, .inProgress)
        XCTAssertNotNil(manager.activeRun)
        
        manager.completeRun(id: run.id)
        let completedRun = manager.getRun(id: run.id)
        XCTAssertEqual(completedRun?.status, .completed)
        XCTAssertNil(manager.activeRun)
        
        // Test 5: Data Persistence
        manager.saveToStorage()
        
        let newManager = SchoolRunManager()
        XCTAssertEqual(newManager.runs.count, 1)
        XCTAssertEqual(newManager.runs.first?.title, "Test Run")
        
        // Cleanup
        manager.clearAllRuns()
    }
    
    func testSchoolRunValidation() throws {
        // Test valid run
        let validRun = SchoolRun(
            title: "Valid Run",
            date: Date().addingTimeInterval(3600),
            route: [
                RunStop(name: "Home", time: Date().addingTimeInterval(3600), type: .pickup)
            ]
        )
        
        XCTAssertNoThrow(try SchoolRunValidation.validateRun(validRun))
        
        // Test invalid run
        let invalidRun = SchoolRun(
            title: "",
            date: Date().addingTimeInterval(-3600) // Past date
        )
        
        XCTAssertThrowsError(try SchoolRunValidation.validateRun(invalidRun))
    }
    
    func testAccessibilityProperties() {
        let run = SchoolRun(
            title: "Accessibility Test",
            date: Date(),
            route: [
                RunStop(name: "Home", time: Date(), type: .pickup),
                RunStop(name: "School", time: Date().addingTimeInterval(1200), type: .dropoff)
            ]
        )
        
        // Test that accessibility-required properties are not empty
        XCTAssertFalse(run.title.isEmpty)
        XCTAssertFalse(run.formattedDate.isEmpty)
        XCTAssertFalse(run.status.displayText.isEmpty)
        XCTAssertFalse(run.status.icon.isEmpty)
        
        let stop = run.route.first!
        XCTAssertFalse(stop.name.isEmpty)
        XCTAssertFalse(stop.type.displayName.isEmpty)
        XCTAssertFalse(stop.formattedTime.isEmpty)
    }
}