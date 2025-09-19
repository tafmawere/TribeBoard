import Foundation

/// State machine for tracking family creation progress
enum FamilyCreationState: Equatable, CaseIterable {
    case idle
    case validating
    case generatingCode
    case creatingLocally
    case syncingToCloudKit
    case completed
    case failed(FamilyCreationError)
    
    // MARK: - State Properties
    
    /// Whether the creation process is currently active
    var isActive: Bool {
        switch self {
        case .idle, .completed, .failed:
            return false
        case .validating, .generatingCode, .creatingLocally, .syncingToCloudKit:
            return true
        }
    }
    
    /// Whether the state represents a loading/processing state
    var isLoading: Bool {
        return isActive
    }
    
    /// Whether the creation process has completed successfully
    var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }
    
    /// Whether the creation process has failed
    var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
    
    /// The error associated with a failed state, if any
    var error: FamilyCreationError? {
        if case .failed(let error) = self {
            return error
        }
        return nil
    }
    
    /// User-friendly description of the current state
    var userDescription: String {
        switch self {
        case .idle:
            return "Ready to create family"
        case .validating:
            return "Validating family information..."
        case .generatingCode:
            return "Generating unique family code..."
        case .creatingLocally:
            return "Creating family..."
        case .syncingToCloudKit:
            return "Syncing to iCloud..."
        case .completed:
            return "Family created successfully!"
        case .failed(let error):
            return "Creation failed: \(error.userFriendlyMessage)"
        }
    }
    
    /// Technical description for logging and debugging
    var technicalDescription: String {
        switch self {
        case .idle:
            return "State: idle"
        case .validating:
            return "State: validating input data"
        case .generatingCode:
            return "State: generating unique family code"
        case .creatingLocally:
            return "State: creating family in local database"
        case .syncingToCloudKit:
            return "State: syncing family to CloudKit"
        case .completed:
            return "State: creation completed successfully"
        case .failed(let error):
            return "State: failed with error - \(error.technicalDescription)"
        }
    }
    
    /// Progress percentage (0.0 to 1.0) for UI progress indicators
    var progress: Double {
        switch self {
        case .idle:
            return 0.0
        case .validating:
            return 0.2
        case .generatingCode:
            return 0.4
        case .creatingLocally:
            return 0.6
        case .syncingToCloudKit:
            return 0.8
        case .completed:
            return 1.0
        case .failed:
            return 0.0 // Reset progress on failure
        }
    }
    
    /// Whether the current state can transition to the specified state
    func canTransition(to newState: FamilyCreationState) -> Bool {
        switch (self, newState) {
        // From idle
        case (.idle, .validating):
            return true
        case (.idle, .failed):
            return true
            
        // From validating
        case (.validating, .generatingCode):
            return true
        case (.validating, .failed):
            return true
        case (.validating, .idle):
            return true // Allow reset
            
        // From generating code
        case (.generatingCode, .creatingLocally):
            return true
        case (.generatingCode, .failed):
            return true
        case (.generatingCode, .idle):
            return true // Allow reset
            
        // From creating locally
        case (.creatingLocally, .syncingToCloudKit):
            return true
        case (.creatingLocally, .completed):
            return true // Can complete without CloudKit sync
        case (.creatingLocally, .failed):
            return true
        case (.creatingLocally, .idle):
            return true // Allow reset
            
        // From syncing to CloudKit
        case (.syncingToCloudKit, .completed):
            return true
        case (.syncingToCloudKit, .failed):
            return true
        case (.syncingToCloudKit, .idle):
            return true // Allow reset
            
        // From completed
        case (.completed, .idle):
            return true // Allow reset for new creation
            
        // From failed
        case (.failed, .idle):
            return true // Allow reset
        case (.failed, .validating):
            return true // Allow retry
            
        // Invalid transitions
        default:
            return false
        }
    }
    
    /// The next expected state in the normal flow
    var nextState: FamilyCreationState? {
        switch self {
        case .idle:
            return .validating
        case .validating:
            return .generatingCode
        case .generatingCode:
            return .creatingLocally
        case .creatingLocally:
            return .syncingToCloudKit
        case .syncingToCloudKit:
            return .completed
        case .completed, .failed:
            return nil // Terminal states
        }
    }
    
    /// Whether this state allows user cancellation
    var isCancellable: Bool {
        switch self {
        case .idle, .completed, .failed:
            return false
        case .validating, .generatingCode, .creatingLocally, .syncingToCloudKit:
            return true
        }
    }
    
    /// Whether this state should show a loading indicator
    var shouldShowLoadingIndicator: Bool {
        return isActive
    }
    
    /// Whether this state should show progress details
    var shouldShowProgressDetails: Bool {
        switch self {
        case .generatingCode, .creatingLocally, .syncingToCloudKit:
            return true
        case .idle, .validating, .completed, .failed:
            return false
        }
    }
    
    /// Whether this state allows retry operations
    var allowsRetry: Bool {
        if case .failed(let error) = self {
            return error.isRetryable
        }
        return false
    }
    
    /// The appropriate retry strategy for this state
    var retryStrategy: ErrorRecoveryStrategy? {
        if case .failed(let error) = self {
            return error.recoveryStrategy
        }
        return nil
    }
    
    // MARK: - State Transition Methods
    
    /// Creates a new state with validation for the transition
    func transition(to newState: FamilyCreationState) -> FamilyCreationState {
        guard canTransition(to: newState) else {
            print("⚠️ Invalid state transition from \(self) to \(newState)")
            return self
        }
        return newState
    }
    
    /// Creates a failed state with the specified error
    static func failed(with error: FamilyCreationError) -> FamilyCreationState {
        return .failed(error)
    }
    
    /// Resets the state to idle
    func reset() -> FamilyCreationState {
        return .idle
    }
    
    // MARK: - Equatable Implementation
    
    static func == (lhs: FamilyCreationState, rhs: FamilyCreationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.validating, .validating):
            return true
        case (.generatingCode, .generatingCode):
            return true
        case (.creatingLocally, .creatingLocally):
            return true
        case (.syncingToCloudKit, .syncingToCloudKit):
            return true
        case (.completed, .completed):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
    
    // MARK: - CaseIterable Implementation
    
    static var allCases: [FamilyCreationState] {
        return [
            .idle,
            .validating,
            .generatingCode,
            .creatingLocally,
            .syncingToCloudKit,
            .completed,
            .failed(.unknownError(NSError(domain: "Example", code: 0, userInfo: nil)))
        ]
    }
}

