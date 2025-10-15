import UIKit
import os.log

/// Specialized haptic feedback manager for calendar interactions
///
/// This manager provides context-aware haptic feedback specifically designed for calendar
/// operations, building on the base HapticManager to provide calendar-specific patterns
/// and feedback sequences.
class CalendarHapticManager {
    /// Shared singleton instance
    static let shared = CalendarHapticManager()
    
    /// Base haptic manager for core functionality
    private let hapticManager = HapticManager.shared
    
    /// Logger for calendar haptic events
    private let logger = Logger(subsystem: "com.tribeboard.app", category: "CalendarHapticManager")
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    // MARK: - Calendar Navigation Haptics
    
    /// Provides haptic feedback for date selection in calendar views
    /// - Parameter date: The selected date
    /// - Parameter isToday: Whether the selected date is today
    func dateSelected(_ date: Date, isToday: Bool = false) {
        if isToday {
            // Slightly stronger feedback for selecting today
            hapticManager.mediumImpact()
        } else {
            hapticManager.selection()
        }
        
        logger.debug("Date selection haptic triggered for \(date)")
    }
    
    /// Provides haptic feedback for navigating between weeks/months
    /// - Parameter direction: The navigation direction
    func calendarNavigation(_ direction: NavigationDirection) {
        hapticManager.lightImpact()
        logger.debug("Calendar navigation haptic triggered: \(direction.rawValue)")
    }
    
    /// Provides haptic feedback for filter changes
    /// - Parameter filter: The selected filter
    func filterChanged(_ filter: String) {
        hapticManager.selection()
        logger.debug("Filter change haptic triggered: \(filter)")
    }
    
    // MARK: - Event Interaction Haptics
    
    /// Provides haptic feedback for event selection
    /// - Parameter event: The selected event
    func eventSelected(_ event: CalendarEvent) {
        if event.isHappening {
            // Special feedback for currently happening events
            hapticManager.mediumImpact()
        } else {
            hapticManager.selection()
        }
        
        logger.debug("Event selection haptic triggered for: \(event.title)")
    }
    
    /// Provides haptic feedback for successful event creation
    /// - Parameter event: The created event
    func eventCreated(_ event: CalendarEvent) {
        // Success pattern: medium impact followed by light impact
        hapticManager.mediumImpact()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.hapticManager.lightImpact()
        }
        
