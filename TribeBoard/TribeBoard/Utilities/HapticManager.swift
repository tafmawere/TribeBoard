import UIKit

/// Haptic feedback manager for enhanced user interactions
@MainActor
class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    // MARK: - Impact Feedback
    
    /// Light impact feedback for subtle interactions
    func lightImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    /// Medium impact feedback for standard interactions
    func mediumImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    /// Heavy impact feedback for significant interactions
    func heavyImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Notification Feedback
    
    /// Success notification feedback
    func success() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    /// Warning notification feedback
    func warning() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }
    
    /// Error notification feedback
    func error() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    // MARK: - Selection Feedback
    
    /// Selection changed feedback
    func selectionChanged() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    // MARK: - Context-Specific Feedback
    
    /// Button press feedback
    func buttonPress() {
        mediumImpact()
    }
    
    /// Navigation feedback
    func navigation() {
        lightImpact()
    }
    
    /// Toggle switch feedback
    func toggle() {
        lightImpact()
    }
    
    /// Swipe action feedback
    func swipeAction() {
        mediumImpact()
    }
    
    /// Long press feedback
    func longPress() {
        heavyImpact()
    }
    
    /// Pull to refresh feedback
    func pullToRefresh() {
        lightImpact()
    }
    
    /// Page transition feedback
    func pageTransition() {
        lightImpact()
    }
    
    /// Form validation feedback
    func validationSuccess() {
        success()
    }
    
    /// Form validation error feedback
    func validationError() {
        error()
    }
    
    /// Loading completion feedback
    func loadingComplete() {
        success()
    }
    
    /// Action completion feedback
    func actionComplete() {
        success()
    }
    
    /// Deletion feedback
    func deletion() {
        heavyImpact()
    }
    
    /// Creation feedback
    func creation() {
        success()
    }
    
    // MARK: - Prototype-Specific Feedback
    
    /// Mock authentication success
    func mockAuthSuccess() {
        success()
    }
    
    /// Mock family creation
    func mockFamilyCreation() {
        creation()
    }
    
    /// Mock family joining
    func mockFamilyJoining() {
        success()
    }
    
    /// Mock task completion
    func mockTaskCompletion() {
        actionComplete()
    }
    
    /// Mock message sent
    func mockMessageSent() {
        lightImpact()
    }
    
    /// Mock QR code scan
    func mockQRCodeScan() {
        mediumImpact()
    }
    
    /// Mock role assignment
    func mockRoleAssignment() {
        success()
    }
    
    /// Mock sync completion
    func mockSyncComplete() {
        loadingComplete()
    }
    
    /// Mock error scenario
    func mockError() {
        error()
    }
    
    /// Error impact feedback (alias for error notification)
    func errorImpact() {
        error()
    }
    
    /// Success impact feedback (alias for success notification)
    func successImpact() {
        success()
    }
    
    /// Selection feedback (alias for selectionChanged)
    func selection() {
        selectionChanged()
    }
    
    /// Mock network issue
    func mockNetworkIssue() {
        warning()
    }
    
    /// Celebration feedback for special occasions
    func celebration() {
        // Double success feedback for extra emphasis
        success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.lightImpact()
        }
    }
}

/// Haptic style enum for consistent feedback patterns
enum HapticStyle {
    case light
    case medium
    case heavy
    case success
    case warning
    case error
    case selection
    case navigation
    
    @MainActor
    func trigger() {
        switch self {
        case .light:
            HapticManager.shared.lightImpact()
        case .medium:
            HapticManager.shared.mediumImpact()
        case .heavy:
            HapticManager.shared.heavyImpact()
        case .success:
            HapticManager.shared.success()
        case .warning:
            HapticManager.shared.warning()
        case .error:
            HapticManager.shared.error()
        case .selection:
            HapticManager.shared.selectionChanged()
        case .navigation:
            HapticManager.shared.navigation()
        }
    }
}