// MARK: - State Machine Manager

/// Manages state transitions and validation for family creation
@MainActor
class FamilyCreationStateManager: ObservableObject {
    @Published private(set) var currentState: FamilyCreationState = .idle
    @Published private(set) var stateHistory: [FamilyCreationState] = [.idle]
    
    /// The current error, if any
    var currentError: FamilyCreationError? {
        return currentState.error
    }
    
    /// Whether the creation process is currently active
    var isActive: Bool {
        return currentState.isActive
    }
    
    /// Whether the creation process has completed
    var isCompleted: Bool {
        return currentState.isCompleted
    }
    
    /// Whether the creation process has failed
    var isFailed: Bool {
        return currentState.isFailed
    }
    
    /// Current progress (0.0 to 1.0)
    var progress: Double {
        return currentState.progress
    }
    
    /// User-friendly status message
    var statusMessage: String {
        return currentState.userDescription
    }
    
    /// Transitions to a new state with validation
    func transition(to newState: FamilyCreationState) {
        let validatedState = currentState.transition(to: newState)
        if validatedState != currentState {
            let previousState = currentState
            currentState = validatedState
            stateHistory.append(validatedState)
            
            print("🔄 State transition: \(previousState.technicalDescription) → \(validatedState.technicalDescription)")
            
            // Post notification for observers
            NotificationCenter.default.post(
                name: .familyCreationStateChanged,
                object: self,
                userInfo: [
                    "previousState": previousState,
                    "newState": validatedState
                ]
            )
        }
    }
    
    /// Transitions to a failed state with the specified error
    func fail(with error: FamilyCreationError) {
        transition(to: .failed(error))
    }
    
    /// Resets the state machine to idle
    func reset() {
        currentState = .idle
        stateHistory = [.idle]
        
        print("🔄 State machine reset to idle")
        
        NotificationCenter.default.post(
            name: .familyCreationStateReset,
            object: self
        )
    }
    
    /// Attempts to retry the current operation if possible
    func retry() -> Bool {
        guard currentState.allowsRetry else {
            return false
        }
        
        // Reset to idle and allow retry
        reset()
        return true
    }
    
    /// Gets the state history for debugging
    func getStateHistory() -> [FamilyCreationState] {
        return stateHistory
    }
    
    /// Gets the duration spent in each state
    func getStateDurations() -> [String: TimeInterval] {
        // This would require timestamp tracking for each state transition
        // Implementation would depend on specific requirements
        return [:]
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let familyCreationStateChanged = Notification.Name("familyCreationStateChanged")
    static let familyCreationStateReset = Notification.Name("familyCreationStateReset")
}

// MARK: - State Analytics

/// Analytics helper for tracking state transitions and errors
struct FamilyCreationAnalytics {
    
    /// Records a state transition for analytics
    static func recordStateTransition(from: FamilyCreationState, to: FamilyCreationState) {
        // Implementation would depend on analytics framework
        print("📊 Analytics: State transition \(from) → \(to)")
    }
    
    /// Records an error for analytics
    static func recordError(_ error: FamilyCreationError, in state: FamilyCreationState) {
        print("📊 Analytics: Error in state \(state) - \(error.category.rawValue): \(error.technicalDescription)")
    }
    
    /// Records successful completion
    static func recordSuccess(duration: TimeInterval, stateHistory: [FamilyCreationState]) {
        print("📊 Analytics: Family creation succeeded in \(duration)s with \(stateHistory.count) state transitions")
    }
}