import Foundation

/// Family creation specific CloudKit sync errors
enum FamilyCloudKitError: Equatable {
    case recordNotFound
    case conflictResolution
    case containerNotFound
    case retryLimitExceeded
    case invalidRecord
    case syncFailed(Error)
    
    static func == (lhs: FamilyCloudKitError, rhs: FamilyCloudKitError) -> Bool {
        switch (lhs, rhs) {
        case (.recordNotFound, .recordNotFound),
             (.conflictResolution, .conflictResolution),
             (.containerNotFound, .containerNotFound),
             (.retryLimitExceeded, .retryLimitExceeded),
             (.invalidRecord, .invalidRecord):
            return true
        case (.syncFailed(let lhsError), .syncFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// Error recovery strategies
enum ErrorRecoveryStrategy {
    case automaticRetry(delay: TimeInterval, maxAttempts: Int)
    case fallbackToLocal
    case userIntervention
    case noRecovery
}

enum FamilyCreationError: LocalizedError, Equatable {
    case invalidFamilyName
    case emptyFamilyName
    case codeGenerationFailed
    case userNotFound
    case familyAlreadyExists
    case operationCancelled
    case unknownError(String?)
    
    // Network-related errors
    case networkUnavailable
    case connectionTimeout
    case serverError(Int)
    
    // CloudKit-related errors
    case cloudKitUnavailable
    case cloudKitSyncFailed(FamilyCloudKitError)
    case quotaExceeded
    case userNotAuthenticated
    case insufficientPermissions
    case accountNotAvailable
    
    // Validation and data errors
    case validationFailed(String)
    case constraintViolation(String)
    case dataCorruption(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFamilyName:
            return "Family name contains invalid characters"
        case .emptyFamilyName:
            return "Family name cannot be empty"
        case .codeGenerationFailed:
            return "Failed to generate family code"
        case .userNotFound:
            return "User not found"
        case .familyAlreadyExists:
            return "A family with this name already exists"
        case .operationCancelled:
            return "Operation was cancelled"
        case .unknownError:
            return "An unexpected error occurred"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .connectionTimeout:
            return "Connection timed out"
        case .serverError(let code):
            return "Server error (code: \(code))"
        case .cloudKitUnavailable:
            return "CloudKit service unavailable"
        case .cloudKitSyncFailed(let syncError):
            return "CloudKit sync failed: \(syncError)"
        case .quotaExceeded:
            return "iCloud storage quota exceeded"
        case .userNotAuthenticated:
            return "User not authenticated with iCloud"
        case .insufficientPermissions:
            return "Insufficient permissions"
        case .accountNotAvailable:
            return "iCloud account not available"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .constraintViolation(let message):
            return "Constraint violation: \(message)"
        case .dataCorruption(let message):
            return "Data corruption: \(message)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .invalidFamilyName:
            return "The family name contains special characters or is too long"
        case .emptyFamilyName:
            return "A family name is required to create a family"
        case .codeGenerationFailed:
            return "The system was unable to generate a unique family code"
        case .userNotFound:
            return "The current user could not be identified"
        case .familyAlreadyExists:
            return "Another family with the same name already exists"
        case .operationCancelled:
            return "The user cancelled the operation"
        case .unknownError:
            return "An internal error occurred while creating the family"
        case .networkUnavailable:
            return "No internet connection is available"
        case .connectionTimeout:
            return "The request took too long to complete"
        case .serverError:
            return "The server encountered an error"
        case .cloudKitUnavailable:
            return "CloudKit service is temporarily unavailable"
        case .cloudKitSyncFailed:
            return "Failed to sync data with iCloud"
        case .quotaExceeded:
            return "Your iCloud storage is full"
        case .userNotAuthenticated:
            return "You are not signed in to iCloud"
        case .insufficientPermissions:
            return "You don't have permission to perform this action"
        case .accountNotAvailable:
            return "iCloud account is not available on this device"
        case .validationFailed:
            return "The provided data is invalid"
        case .constraintViolation:
            return "The data violates system constraints"
        case .dataCorruption:
            return "The data is corrupted or incompatible"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidFamilyName:
            return "Please use only letters, numbers, and spaces in the family name"
        case .emptyFamilyName:
            return "Please enter a family name"
        case .codeGenerationFailed:
            return "Please try again in a moment"
        case .userNotFound:
            return "Please restart the app and try again"
        case .familyAlreadyExists:
            return "Please choose a different family name"
        case .operationCancelled:
            return "You can try again when ready"
        case .unknownError:
            return "Please try again or restart the app"
        case .networkUnavailable:
            return "Please check your internet connection and try again"
        case .connectionTimeout:
            return "Please check your connection and try again"
        case .serverError:
            return "Please try again later"
        case .cloudKitUnavailable:
            return "Please try again in a few minutes"
        case .cloudKitSyncFailed:
            return "Please check your iCloud connection and try again"
        case .quotaExceeded:
            return "Please free up iCloud storage or upgrade your plan"
        case .userNotAuthenticated:
            return "Please sign in to iCloud in Settings"
        case .insufficientPermissions:
            return "Please check your iCloud settings and permissions"
        case .accountNotAvailable:
            return "Please sign in to iCloud in Settings"
        case .validationFailed:
            return "Please check your input and try again"
        case .constraintViolation:
            return "Please modify your input to meet the requirements"
        case .dataCorruption:
            return "Please restart the app or contact support"
        }
    }
    
    var category: ErrorCategory {
        switch self {
        case .invalidFamilyName, .emptyFamilyName, .validationFailed:
            return .validation
        case .codeGenerationFailed, .unknownError, .userNotFound, .dataCorruption:
            return .system
        case .familyAlreadyExists, .constraintViolation:
            return .data
        case .operationCancelled:
            return .user
        case .networkUnavailable, .connectionTimeout, .serverError:
            return .network
        case .cloudKitUnavailable, .cloudKitSyncFailed, .quotaExceeded:
            return .cloudKit
        case .userNotAuthenticated, .insufficientPermissions, .accountNotAvailable:
            return .authentication
        }
    }
    
    var priority: ErrorPriority {
        switch self {
        case .invalidFamilyName, .emptyFamilyName, .validationFailed:
            return .medium
        case .codeGenerationFailed, .networkUnavailable, .connectionTimeout:
            return .high
        case .familyAlreadyExists, .constraintViolation:
            return .medium
        case .operationCancelled:
            return .low
        case .unknownError, .userNotFound, .dataCorruption:
            return .critical
        case .serverError, .cloudKitUnavailable, .cloudKitSyncFailed:
            return .high
        case .quotaExceeded, .userNotAuthenticated, .insufficientPermissions, .accountNotAvailable:
            return .medium
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .invalidFamilyName, .emptyFamilyName, .operationCancelled, .validationFailed, .constraintViolation:
            return false
        case .codeGenerationFailed, .familyAlreadyExists, .unknownError, .userNotFound:
            return true
        case .networkUnavailable, .connectionTimeout, .serverError:
            return true
        case .cloudKitUnavailable, .cloudKitSyncFailed:
            return true
        case .quotaExceeded, .userNotAuthenticated, .insufficientPermissions, .accountNotAvailable:
            return false
        case .dataCorruption:
            return false
        }
    }
    
    var recoveryStrategy: ErrorRecoveryStrategy {
        switch self {
        case .networkUnavailable, .connectionTimeout, .cloudKitUnavailable:
            return .automaticRetry(delay: 2.0, maxAttempts: 3)
        case .codeGenerationFailed, .serverError, .cloudKitSyncFailed:
            return .automaticRetry(delay: 1.0, maxAttempts: 2)
        case .quotaExceeded, .userNotAuthenticated, .insufficientPermissions, .accountNotAvailable:
            return .userIntervention
        case .invalidFamilyName, .emptyFamilyName, .validationFailed, .constraintViolation:
            return .userIntervention
        case .operationCancelled:
            return .noRecovery
        case .dataCorruption, .unknownError:
            return .fallbackToLocal
        case .familyAlreadyExists, .userNotFound:
            return .userIntervention
        }
    }
    
    var userFriendlyMessage: String {
        switch self {
        case .invalidFamilyName:
            return "Please use only letters, numbers, and spaces in the family name."
        case .emptyFamilyName:
            return "Please enter a family name to continue."
        case .codeGenerationFailed:
            return "We're having trouble creating your family code. Please try again."
        case .userNotFound:
            return "We couldn't find your user account. Please restart the app."
        case .familyAlreadyExists:
            return "A family with this name already exists. Please choose a different name."
        case .operationCancelled:
            return "The operation was cancelled."
        case .unknownError:
            return "Something went wrong. Please try again."
        case .networkUnavailable:
            return "No internet connection. Please check your connection and try again."
        case .connectionTimeout:
            return "The request timed out. Please try again."
        case .serverError:
            return "Our servers are having issues. Please try again later."
        case .cloudKitUnavailable:
            return "iCloud is temporarily unavailable. Please try again in a few minutes."
        case .cloudKitSyncFailed:
            return "Failed to sync with iCloud. Please check your connection."
        case .quotaExceeded:
            return "Your iCloud storage is full. Please free up space or upgrade your plan."
        case .userNotAuthenticated:
            return "Please sign in to iCloud in Settings to continue."
        case .insufficientPermissions:
            return "You don't have permission to perform this action."
        case .accountNotAvailable:
            return "iCloud account is not available. Please sign in to iCloud in Settings."
        case .validationFailed(let message):
            return message
        case .constraintViolation(let message):
            return message
        case .dataCorruption(let message):
            return "Data error: \(message). Please restart the app."
        }
    }
    
    var technicalDescription: String {
        switch self {
        case .invalidFamilyName:
            return "FamilyCreationError.invalidFamilyName: Family name validation failed"
        case .emptyFamilyName:
            return "FamilyCreationError.emptyFamilyName: Empty family name provided"
        case .codeGenerationFailed:
            return "FamilyCreationError.codeGenerationFailed: Family code generation failed"
        case .userNotFound:
            return "FamilyCreationError.userNotFound: Current user not found in system"
        case .familyAlreadyExists:
            return "FamilyCreationError.familyAlreadyExists: Family name already exists"
        case .operationCancelled:
            return "FamilyCreationError.operationCancelled: User cancelled operation"
        case .unknownError(let message):
            return "FamilyCreationError.unknownError: \(message ?? "Unknown error")"
        case .networkUnavailable:
            return "FamilyCreationError.networkUnavailable: Network connection unavailable"
        case .connectionTimeout:
            return "FamilyCreationError.connectionTimeout: Request timed out"
        case .serverError(let code):
            return "FamilyCreationError.serverError: Server error with code \(code)"
        case .cloudKitUnavailable:
            return "FamilyCreationError.cloudKitUnavailable: CloudKit service unavailable"
        case .cloudKitSyncFailed(let syncError):
            return "FamilyCreationError.cloudKitSyncFailed: \(syncError)"
        case .quotaExceeded:
            return "FamilyCreationError.quotaExceeded: iCloud storage quota exceeded"
        case .userNotAuthenticated:
            return "FamilyCreationError.userNotAuthenticated: User not authenticated with iCloud"
        case .insufficientPermissions:
            return "FamilyCreationError.insufficientPermissions: Insufficient permissions"
        case .accountNotAvailable:
            return "FamilyCreationError.accountNotAvailable: iCloud account not available"
        case .validationFailed(let message):
            return "FamilyCreationError.validationFailed: \(message)"
        case .constraintViolation(let message):
            return "FamilyCreationError.constraintViolation: \(message)"
        case .dataCorruption(let message):
            return "FamilyCreationError.dataCorruption: \(message)"
        }
    }
}

enum FamilyJoinError: LocalizedError, Equatable {
    case invalidCode
    case emptyCode
    case familyNotFound
    case alreadyMember
    case userNotFound
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "Invalid family code format"
        case .emptyCode:
            return "Family code cannot be empty"
        case .familyNotFound:
            return "Family not found"
        case .alreadyMember:
            return "You are already a member of this family"
        case .userNotFound:
            return "User not found"
        case .unknownError:
            return "An unexpected error occurred"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .invalidCode:
            return "The family code must be 6 characters long and contain only letters and numbers"
        case .emptyCode:
            return "A family code is required to join a family"
        case .familyNotFound:
            return "No family exists with the provided code"
        case .alreadyMember:
            return "You have already joined this family"
        case .userNotFound:
            return "The current user could not be identified"
        case .unknownError:
            return "An internal error occurred while joining the family"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidCode:
            return "Please enter a 6-character code with letters and numbers only"
        case .emptyCode:
            return "Please enter the family code"
        case .familyNotFound:
            return "Please check the code and try again"
        case .alreadyMember:
            return "You can view your family from the dashboard"
        case .userNotFound:
            return "Please restart the app and try again"
        case .unknownError:
            return "Please try again or restart the app"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .invalidCode, .emptyCode, .alreadyMember:
            return false
        case .familyNotFound, .userNotFound, .unknownError:
            return true
        }
    }
}