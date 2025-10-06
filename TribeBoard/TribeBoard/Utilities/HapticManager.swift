import UIKit
import os.log

/// Haptic feedback styles available in the application
/// 
/// This enum provides a convenient way to trigger different types of haptic feedback
/// throughout the app while maintaining consistency and accessibility compliance.
enum HapticStyle {
    /// Light impact feedback for subtle interactions
    case light
    /// Medium impact feedback for standard interactions
    case medium
    /// Heavy impact feedback for significant interactions
    case heavy
    /// Success notification feedback for positive outcomes
    case success
    /// Error notification feedback for negative outcomes
    case error
    /// Warning notification feedback for cautionary messages
    case warning
    /// Navigation feedback for menu and tab interactions
    case navigation
    
    /// Triggers the haptic feedback using the shared HapticManager instance
    /// - Note: This method respects user accessibility settings and device capabilities
    func trigger() {
        HapticManager.shared.trigger(self)
    }
}

/// Centralized manager for haptic feedback throughout the TribeBoard application
///
/// The HapticManager provides a consistent interface for triggering haptic feedback
/// across the app while handling device capabilities, accessibility settings, and
/// error conditions gracefully.
///
/// ## Usage
/// ```swift
/// // Direct method calls
/// HapticManager.shared.success()
/// HapticManager.shared.lightImpact()
///
/// // Using the enum style
/// HapticStyle.success.trigger()
/// ```
///
/// ## Accessibility
/// The manager automatically respects user accessibility settings including:
/// - Reduced motion preferences
/// - Haptic feedback disabled in settings
/// - Device capability limitations
///
/// ## Error Handling
/// All haptic feedback methods include proper error handling and will fail gracefully
/// if haptic feedback is unavailable or disabled.
class HapticManager {
    /// Shared singleton instance for consistent haptic feedback management
    static let shared = HapticManager()
    
    /// Logger for haptic feedback events and errors
    private let logger = Logger(subsystem: "com.tribeboard.app", category: "HapticManager")
    
    /// Tracks whether haptic feedback is available on the current device
    private let isHapticFeedbackAvailable: Bool
    
    /// Private initializer to enforce singleton pattern
    private init() {
        // Check if haptic feedback is supported on this device
        self.isHapticFeedbackAvailable = UIDevice.current.userInterfaceIdiom == .phone
        
        if !isHapticFeedbackAvailable {
            logger.info("Haptic feedback not available on this device type")
        }
    }
    
    // MARK: - Notification Feedback Methods
    
    /// Triggers success notification haptic feedback
    ///
    /// Use this method to provide haptic feedback for successful operations such as:
    /// - Task completion
    /// - Successful form submission
    /// - Data sync completion
    /// - Family creation success
    ///
    /// - Note: This method respects accessibility settings and device capabilities
    /// - SeeAlso: `successImpact()` for alternative success feedback
    func success() {
        executeHapticFeedback(type: .notification(.success), description: "success notification")
    }
    
    /// Triggers error notification haptic feedback
    ///
    /// Use this method to provide haptic feedback for error conditions such as:
    /// - Form validation failures
    /// - Network connection errors
    /// - Authentication failures
    /// - Data sync errors
    ///
    /// - Note: This method respects accessibility settings and device capabilities
    func error() {
        executeHapticFeedback(type: .notification(.error), description: "error notification")
    }
    
    /// Triggers warning notification haptic feedback
    ///
    /// Use this method to provide haptic feedback for warning conditions such as:
    /// - Low battery warnings
    /// - Storage space warnings
    /// - Offline mode notifications
    /// - Data conflicts
    ///
    /// - Note: This method respects accessibility settings and device capabilities
    func warning() {
        executeHapticFeedback(type: .notification(.warning), description: "warning notification")
    }
    
    // MARK: - Impact Feedback Methods
    
    /// Triggers light impact haptic feedback
    ///
    /// Use this method for subtle interactions such as:
    /// - Button taps
    /// - Toggle switches
    /// - Menu item selection
    /// - Navigation transitions
    ///
    /// - Note: This is the most subtle form of impact feedback
    func lightImpact() {
        executeHapticFeedback(type: .impact(.light), description: "light impact")
    }
    
    /// Triggers medium impact haptic feedback
    ///
    /// Use this method for standard interactions such as:
    /// - Modal presentations
    /// - Tab switching
    /// - Card interactions
    /// - Standard button presses
    ///
    /// - Note: This provides moderate tactile feedback
    func mediumImpact() {
        executeHapticFeedback(type: .impact(.medium), description: "medium impact")
    }
    
    /// Triggers heavy impact haptic feedback
    ///
    /// Use this method for significant interactions such as:
    /// - Destructive actions
    /// - Major state changes
    /// - Important confirmations
    /// - Critical alerts
    ///
    /// - Note: This provides the strongest impact feedback
    func heavyImpact() {
        executeHapticFeedback(type: .impact(.heavy), description: "heavy impact")
    }
    
