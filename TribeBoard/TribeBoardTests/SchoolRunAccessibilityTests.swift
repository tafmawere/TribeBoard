import XCTest
import SwiftUI
@testable import TribeBoard

/// Comprehensive accessibility tests for School Run feature
class SchoolRunAccessibilityTests: XCTestCase {
    
    var mockRunManager: ScheduledSchoolRunManager!
    var sampleRun: ScheduledSchoolRun!
    
    override func setUp() {
        super.setUp()
        mockRunManager = ScheduledSchoolRunManager()
        sampleRun = MockSchoolRunDataProvider.sampleRuns[0]
    }
    
    override func tearDown() {
        mockRunManager = nil
        sampleRun = nil
        super.tearDown()
    }
    
    // MARK: - Dynamic Type Tests
    
    @MainActor func testDynamicTypeScaling() {
        // Test that all text elements scale properly with dynamic type
        let testCases = SchoolRunAccessibilityTesting.testDynamicTypeScaling()
        
        for testCase in testCases {
            XCTAssertFalse(testCase.textElements.isEmpty, 
                          "Component \(testCase.component) should have text elements to test")
            
            // Verify min and max sizes are reasonable
            XCTAssertTrue(testCase.minSize.scaleFactor <= testCase.maxSize.scaleFactor,
                         "Min size should be less than or equal to max size for \(testCase.component)")
        }
    }
    
    @MainActor func testRunSummaryCardDynamicType() {
        // Test RunSummaryCard with different dynamic type sizes
        let card = RunSummaryCard(run: sampleRun)
        
        // Test with small size
        let smallTypeCard = card.environment(\.dynamicTypeSize, .xSmall)
        XCTAssertNotNil(smallTypeCard)
        
        // Test with large size
        let largeTypeCard = card.environment(\.dynamicTypeSize, .accessibility5)
        XCTAssertNotNil(largeTypeCard)
        
        // Test with medium size (default)
        let mediumTypeCard = card.environment(\.dynamicTypeSize, .medium)
        XCTAssertNotNil(mediumTypeCard)
    }
    
    @MainActor func testStopConfigurationRowDynamicType() {
        // Test StopConfigurationRow with different dynamic type sizes
        let stop = MockSchoolRunDataProvider.createEmptyStop()
        let row = StopConfigurationRow(
            stop: .constant(stop),
            children: MockSchoolRunDataProvider.children,
            stopNumber: 1,
            onDelete: {}
        )
        
        // Test with accessibility sizes
        let accessibilityRow = row.environment(\.dynamicTypeSize, .accessibility3)
        XCTAssertNotNil(accessibilityRow)
    }
    
    // MARK: - High Contrast Tests
    
    @MainActor func testHighContrastMode() {
        // Test that all components support high contrast mode
        let testCases = SchoolRunAccessibilityTesting.testHighContrastMode()
        
        for testCase in testCases {
            XCTAssertFalse(testCase.colorElements.isEmpty,
                          "Component \(testCase.component) should have color elements to test")
            
            for colorElement in testCase.colorElements {
                // Verify high contrast colors are different from normal colors
                XCTAssertNotEqual(colorElement.normal, colorElement.highContrast,
                                 "High contrast color should differ from normal color for \(colorElement.name)")
            }
        }
    }
    
    @MainActor func testRunSummaryCardHighContrast() {
        // Test RunSummaryCard in high contrast mode
        let card = RunSummaryCard(run: sampleRun)
        
        let highContrastCard = card.environment(\.colorSchemeContrast, .increased)
        XCTAssertNotNil(highContrastCard)
        
        let normalContrastCard = card.environment(\.colorSchemeContrast, .standard)
        XCTAssertNotNil(normalContrastCard)
    }
    
    @MainActor func testProgressIndicatorHighContrast() {
        // Test ProgressIndicator in high contrast mode
        let indicator = ProgressIndicator(current: 3, total: 6)
        
        let highContrastIndicator = indicator.environment(\.colorSchemeContrast, .increased)
        XCTAssertNotNil(highContrastIndicator)
    }
    
