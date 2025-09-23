import SwiftUI
import Foundation

/// Utilities for prototype demonstration and mock interactions
class PrototypeUtilities: ObservableObject {
    static let shared = PrototypeUtilities()
    
    private init() {}
    
    // MARK: - Demo State Management
    
    @Published var isDemoMode = true
    @Published var demoScenario: DemoScenario = .newUserOnboarding
    
    // MARK: - Demo Actions
    
    @MainActor
    func startDemoSequence() {
        ToastManager.shared.showDemoModeSequence()
        
        // Show demo instructions after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            self.showDemoInstructions()
        }
    }
    
    @MainActor
    func resetDemoState() {
        demoScenario = .newUserOnboarding
        ToastManager.shared.info("🔄 Demo state reset to beginning")
        HapticManager.shared.lightImpact()
    }
    
    @MainActor
    func switchDemoScenario(to scenario: DemoScenario) {
        demoScenario = scenario
        ToastManager.shared.info("🎭 Switched to: \(scenario.description)")
        HapticManager.shared.selection()
    }
    
    @MainActor
    private func showDemoInstructions() {
        ToastManager.shared.info("💡 Tap any button to see instant responses")
    }
    
    // MARK: - Mock Interaction Helpers
    
    func simulateNetworkDelay(completion: @escaping () -> Void) {
        let delay = TimeInterval.random(in: 0.5...2.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            completion()
        }
    }
    
    @MainActor
    func simulateSuccess(message: String, completion: (() -> Void)? = nil) {
        HapticManager.shared.success()
        ToastManager.shared.success(message)
        completion?()
    }
    
    @MainActor
    func simulateError(message: String, completion: (() -> Void)? = nil) {
        HapticManager.shared.error()
        ToastManager.shared.error(message)
        completion?()
    }
    
    func simulateLoading(duration: TimeInterval = 2.0, completion: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            completion()
        }
    }
    
    // MARK: - Random Demo Data
    
    func getRandomSuccessMessage() -> String {
        let messages = [
            "🎉 Action completed successfully!",
            "✅ Great job! Everything looks good.",
            "🚀 Operation successful!",
            "💫 Perfect! Changes saved.",
            "🌟 Excellent! Task completed.",
            "🎊 Success! All done.",
            "✨ Wonderful! Action completed.",
            "🏆 Outstanding! Operation finished."
        ]
        return messages.randomElement() ?? messages[0]
    }
    
    func getRandomErrorMessage() -> String {
        let messages = [
            "⚠️ Oops! Something went wrong.",
            "🔧 Technical issue detected.",
            "📡 Connection temporarily unavailable.",
            "🔄 Please try again in a moment.",
            "⏰ Request timed out.",
            "🚫 Action could not be completed.",
            "💥 Unexpected error occurred.",
            "🔍 Unable to process request."
        ]
        return messages.randomElement() ?? messages[0]
    }
    
    func getRandomLoadingMessage() -> String {
        let messages = [
            "🔄 Processing your request...",
            "⏳ Just a moment please...",
            "🚀 Working on it...",
            "💫 Almost there...",
            "🎯 Finalizing details...",
            "⚡ Processing data...",
            "🔮 Making magic happen...",
            "🛠️ Setting things up..."
        ]
        return messages.randomElement() ?? messages[0]
    }
    
    // MARK: - Demo Feature Flags
    
    var enableAdvancedFeatures: Bool {
        return demoScenario == .familyAdminTasks
    }
    
    var enableChildRestrictions: Bool {
        return demoScenario == .childUserExperience
    }
    
    var enableVisitorLimitations: Bool {
        return false // No visitor scenario in current DemoScenario enum
    }
    
    // MARK: - Mock Data Helpers
    
    func getMockFamilyCode() -> String {
        let codes = ["ABC123", "DEMO01", "TEST99", "FAMILY", "PROTO1"]
        return codes.randomElement() ?? "ABC123"
    }
    
    func getMockFamilyName() -> String {
        let names = ["Mawere Family", "Demo Family", "Test Household", "Prototype Family", "Sample Group"]
        return names.randomElement() ?? "Mawere Family"
    }
    
    func getMockUserName() -> String {
        let names = ["John Doe", "Jane Smith", "Alex Johnson", "Sam Wilson", "Taylor Brown"]
        return names.randomElement() ?? "John Doe"
    }
    
    // MARK: - Prototype Validation
    
    func validatePrototypeInput(_ input: String, type: InputType) -> ValidationResult {
        switch type {
        case .familyName:
            return validateFamilyName(input)
        case .familyCode:
            return validateFamilyCode(input)
        case .userName:
            return validateUserName(input)
        }
    }
    
    enum InputType {
        case familyName
        case familyCode
        case userName
    }
    
    struct ValidationResult {
        let isValid: Bool
        let message: String
        let suggestion: String?
    }
    
    private func validateFamilyName(_ name: String) -> ValidationResult {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return ValidationResult(
                isValid: false,
                message: "Family name is required",
                suggestion: "Try 'Mawere Family'"
            )
        }
        
        if trimmed.lowercased().contains("mawere") {
            return ValidationResult(
                isValid: true,
                message: "Perfect! This matches our demo family",
                suggestion: nil
            )
        }
        
        if trimmed.count < 2 {
            return ValidationResult(
                isValid: false,
                message: "Family name must be at least 2 characters",
                suggestion: "Try 'Mawere Family'"
            )
        }
        
        return ValidationResult(
            isValid: true,
            message: "Great choice!",
            suggestion: nil
        )
    }
    
    private func validateFamilyCode(_ code: String) -> ValidationResult {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if trimmed.isEmpty {
            return ValidationResult(
                isValid: false,
                message: "Family code is required",
                suggestion: "Try 'ABC123'"
            )
        }
        
        if trimmed == "ABC123" || trimmed == "DEMO01" {
            return ValidationResult(
                isValid: true,
                message: "Perfect! This is a valid demo code",
                suggestion: nil
            )
        }
        
        if trimmed.count < 4 || trimmed.count > 8 {
            return ValidationResult(
                isValid: false,
                message: "Family code must be 4-8 characters",
                suggestion: "Try 'ABC123'"
            )
        }
        
        return ValidationResult(
            isValid: true,
            message: "Valid format - try 'ABC123' for demo",
            suggestion: "ABC123"
        )
    }
    
    private func validateUserName(_ name: String) -> ValidationResult {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return ValidationResult(
                isValid: false,
                message: "Name is required",
                suggestion: "Try 'John Doe'"
            )
        }
        
        if trimmed.count < 2 {
            return ValidationResult(
                isValid: false,
                message: "Name must be at least 2 characters",
                suggestion: "Try 'John Doe'"
            )
        }
        
        return ValidationResult(
            isValid: true,
            message: "Looks good!",
            suggestion: nil
        )
    }
}



