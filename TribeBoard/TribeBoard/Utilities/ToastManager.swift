import SwiftUI
import os.log

/// Enhanced manager for toast notifications with accessibility and performance improvements
///
/// The ToastManager provides a centralized system for displaying toast notifications
/// throughout the TribeBoard application. It includes comprehensive accessibility support,
/// error handling, and performance optimizations.
///
/// ## Features
/// - Automatic haptic feedback integration
/// - VoiceOver and accessibility support
/// - Reduce motion compliance
/// - Task-based duration management
/// - Comprehensive error handling
/// - Mock data support for prototyping
///
/// ## Usage
/// ```swift
/// // Basic usage
/// ToastManager.shared.success("Operation completed!")
/// ToastManager.shared.error("Something went wrong")
///
/// // In SwiftUI views
/// SomeView()
///     .withToast()
/// ```
///
/// ## Accessibility
/// - Automatically announces messages to VoiceOver users
/// - Respects reduce motion preferences
/// - Provides proper accessibility labels and hints
/// - Supports dismissal via accessibility actions
///
/// ## Error Handling
/// - Graceful handling of task cancellation
/// - Proper cleanup of resources
/// - Logging of errors and important events
/// - Fallback behavior for accessibility failures
@MainActor
class ToastManager: ObservableObject {
    /// Shared singleton instance for consistent toast management
    static let shared = ToastManager()
    
    /// Currently displayed toast message, if any
    @Published var currentToast: ToastMessage?
    
    /// Logger for toast events and errors
    private let logger = Logger(subsystem: "com.tribeboard.app", category: "ToastManager")
    
    /// Task for managing toast auto-hide functionality
    private var hideTask: Task<Void, Never>?
    
    /// Tracks the number of active toasts for debugging
    private var toastCounter: Int = 0
    
    /// Private initializer to enforce singleton pattern
    private init() {
        logger.info("ToastManager initialized")
    }
    
    // MARK: - Core Toast Methods
    
    /// Displays a success toast notification with haptic feedback
    ///
    /// Use this method to provide positive feedback for successful operations such as:
    /// - Task completion
    /// - Data saved successfully
    /// - Family creation success
    /// - Sync completion
    ///
    /// - Parameters:
    ///   - message: The success message to display
    ///   - duration: How long to show the toast (default: 3.0 seconds)
    ///
    /// - Note: Automatically triggers success haptic feedback and VoiceOver announcement
    func success(_ message: String, duration: TimeInterval = 3.0) {
        guard !message.isEmpty else {
            logger.warning("Attempted to show success toast with empty message")
            return
        }
        
        logger.info("Showing success toast: \(message)")
        
        // Trigger haptic feedback
        HapticManager.shared.success()
        
        // Show the toast
        showToast(ToastMessage(message: message, type: .success), duration: duration)
        
        // Announce to accessibility services
        announceToAccessibility(message, prefix: "Success")
    }
    
    /// Displays an error toast notification with haptic feedback
    ///
    /// Use this method to provide feedback for error conditions such as:
    /// - Network failures
    /// - Validation errors
    /// - Authentication failures
    /// - Data sync errors
    ///
    /// - Parameters:
    ///   - message: The error message to display
    ///   - duration: How long to show the toast (default: 4.0 seconds)
    ///
    /// - Note: Automatically triggers error haptic feedback and VoiceOver announcement
    func error(_ message: String, duration: TimeInterval = 4.0) {
        guard !message.isEmpty else {
            logger.warning("Attempted to show error toast with empty message")
            return
        }
        
        logger.error("Showing error toast: \(message)")
        
        // Trigger haptic feedback
        HapticManager.shared.error()
        
        // Show the toast
        showToast(ToastMessage(message: message, type: .error), duration: duration)
        
        // Announce to accessibility services
        announceToAccessibility(message, prefix: "Error")
    }
    