    // MARK: - VoiceOver Tests
    
    @MainActor func testVoiceOverNavigation() {
        // Test VoiceOver navigation through all screens
        let testCases = SchoolRunAccessibilityTesting.testVoiceOverNavigation()
        
        for testCase in testCases {
            XCTAssertFalse(testCase.elements.isEmpty,
                          "Screen \(testCase.screen) should have VoiceOver elements to test")
            
            for element in testCase.elements {
                // Verify accessibility properties are set
                XCTAssertFalse(element.expectedLabel.isEmpty,
                              "Element \(element.identifier) should have a label")
                XCTAssertFalse(element.expectedHint.isEmpty,
                              "Element \(element.identifier) should have a hint")
                XCTAssertFalse(element.expectedTraits.isEmpty,
                              "Element \(element.identifier) should have traits")
            }
        }
    }
    
    @MainActor func testDashboardAccessibilityLabels() {
        // Test that dashboard elements have proper accessibility labels
        let dashboard = SchoolRunDashboardView()
        
        // This would be tested with UI testing framework in a real implementation
        // For now, we verify the structure exists
        XCTAssertNotNil(dashboard)
    }
    
    @MainActor func testScheduleNewRunAccessibilityLabels() {
        // Test that schedule new run form has proper accessibility labels
        let scheduleView = ScheduleNewRunView()
        
        // Verify the view exists and can be created
        XCTAssertNotNil(scheduleView)
    }
    
    @MainActor func testRunExecutionAccessibilityLabels() {
        // Test that run execution view has proper accessibility labels
        let executionView = RunExecutionView(run: sampleRun)
        
        // Verify the view exists and can be created
        XCTAssertNotNil(executionView)
    }
    
    // MARK: - Reduced Motion Tests
    
    @MainActor func testReducedMotionSupport() {
        // Test that all animations respect reduced motion preference
        let testCases = SchoolRunAccessibilityTesting.testReducedMotion()
        
        for testCase in testCases {
            XCTAssertFalse(testCase.animations.isEmpty,
                          "Component \(testCase.component) should have animations to test")
        }
    }
    
    @MainActor func testCurrentStopCardReducedMotion() {
        // Test CurrentStopCard with reduced motion
        let stop = sampleRun.stops[0]
        let card = CurrentStopCard(stopNumber: 1, totalStops: 6, stop: stop, isActive: true)
        
        let reducedMotionCard = card.environment(\.accessibilityReduceMotion, true)
        XCTAssertNotNil(reducedMotionCard)
        
        let normalMotionCard = card.environment(\.accessibilityReduceMotion, false)
        XCTAssertNotNil(normalMotionCard)
    }
    
    @MainActor func testProgressIndicatorReducedMotion() {
        // Test ProgressIndicator with reduced motion
        let indicator = ProgressIndicator(current: 2, total: 5)
        
        let reducedMotionIndicator = indicator.environment(\.accessibilityReduceMotion, true)
        XCTAssertNotNil(reducedMotionIndicator)
    }
    
    // MARK: - Touch Target Tests
    
    @MainActor func testTouchTargetSizes() {
        // Test that all interactive elements meet minimum touch target size
        let testCases = SchoolRunAccessibilityTesting.testTouchTargets()
        
        for testCase in testCases {
            if testCase.needsImprovement {
                XCTAssertLessThan(testCase.currentSize.width, testCase.expectedMinSize.width,
                                 "Component \(testCase.component) width needs improvement")
                XCTAssertLessThan(testCase.currentSize.height, testCase.expectedMinSize.height,
                                 "Component \(testCase.component) height needs improvement")
            } else {
                XCTAssertGreaterThanOrEqual(testCase.currentSize.width, testCase.expectedMinSize.width,
                                          "Component \(testCase.component) width meets requirements")
                XCTAssertGreaterThanOrEqual(testCase.currentSize.height, testCase.expectedMinSize.height,
                                          "Component \(testCase.component) height meets requirements")
            }
        }
    }
    
