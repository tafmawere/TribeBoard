import Foundation

/// Utility class for generating and validating family codes
class FamilyCodeGenerator {
    
    /// Generate a unique 6-character alphanumeric family code
    /// - Returns: A string in format "ABC123"
    static func generateCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
    
    /// Validate if a family code has the correct format
    /// - Parameter code: The code to validate
    /// - Returns: True if the code is 6 characters with letters and numbers only
    static func isValidCodeFormat(_ code: String) -> Bool {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCode.count == 6 && trimmedCode.allSatisfy { $0.isLetter || $0.isNumber }
    }
}