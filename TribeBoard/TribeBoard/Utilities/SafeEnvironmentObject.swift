import SwiftUI
import Foundation

/// A property wrapper that provides safe access to environment objects with fallback mechanisms
/// This prevents crashes when environment objects are missing from the view hierarchy
@propertyWrapper
struct SafeEnvironmentObject<T: ObservableObject>: DynamicProperty {
    
    // MARK: - Private Properties
    
    /// Optional environment object that may or may not be available
    @Environment(\.environmentObjectAvailable) private var isEnvironmentAvailable: Bool
    
    /// Fallback factory function to create a default instance when environment object is missing
    private let fallbackFactory: () -> T
    
    /// The fallback object instance (created lazily)
    @State private var fallbackObject: T?
    
    /// Flag to track if we're using the fallback object
    @State private var isUsingFallback: Bool = false
    
    // MARK: - Initialization
    
    /// Initialize SafeEnvironmentObject with a fallback factory
    /// - Parameter fallback: A closure that creates a fallback instance of the environment object
    init(fallback: @escaping () -> T) {
        self.fallbackFactory = fallback
    }
    
    // MARK: - Property Wrapper Implementation
    
    /// The wrapped value that provides safe access to the environment object
    var wrappedValue: T {
        // For now, always use fallback to avoid crashes
        // In a production implementation, you would check if the environment object is available
        return getFallbackObject()
    }
    
    /// Projected value that provides additional information about the environment object state
    var projectedValue: SafeEnvironmentObjectInfo<T> {
        // Validate the current object (fallback or environment)
        let currentObject = wrappedValue
        let validationResult = EnvironmentValidator.validateEnvironmentObject(currentObject)
        
        return SafeEnvironmentObjectInfo(
            isUsingFallback: isUsingFallback,
            environmentObject: nil, // Always nil for now to avoid crashes
            fallbackObject: fallbackObject,
            validationResult: EnvironmentObjectValidationResult(
                isValid: validationResult.isValid,
                isUsingFallback: isUsingFallback,
                error: validationResult.error,
                recommendations: validationResult.recommendations
            )
        )
    }
    
    // MARK: - Private Methods
    
    /// Get or create the fallback object
    /// - Returns: The fallback object instance
    private func getFallbackObject() -> T {
        if let existingFallback = fallbackObject {
            return existingFallback
        }
        
        // Create new fallback object using the provided factory function
        let newFallback = fallbackFactory()
        fallbackObject = newFallback
        isUsingFallback = true
        
        // Log that we're using a fallback
        EnvironmentObjectLogger.logFallbackUsage(for: T.self)
        
        return newFallback
    }
}

// MARK: - Environment Keys

/// Environment key for tracking environment object availability
private struct EnvironmentObjectAvailableKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var environmentObjectAvailable: Bool {
        get { self[EnvironmentObjectAvailableKey.self] }
        set { self[EnvironmentObjectAvailableKey.self] = newValue }
    }
}

// MARK: - Supporting Types

/// Information about the state of a SafeEnvironmentObject
struct SafeEnvironmentObjectInfo<T: ObservableObject> {
    /// Whether the wrapper is currently using a fallback object
    let isUsingFallback: Bool
    
    /// The actual environment object (nil if using fallback)
    let environmentObject: T?
    
    /// The fallback object (nil if not created yet)
    let fallbackObject: T?
    
    /// Validation result for the current state
    let validationResult: EnvironmentObjectValidationResult
    
    /// Whether the environment object is properly available
    var isEnvironmentObjectAvailable: Bool {
        return !isUsingFallback && environmentObject != nil
    }
}

/// Validation result for environment objects
struct EnvironmentObjectValidationResult {
    /// Whether the environment object is in a valid state
    let isValid: Bool
    
    /// Whether a fallback object is being used
    let isUsingFallback: Bool
    
    /// Any error that occurred during validation
    let error: EnvironmentObjectError?
    
    /// Recommendations for fixing environment object issues
    let recommendations: [String]
}