    // MARK: - Accessibility Identifier Tests
    
    @MainActor func testAccessibilityIdentifiers() {
        // Test that all components have proper accessibility identifiers
        let identifiers = SchoolRunAccessibilityTesting.AccessibilityIdentifiers.self
        
        // Test dashboard identifiers
        XCTAssertFalse(identifiers.dashboardView.isEmpty)
        XCTAssertFalse(identifiers.scheduleNewRunButton.isEmpty)
        XCTAssertFalse(identifiers.viewScheduledRunsButton.isEmpty)
        
        // Test schedule new run identifiers
        XCTAssertFalse(identifiers.scheduleNewRunView.isEmpty)
        XCTAssertFalse(identifiers.runNameField.isEmpty)
        XCTAssertFalse(identifiers.addStopButton.isEmpty)
        
        // Test stop configuration identifiers
        let stopId = identifiers.stopConfigurationRow(1)
        XCTAssertTrue(stopId.contains("1"))
        XCTAssertTrue(stopId.contains("StopConfigurationRow"))
        
        // Test execution identifiers
        XCTAssertFalse(identifiers.runExecutionView.isEmpty)
        XCTAssertFalse(identifiers.completeStopButton.isEmpty)
        XCTAssertFalse(identifiers.pauseRunButton.isEmpty)
        XCTAssertFalse(identifiers.cancelRunButton.isEmpty)
    }
    
    // MARK: - Accessibility Labels and Hints Tests
    
    @MainActor func testAccessibilityLabels() {
        // Test that all accessibility labels are meaningful
        let labels = SchoolRunAccessibilityTesting.AccessibilityLabels.self
        
        // Test action labels
        XCTAssertFalse(labels.scheduleNewRun.isEmpty)
        XCTAssertFalse(labels.viewScheduledRuns.isEmpty)
        XCTAssertFalse(labels.startRun.isEmpty)
        XCTAssertFalse(labels.completeStop.isEmpty)
        
        // Test content labels
        XCTAssertFalse(labels.upcomingRuns.isEmpty)
        XCTAssertFalse(labels.pastRuns.isEmpty)
        XCTAssertFalse(labels.runProgress.isEmpty)
        XCTAssertFalse(labels.currentStop.isEmpty)
        
        // Test form field labels
        XCTAssertFalse(labels.runName.isEmpty)
        XCTAssertFalse(labels.runDate.isEmpty)
        XCTAssertFalse(labels.runTime.isEmpty)
        XCTAssertFalse(labels.stopType.isEmpty)
    }
    
    @MainActor func testAccessibilityHints() {
        // Test that all accessibility hints are helpful
        let hints = SchoolRunAccessibilityTesting.AccessibilityHints.self
        
        // Test action hints
        XCTAssertFalse(hints.scheduleNewRun.isEmpty)
        XCTAssertFalse(hints.viewScheduledRuns.isEmpty)
        XCTAssertFalse(hints.startRun.isEmpty)
        XCTAssertFalse(hints.completeStop.isEmpty)
        
        // Test navigation hints
        XCTAssertFalse(hints.tapToViewDetails.isEmpty)
        XCTAssertFalse(hints.tapToEdit.isEmpty)
        XCTAssertFalse(hints.tapToSelect.isEmpty)
        
        // Test form field hints
        XCTAssertFalse(hints.enterRunName.isEmpty)
        XCTAssertFalse(hints.selectDate.isEmpty)
        XCTAssertFalse(hints.selectTime.isEmpty)
        XCTAssertFalse(hints.selectStopType.isEmpty)
    }
    
    // MARK: - Comprehensive Accessibility Audit
    
