import Foundation

// MARK: - Mock Error Data Structures

/// Comprehensive mock error for prototype error handling
struct MockError: Identifiable, Equatable {
    let id: UUID
    let category: MockErrorCategory
    let type: MockErrorType
    let title: String
    let message: String
    let severity: MockErrorSeverity
    let isRetryable: Bool
    let recoveryActions: [MockRecoveryAction]
    let context: [String: Any]
    let timestamp: Date
    
    init(
        id: UUID = UUID(),
        category: MockErrorCategory,
        type: MockErrorType,
        title: String,
        message: String,
        severity: MockErrorSeverity,
        isRetryable: Bool,
        recoveryActions: [MockRecoveryAction],
        context: [String: Any] = [:]
    ) {
        self.id = id
        self.category = category
        self.type = type
        self.title = title
        self.message = message
        self.severity = severity
        self.isRetryable = isRetryable
        self.recoveryActions = recoveryActions
        self.context = context
        self.timestamp = Date()
    }
    
    // MARK: - Equatable Implementation
    
    static func == (lhs: MockError, rhs: MockError) -> Bool {
        return lhs.id == rhs.id &&
               lhs.category == rhs.category &&
               lhs.type == rhs.type &&
               lhs.title == rhs.title &&
               lhs.message == rhs.message &&
               lhs.severity == rhs.severity
    }
}

/// Categories of mock errors
enum MockErrorCategory: String, CaseIterable, Hashable {
    case authentication = "authentication"
    case network = "network"
    case validation = "validation"
    case permission = "permission"
    case familyManagement = "family_management"
    case sync = "sync"
    case qrCode = "qr_code"
    case prototype = "prototype"
    
    var displayName: String {
        switch self {
        case .authentication:
            return "Authentication"
        case .network:
            return "Network"
        case .validation:
            return "Validation"
        case .permission:
            return "Permission"
        case .familyManagement:
            return "Family Management"
        case .sync:
            return "Sync"
        case .qrCode:
            return "QR Code"
        case .prototype:
            return "Prototype"
        }
    }
    
    var icon: String {
        switch self {
        case .authentication:
            return "person.crop.circle.badge.exclamationmark"
        case .network:
            return "wifi.exclamationmark"
        case .validation:
            return "exclamationmark.triangle.fill"
        case .permission:
            return "lock.fill"
        case .familyManagement:
            return "person.3.fill"
        case .sync:
            return "arrow.triangle.2.circlepath"
        case .qrCode:
            return "qrcode.viewfinder"
        case .prototype:
            return "info.circle.fill"
        }
    }
}

/// Specific types of mock errors
enum MockErrorType: String, CaseIterable, Hashable {
    // Authentication errors
    case sessionExpired = "session_expired"
    case accountNotFound = "account_not_found"
    case authenticationFailed = "authentication_failed"
    case biometricFailed = "biometric_failed"
    
    // Network errors
    case noConnection = "no_connection"
    case slowConnection = "slow_connection"
    case serverUnavailable = "server_unavailable"
    case timeout = "timeout"
    
    // Validation errors
    case invalidInput = "invalid_input"
    case duplicateData = "duplicate_data"
    case invalidFormat = "invalid_format"
    
    // Permission errors
    case accessDenied = "access_denied"
    case childRestriction = "child_restriction"
    case cameraPermission = "camera_permission"
    
    // Family management errors
    case familyNotFound = "family_not_found"
    case familyFull = "family_full"
    case alreadyMember = "already_member"
    
    // Sync errors
    case syncFailed = "sync_failed"
    case conflictDetected = "conflict_detected"
    case quotaExceeded = "quota_exceeded"
    
    // QR Code errors
    case scanFailed = "scan_failed"
    case invalidQRCode = "invalid_qr_code"
    
    // Prototype errors
    case featurePreview = "feature_preview"
    case dataLimit = "data_limit"
}

