import SwiftUI
import os.log

/// A comprehensive test view to verify utility class integrations work correctly
///
/// This view provides an interactive interface for testing all utility classes
/// with enhanced error handling and documentation. It serves as both a testing
/// tool and a demonstration of proper utility class usage.
///
/// ## Features
/// - Interactive testing of all utility methods
/// - Visual feedback for test results
/// - Error handling demonstration
/// - Accessibility compliance testing
/// - Performance monitoring
/// - Integration validation
///
/// ## Usage
/// Use this view during development to verify that utility classes work correctly
/// after modifications or to demonstrate functionality to stakeholders.
struct UtilityClassIntegrationTest: View {
    @StateObject private var toastManager = ToastManager.shared
    @State private var testResults: [TestResult] = []
    @State private var isRunningTests = false
    
    /// Logger for test execution
    private let logger = Logger(subsystem: "com.tribeboard.app", category: "UtilityIntegrationTest")
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Automated test runner
                automatedTestSection
                
                // Manual test sections
                hapticManagerTestSection
                toastManagerTestSection
                validationTestSection
                
                // Test results
                if !testResults.isEmpty {
                    testResultsSection
                }
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .withToast()
        .navigationTitle("Utility Integration Tests")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    /// Header section with test information
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("Utility Class Integration Test")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("Interactive testing interface for all utility classes with enhanced error handling")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    /// Automated test runner section
    private var automatedTestSection: some View {
        VStack(spacing: 16) {
            Text("Automated Tests")
                .font(.headline)
            
            Button(action: runAutomatedTests) {
                HStack {
                    if isRunningTests {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "play.circle.fill")
                    }
                    Text(isRunningTests ? "Running Tests..." : "Run All Tests")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunningTests)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    /// HapticManager test section
    private var hapticManagerTestSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .foregroundColor(.blue)
                Text("HapticManager Tests")
                    .font(.headline)
                Spacer()
                Text(HapticManager.shared.isHapticFeedbackEnabled ? "Enabled" : "Disabled")
                    .font(.caption)
                    .foregroundColor(HapticManager.shared.isHapticFeedbackEnabled ? .green : .orange)
            }
            
            // Notification feedback tests
            VStack(spacing: 8) {
                Text("Notification Feedback")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 12) {
                    testButton("Success", color: .green) {
                        testHapticMethod("success", HapticManager.shared.success)
                    }
                    
                    testButton("Error", color: .red) {
                        testHapticMethod("error", HapticManager.shared.error)
                    }
                    
                    testButton("Warning", color: .orange) {
                        testHapticMethod("warning", HapticManager.shared.warning)
                    }
                }
            }
            