    /// Displays an informational toast notification
    ///
    /// Use this method to provide neutral information such as:
    /// - Status updates
    /// - Tips and hints
    /// - Feature announcements
    /// - Offline mode notifications
    ///
    /// - Parameters:
    ///   - message: The informational message to display
    ///   - duration: How long to show the toast (default: 3.0 seconds)
    ///
    /// - Note: Triggers light haptic feedback and VoiceOver announcement
    func info(_ message: String, duration: TimeInterval = 3.0) {
        guard !message.isEmpty else {
            logger.warning("Attempted to show info toast with empty message")
            return
        }
        
        logger.info("Showing info toast: \(message)")
        
        // Trigger haptic feedback
        HapticManager.shared.lightImpact()
        
        // Show the toast
        showToast(ToastMessage(message: message, type: .info), duration: duration)
        
        // Announce to accessibility services
        announceToAccessibility(message, prefix: "Information")
    }
    
    /// Displays a warning toast notification with haptic feedback
    ///
    /// Use this method to provide cautionary feedback such as:
    /// - Low battery warnings
    /// - Storage space warnings
    /// - Data conflicts
    /// - Offline mode limitations
    ///
    /// - Parameters:
    ///   - message: The warning message to display
    ///   - duration: How long to show the toast (default: 3.5 seconds)
    ///
    /// - Note: Automatically triggers warning haptic feedback and VoiceOver announcement
    func warning(_ message: String, duration: TimeInterval = 3.5) {
        guard !message.isEmpty else {
            logger.warning("Attempted to show warning toast with empty message")
            return
        }
        
        logger.warning("Showing warning toast: \(message)")
        
        // Trigger haptic feedback
        HapticManager.shared.warning()
        
        // Show the toast
        showToast(ToastMessage(message: message, type: .warning), duration: duration)
        
        // Announce to accessibility services
        announceToAccessibility(message, prefix: "Warning")
    }
    
    // MARK: - Toast Control Methods
    