// MARK: - View Extensions for Prototype

extension View {
    /// Add demo control panel overlay
    func withDemoControls() -> some View {
        ZStack(alignment: .topTrailing) {
            self
            
            if PrototypeUtilities.shared.isDemoMode {
                DemoControlPanel(demoManager: DemoJourneyManager.shared)
            }
        }
    }
    
    /// Add prototype-specific loading behavior
    func prototypeLoading<T>(
        isLoading: Bool,
        scenario: LoadingStateView.MockLoadingScenario,
        onComplete: @escaping () -> Void
    ) -> some View {
        ZStack {
            self
                .disabled(isLoading)
                .blur(radius: isLoading ? 2 : 0)
            
            if isLoading {
                LoadingStateView(
                    style: .overlay,
                    mockScenario: scenario,
                    onComplete: onComplete
                )
            }
        }
    }
    
    /// Add prototype-specific error handling
    func prototypeErrorHandling(
        showError: Binding<Bool>,
        errorType: MockErrorScenarios.Type = MockErrorScenarios.self
    ) -> some View {
        self.sheet(isPresented: showError) {
            NavigationView {
                VStack {
                    Spacer()
                    MockErrorScenarios.randomError()
                    Spacer()
                }
                .navigationTitle("Error")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Dismiss") {
                            showError.wrappedValue = false
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Demo Control Panel") {
    DemoControlPanel(demoManager: DemoJourneyManager())
        .withToast()
}

#Preview("Prototype Utilities Demo") {
    VStack(spacing: 20) {
        Text("Prototype Utilities Demo")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        Button("Simulate Success") {
            PrototypeUtilities.shared.simulateSuccess(
                message: PrototypeUtilities.shared.getRandomSuccessMessage()
            )
        }
        .buttonStyle(.borderedProminent)
        
        Button("Simulate Error") {
            PrototypeUtilities.shared.simulateError(
                message: PrototypeUtilities.shared.getRandomErrorMessage()
            )
        }
        .buttonStyle(.bordered)
        
        Button("Start Demo Sequence") {
            PrototypeUtilities.shared.startDemoSequence()
        }
        .buttonStyle(.bordered)
    }
    .padding()
    .withToast()
    .withDemoControls()
}