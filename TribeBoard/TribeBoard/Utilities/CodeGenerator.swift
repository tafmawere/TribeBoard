import Foundation
import CloudKit

/// Configuration for code generation retry strategies
struct CodeGenerationConfig {
    let maxRetries: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let backoffMultiplier: Double
    let enableLocalFallback: Bool
    let enableRemoteFallback: Bool
    
    static let `default` = CodeGenerationConfig(
        maxRetries: 10,
        baseDelay: 0.1,
        maxDelay: 5.0,
        backoffMultiplier: 2.0,
        enableLocalFallback: true,
        enableRemoteFallback: true
    )
}

/// Enhanced utility for generating unique family codes with robust error handling and fallback mechanisms
class CodeGenerator {
    
    // MARK: - Properties
    
    private let codeLength: Int
    private let allowedCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    private let config: CodeGenerationConfig
    
    // MARK: - Initialization
    
    init(codeLength: Int = 6, config: CodeGenerationConfig = .default) {
        self.codeLength = max(6, min(8, codeLength)) // Ensure code length is between 6-8
        self.config = config
    }
    
    // MARK: - Public Methods
    
    /// Generates a unique family code with enhanced safety and fallback mechanisms
    /// - Parameters:
    ///   - checkLocal: Closure to check local storage for code uniqueness
    ///   - checkRemote: Closure to check remote storage (CloudKit) for code uniqueness
    /// - Returns: Unique family code
    /// - Throws: FamilyCodeGenerationError if unable to generate unique code
    func generateUniqueCodeSafely(
        checkLocal: @escaping (String) async throws -> Bool,
        checkRemote: @escaping (String) async throws -> Bool
    ) async throws -> String {
        print("🔧 CodeGenerator: Starting safe unique code generation")
        
        var lastError: Error?
        
        for attempt in 1...config.maxRetries {
            print("🔄 CodeGenerator: Generation attempt \(attempt)/\(config.maxRetries)")
            
            do {
                // Generate a random code
                let code = generateRandomCode()
                print("🎲 CodeGenerator: Generated candidate code: \(code)")
                
                // Validate format first
                guard validateCodeFormat(code) else {
                    throw FamilyCodeGenerationError.formatValidationFailed("Generated code has invalid format")
                }
                
                // Check uniqueness with separate local and remote checking
                let isUnique = try await checkUniquenessWithFallback(
                    code: code,
                    checkLocal: checkLocal,
                    checkRemote: checkRemote
                )
                
                if isUnique {
                    print("✅ CodeGenerator: Successfully generated unique code after \(attempt) attempts")
                    return code
                } else {
                    print("⚠️ CodeGenerator: Code collision detected, retrying...")
                    lastError = FamilyCodeGenerationError.uniquenessCheckFailed
                }
                
            } catch let error as FamilyCodeGenerationError {
                print("❌ CodeGenerator: Generation error on attempt \(attempt): \(error.technicalDescription)")
                lastError = error
                
                // Check if error is retryable
                if !error.isRetryable {
                    throw error
                }
                
                // Apply exponential backoff for retryable errors
                if attempt < config.maxRetries {
                    let delay = calculateBackoffDelay(attempt: attempt)
                    print("⏳ CodeGenerator: Waiting \(delay)s before retry...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                
            } catch {
                print("❌ CodeGenerator: Unexpected error on attempt \(attempt): \(error.localizedDescription)")
                lastError = error
                
                // Apply exponential backoff for unexpected errors
                if attempt < config.maxRetries {
                    let delay = calculateBackoffDelay(attempt: attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // All attempts failed
        print("❌ CodeGenerator: Failed to generate unique code after \(config.maxRetries) attempts")
        
        if let lastError = lastError as? FamilyCodeGenerationError {
            throw lastError
        } else if lastError != nil {
            throw FamilyCodeGenerationError.generationAlgorithmFailed
        } else {
            throw FamilyCodeGenerationError.maxAttemptsExceeded
        }
    }
    
    /// Legacy method for backward compatibility
    /// - Parameter checkUniqueness: Closure to check if code already exists
    /// - Returns: Unique family code
    /// - Throws: CodeGenerationError if unable to generate unique code
    func generateUniqueCode(checkUniqueness: @escaping (String) async throws -> Bool) async throws -> String {
        // Convert to new format by using the same check for both local and remote
        return try await generateUniqueCodeSafely(
            checkLocal: checkUniqueness,
            checkRemote: checkUniqueness
        )
    }
    
    /// Generates a random code without uniqueness check
    /// - Returns: Random alphanumeric code
    func generateRandomCode() -> String {
        return String((0..<codeLength).compactMap { _ in
            allowedCharacters.randomElement()
        })
    }
    
    /// Validates if a code matches the expected format
    /// - Parameter code: Code to validate
    /// - Returns: True if code is valid format
    func isValidCodeFormat(_ code: String) -> Bool {
        return validateCodeFormat(code)
    }
    
    /// Enhanced code format validation with detailed error reporting
    /// - Parameter code: Code to validate
    /// - Returns: True if code is valid format
    /// - Throws: FamilyCodeGenerationError if format is invalid
    func validateCodeFormat(_ code: String) -> Bool {
        guard !code.isEmpty else {
            print("❌ CodeGenerator: Code validation failed - empty code")
            return false
        }
        
        guard code.count >= 6 && code.count <= 8 else {
            print("❌ CodeGenerator: Code validation failed - invalid length: \(code.count)")
            return false
        }
        
        let allowedSet = CharacterSet(charactersIn: allowedCharacters)
        let codeSet = CharacterSet(charactersIn: code.uppercased())
        
        guard allowedSet.isSuperset(of: codeSet) else {
            print("❌ CodeGenerator: Code validation failed - invalid characters in: \(code)")
            return false
        }
        
        return true
    }
    
    // MARK: - Private Methods
    
    /// Checks code uniqueness with fallback mechanisms
    private func checkUniquenessWithFallback(
        code: String,
        checkLocal: @escaping (String) async throws -> Bool,
        checkRemote: @escaping (String) async throws -> Bool
    ) async throws -> Bool {
        var localCheckPassed = false
        var remoteCheckPassed = false
        var localError: Error?
        var remoteError: Error?
        
        // Check local storage first (faster and more reliable)
        do {
            let isLocallyUnique = try await checkLocal(code)
            localCheckPassed = true
            
            if !isLocallyUnique {
                print("⚠️ CodeGenerator: Code exists in local storage")
                return false
            }
            
            print("✅ CodeGenerator: Code is unique in local storage")
            
        } catch {
            localError = error
            print("❌ CodeGenerator: Local uniqueness check failed: \(error.localizedDescription)")
            
            if !config.enableLocalFallback {
                throw FamilyCodeGenerationError.localCheckFailed(DataServiceError.invalidData(error.localizedDescription))
            }
        }
        
        // Check remote storage (CloudKit) if enabled
        do {
            let isRemotelyUnique = try await checkRemote(code)
            remoteCheckPassed = true
            
            if !isRemotelyUnique {
                print("⚠️ CodeGenerator: Code exists in remote storage")
                return false
            }
            
            print("✅ CodeGenerator: Code is unique in remote storage")
            
        } catch {
            remoteError = error
            print("❌ CodeGenerator: Remote uniqueness check failed: \(error.localizedDescription)")
            
            if !config.enableRemoteFallback {
                throw FamilyCodeGenerationError.remoteCheckFailed(CloudKitError.syncFailed(error))
            }
        }
        
        // Determine if code is unique based on successful checks
        if localCheckPassed && remoteCheckPassed {
            // Both checks passed - code is unique
            return true
        } else if localCheckPassed && remoteError != nil {
            // Local check passed, remote failed - fallback to local-only
            print("⚠️ CodeGenerator: Using local-only uniqueness check due to remote failure")
            return true
        } else if remoteCheckPassed && localError != nil {
            // Remote check passed, local failed - use remote result
            print("⚠️ CodeGenerator: Using remote-only uniqueness check due to local failure")
            return true
        } else {
            // Both checks failed
            if localError != nil && remoteError != nil {
                print("❌ CodeGenerator: Both local and remote checks failed")
                throw FamilyCodeGenerationError.uniquenessCheckFailed
            } else if let localError = localError {
                throw FamilyCodeGenerationError.localCheckFailed(DataServiceError.invalidData(localError.localizedDescription))
            } else if let remoteError = remoteError {
                throw FamilyCodeGenerationError.remoteCheckFailed(CloudKitError.syncFailed(remoteError))
            } else {
                throw FamilyCodeGenerationError.uniquenessCheckFailed
            }
        }
    }
    
    /// Calculates exponential backoff delay for retry attempts
    private func calculateBackoffDelay(attempt: Int) -> TimeInterval {
        let exponentialDelay = config.baseDelay * pow(config.backoffMultiplier, Double(attempt - 1))
        let jitteredDelay = exponentialDelay * (0.5 + Double.random(in: 0...0.5)) // Add jitter
        return min(jitteredDelay, config.maxDelay)
    }
    
    /// Handles code generation errors with appropriate logging and recovery
    private func handleGenerationError(_ error: Error, attempt: Int) -> FamilyCodeGenerationError {
        print("🔧 CodeGenerator: Handling generation error on attempt \(attempt)")
        
        if let codeError = error as? FamilyCodeGenerationError {
            return codeError
        } else if let dataError = error as? DataServiceError {
            return FamilyCodeGenerationError.localCheckFailed(dataError)
        } else if let cloudKitError = error as? CloudKitError {
            return FamilyCodeGenerationError.remoteCheckFailed(cloudKitError)
        } else {
            return FamilyCodeGenerationError.generationAlgorithmFailed
        }
    }
}

// MARK: - Legacy Error Types (for backward compatibility)

enum CodeGenerationError: LocalizedError {
    case maxRetriesExceeded
    case uniquenessCheckFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .maxRetriesExceeded:
            return "Unable to generate unique code after maximum retries"
        case .uniquenessCheckFailed(let error):
            return "Failed to check code uniqueness: \(error.localizedDescription)"
        }
    }
}