/// Severity levels for mock errors
enum MockErrorSeverity: String, CaseIterable, Comparable {
    case info = "info"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .info:
            return "Info"
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        case .critical:
            return "Critical"
        }
    }
    
    var color: String {
        switch self {
        case .info:
            return "blue"
        case .low:
            return "green"
        case .medium:
            return "orange"
        case .high:
            return "red"
        case .critical:
            return "purple"
        }
    }
    
    var priority: Int {
        switch self {
        case .info:
            return 1
        case .low:
            return 2
        case .medium:
            return 3
        case .high:
            return 4
        case .critical:
            return 5
        }
    }
    
    static func < (lhs: MockErrorSeverity, rhs: MockErrorSeverity) -> Bool {
        return lhs.priority < rhs.priority
    }
}

/// Recovery actions available for mock errors
enum MockRecoveryAction: String, CaseIterable, Hashable {
    // General actions
    case dismiss = "dismiss"
    case retry = "retry"
    case cancel = "cancel"
    
    // Authentication actions
    case signIn = "sign_in"
    case createAccount = "create_account"
    case tryDifferentAccount = "try_different_account"
    case tryDifferentMethod = "try_different_method"
    case usePasscode = "use_passcode"
    case signInManually = "sign_in_manually"
    
    // Network actions
    case checkConnection = "check_connection"
    case workOffline = "work_offline"
    case checkStatus = "check_status"
    case continueAnyway = "continue_anyway"
    
    // Validation actions
    case editInput = "edit_input"
    case chooseDifferentName = "choose_different_name"
    case addSuffix = "add_suffix"
    case generateNewCode = "generate_new_code"
    case editCode = "edit_code"
    
    // Permission actions
    case contactAdmin = "contact_admin"
    case requestPermission = "request_permission"
    case askParent = "ask_parent"
    case openSettings = "open_settings"
    case enterCodeManually = "enter_code_manually"
    
    // Family management actions
    case tryDifferentCode = "try_different_code"
    case scanQRCode = "scan_qr_code"
    case contactSender = "contact_sender"
    case waitForSpace = "wait_for_space"
    case switchFamilies = "switch_families"
    case stayInCurrent = "stay_in_current"
    
    // Sync actions
    case forceSync = "force_sync"
    case continueOffline = "continue_offline"
    case reviewChanges = "review_changes"
    case acceptMerge = "accept_merge"
    case manageStorage = "manage_storage"
    case upgradeStorage = "upgrade_storage"
    case continueLocal = "continue_local"
    
    // QR Code actions
    case tryAgain = "try_again"
    case improveLight = "improve_light"
    case scanDifferentCode = "scan_different_code"
    case getNewCode = "get_new_code"
    
    // Prototype actions
    case learnMore = "learn_more"
    case continueDemo = "continue_demo"
    case resetDemo = "reset_demo"
    
    var title: String {
        switch self {
        case .dismiss:
            return "Dismiss"
        case .retry:
            return "Try Again"
        case .cancel:
            return "Cancel"
        case .signIn:
            return "Sign In"
        case .createAccount:
            return "Create Account"
        case .tryDifferentAccount:
            return "Try Different Account"
        case .tryDifferentMethod:
            return "Try Different Method"
        case .usePasscode:
            return "Use Passcode"
        case .signInManually:
            return "Sign In Manually"
        case .checkConnection:
            return "Check Connection"
        case .workOffline:
            return "Work Offline"
        case .checkStatus:
            return "Check Status"
        case .continueAnyway:
            return "Continue Anyway"
        case .editInput:
            return "Edit Input"
        case .chooseDifferentName:
            return "Choose Different Name"
        case .addSuffix:
            return "Add Suffix"
        case .generateNewCode:
            return "Generate New Code"
        case .editCode:
            return "Edit Code"
        case .contactAdmin:
            return "Contact Admin"
        case .requestPermission:
            return "Request Permission"
        case .askParent:
            return "Ask Parent"
        case .openSettings:
            return "Open Settings"
        case .enterCodeManually:
            return "Enter Code Manually"
        case .tryDifferentCode:
            return "Try Different Code"
        case .scanQRCode:
            return "Scan QR Code"
        case .contactSender:
            return "Contact Sender"
        case .waitForSpace:
            return "Wait for Space"
        case .switchFamilies:
            return "Switch Families"
        case .stayInCurrent:
            return "Stay in Current"
        case .forceSync:
            return "Force Sync"
        case .continueOffline:
            return "Continue Offline"
        case .reviewChanges:
            return "Review Changes"
        case .acceptMerge:
            return "Accept Merge"
        case .manageStorage:
            return "Manage Storage"
        case .upgradeStorage:
            return "Upgrade Storage"
        case .continueLocal:
            return "Continue Local"
        case .tryAgain:
            return "Try Again"
        case .improveLight:
            return "Improve Lighting"
        case .scanDifferentCode:
            return "Scan Different Code"
        case .getNewCode:
            return "Get New Code"
        case .learnMore:
            return "Learn More"
        case .continueDemo:
            return "Continue Demo"
        case .resetDemo:
            return "Reset Demo"
        }
    }
    
