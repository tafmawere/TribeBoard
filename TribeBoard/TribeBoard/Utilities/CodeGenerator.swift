import Foundation
import CloudKit

/// Utility for generating unique family codes with collision detection
class CodeGenerator {
    
    // MARK: - Properties
    
    private let codeLength: Int
    private let allowedCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    private let maxRetries = 10
    
    // MARK: - Initialization
    
    init(codeLength: Int = 6) {
        self.codeLength = max(6, min(8, codeLength)) // Ensure code length is between 6-8
    }
    
    // MARK: - Public Methods
    
    /// Generates a unique family code with collision detection
    /// - Parameter checkUniqueness: Closure to check if code already exists
    /// - Returns: Unique family code
    /// - Throws: CodeGenerationError if unable to generate unique code
    func generateUniqueCode(checkUniqueness: @escaping (String) async throws -> Bool) async throws -> String {
        for attempt in 1...maxRetries {
            let code = generateRandomCode()
            
            do {
                let isUnique = try await checkUniqueness(code)
                if isUnique {
                    return code
                }
            } catch {
                // If check fails, continue to next attempt
                if attempt == maxRetries {
                    throw CodeGenerationError.uniquenessCheckFailed(error)
                }
            }
        }
        
        throw CodeGenerationError.maxRetriesExceeded
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
        guard code.count >= 6 && code.count <= 8 else { return false }
        
        let allowedSet = CharacterSet(charactersIn: allowedCharacters)
        let codeSet = CharacterSet(charactersIn: code.uppercased())
        
        return allowedSet.isSuperset(of: codeSet)
    }
}

// MARK: - Error Types

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