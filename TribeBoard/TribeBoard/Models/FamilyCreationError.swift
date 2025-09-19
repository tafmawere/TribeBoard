import Foundation

/// Comprehensive error types for family creation with user-friendly messages and retry logic
enum FamilyCreationError: LocalizedError, Equatable {
    // MARK: - Validation Errors
    case validationFailed(String)
    case invalidFamilyName(String)
    case invalidUserData(String)
    
    // MARK: - Code Generation Errors
    case codeGenerationFailed(FamilyCodeGenerationError)
    case maxCodeGenerationAttemptsExceeded
    case codeCollisionDetected
    
    // MARK: - Local Database Errors
    case localCreationFailed(DataServiceError)
    case databaseUnavailable
    case dataCorruption(String)
    case constraintViolation(String)
    
    // MARK: - CloudKit Sync Errors
    case cloudKitSyncFailed(CloudKitError)
    case cloudKitUnavailable
    case quotaExceeded
    case accountNotAvailable
    
    // MARK: - Network Errors
    case networkUnavailable
    case connectionTimeout
    case serverError(Int)
    
    // MARK: - System Errors
    case maxRetriesExceeded
    case operationCancelled
    case operationSucceeded
    case unknownError(Error)
    
    // MARK: - User Authentication Errors
    case userNotAuthenticated
    case insufficientPermissions
    
    // MARK: - LocalizedError Implementation
    
    var errorDescription: String? {
        return userFriendlyMessage
    }
    