    var icon: String {
        switch self {
        case .dismiss:
            return "xmark.circle"
        case .retry:
            return "arrow.clockwise"
        case .cancel:
            return "xmark"
        case .signIn:
            return "person.crop.circle"
        case .createAccount:
            return "person.crop.circle.badge.plus"
        case .tryDifferentAccount:
            return "person.2.crop.square.stack"
        case .tryDifferentMethod:
            return "arrow.triangle.swap"
        case .usePasscode:
            return "lock.fill"
        case .signInManually:
            return "hand.point.up.left"
        case .checkConnection:
            return "wifi"
        case .workOffline:
            return "wifi.slash"
        case .checkStatus:
            return "info.circle"
        case .continueAnyway:
            return "arrow.right.circle"
        case .editInput:
            return "pencil"
        case .chooseDifferentName:
            return "textformat.abc"
        case .addSuffix:
            return "plus.circle"
        case .generateNewCode:
            return "arrow.clockwise.circle"
        case .editCode:
            return "pencil.circle"
        case .contactAdmin:
            return "envelope"
        case .requestPermission:
            return "hand.raised"
        case .askParent:
            return "person.2"
        case .openSettings:
            return "gear"
        case .enterCodeManually:
            return "keyboard"
        case .tryDifferentCode:
            return "textformat.123"
        case .scanQRCode:
            return "qrcode.viewfinder"
        case .contactSender:
            return "message"
        case .waitForSpace:
            return "clock"
        case .switchFamilies:
            return "arrow.triangle.swap"
        case .stayInCurrent:
            return "checkmark.circle"
        case .forceSync:
            return "arrow.triangle.2.circlepath"
        case .continueOffline:
            return "wifi.slash"
        case .reviewChanges:
            return "doc.text.magnifyingglass"
        case .acceptMerge:
            return "checkmark.circle.fill"
        case .manageStorage:
            return "externaldrive"
        case .upgradeStorage:
            return "arrow.up.circle"
        case .continueLocal:
            return "internaldrive"
        case .tryAgain:
            return "arrow.clockwise"
        case .improveLight:
            return "lightbulb"
        case .scanDifferentCode:
            return "qrcode"
        case .getNewCode:
            return "qrcode.viewfinder"
        case .learnMore:
            return "info.circle"
        case .continueDemo:
            return "play.circle"
        case .resetDemo:
            return "arrow.counterclockwise"
        }
    }
    
    var style: MockActionStyle {
        switch self {
        case .dismiss, .cancel:
            return .secondary
        case .retry, .tryAgain, .forceSync:
            return .primary
        case .signIn, .createAccount, .openSettings:
            return .primary
        case .workOffline, .continueOffline, .continueAnyway, .continueLocal:
            return .tertiary
        case .contactAdmin, .requestPermission, .askParent:
            return .secondary
        case .learnMore, .checkStatus, .reviewChanges:
            return .tertiary
        default:
            return .secondary
        }
    }
}

/// Action button styles
enum MockActionStyle {
    case primary
    case secondary
    case tertiary
    case destructive
}

extension MockActionStyle: CustomStringConvertible {
    var description: String {
        switch self {
        case .primary:
            return "primary"
        case .secondary:
            return "secondary"
        case .tertiary:
            return "tertiary"
        case .destructive:
            return "destructive"
        }
    }
}