    /// Hides the current toast immediately with animation
    ///
    /// This method cancels any pending auto-hide tasks and immediately dismisses
    /// the current toast with a smooth animation.
    ///
    /// - Note: Safe to call even when no toast is currently displayed
    func hide() {
        logger.debug("Hiding current toast")
        
        // Cancel any pending hide task
        hideTask?.cancel()
        hideTask = nil
        
        // Hide with animation and error handling
        do {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentToast = nil
            }
        } catch {
            logger.error("Failed to animate toast hide: \(error.localizedDescription)")
            // Fallback: hide without animation
            currentToast = nil
        }
    }
    
    /// Dismisses the current toast (alias for hide() for API compatibility)
    ///
    /// This method provides an alternative name for the hide() method to maintain
    /// compatibility with existing code that may use "dismiss" terminology.
    ///
    /// - SeeAlso: `hide()` for the primary hide method
    func dismiss() {
        hide()
    }
    
    /// Hides all toasts and resets the manager state
    ///
    /// This method provides a way to completely reset the toast manager,
    /// which can be useful during app state transitions or error recovery.
    func hideAll() {
        logger.info("Hiding all toasts and resetting state")
        
        hideTask?.cancel()
        hideTask = nil
        currentToast = nil
        toastCounter = 0
    }
    
    /// Show a random success toast message
    func showRandomSuccessToast() {
        let messages = [
            "Success!",
            "Great job!",
            "Well done!",
            "Perfect!",
            "Excellent!"
        ]
        let randomMessage = messages.randomElement() ?? "Success!"
        success(randomMessage)
    }
    
    /// Show a random error toast message
    func showRandomErrorToast() {
        let messages = [
            "Something went wrong",
            "Please try again",
            "An error occurred",
            "Oops! That didn't work",
            "Please check and retry"
        ]
        let randomMessage = messages.randomElement() ?? "An error occurred"
        error(randomMessage)
    }
    
    // MARK: - Mock Toast Methods for Prototype
    
    /// Show mock family created success toast
    func showMockFamilyCreated() {
        success("Family 'Mawere Family' created successfully! 🎉")
    }
    
    /// Show mock task completed toast
    func showMockTaskCompleted() {
        success("Task completed successfully! ✅")
    }
    
    /// Show mock message sent toast
    func showMockMessageSent() {
        success("Message sent to family! 💬")
    }
    
    /// Show mock data synced toast
    func showMockDataSynced() {
        success("Data synced across all devices! 🔄")
    }
    
    /// Show mock network error toast
    func showMockNetworkError() {
        error("Network connection failed. Please check your internet.")
    }
    
    /// Show mock permission error toast
    func showMockPermissionError() {
        error("Permission denied. Please check app settings.")
    }
    
    /// Show mock validation error toast
    func showMockValidationError() {
        error("Please check your input and try again.")
    }
    
    /// Show mock authentication error toast
    func showMockAuthenticationError() {
        error("Authentication failed. Please sign in again.")
    }
    
    /// Show mock sync warning toast
    func showMockSyncWarning() {
        warning("Some data may not be up to date.")
    }
    
    /// Show mock battery warning toast
    func showMockBatteryWarning() {
        warning("Low battery may affect background sync.")
    }
    
    /// Show mock storage warning toast
    func showMockStorageWarning() {
        warning("Storage space is running low.")
    }
    
    /// Show mock offline warning toast
    func showMockOfflineWarning() {
        warning("You're offline. Some features may be limited.")
    }
    
    /// Show mock offline mode info toast
    func showMockOfflineMode() {
        info("Offline mode enabled. Changes will sync when online.")
    }
    
    /// Show mock new feature info toast
    func showMockNewFeature() {
        info("New feature available! Check out the latest updates.")
    }
    
    /// Show mock tip of the day toast
    func showMockTipOfTheDay() {
        info("Tip: Tap and hold on tasks to see more options!")
    }
    
    /// Show mock backup complete toast
    func showMockBackupComplete() {
        info("Backup completed successfully to iCloud.")
    }
    
    // MARK: - Toast Sequences
    
    /// Show family creation toast sequence
    func showFamilyCreationToasts() {
        success("Creating family...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.success("Family created successfully!")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            self.info("Invite family members with code: ABC123")
        }
    }
    
    /// Show family joining toast sequence
    func showFamilyJoiningToasts() {
        info("Searching for family...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.success("Family found! Joining...")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.success("Welcome to the Mawere Family! 🎉")
        }
    }
    
    /// Show sync sequence toasts
    func showSyncSequenceToasts() {
        info("Starting sync...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.info("Syncing calendar events...")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.info("Syncing tasks...")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            self.success("All data synced successfully!")
        }
    }
    
    /// Show prototype welcome sequence
    func showPrototypeWelcomeSequence() {
        success("Welcome to TribeBoard Prototype! 🎉")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.info("This is a demonstration of the app's features.")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            self.info("Explore the different sections to see what's possible!")
        }
    }
    
    /// Show demo mode sequence
    func showDemoModeSequence() {
        info("Demo mode activated! 🎭")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.info("All data is simulated for demonstration.")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.success("Ready to explore TribeBoard!")
        }
    }
    
    // MARK: - Private Implementation
    
    /// Internal method to display a toast with comprehensive error handling
    ///
    /// This method handles the core toast display logic including animation,
    /// task management, and error recovery.
    ///
    /// - Parameters:
    ///   - toast: The toast message to display
    ///   - duration: How long to display the toast before auto-hiding
    private func showToast(_ toast: ToastMessage, duration: TimeInterval) {
        // Validate duration
        let safeDuration = max(0.5, min(duration, 10.0)) // Clamp between 0.5 and 10 seconds
        if safeDuration != duration {
            logger.warning("Toast duration clamped from \(duration) to \(safeDuration) seconds")
        }
        
        // Cancel any existing hide task
        hideTask?.cancel()
        hideTask = nil
        
        // Increment counter for debugging
        toastCounter += 1
        let currentToastId = toastCounter
        
        logger.debug("Showing toast #\(currentToastId): \(toast.message)")
        
        // Show the toast with animation and error handling
        do {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                currentToast = toast
            }
        } catch {
            logger.error("Failed to animate toast show: \(error.localizedDescription)")
            // Fallback: show without animation
            currentToast = toast
        }
        
        // Schedule auto-hide with proper task management and error handling
        hideTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(safeDuration * 1_000_000_000))
                
                // Check if task was cancelled or if self is still valid
                guard !Task.isCancelled, let self = self else {
                    return
                }
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    
                    // Only hide if this is still the current toast
                    if let current = self.currentToast, current.id == toast.id {
                        self.logger.debug("Auto-hiding toast #\(currentToastId)")
                        
                        do {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                self.currentToast = nil
                            }
                        } catch {
                            self.logger.error("Failed to animate toast auto-hide: \(error.localizedDescription)")
                            // Fallback: hide without animation
                            self.currentToast = nil
                        }
                    }
                }
            } catch {
                // Task was cancelled or sleep failed
                if !Task.isCancelled {
                    await MainActor.run { [weak self] in
                        self?.logger.error("Toast auto-hide task failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    /// Announces a message to accessibility services with error handling
    ///
    /// This method handles VoiceOver announcements with proper error handling
    /// and fallback behavior.
    ///
    /// - Parameters:
    ///   - message: The message to announce
    ///   - prefix: Optional prefix to add context (e.g., "Error", "Success")
    private func announceToAccessibility(_ message: String, prefix: String? = nil) {
        guard UIAccessibility.isVoiceOverRunning else {
            logger.debug("Skipping accessibility announcement - VoiceOver not running")
            return
        }
        
        let announcement = if let prefix = prefix {
            "\(prefix): \(message)"
        } else {
            message
        }
        
        do {
            UIAccessibility.post(notification: .announcement, argument: announcement)
            logger.debug("Posted accessibility announcement: \(announcement)")
        } catch {
            logger.error("Failed to post accessibility announcement: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Utility Methods
    
    /// Checks if a toast is currently being displayed
    ///
    /// - Returns: `true` if a toast is currently visible, `false` otherwise
    public var isToastVisible: Bool {
        return currentToast != nil
    }
    
    /// Gets the current toast message if one is displayed
    ///
    /// - Returns: The current toast message, or `nil` if no toast is displayed
    public var currentToastMessage: String? {
        return currentToast?.message
    }
    
    /// Cancels any pending auto-hide tasks without hiding the current toast
    ///
    /// This can be useful when you want to keep a toast visible indefinitely
    /// or manage the hide timing manually.
    public func cancelAutoHide() {
        logger.debug("Cancelling auto-hide task")
        hideTask?.cancel()
        hideTask = nil
    }
}

// MARK: - Toast Message Model

/// Enhanced toast message model with comprehensive accessibility support
///
/// This struct represents a single toast notification with all the information
/// needed for display, accessibility, and user interaction.
///
/// ## Features
/// - Unique identification for proper SwiftUI updates
/// - Type-based styling and behavior
/// - Comprehensive accessibility support
/// - Equatable conformance for efficient updates
struct ToastMessage: Identifiable, Equatable {
    /// Unique identifier for SwiftUI list management and animations
    let id = UUID()
    
    /// The text message to display to the user
    let message: String
    
    /// The type of toast, which determines styling and behavior
    let type: ToastType
    
    /// Toast notification types with associated styling and accessibility information
    ///
    /// Each type provides appropriate visual styling, icons, and accessibility labels
    /// to ensure consistent user experience across the application.
    enum ToastType: CaseIterable {
        /// Success notifications for positive outcomes
        case success
        /// Error notifications for failures and problems
        case error
        /// Informational notifications for neutral updates
        case info
        /// Warning notifications for cautionary messages
        case warning
        
        /// The primary color associated with this toast type
        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .info: return .blue
            case .warning: return .orange
            }
        }
        
        /// The SF Symbol icon name for this toast type
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
        
        /// The accessibility label for screen readers
        var accessibilityLabel: String {
            switch self {
            case .success: return "Success"
            case .error: return "Error"
            case .info: return "Information"
            case .warning: return "Warning"
            }
        }
        
        /// The accessibility trait for this toast type
        var accessibilityTrait: AccessibilityTraits {
            switch self {
            case .success: return [.isStaticText]
            case .error: return [.isStaticText]
            case .info: return [.isStaticText]
            case .warning: return [.isStaticText]
            }
        }
    }
    
    /// Equatable conformance based on unique ID for efficient SwiftUI updates
    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - SwiftUI Integration

/// Enhanced view modifier to add toast notification support with comprehensive accessibility
///
/// This view modifier integrates toast notifications into any SwiftUI view hierarchy
/// with full accessibility support, error handling, and performance optimizations.
///
/// ## Features
/// - Automatic toast display management
/// - Reduce motion compliance
/// - VoiceOver integration
/// - Gesture-based dismissal
/// - Proper z-index management
/// - Error handling for animation failures
///
/// ## Usage
/// ```swift
/// ContentView()
///     .withToast()
/// ```
struct WithToast: ViewModifier {
    /// Reference to the shared toast manager
    @StateObject private var toastManager = ToastManager.shared
    
    /// Accessibility setting for reduced motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    /// Logger for view modifier events
    private let logger = Logger(subsystem: "com.tribeboard.app", category: "WithToast")
    
    func body(content: Content) -> some View {
        content
            .overlay(
                toastView,
                alignment: .top
            )
            .onAppear {
                logger.debug("Toast overlay attached to view")
            }
    }
    
    /// The toast view implementation with comprehensive error handling and accessibility
    @ViewBuilder
    private var toastView: some View {
        if let toast = toastManager.currentToast {
            HStack(spacing: 12) {
                // Toast type icon
                Image(systemName: toast.type.icon)
                    .foregroundColor(toast.type.color)
                    .accessibilityHidden(true)
                    .font(.system(size: 16, weight: .medium))
                
                // Toast message text
                Text(toast.message)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer(minLength: 8)
                
                // Dismiss button
                Button(action: dismissToast) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                        .font(.caption.weight(.medium))
                }
                .accessibilityLabel("Dismiss notification")
                .accessibilityHint("Dismisses the current notification")
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(toastBackground(for: toast))
            .overlay(toastBorder(for: toast))
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(toastTransition)
            .animation(toastAnimation, value: toast.id)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(toast.type.accessibilityLabel): \(toast.message)")
            .accessibilityAddTraits(toast.type.accessibilityTrait)
            .accessibilityAction(named: "Dismiss") {
                dismissToast()
            }
            .zIndex(1000)
            .onTapGesture {
                // Allow tap to dismiss
                dismissToast()
            }
        }
    }
    
    /// Handles toast dismissal with error handling and haptic feedback
    private func dismissToast() {
        HapticManager.shared.lightImpact()
        toastManager.hide()
    }
    
    /// Creates the background for the toast with error handling
    @ViewBuilder
    private func toastBackground(for toast: ToastMessage) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemBackground))
            .shadow(
                color: .black.opacity(0.1),
                radius: 8,
                x: 0,
                y: 2
            )
    }
    
    /// Creates the border for the toast
    @ViewBuilder
    private func toastBorder(for toast: ToastMessage) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(toast.type.color.opacity(0.3), lineWidth: 1)
    }
    
    /// The transition animation for the toast
    private var toastTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        } else {
            return .move(edge: .top)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.95))
        }
    }
    
    /// The animation for the toast
    private var toastAnimation: Animation {
        if reduceMotion {
            return .easeInOut(duration: 0.3)
        } else {
            return .spring(response: 0.5, dampingFraction: 0.8)
        }
    }
}

// MARK: - View Extension

extension View {
    /// Adds toast notification support to any SwiftUI view
    ///
    /// This method applies the WithToast view modifier to enable toast notifications
    /// throughout the view hierarchy. The toast overlay will appear at the top of
    /// the view with proper z-index management.
    ///
    /// ## Usage
    /// ```swift
    /// NavigationView {
    ///     ContentView()
    /// }
    /// .withToast()
    /// ```
    ///
    /// ## Features
    /// - Automatic toast display management
    /// - Accessibility compliance
    /// - Gesture-based dismissal
    /// - Reduce motion support
    /// - Error handling for animations
    ///
    /// - Returns: A view with toast notification support enabled
    func withToast() -> some View {
        modifier(WithToast())
    }
}