    /// User-friendly error messages for display in the UI
    var userFriendlyMessage: String {
        switch self {
        // Validation Errors
        case .validationFailed(let message):
            return "Please check your input: \(message)"
        case .invalidFamilyName(let message):
            return "Family name issue: \(message)"
        case .invalidUserData(let message):
            return "User information issue: \(message)"
            
        // Code Generation Errors
        case .codeGenerationFailed(let codeError):
            return "Unable to generate family code: \(codeError.userFriendlyMessage)"
        case .maxCodeGenerationAttemptsExceeded:
            return "Unable to create a unique family code. Please try again in a moment."
        case .codeCollisionDetected:
            return "Family code already exists. Generating a new one..."
            
        // Local Database Errors
        case .localCreationFailed(let dataError):
            return "Unable to save family locally: \(dataError.localizedDescription ?? "Unknown error")"
        case .databaseUnavailable:
            return "Local storage is temporarily unavailable. Please try again."
        case .dataCorruption(let message):
            return "Data integrity issue: \(message). Please restart the app."
        case .constraintViolation(let message):
            return "Data constraint issue: \(message)"
            
        // CloudKit Sync Errors
        case .cloudKitSyncFailed(let cloudKitError):
            return "Sync failed: \(cloudKitError.localizedDescription ?? "Unknown sync error"). Family saved locally."
        case .cloudKitUnavailable:
            return "iCloud is temporarily unavailable. Family saved locally and will sync later."
        case .quotaExceeded:
            return "iCloud storage is full. Please free up space or family will only be saved locally."
        case .accountNotAvailable:
            return "iCloud account not available. Please sign in to iCloud in Settings."
            
        // Network Errors
        case .networkUnavailable:
            return "No internet connection. Family saved locally and will sync when connected."
        case .connectionTimeout:
            return "Connection timed out. Family saved locally and will sync later."
        case .serverError(let code):
            return "Server error (\(code)). Family saved locally and will sync later."
            
        // System Errors
        case .maxRetriesExceeded:
            return "Operation failed after multiple attempts. Please try again."
        case .operationCancelled:
            return "Operation was cancelled."
        case .operationSucceeded:
            return "Operation completed successfully."
        case .unknownError(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
            
        // User Authentication Errors
        case .userNotAuthenticated:
            return "Please sign in to create a family."
        case .insufficientPermissions:
            return "You don't have permission to perform this action."
        }
    }
    
    /// Technical error message for logging and debugging
    var technicalDescription: String {
        switch self {
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .invalidFamilyName(let message):
            return "Invalid family name: \(message)"
        case .invalidUserData(let message):
            return "Invalid user data: \(message)"
        case .codeGenerationFailed(let codeError):
            return "Code generation failed: \(codeError.technicalDescription)"
        case .maxCodeGenerationAttemptsExceeded:
            return "Maximum code generation attempts exceeded"
        case .codeCollisionDetected:
            return "Code collision detected during generation"
        case .localCreationFailed(let dataError):
            return "Local creation failed: \(dataError.localizedDescription ?? "Unknown DataService error")"
        case .databaseUnavailable:
            return "Database unavailable"
        case .dataCorruption(let message):
            return "Data corruption: \(message)"
        case .constraintViolation(let message):
            return "Constraint violation: \(message)"
        case .cloudKitSyncFailed(let cloudKitError):
            return "CloudKit sync failed: \(cloudKitError.localizedDescription ?? "Unknown CloudKit error")"
        case .cloudKitUnavailable:
            return "CloudKit unavailable"
        case .quotaExceeded:
            return "CloudKit quota exceeded"
        case .accountNotAvailable:
            return "CloudKit account not available"
        case .networkUnavailable:
            return "Network unavailable"
        case .connectionTimeout:
            return "Connection timeout"
        case .serverError(let code):
            return "Server error: HTTP \(code)"
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        case .operationCancelled:
            return "Operation cancelled"
        case .operationSucceeded:
            return "Operation succeeded"
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
        case .userNotAuthenticated:
            return "User not authenticated"
        case .insufficientPermissions:
            return "Insufficient permissions"
        }
    }
    
    /// Determines if the error is retryable
    var isRetryable: Bool {
        switch self {
        // Retryable errors
        case .codeCollisionDetected,
             .networkUnavailable,
             .connectionTimeout,
             .cloudKitUnavailable,
             .databaseUnavailable:
            return true
            
        // Conditionally retryable errors
        case .codeGenerationFailed(let codeError):
            return codeError.isRetryable
        case .localCreationFailed:
            return true // DataService errors are generally retryable
        case .cloudKitSyncFailed:
            return true // CloudKit errors are generally retryable
        case .serverError(let code):
            return code >= 500 // Server errors (5xx) are retryable, client errors (4xx) are not
            
        // Non-retryable errors
        case .validationFailed,
             .invalidFamilyName,
             .invalidUserData,
             .maxCodeGenerationAttemptsExceeded,
             .dataCorruption,
             .constraintViolation,
             .quotaExceeded,
             .accountNotAvailable,
             .maxRetriesExceeded,
             .operationCancelled,
             .operationSucceeded,
             .userNotAuthenticated,
             .insufficientPermissions,
             .unknownError:
            return false
        }
    }
    
    /// Determines the recovery strategy for the error
    var recoveryStrategy: ErrorRecoveryStrategy {
        switch self {
        // Automatic retry strategies
        case .codeCollisionDetected:
            return .automaticRetry(delay: 0.1, maxAttempts: 5)
        case .networkUnavailable, .connectionTimeout:
            return .automaticRetry(delay: 2.0, maxAttempts: 3)
        case .cloudKitUnavailable, .databaseUnavailable:
            return .automaticRetry(delay: 1.0, maxAttempts: 3)
        case .serverError(let code) where code >= 500:
            return .automaticRetry(delay: 5.0, maxAttempts: 2)
            
        // Fallback strategies
        case .cloudKitSyncFailed, .quotaExceeded:
            return .fallbackToLocal
        case .accountNotAvailable:
            return .fallbackToLocal
            
        // User intervention required
        case .validationFailed, .invalidFamilyName, .invalidUserData:
            return .userIntervention
        case .userNotAuthenticated, .insufficientPermissions:
            return .userIntervention
            
        // No recovery possible
        case .maxCodeGenerationAttemptsExceeded,
             .maxRetriesExceeded,
             .dataCorruption,
             .operationCancelled,
             .operationSucceeded,
             .unknownError:
            return .noRecovery
            
        // Conditional recovery based on nested error
        case .codeGenerationFailed(let codeError):
            return codeError.recoveryStrategy
        case .localCreationFailed:
            return .automaticRetry(delay: 1.0, maxAttempts: 2)
        case .constraintViolation:
            return .userIntervention
        case .serverError(let code):
            if code < 500 {
                return .userIntervention
            } else {
                return .automaticRetry(delay: 5.0, maxAttempts: 2)
            }
        }
    }
    
    /// Error category for analytics and monitoring
    var category: ErrorCategory {
        switch self {
        case .validationFailed, .invalidFamilyName, .invalidUserData:
            return .validation
        case .codeGenerationFailed, .maxCodeGenerationAttemptsExceeded, .codeCollisionDetected:
            return .codeGeneration
        case .localCreationFailed, .databaseUnavailable, .dataCorruption, .constraintViolation:
            return .localDatabase
        case .cloudKitSyncFailed, .cloudKitUnavailable, .quotaExceeded, .accountNotAvailable:
            return .cloudKit
        case .networkUnavailable, .connectionTimeout, .serverError:
            return .network
        case .maxRetriesExceeded, .operationCancelled, .operationSucceeded, .unknownError:
            return .system
        case .userNotAuthenticated, .insufficientPermissions:
            return .authentication
        }
    }
    
    /// Priority level for error handling and user notification
    var priority: ErrorPriority {
        switch self {
        // High priority - blocks user progress
        case .userNotAuthenticated, .dataCorruption, .maxRetriesExceeded:
            return .high
            
        // Medium priority - affects functionality but has workarounds
        case .validationFailed, .invalidFamilyName, .invalidUserData,
             .maxCodeGenerationAttemptsExceeded, .constraintViolation,
             .quotaExceeded, .accountNotAvailable:
            return .medium
            
        // Low priority - temporary issues or fallback available
        case .codeCollisionDetected, .networkUnavailable, .connectionTimeout,
             .cloudKitUnavailable, .cloudKitSyncFailed, .databaseUnavailable,
             .serverError, .operationCancelled, .operationSucceeded:
            return .low
            
        // Conditional priority based on nested error
        case .codeGenerationFailed(let codeError):
            return codeError.priority
        case .localCreationFailed:
            return .medium
        case .unknownError, .insufficientPermissions:
            return .medium
        }
    }
    
    // MARK: - Equatable Implementation
    
    static func == (lhs: FamilyCreationError, rhs: FamilyCreationError) -> Bool {
        switch (lhs, rhs) {
        case (.validationFailed(let lhsMsg), .validationFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.invalidFamilyName(let lhsMsg), .invalidFamilyName(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.invalidUserData(let lhsMsg), .invalidUserData(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.codeGenerationFailed, .codeGenerationFailed):
            return true
        case (.maxCodeGenerationAttemptsExceeded, .maxCodeGenerationAttemptsExceeded):
            return true
        case (.codeCollisionDetected, .codeCollisionDetected):
            return true
        case (.localCreationFailed, .localCreationFailed):
            return true
        case (.databaseUnavailable, .databaseUnavailable):
            return true
        case (.dataCorruption(let lhsMsg), .dataCorruption(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.constraintViolation(let lhsMsg), .constraintViolation(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.cloudKitSyncFailed, .cloudKitSyncFailed):
            return true
        case (.cloudKitUnavailable, .cloudKitUnavailable):
            return true
        case (.quotaExceeded, .quotaExceeded):
            return true
        case (.accountNotAvailable, .accountNotAvailable):
            return true
        case (.networkUnavailable, .networkUnavailable):
            return true
        case (.connectionTimeout, .connectionTimeout):
            return true
        case (.serverError(let lhsCode), .serverError(let rhsCode)):
            return lhsCode == rhsCode
        case (.maxRetriesExceeded, .maxRetriesExceeded):
            return true
        case (.operationCancelled, .operationCancelled):
            return true
        case (.operationSucceeded, .operationSucceeded):
            return true
        case (.userNotAuthenticated, .userNotAuthenticated):
            return true
        case (.insufficientPermissions, .insufficientPermissions):
            return true
        default:
            return false
        }
    }
}

/// Specific errors for code generation
enum FamilyCodeGenerationError: LocalizedError {
    case uniquenessCheckFailed
    case localCheckFailed(DataServiceError)
    case remoteCheckFailed(CloudKitError)
    case formatValidationFailed(String)
    case maxAttemptsExceeded
    case generationAlgorithmFailed
    
    var errorDescription: String? {
        return userFriendlyMessage
    }
    
    var userFriendlyMessage: String {
        switch self {
        case .uniquenessCheckFailed:
            return "Unable to verify code uniqueness"
        case .localCheckFailed:
            return "Unable to check local codes"
        case .remoteCheckFailed:
            return "Unable to check remote codes"
        case .formatValidationFailed(let message):
            return "Code format issue: \(message)"
        case .maxAttemptsExceeded:
            return "Unable to generate unique code"
        case .generationAlgorithmFailed:
            return "Code generation system error"
        }
    }
    
    var technicalDescription: String {
        switch self {
        case .uniquenessCheckFailed:
            return "Uniqueness check failed"
        case .localCheckFailed(let error):
            return "Local check failed: \(error.localizedDescription ?? "Unknown error")"
        case .remoteCheckFailed(let error):
            return "Remote check failed: \(error.localizedDescription ?? "Unknown error")"
        case .formatValidationFailed(let message):
            return "Format validation failed: \(message)"
        case .maxAttemptsExceeded:
            return "Maximum generation attempts exceeded"
        case .generationAlgorithmFailed:
            return "Generation algorithm failed"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .uniquenessCheckFailed, .localCheckFailed, .remoteCheckFailed:
            return true
        case .formatValidationFailed, .maxAttemptsExceeded, .generationAlgorithmFailed:
            return false
        }
    }
    
    var recoveryStrategy: ErrorRecoveryStrategy {
        switch self {
        case .uniquenessCheckFailed, .localCheckFailed, .remoteCheckFailed:
            return .automaticRetry(delay: 1.0, maxAttempts: 3)
        case .formatValidationFailed, .generationAlgorithmFailed:
            return .noRecovery
        case .maxAttemptsExceeded:
            return .userIntervention
        }
    }
    
    var priority: ErrorPriority {
        switch self {
        case .maxAttemptsExceeded, .generationAlgorithmFailed:
            return .high
        case .formatValidationFailed:
            return .medium
        case .uniquenessCheckFailed, .localCheckFailed, .remoteCheckFailed:
            return .low
        }
    }
}

/// Recovery strategies for different types of errors
enum ErrorRecoveryStrategy: Equatable {
    case automaticRetry(delay: TimeInterval, maxAttempts: Int)
    case fallbackToLocal
    case userIntervention
    case noRecovery
    
    static func == (lhs: ErrorRecoveryStrategy, rhs: ErrorRecoveryStrategy) -> Bool {
        switch (lhs, rhs) {
        case (.automaticRetry(let lhsDelay, let lhsAttempts), .automaticRetry(let rhsDelay, let rhsAttempts)):
            return lhsDelay == rhsDelay && lhsAttempts == rhsAttempts
        case (.fallbackToLocal, .fallbackToLocal):
            return true
        case (.userIntervention, .userIntervention):
            return true
        case (.noRecovery, .noRecovery):
            return true
        default:
            return false
        }
    }
}

/// Categories for error classification
enum ErrorCategory: String, CaseIterable {
    case validation = "validation"
    case codeGeneration = "code_generation"
    case localDatabase = "local_database"
    case cloudKit = "cloud_kit"
    case network = "network"
    case system = "system"
    case authentication = "authentication"
}

/// Priority levels for error handling
enum ErrorPriority: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
}

// MARK: - Extensions for existing error types

// Extensions removed to avoid compilation issues with existing error types