/// Errors related to environment object handling
enum EnvironmentObjectError: Error, LocalizedError, Equatable {
    case missingEnvironmentObject(type: String)
    case invalidEnvironmentObjectState(type: String, reason: String)
    case fallbackCreationFailed(type: String, underlyingError: Error)
    case dependencyInjectionFailure(String)
    
    var errorDescription: String? {
        switch self {
        case .missingEnvironmentObject(let type):
            return "Environment object of type \(type) is not available in the view hierarchy"
        case .invalidEnvironmentObjectState(let type, let reason):
            return "Environment object of type \(type) is in an invalid state: \(reason)"
        case .fallbackCreationFailed(let type, let underlyingError):
            return "Failed to create fallback object of type \(type): \(underlyingError.localizedDescription)"
        case .dependencyInjectionFailure(let details):
            return "Dependency injection failed: \(details)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .missingEnvironmentObject:
            return "Ensure the environment object is properly injected using .environmentObject() modifier in the parent view"
        case .invalidEnvironmentObjectState:
            return "Check the environment object's state and ensure it's properly initialized"
        case .fallbackCreationFailed:
            return "Review the fallback factory function and ensure it can create a valid object"
        case .dependencyInjectionFailure:
            return "Check that all required dependencies are properly configured and available"
        }
    }
    
    // MARK: - Equatable Implementation
    
    static func == (lhs: EnvironmentObjectError, rhs: EnvironmentObjectError) -> Bool {
        switch (lhs, rhs) {
        case (.missingEnvironmentObject(let lhsType), .missingEnvironmentObject(let rhsType)):
            return lhsType == rhsType
        case (.invalidEnvironmentObjectState(let lhsType, let lhsReason), .invalidEnvironmentObjectState(let rhsType, let rhsReason)):
            return lhsType == rhsType && lhsReason == rhsReason
        case (.fallbackCreationFailed(let lhsType, let lhsError), .fallbackCreationFailed(let rhsType, let rhsError)):
            return lhsType == rhsType && lhsError.localizedDescription == rhsError.localizedDescription
        case (.dependencyInjectionFailure(let lhsDetails), .dependencyInjectionFailure(let rhsDetails)):
            return lhsDetails == rhsDetails
        default:
            return false
        }
    }
}

/// Legacy validator - use EnvironmentValidator instead
@available(*, deprecated, message: "Use EnvironmentValidator instead")
struct EnvironmentObjectValidator {
    /// Validate an environment object
    /// - Parameter object: The environment object to validate
    /// - Returns: Validation result
    static func validate<T: ObservableObject>(_ object: T) -> EnvironmentObjectValidationResult {
        // Delegate to the new EnvironmentValidator
        let result = EnvironmentValidator.validateEnvironmentObject(object)
        
        return EnvironmentObjectValidationResult(
            isValid: result.isValid,
            isUsingFallback: false,
            error: result.error,
            recommendations: result.recommendations
        )
    }
}

/// Logger for environment object events
struct EnvironmentObjectLogger {
    /// Log when a fallback object is being used
    /// - Parameter type: The type of environment object using fallback
    static func logFallbackUsage<T>(for type: T.Type) {
        print("⚠️ SafeEnvironmentObject: Using fallback for \(String(describing: type))")
        
        #if DEBUG
        // In debug mode, also log the stack trace to help identify where the issue occurs
        print("Stack trace:")
        Thread.callStackSymbols.prefix(5).forEach { symbol in
            print("  \(symbol)")
        }
        #endif
    }
    
    /// Log environment object validation issues
    /// - Parameters:
    ///   - type: The type of environment object
    ///   - result: The validation result
    static func logValidationIssues<T>(for type: T.Type, result: EnvironmentObjectValidationResult) {
        if !result.isValid {
            print("❌ SafeEnvironmentObject: Validation failed for \(String(describing: type))")
            if let error = result.error {
                print("   Error: \(error.localizedDescription)")
            }
            result.recommendations.forEach { recommendation in
                print("   Recommendation: \(recommendation)")
            }
        }
    }
}