        logger.debug("Event creation success haptic triggered for: \(event.title)")
    }
    
    /// Provides haptic feedback for successful event updates
    /// - Parameter event: The updated event
    func eventUpdated(_ event: CalendarEvent) {
        hapticManager.success()
        logger.debug("Event update success haptic triggered for: \(event.title)")
    }
    
    /// Provides haptic feedback for event deletion confirmation
    /// - Parameter event: The event being deleted
    func eventDeletionWarning(_ event: CalendarEvent) {
        hapticManager.warning()
        logger.debug("Event deletion warning haptic triggered for: \(event.title)")
    }
    
    /// Provides haptic feedback for successful event deletion
    /// - Parameter eventTitle: The title of the deleted event
    func eventDeleted(_ eventTitle: String) {
        // Deletion pattern: warning followed by light impact
        hapticManager.warning()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.hapticManager.lightImpact()
        }
        
        logger.debug("Event deletion haptic triggered for: \(eventTitle)")
    }
    
    // MARK: - Form Interaction Haptics
    
    /// Provides haptic feedback for form field validation errors
    /// - Parameter fieldName: The name of the field with validation error
    func validationError(_ fieldName: String) {
        hapticManager.error()
        logger.debug("Validation error haptic triggered for field: \(fieldName)")
    }
    
    /// Provides haptic feedback for successful form validation
    /// - Parameter fieldName: The name of the validated field
    func validationSuccess(_ fieldName: String) {
        hapticManager.lightImpact()
        logger.debug("Validation success haptic triggered for field: \(fieldName)")
    }
    
    /// Provides haptic feedback for privacy level changes
    /// - Parameter level: The selected privacy level
    func privacyLevelChanged(_ level: CalendarEvent.PrivacyLevel) {
        hapticManager.selection()
        logger.debug("Privacy level change haptic triggered: \(level.displayName)")
    }
    
    /// Provides haptic feedback for all-day toggle changes
    /// - Parameter isAllDay: Whether all-day is enabled
    func allDayToggled(_ isAllDay: Bool) {
        hapticManager.selection()
        logger.debug("All-day toggle haptic triggered: \(isAllDay)")
    }
    
    // MARK: - Sync Operation Haptics
    
    /// Provides haptic feedback for successful calendar sync
    func syncSuccess() {
        // Success pattern: success notification followed by light impact
        hapticManager.success()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.hapticManager.lightImpact()
        }
        
        logger.debug("Sync success haptic triggered")
    }
    
    /// Provides haptic feedback for sync errors
    /// - Parameter error: The sync error
    func syncError(_ error: Error) {
        hapticManager.error()
        logger.debug("Sync error haptic triggered: \(error.localizedDescription)")
    }
    
    /// Provides haptic feedback for sync conflicts
    func syncConflict() {
        // Conflict pattern: warning followed by selection
        hapticManager.warning()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.hapticManager.selection()
        }
        
        logger.debug("Sync conflict haptic triggered")
    }
    
    /// Provides haptic feedback for manual sync initiation
    func syncInitiated() {
        hapticManager.lightImpact()
        logger.debug("Sync initiation haptic triggered")
    }
    
    // MARK: - Apple Calendar Integration Haptics
    
    /// Provides haptic feedback for successful Apple Calendar permission grant
    func appleCalendarPermissionGranted() {
        hapticManager.success()
        logger.debug("Apple Calendar permission granted haptic triggered")
    }
    
    /// Provides haptic feedback for Apple Calendar permission denial
    func appleCalendarPermissionDenied() {
        hapticManager.error()
        logger.debug("Apple Calendar permission denied haptic triggered")
    }
    
    /// Provides haptic feedback for Apple Calendar sync setup completion
    func appleCalendarSetupComplete() {
        // Setup completion pattern: success followed by medium impact
        hapticManager.success()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.hapticManager.mediumImpact()
        }
        
        logger.debug("Apple Calendar setup completion haptic triggered")
    }
    
    // MARK: - Loading and State Change Haptics
    
    /// Provides haptic feedback for loading state changes
    /// - Parameter isLoading: Whether loading has started or ended
    func loadingStateChanged(_ isLoading: Bool) {
        if isLoading {
            hapticManager.lightImpact()
        } else {
            hapticManager.selection()
        }
        
        logger.debug("Loading state change haptic triggered: \(isLoading)")
    }
    
    /// Provides haptic feedback for pull-to-refresh actions
    func pullToRefresh() {
        hapticManager.lightImpact()
        logger.debug("Pull-to-refresh haptic triggered")
    }
    
    /// Provides haptic feedback for refresh completion
    func refreshComplete() {
        hapticManager.selection()
        logger.debug("Refresh completion haptic triggered")
    }
    
    // MARK: - Error and Warning Haptics
    
    /// Provides haptic feedback for general calendar errors
    /// - Parameter error: The error that occurred
    func calendarError(_ error: Error) {
        hapticManager.error()
        logger.debug("Calendar error haptic triggered: \(error.localizedDescription)")
    }
    
    /// Provides haptic feedback for calendar warnings
    /// - Parameter message: The warning message
    func calendarWarning(_ message: String) {
        hapticManager.warning()
        logger.debug("Calendar warning haptic triggered: \(message)")
    }
    
    /// Provides haptic feedback for permission-related warnings
    func permissionWarning() {
        hapticManager.warning()
        logger.debug("Permission warning haptic triggered")
    }
    
    // MARK: - Complex Interaction Patterns
    
    /// Provides a sequence of haptic feedback for successful event creation workflow
    /// - Parameter event: The created event
    func eventCreationWorkflowSuccess(_ event: CalendarEvent) {
        // Complex pattern: light -> medium -> success
        hapticManager.lightImpact()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.hapticManager.mediumImpact()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.hapticManager.success()
        }
        
        logger.debug("Event creation workflow success haptic sequence triggered for: \(event.title)")
    }
    
    /// Provides a sequence of haptic feedback for event conflict resolution
    func eventConflictResolution() {
        // Conflict resolution pattern: warning -> selection -> light
        hapticManager.warning()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.hapticManager.selection()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.hapticManager.lightImpact()
        }
        
        logger.debug("Event conflict resolution haptic sequence triggered")
    }
    
    /// Provides haptic feedback for bulk operations
    /// - Parameter count: Number of items affected
    /// - Parameter operation: The type of bulk operation
    func bulkOperation(count: Int, operation: BulkOperation) {
        switch operation {
        case .delete:
            // Stronger feedback for bulk deletions
            hapticManager.warning()
        case .update:
            hapticManager.mediumImpact()
        case .sync:
            hapticManager.lightImpact()
        }
        
        logger.debug("Bulk operation haptic triggered: \(operation.rawValue) for \(count) items")
    }
    
    // MARK: - Accessibility-Enhanced Haptics
    
    /// Provides enhanced haptic feedback for accessibility users
    /// - Parameter interaction: The type of interaction
    /// - Parameter context: Additional context for the interaction
    func accessibilityInteraction(_ interaction: AccessibilityInteraction, context: String = "") {
        switch interaction {
        case .focus:
            hapticManager.lightImpact()
        case .selection:
            hapticManager.selection()
        case .navigation:
            hapticManager.lightImpact()
        case .confirmation:
            hapticManager.mediumImpact()
        case .error:
            hapticManager.error()
        }
        
        logger.debug("Accessibility interaction haptic triggered: \(interaction.rawValue) - \(context)")
    }
    
    // MARK: - Utility Methods
    
    /// Prepares haptic generators for optimal calendar performance
    func prepareForCalendarSession() {
        hapticManager.prepareForHapticSequence()
        logger.debug("Calendar haptic session prepared")
    }
    
    /// Checks if haptic feedback is available for calendar interactions
    var isCalendarHapticEnabled: Bool {
        return hapticManager.isHapticFeedbackEnabled
    }
}