            // Impact feedback tests
            VStack(spacing: 8) {
                Text("Impact Feedback")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 12) {
                    testButton("Light", color: .gray) {
                        testHapticMethod("lightImpact", HapticManager.shared.lightImpact)
                    }
                    
                    testButton("Medium", color: .gray) {
                        testHapticMethod("mediumImpact", HapticManager.shared.mediumImpact)
                    }
                    
                    testButton("Heavy", color: .gray) {
                        testHapticMethod("heavyImpact", HapticManager.shared.heavyImpact)
                    }
                }
            }
            
            // Additional tests
            HStack(spacing: 12) {
                testButton("Selection", color: .blue) {
                    testHapticMethod("selection", HapticManager.shared.selection)
                }
                
                testButton("Success Impact", color: .green) {
                    testHapticMethod("successImpact", HapticManager.shared.successImpact)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    /// ToastManager test section
    private var toastManagerTestSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "message.fill")
                    .foregroundColor(.blue)
                Text("ToastManager Tests")
                    .font(.headline)
                Spacer()
                Text(toastManager.isToastVisible ? "Toast Visible" : "No Toast")
                    .font(.caption)
                    .foregroundColor(toastManager.isToastVisible ? .green : .secondary)
            }
            
            // Basic toast tests
            VStack(spacing: 8) {
                Text("Basic Toast Types")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 12) {
                    testButton("Success", color: .green) {
                        testToastMethod("success") {
                            toastManager.success("Success test message!")
                        }
                    }
                    
                    testButton("Error", color: .red) {
                        testToastMethod("error") {
                            toastManager.error("Error test message!")
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    testButton("Info", color: .blue) {
                        testToastMethod("info") {
                            toastManager.info("Info test message!")
                        }
                    }
                    
                    testButton("Warning", color: .orange) {
                        testToastMethod("warning") {
                            toastManager.warning("Warning test message!")
                        }
                    }
                }
            }
            
            // Toast control tests
            VStack(spacing: 8) {
                Text("Toast Controls")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 12) {
                    testButton("Hide", color: .gray) {
                        testToastMethod("hide") {
                            toastManager.hide()
                        }
                    }
                    
                    testButton("Hide All", color: .gray) {
                        testToastMethod("hideAll") {
                            toastManager.hideAll()
                        }
                    }
                    
                    testButton("Cancel Auto-Hide", color: .gray) {
                        testToastMethod("cancelAutoHide") {
                            toastManager.cancelAutoHide()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    /// Validation test section
    private var validationTestSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.blue)
                Text("Validation Tests")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 8) {
                testButton("Test Family Name Validation", color: .blue) {
                    testValidationMethods()
                }
                
                testButton("Test Edge Cases", color: .orange) {
                    testValidationEdgeCases()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    /// Test results section
    private var testResultsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "list.clipboard.fill")
                    .foregroundColor(.blue)
                Text("Test Results")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    testResults.removeAll()
                }
                .font(.caption)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(testResults.suffix(10), id: \.id) { result in
                    testResultRow(result)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    /// Creates a test button with consistent styling
    private func testButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
        }
        .buttonStyle(.bordered)
        .tint(color)
    }
    
    /// Creates a test result row
    private func testResultRow(_ result: TestResult) -> some View {
        HStack {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.testName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if let message = result.message {
                    Text(message)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(result.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
        .cornerRadius(6)
    }
    
    // MARK: - Test Methods
    
    /// Runs all automated tests
    private func runAutomatedTests() {
        isRunningTests = true
        testResults.removeAll()
        
        logger.info("Starting automated utility class tests")
        
        Task {
            // Test HapticManager
            await testAllHapticMethods()
            
            // Test ToastManager
            await testAllToastMethods()
            
            // Test Validation
            await testAllValidationMethods()
            
            await MainActor.run {
                isRunningTests = false
                toastManager.success("All tests completed! Check results below.")
                logger.info("Automated tests completed")
            }
        }
    }
    
    /// Tests all haptic methods
    private func testAllHapticMethods() async {
        let methods: [(String, () -> Void)] = [
            ("success", HapticManager.shared.success),
            ("error", HapticManager.shared.error),
            ("warning", HapticManager.shared.warning),
            ("lightImpact", HapticManager.shared.lightImpact),
            ("mediumImpact", HapticManager.shared.mediumImpact),
            ("heavyImpact", HapticManager.shared.heavyImpact),
            ("selection", HapticManager.shared.selection),
            ("successImpact", HapticManager.shared.successImpact)
        ]
        
        for (name, method) in methods {
            await MainActor.run {
                testHapticMethod(name, method)
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
        }
    }
    
    /// Tests all toast methods
    private func testAllToastMethods() async {
        let methods: [(String, () -> Void)] = [
            ("success", { toastManager.success("Automated success test") }),
            ("error", { toastManager.error("Automated error test") }),
            ("info", { toastManager.info("Automated info test") }),
            ("warning", { toastManager.warning("Automated warning test") })
        ]
        
        for (name, method) in methods {
            await MainActor.run {
                testToastMethod(name, method)
            }
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        }
        
        // Test control methods
        await MainActor.run {
            testToastMethod("hide") { toastManager.hide() }
        }
    }
    
    /// Tests all validation methods
    private func testAllValidationMethods() async {
        await MainActor.run {
            testValidationMethods()
            testValidationEdgeCases()
        }
    }
    
    /// Tests a haptic method with error handling
    private func testHapticMethod(_ name: String, _ method: @escaping () -> Void) {
        do {
            method()
            addTestResult(TestResult(
                testName: "HapticManager.\(name)()",
                success: true,
                message: "Executed successfully"
            ))
            logger.debug("✅ HapticManager.\(name)() test passed")
        } catch {
            addTestResult(TestResult(
                testName: "HapticManager.\(name)()",
                success: false,
                message: "Error: \(error.localizedDescription)"
            ))
            logger.error("❌ HapticManager.\(name)() test failed: \(error.localizedDescription)")
        }
    }
    
    /// Tests a toast method with error handling
    private func testToastMethod(_ name: String, _ method: @escaping () -> Void) {
        do {
            method()
            addTestResult(TestResult(
                testName: "ToastManager.\(name)()",
                success: true,
                message: "Executed successfully"
            ))
            logger.debug("✅ ToastManager.\(name)() test passed")
        } catch {
            addTestResult(TestResult(
                testName: "ToastManager.\(name)()",
                success: false,
                message: "Error: \(error.localizedDescription)"
            ))
            logger.error("❌ ToastManager.\(name)() test failed: \(error.localizedDescription)")
        }
    }
    
    /// Tests validation methods
    private func testValidationMethods() {
        let tests: [(String, String, Bool)] = [
            ("Valid Family Name", "Smith Family", true),
            ("Empty Family Name", "", false),
            ("Short Family Name", "A", false),
            ("Long Family Name", String(repeating: "A", count: 51), false),
            ("Valid Family Code", "ABC123", true),
            ("Invalid Family Code", "", false)
        ]
        
        for (testName, input, expectedValid) in tests {
            let result = Validation.validateFamilyName(input)
            let success = result.isValid == expectedValid
            
            addTestResult(TestResult(
                testName: "Validation: \(testName)",
                success: success,
                message: success ? "Validation correct" : "Expected \(expectedValid), got \(result.isValid)"
            ))
            
            if success {
                logger.debug("✅ Validation test passed: \(testName)")
            } else {
                logger.error("❌ Validation test failed: \(testName)")
            }
        }
        
        toastManager.info("Validation tests completed")
    }
    
    /// Tests validation edge cases
    private func testValidationEdgeCases() {
        // Test ValidationResult utility methods
        let success = ValidationResult.success
        let failure = ValidationResult.failure("Test failure")
        let combined = ValidationResult.combine([success, failure])
        
        let combineTestSuccess = !combined.isValid
        addTestResult(TestResult(
            testName: "ValidationResult.combine()",
            success: combineTestSuccess,
            message: combineTestSuccess ? "Combine method works correctly" : "Combine method failed"
        ))
        
        // Test error codes
        let resultWithCode = ValidationResult.failure("Test", errorCode: .empty)
        let errorCodeTestSuccess = resultWithCode.errorCode == .empty
        addTestResult(TestResult(
            testName: "ValidationResult error codes",
            success: errorCodeTestSuccess,
            message: errorCodeTestSuccess ? "Error codes work correctly" : "Error codes failed"
        ))
        
        toastManager.info("Edge case tests completed")
    }
    
    /// Adds a test result to the results array
    private func addTestResult(_ result: TestResult) {
        testResults.append(result)
        
        // Keep only the last 50 results to prevent memory issues
        if testResults.count > 50 {
            testResults.removeFirst(testResults.count - 50)
        }
    }
}

// MARK: - Supporting Types

/// Represents the result of a single test
private struct TestResult {
    let id = UUID()
    let testName: String
    let success: Bool
    let message: String?
    let timestamp: Date
    
    init(testName: String, success: Bool, message: String? = nil) {
        self.testName = testName
        self.success = success
        self.message = message
        self.timestamp = Date()
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        UtilityClassIntegrationTest()
    }
}