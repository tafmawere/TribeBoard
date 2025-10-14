import UIKit
import SwiftUI

/// School Run specific haptic feedback utilities that respect accessibility settings
struct SchoolRunHapticFeedback {
    
    /// Provides haptic feedback for run start actions
    /// Respects accessibility settings including reduced motion
    static func runStarted() {
        guard shouldProvideHapticFeedback() else { return }
        HapticManager.shared.mediumImpact()
    }
    
    /// Provides haptic feedback for run completion
    /// Uses success feedback for positive completion
    static func runCompleted() {
        guard shouldProvideHapticFeedback() else { return }
        HapticManager.shared.success()
    }
    
    /// Provides haptic feedback for run cancellation
    /// Uses heavy impact for destructive actions
    static func runCancelled() {
        guard shouldProvideHapticFeedback() else { return }
        HapticManager.shared.heavyImpact()
    }
    
    /// Provides haptic feedback for stop completion
    /// Uses success feedback for positive actions
    static func stopCompleted() {
        guard shouldProvideHapticFeedback() else { return }
        HapticManager.shared.success()
    }
    
    /// Provides haptic feedback for stop progression
    /// Uses light impact for navigation between stops
    static func stopProgressed() {
        guard shouldProvideHapticFeedback() else { return }
        HapticManager.shared.lightImpact()
    }
    
    /// Provides haptic feedback for navigation actions
    /// Uses light impact for general navigation
    static func navigationAction() {
        guard shouldProvideHapticFeedback() else { return }
        HapticManager.shared.lightImpact()
    }
    
    /// Provides haptic feedback for form interactions
    /// Uses light impact for form field interactions
    static func formInteraction() {
        guard shouldProvideHapticFeedback() else { return }
        HapticManager.shared.lightImpact()
    }
    
    /// Provides haptic feedback for destructive actions
    /// Uses heavy impact for delete/cancel actions
    static func destructiveAction() {
        guard shouldProvideHapticFeedback() else { return }
        HapticManager.shared.heavyImpact()
    }
    
    /// Provides haptic feedback for error conditions
    /// Uses error notification for validation failures
    static func errorOccurred() {
        guard shouldProvideHapticFeedback() else { return }
        HapticManager.shared.error()
    }
    
    /// Provides haptic feedback for successful save operations
    /// Uses success notification for positive outcomes
    static func saveSuccessful() {
        guard shouldProvideHapticFeedback() else { return }
        HapticManager.shared.success()
    }
    
    /// Provides haptic feedback for pause/resume actions
    /// Uses medium impact for state change actions
    static func runStateChanged() {
        guard shouldProvideHapticFeedback() else { return }
        HapticManager.shared.mediumImpact()
    }
    
    // MARK: - Private Helpers
    
    /// Determines if haptic feedback should be provided based on accessibility settings
    /// Respects user preferences for reduced motion and haptic feedback availability
    private static func shouldProvideHapticFeedback() -> Bool {
        // Check if haptic feedback is available on the device
        guard HapticManager.shared.isHapticFeedbackEnabled else {
            return false
        }
        
        // Respect reduced motion accessibility setting
        guard !UIAccessibility.isReduceMotionEnabled else {
            return false
        }
        
        // Check if the device supports haptic feedback
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            return false
        }
        
        return true
    }
}

// MARK: - SwiftUI Environment Integration

/// Environment key for haptic feedback preferences
struct HapticFeedbackEnabledKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    /// Whether haptic feedback is enabled in the current environment
    var hapticFeedbackEnabled: Bool {
        get { self[HapticFeedbackEnabledKey.self] }
        set { self[HapticFeedbackEnabledKey.self] = newValue }
    }
}

// MARK: - View Modifier for Haptic Feedback

/// View modifier that provides haptic feedback for School Run interactions
struct SchoolRunHapticModifier: ViewModifier {
    let feedbackType: SchoolRunHapticFeedback.FeedbackType
    let trigger: Bool
    
    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    switch feedbackType {
                    case .runStarted:
                        SchoolRunHapticFeedback.runStarted()
                    case .runCompleted:
                        SchoolRunHapticFeedback.runCompleted()
                    case .runCancelled:
                        SchoolRunHapticFeedback.runCancelled()
                    case .stopCompleted:
                        SchoolRunHapticFeedback.stopCompleted()
                    case .stopProgressed:
                        SchoolRunHapticFeedback.stopProgressed()
                    case .navigationAction:
                        SchoolRunHapticFeedback.navigationAction()
                    case .formInteraction:
                        SchoolRunHapticFeedback.formInteraction()
                    case .destructiveAction:
                        SchoolRunHapticFeedback.destructiveAction()
                    case .errorOccurred:
                        SchoolRunHapticFeedback.errorOccurred()
                    case .saveSuccessful:
                        SchoolRunHapticFeedback.saveSuccessful()
                    case .runStateChanged:
                        SchoolRunHapticFeedback.runStateChanged()
                    }
                }
            }
    }
}

extension SchoolRunHapticFeedback {
    enum FeedbackType {
        case runStarted
        case runCompleted
        case runCancelled
        case stopCompleted
        case stopProgressed
        case navigationAction
        case formInteraction
        case destructiveAction
        case errorOccurred
        case saveSuccessful
        case runStateChanged
    }
}

extension View {
    /// Adds haptic feedback for School Run interactions
    /// - Parameters:
    ///   - feedbackType: The type of haptic feedback to provide
    ///   - trigger: A boolean value that triggers the haptic feedback when it becomes true
    /// - Returns: A view with haptic feedback support
    func schoolRunHapticFeedback(_ feedbackType: SchoolRunHapticFeedback.FeedbackType, trigger: Bool) -> some View {
        modifier(SchoolRunHapticModifier(feedbackType: feedbackType, trigger: trigger))
    }
}