// MARK: - Supporting Enums

/// Navigation directions for calendar haptic feedback
enum NavigationDirection: String, CaseIterable {
    case previous = "previous"
    case next = "next"
    case today = "today"
}

/// Bulk operation types for haptic feedback
enum BulkOperation: String, CaseIterable {
    case delete = "delete"
    case update = "update"
    case sync = "sync"
}

/// Accessibility interaction types for enhanced haptic feedback
enum AccessibilityInteraction: String, CaseIterable {
    case focus = "focus"
    case selection = "selection"
    case navigation = "navigation"
    case confirmation = "confirmation"
    case error = "error"
}

// MARK: - Calendar Event Extensions for Haptic Context

extension CalendarEvent {
    /// Provides haptic context based on event properties
    var hapticContext: HapticContext {
        if isHappening {
            return .currentEvent
        } else if isToday {
            return .todayEvent
        } else if isPast {
            return .pastEvent
        } else {
            return .futureEvent
        }
    }
}

/// Haptic context for different event states
enum HapticContext: String, CaseIterable {
    case currentEvent = "current"
    case todayEvent = "today"
    case pastEvent = "past"
    case futureEvent = "future"
    
    /// Provides appropriate haptic style for the context
    var hapticStyle: HapticStyle {
        switch self {
        case .currentEvent:
            return .medium
        case .todayEvent:
            return .light
        case .pastEvent:
            return .light
        case .futureEvent:
            return .light
        }
    }
}