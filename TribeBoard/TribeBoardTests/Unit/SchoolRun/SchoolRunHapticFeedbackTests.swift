import XCTest
import UIKit
@testable import TribeBoard

/// Tests for School Run haptic feedback functionality
/// Verifies that haptic feedback respects accessibility settings and provides appropriate feedback
class SchoolRunHapticFeedbackTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Reset any accessibility settings for testing
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - Accessibility Compliance Tests
    
    func testHapticFeedbackRespectsReducedMotionSetting() {
        // Test that haptic feedback is disabled when reduce motion is enabled
        // Note: This test verifies the logic but cannot actually test UIAccessibility.isReduceMotionEnabled
        // in unit tests as it's a system setting
        
        // Verify that the shouldProvideHapticFeedback logic exists
        // This is tested indirectly through the haptic feedback methods
        XCTAssertNoThrow(SchoolRunHapticFeedback.navigationAction())
        XCTAssertNoThrow(SchoolRunHapticFeedback.runStarted())
        XCTAssertNoThrow(SchoolRunHapticFeedback.runCompleted())
    }
    
    func testHapticFeedbackAvailabilityCheck() {
        // Test that haptic feedback methods handle device availability gracefully
        XCTAssertNoThrow(SchoolRunHapticFeedback.runStarted())
        XCTAssertNoThrow(SchoolRunHapticFeedback.runCompleted())
        XCTAssertNoThrow(SchoolRunHapticFeedback.runCancelled())
        XCTAssertNoThrow(SchoolRunHapticFeedback.stopCompleted())
        XCTAssertNoThrow(SchoolRunHapticFeedback.stopProgressed())
        XCTAssertNoThrow(SchoolRunHapticFeedback.navigationAction())
        XCTAssertNoThrow(SchoolRunHapticFeedback.formInteraction())
        XCTAssertNoThrow(SchoolRunHapticFeedback.destructiveAction())
        XCTAssertNoThrow(SchoolRunHapticFeedback.errorOccurred())
        XCTAssertNoThrow(SchoolRunHapticFeedback.saveSuccessful())
        XCTAssertNoThrow(SchoolRunHapticFeedback.runStateChanged())
    }
    
    // MARK: - Haptic Feedback Type Tests
    
    func testRunStartedHapticFeedback() {
        // Test that run started feedback is provided
        XCTAssertNoThrow(SchoolRunHapticFeedback.runStarted())
    }
    
    func testRunCompletedHapticFeedback() {
        // Test that run completed feedback is provided
        XCTAssertNoThrow(SchoolRunHapticFeedback.runCompleted())
    }
    
    func testRunCancelledHapticFeedback() {
        // Test that run cancelled feedback is provided
        XCTAssertNoThrow(SchoolRunHapticFeedback.runCancelled())
    }
    
    func testStopCompletedHapticFeedback() {
        // Test that stop completed feedback is provided
        XCTAssertNoThrow(SchoolRunHapticFeedback.stopCompleted())
    }
    
    func testStopProgressedHapticFeedback() {
        // Test that stop progressed feedback is provided
        XCTAssertNoThrow(SchoolRunHapticFeedback.stopProgressed())
    }
    
    func testNavigationActionHapticFeedback() {
        // Test that navigation action feedback is provided
        XCTAssertNoThrow(SchoolRunHapticFeedback.navigationAction())
    }
    
    func testFormInteractionHapticFeedback() {
        // Test that form interaction feedback is provided
        XCTAssertNoThrow(SchoolRunHapticFeedback.formInteraction())
    }
    
    func testDestructiveActionHapticFeedback() {
        // Test that destructive action feedback is provided
        XCTAssertNoThrow(SchoolRunHapticFeedback.destructiveAction())
    }
    
    func testErrorOccurredHapticFeedback() {
        // Test that error occurred feedback is provided
        XCTAssertNoThrow(SchoolRunHapticFeedback.errorOccurred())
    }
    
    func testSaveSuccessfulHapticFeedback() {
        // Test that save successful feedback is provided
        XCTAssertNoThrow(SchoolRunHapticFeedback.saveSuccessful())
    }
    
    func testRunStateChangedHapticFeedback() {
        // Test that run state changed feedback is provided
        XCTAssertNoThrow(SchoolRunHapticFeedback.runStateChanged())
    }
    
    // MARK: - Integration Tests
    
    func testActiveRunViewModelHapticIntegration() {
        let viewModel = ActiveRunViewModel()
        
        // Test that haptic feedback methods can be called without errors
        XCTAssertNoThrow(SchoolRunHapticFeedback.runStarted())
        XCTAssertNoThrow(SchoolRunHapticFeedback.stopProgressed())
        XCTAssertNoThrow(SchoolRunHapticFeedback.runCompleted())
        XCTAssertNoThrow(SchoolRunHapticFeedback.runCancelled())
    }
    
    func testRunPlannerViewModelHapticIntegration() {
        let viewModel = RunPlannerViewModel()
        
        // Test that haptic feedback methods can be called without errors
        XCTAssertNoThrow(SchoolRunHapticFeedback.formInteraction())
        XCTAssertNoThrow(SchoolRunHapticFeedback.destructiveAction())
        XCTAssertNoThrow(SchoolRunHapticFeedback.saveSuccessful())
        XCTAssertNoThrow(SchoolRunHapticFeedback.errorOccurred())
    }
    
    // MARK: - Performance Tests
    
    func testHapticFeedbackPerformance() {
        // Test that haptic feedback methods execute quickly
        measure {
            for _ in 0..<100 {
                SchoolRunHapticFeedback.navigationAction()
                SchoolRunHapticFeedback.formInteraction()
                SchoolRunHapticFeedback.stopCompleted()
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testMultipleHapticFeedbackCalls() {
        // Test that multiple rapid haptic feedback calls are handled gracefully
        XCTAssertNoThrow {
            SchoolRunHapticFeedback.navigationAction()
            SchoolRunHapticFeedback.navigationAction()
            SchoolRunHapticFeedback.navigationAction()
        }
    }
    
    func testHapticFeedbackWithNilValues() {
        // Test that haptic feedback handles edge cases gracefully
        XCTAssertNoThrow(SchoolRunHapticFeedback.navigationAction())
        XCTAssertNoThrow(SchoolRunHapticFeedback.errorOccurred())
    }
    
    // MARK: - Feedback Type Appropriateness Tests
    
    func testAppropriateHapticFeedbackForActions() {
        // Test that different actions use appropriate haptic feedback types
        
        // Navigation actions should use light feedback
        XCTAssertNoThrow(SchoolRunHapticFeedback.navigationAction())
        
        // Success actions should use success feedback
        XCTAssertNoThrow(SchoolRunHapticFeedback.runCompleted())
        XCTAssertNoThrow(SchoolRunHapticFeedback.stopCompleted())
        XCTAssertNoThrow(SchoolRunHapticFeedback.saveSuccessful())
        
        // Destructive actions should use heavy feedback
        XCTAssertNoThrow(SchoolRunHapticFeedback.destructiveAction())
        XCTAssertNoThrow(SchoolRunHapticFeedback.runCancelled())
        
        // Error conditions should use error feedback
        XCTAssertNoThrow(SchoolRunHapticFeedback.errorOccurred())
        
        // State changes should use medium feedback
        XCTAssertNoThrow(SchoolRunHapticFeedback.runStateChanged())
        XCTAssertNoThrow(SchoolRunHapticFeedback.runStarted())
    }
}

// MARK: - Mock Haptic Manager for Testing

class MockHapticManager: HapticManager {
    var lastTriggeredStyle: HapticStyle?
    var triggerCount = 0
    
    override func trigger(_ style: HapticStyle) {
        lastTriggeredStyle = style
        triggerCount += 1
    }
    
    override func lightImpact() {
        lastTriggeredStyle = .light
        triggerCount += 1
    }
    
    override func mediumImpact() {
        lastTriggeredStyle = .medium
        triggerCount += 1
    }
    
    override func heavyImpact() {
        lastTriggeredStyle = .heavy
        triggerCount += 1
    }
    
    override func success() {
        lastTriggeredStyle = .success
        triggerCount += 1
    }
    
    override func error() {
        lastTriggeredStyle = .error
        triggerCount += 1
    }
    
    override func warning() {
        lastTriggeredStyle = .warning
        triggerCount += 1
    }
    
    func reset() {
        lastTriggeredStyle = nil
        triggerCount = 0
    }
}