/// Error scenarios for testing
enum MockErrorScenario: String, CaseIterable {
    case networkOutage = "network_outage"
    case networkError = "network_error"
    case authenticationIssues = "authentication_issues"
    case authenticationError = "authentication_error"
    case validationProblems = "validation_problems"
    case permissionDenials = "permission_denials"
    case syncConflicts = "sync_conflicts"
    case syncConflict = "sync_conflict"
    case mixedErrors = "mixed_errors"
    case prototypeDemo = "prototype_demo"
    
    var displayName: String {
        switch self {
        case .networkOutage:
            return "Network Outage"
        case .networkError:
            return "Network Error"
        case .authenticationIssues:
            return "Authentication Issues"
        case .authenticationError:
            return "Authentication Error"
        case .validationProblems:
            return "Validation Problems"
        case .permissionDenials:
            return "Permission Denials"
        case .syncConflicts:
            return "Sync Conflicts"
        case .syncConflict:
            return "Sync Conflict"
        case .mixedErrors:
            return "Mixed Errors"
        case .prototypeDemo:
            return "Prototype Demo"
        }
    }
    
    var description: String {
        switch self {
        case .networkOutage:
            return "Simulates network connectivity issues and server problems"
        case .networkError:
            return "Simulates network connectivity errors"
        case .authenticationIssues:
            return "Simulates authentication failures and session problems"
        case .authenticationError:
            return "Simulates authentication errors"
        case .validationProblems:
            return "Simulates form validation and input errors"
        case .permissionDenials:
            return "Simulates permission and access control issues"
        case .syncConflicts:
            return "Simulates data synchronization problems"
        case .syncConflict:
            return "Simulates data synchronization conflicts"
        case .mixedErrors:
            return "Simulates a variety of different error types"
        case .prototypeDemo:
            return "Simulates prototype-specific limitations and features"
        }
    }
}

/// Error event for tracking
struct MockErrorEvent {
    let error: MockError
    let timestamp: Date
    let context: [String: Any]
}

/// Error pattern analysis
struct MockErrorPattern {
    let type: MockErrorPatternType
    let frequency: Int
    let timespan: TimeInterval
    let recommendation: String
}

enum MockErrorPatternType {
    case repeatedCategory(MockErrorCategory)
    case escalatingSeverity
    case rapidSuccession
    case userSpecific
}

/// Error statistics for analytics
struct MockErrorStatistics {
    let totalErrors: Int
    let errorsByCategory: [MockErrorCategory: Int]
    let errorsBySeverity: [MockErrorSeverity: Int]
    let patterns: [MockErrorPattern]
    let averageErrorsPerHour: Double
}

// MARK: - Error Recovery Flow

/// Represents a complete error recovery flow
struct MockErrorRecoveryFlow {
    let error: MockError
    let steps: [MockRecoveryStep]
    let fallbackOptions: [MockRecoveryAction]
    let successCriteria: [String]
}

/// Individual step in error recovery
struct MockRecoveryStep {
    let action: MockRecoveryAction
    let description: String
    let estimatedTime: TimeInterval?
    let requiresUserInput: Bool
    let successProbability: Double
}

// MARK: - Error Context

/// Context information for error generation and handling
struct MockErrorContext {
    let currentView: String
    let userRole: String?
    let networkStatus: String
    let authenticationStatus: String
    let lastAction: String?
    let errorHistory: [MockError]
    let userPreferences: [String: Any]
}

// MARK: - Error Presentation

/// How errors should be presented to users
enum MockErrorPresentationStyle {
    case toast
    case modal
    case inline
    case banner
    case fullScreen
    
    var duration: TimeInterval? {
        switch self {
        case .toast:
            return 4.0
        case .banner:
            return 6.0
        case .modal, .inline, .fullScreen:
            return nil // User dismisses
        }
    }
}

/// Error presentation configuration
struct MockErrorPresentation {
    let style: MockErrorPresentationStyle
    let priority: Int
    let allowDismissal: Bool
    let showRecoveryActions: Bool
    let animationDuration: TimeInterval
}