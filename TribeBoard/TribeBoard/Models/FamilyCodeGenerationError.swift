import Foundation

/// Comprehensive error types for family code generation with detailed error information
enum FamilyCodeGenerationError: LocalizedError, Equatable {
    case formatValidationFailed(String)
    case uniquenessCheckFailed
    case localCheckFailed(String)
    case remoteCheckFailed(String)
    case generationAlgorithmFailed
    case maxAttemptsExceeded
    case networkUnavailable
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .formatValidationFailed(let reason):
            return "Code format validation failed: \(reason)"
        case .uniquenessCheckFailed:
            return "Unable to verify code uniqueness"
        case .localCheckFailed(let error):
            return "Local storage check failed: \(error)"
        case .remoteCheckFailed(let error):
            return "Remote storage check failed: \(error)"
        case .generationAlgorithmFailed:
            return "Code generation algorithm encountered an error"
        case .maxAttemptsExceeded:
            return "Maximum generation attempts exceeded"
        case .networkUnavailable:
            return "Network connection unavailable for code verification"
        case .invalidConfiguration:
            return "Invalid code generation configuration"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .formatValidationFailed(let reason):
            return reason
        case .uniquenessCheckFailed:
            return "Could not determine if the generated code is unique"
        case .localCheckFailed:
            return "Local database query failed"
        case .remoteCheckFailed:
            return "CloudKit query failed"
        case .generationAlgorithmFailed:
            return "Random code generation failed"
        case .maxAttemptsExceeded:
            return "Too many collisions encountered during generation"
        case .networkUnavailable:
            return "No internet connection available"
        case .invalidConfiguration:
            return "Code generation parameters are invalid"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .formatValidationFailed:
            return "Check code format requirements and try again"
        case .uniquenessCheckFailed:
            return "Try generating a new code"
        case .localCheckFailed:
            return "Check local database connection and try again"
        case .remoteCheckFailed:
            return "Check internet connection and try again"
        case .generationAlgorithmFailed:
            return "Restart the app and try again"
        case .maxAttemptsExceeded:
            return "Wait a moment and try generating a new code"
        case .networkUnavailable:
            return "Connect to the internet and try again"
        case .invalidConfiguration:
            return "Contact support for assistance"
        }
    }
    
    /// Technical description for debugging purposes
    var technicalDescription: String {
        switch self {
        case .formatValidationFailed(let reason):
            return "FORMAT_VALIDATION_FAILED: \(reason)"
        case .uniquenessCheckFailed:
            return "UNIQUENESS_CHECK_FAILED: Unable to verify code uniqueness"
        case .localCheckFailed(let error):
            return "LOCAL_CHECK_FAILED: \(error)"
        case .remoteCheckFailed(let error):
            return "REMOTE_CHECK_FAILED: \(error)"
        case .generationAlgorithmFailed:
            return "GENERATION_ALGORITHM_FAILED: Random generation error"
        case .maxAttemptsExceeded:
            return "MAX_ATTEMPTS_EXCEEDED: Too many generation attempts"
        case .networkUnavailable:
            return "NETWORK_UNAVAILABLE: No internet connection"
        case .invalidConfiguration:
            return "INVALID_CONFIGURATION: Invalid generation parameters"
        }
    }
    
    /// Indicates whether this error type is retryable
    var isRetryable: Bool {
        switch self {
        case .formatValidationFailed, .invalidConfiguration:
            return false
        case .uniquenessCheckFailed, .localCheckFailed, .remoteCheckFailed, 
             .generationAlgorithmFailed, .maxAttemptsExceeded, .networkUnavailable:
            return true
        }
    }
    
    
    static func == (lhs: FamilyCodeGenerationError, rhs: FamilyCodeGenerationError) -> Bool {
        switch (lhs, rhs) {
        case (.formatValidationFailed(let lhsReason), .formatValidationFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.uniquenessCheckFailed, .uniquenessCheckFailed),
             (.generationAlgorithmFailed, .generationAlgorithmFailed),
             (.maxAttemptsExceeded, .maxAttemptsExceeded),
             (.networkUnavailable, .networkUnavailable),
             (.invalidConfiguration, .invalidConfiguration):
            return true
        case (.localCheckFailed(let lhsError), .localCheckFailed(let rhsError)):
            return lhsError == rhsError
        case (.remoteCheckFailed(let lhsError), .remoteCheckFailed(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}