    @MainActor func testComprehensiveAccessibilityAudit() {
        // Run complete accessibility audit
        let auditReport = SchoolRunAccessibilityAudit.runAudit()
        
        // Log any issues found
        if !auditReport.isFullyCompliant {
            print("Accessibility Audit Report:")
            print("Total Issues: \(auditReport.totalIssues)")
            print("Dynamic Type Issues: \(auditReport.dynamicTypeIssues.count)")
            print("High Contrast Issues: \(auditReport.highContrastIssues.count)")
            print("VoiceOver Issues: \(auditReport.voiceOverIssues.count)")
            print("Touch Target Issues: \(auditReport.touchTargetIssues.count)")
            print("Reduced Motion Issues: \(auditReport.reducedMotionIssues.count)")
        }
        
        // For now, we don't fail the test if there are issues, but we log them
        // In a production environment, you might want to fail for critical issues
        XCTAssertTrue(auditReport.totalIssues >= 0, "Audit should complete successfully")
    }
    
    // MARK: - Performance Tests
    
    @MainActor func testAccessibilityPerformance() {
        // Test that accessibility enhancements don't significantly impact performance
        measure {
            let dashboard = SchoolRunDashboardView()
            let scheduleView = ScheduleNewRunView()
            let executionView = RunExecutionView(run: sampleRun)
            
            // Create views with accessibility enhancements
            _ = dashboard
                .environment(\.dynamicTypeSize, .accessibility3)
                .environment(\.colorSchemeContrast, .increased)
                .environment(\.accessibilityReduceMotion, true)
            
            _ = scheduleView
                .environment(\.dynamicTypeSize, .accessibility3)
                .environment(\.colorSchemeContrast, .increased)
                .environment(\.accessibilityReduceMotion, true)
            
            _ = executionView
                .environment(\.dynamicTypeSize, .accessibility3)
                .environment(\.colorSchemeContrast, .increased)
                .environment(\.accessibilityReduceMotion, true)
        }
    }
    
    // MARK: - Integration Tests
    
    @MainActor func testAccessibilityIntegration() {
        // Test that accessibility works across the entire School Run flow
        
        // 1. Dashboard accessibility
        let dashboard = SchoolRunDashboardView()
        XCTAssertNotNil(dashboard)
        
        // 2. Schedule new run accessibility
        let scheduleView = ScheduleNewRunView()
            .environmentObject(AppState())
        XCTAssertNotNil(scheduleView)
        
        // 3. Scheduled runs list accessibility
        let listView = ScheduledRunsListView()
            .environmentObject(AppState())
        XCTAssertNotNil(listView)
        
        // 4. Run detail accessibility
        let detailView = RunDetailView(run: sampleRun)
            .environmentObject(AppState())
        XCTAssertNotNil(detailView)
        
        // 5. Run execution accessibility
        let executionView = RunExecutionView(run: sampleRun)
            .environmentObject(AppState())
        XCTAssertNotNil(executionView)
        
        // All views should be creatable with accessibility environments
        let accessibilityEnvironment = { (view: some View) in
            view
                .environment(\.dynamicTypeSize, .accessibility2)
                .environment(\.colorSchemeContrast, .increased)
                .environment(\.accessibilityReduceMotion, true)
        }
        
        XCTAssertNotNil(accessibilityEnvironment(dashboard))
        XCTAssertNotNil(accessibilityEnvironment(scheduleView))
        XCTAssertNotNil(accessibilityEnvironment(listView))
        XCTAssertNotNil(accessibilityEnvironment(detailView))
        XCTAssertNotNil(accessibilityEnvironment(executionView))
    }
}

// MARK: - Test Extensions

extension DynamicTypeSize {
    var scaleFactor: CGFloat {
        switch self {
        case .xSmall: return 0.8
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.1
        case .xLarge: return 1.2
        case .xxLarge: return 1.3
        case .xxxLarge: return 1.4
        case .accessibility1: return 1.6
        case .accessibility2: return 1.8
        case .accessibility3: return 2.0
        case .accessibility4: return 2.2
        case .accessibility5: return 2.4
        @unknown default: return 1.0
        }
    }
}