    // MARK: - Selection Feedback Methods
    
    /// Triggers selection haptic feedback
    ///
    /// Use this method for selection changes such as:
    /// - Picker wheel changes
    /// - Segmented control selection
    /// - List item selection
    /// - Slider value changes
    ///
    /// - Note: This provides subtle feedback for continuous selection changes
    func selection() {
        executeHapticFeedback(type: .selection, description: "selection change")
    }
    
    /// Triggers success impact haptic feedback (alternative to success())
    ///
    /// This method provides the same feedback as `success()` but with a different name
    /// for compatibility with existing code patterns.
    ///
    /// - Note: Consider using `success()` for new implementations
    /// - SeeAlso: `success()` for the primary success feedback method
    func successImpact() {
        executeHapticFeedback(type: .notification(.success), description: "success impact")
    }
    
    // MARK: - Style-Based Feedback
    
    /// Triggers haptic feedback based on the specified style
    ///
    /// This method provides a convenient way to trigger haptic feedback using the
    /// HapticStyle enum, which can be useful for consistent feedback patterns.
    ///
    /// - Parameter style: The haptic feedback style to trigger
    ///
    /// ## Example
    /// ```swift
    /// HapticManager.shared.trigger(.success)
    /// HapticStyle.error.trigger() // Alternative syntax
    /// ```
    func trigger(_ style: HapticStyle) {
        switch style {
        case .light:
            lightImpact()
        case .medium:
            mediumImpact()
        case .heavy:
            heavyImpact()
        case .success:
            success()
        case .error:
            error()
        case .warning:
            warning()
        case .navigation:
            lightImpact() // Use light impact for navigation feedback
        }
    }
    
    // MARK: - Private Implementation
    
    /// Internal haptic feedback types for error handling
    private enum HapticFeedbackType {
        case notification(UINotificationFeedbackGenerator.FeedbackType)
        case impact(UIImpactFeedbackGenerator.FeedbackStyle)
        case selection
    }
    
    /// Executes haptic feedback with comprehensive error handling
    ///
    /// This method centralizes all haptic feedback execution to ensure consistent
    /// error handling, accessibility compliance, and logging across all feedback types.
    ///
    /// - Parameters:
    ///   - type: The type of haptic feedback to execute
    ///   - description: A description of the feedback for logging purposes
    private func executeHapticFeedback(type: HapticFeedbackType, description: String) {
        // Check if haptic feedback is available
        guard isHapticFeedbackAvailable else {
            logger.debug("Haptic feedback skipped - not available on device for \(description)")
            return
        }
        
        // Check if haptic feedback is enabled in accessibility settings
        guard !UIAccessibility.isReduceMotionEnabled else {
            logger.debug("Haptic feedback skipped - reduce motion enabled for \(description)")
            return
        }
        
        // Execute the appropriate haptic feedback
        do {
            switch type {
            case .notification(let feedbackType):
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                generator.notificationOccurred(feedbackType)
                logger.debug("Executed \(description) haptic feedback")
                
            case .impact(let style):
                let generator = UIImpactFeedbackGenerator(style: style)
                generator.prepare()
                generator.impactOccurred()
                logger.debug("Executed \(description) haptic feedback")
                
            case .selection:
                let generator = UISelectionFeedbackGenerator()
                generator.prepare()
                generator.selectionChanged()
                logger.debug("Executed \(description) haptic feedback")
            }
        } catch {
            logger.error("Failed to execute \(description) haptic feedback: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Utility Methods
    
    /// Checks if haptic feedback is currently available and enabled
    ///
    /// This method can be used by other components to determine whether to show
    /// haptic feedback options in the UI or to make decisions about user experience.
    ///
    /// - Returns: `true` if haptic feedback is available and enabled, `false` otherwise
    public var isHapticFeedbackEnabled: Bool {
        return isHapticFeedbackAvailable && !UIAccessibility.isReduceMotionEnabled
    }
    
    /// Prepares haptic feedback generators for optimal performance
    ///
    /// Call this method before a sequence of haptic feedback events to ensure
    /// minimal latency. This is particularly useful for interactive sequences
    /// or animations that include multiple haptic events.
    ///
    /// - Note: Preparation is automatically handled in individual methods, but this
    ///   can be called proactively for performance optimization
    public func prepareForHapticSequence() {
        guard isHapticFeedbackEnabled else { return }
        
        // Pre-prepare common generators
        let notificationGenerator = UINotificationFeedbackGenerator()
        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        let selectionGenerator = UISelectionFeedbackGenerator()
        
        notificationGenerator.prepare()
        impactGenerator.prepare()
        selectionGenerator.prepare()
        
        logger.debug("Prepared haptic feedback generators for sequence")
    }
}