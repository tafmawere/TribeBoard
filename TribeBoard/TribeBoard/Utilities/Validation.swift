import Foundation

/// Utility for input validation and format checking
struct Validation {
    
    // MARK: - Family Name Validation
    
    /// Validates family name input
    /// - Parameter name: Family name to validate
    /// - Returns: ValidationResult with success/failure and message
    static func validateFamilyName(_ name: String) -> ValidationResult {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            return ValidationResult(isValid: false, message: "Family name cannot be empty")
        }
        
        guard trimmedName.count >= 2 else {
            return ValidationResult(isValid: false, message: "Family name must be at least 2 characters")
        }
        
        guard trimmedName.count <= 50 else {
            return ValidationResult(isValid: false, message: "Family name cannot exceed 50 characters")
        }
        
        // Check for valid characters (letters, numbers, spaces, basic punctuation)
        let allowedCharacterSet = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "'-.,"))
        
        guard trimmedName.unicodeScalars.allSatisfy({ allowedCharacterSet.contains($0) }) else {
            return ValidationResult(isValid: false, message: "Family name contains invalid characters")
        }
        
        return ValidationResult(isValid: true, message: "Valid family name")
    }
    
    // MARK: - Family Code Validation
    
    /// Validates family code format
    /// - Parameter code: Family code to validate
    /// - Returns: ValidationResult with success/failure and message
    static func validateFamilyCode(_ code: String) -> ValidationResult {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        guard !trimmedCode.isEmpty else {
            return ValidationResult(isValid: false, message: "Family code cannot be empty")
        }
        
        guard trimmedCode.count >= 6 && trimmedCode.count <= 8 else {
            return ValidationResult(isValid: false, message: "Family code must be 6-8 characters")
        }
        
        let allowedCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let codeCharacters = CharacterSet(charactersIn: trimmedCode)
        
        guard allowedCharacters.isSuperset(of: codeCharacters) else {
            return ValidationResult(isValid: false, message: "Family code can only contain letters and numbers")
        }
        
        return ValidationResult(isValid: true, message: "Valid family code")
    }
    
    // MARK: - Display Name Validation
    
    /// Validates user display name
    /// - Parameter displayName: Display name to validate
    /// - Returns: ValidationResult with success/failure and message
    static func validateDisplayName(_ displayName: String) -> ValidationResult {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            return ValidationResult(isValid: false, message: "Display name cannot be empty")
        }
        
        guard trimmedName.count >= 1 else {
            return ValidationResult(isValid: false, message: "Display name must be at least 1 character")
        }
        
        guard trimmedName.count <= 30 else {
            return ValidationResult(isValid: false, message: "Display name cannot exceed 30 characters")
        }
        
        // Allow letters, numbers, spaces, and common name characters
        let allowedCharacterSet = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "'-.,"))
        
        guard trimmedName.unicodeScalars.allSatisfy({ allowedCharacterSet.contains($0) }) else {
            return ValidationResult(isValid: false, message: "Display name contains invalid characters")
        }
        
        return ValidationResult(isValid: true, message: "Valid display name")
    }
    
    // MARK: - URL Validation
    
    /// Validates URL format
    /// - Parameter urlString: URL string to validate
    /// - Returns: ValidationResult with success/failure and message
    static func validateURL(_ urlString: String) -> ValidationResult {
        guard !urlString.isEmpty else {
            return ValidationResult(isValid: false, message: "URL cannot be empty")
        }
        
        guard let url = URL(string: urlString), 
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()) else {
            return ValidationResult(isValid: false, message: "Invalid URL format")
        }
        
        return ValidationResult(isValid: true, message: "Valid URL")
    }
    
    // MARK: - Helper Methods
    
    /// Sanitizes input by trimming whitespace and limiting length
    /// - Parameters:
    ///   - input: Input string to sanitize
    ///   - maxLength: Maximum allowed length
    /// - Returns: Sanitized string
    static func sanitizeInput(_ input: String, maxLength: Int = 100) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(maxLength))
    }
    
    /// Formats family code to uppercase and removes invalid characters
    /// - Parameter code: Raw family code input
    /// - Returns: Formatted family code
    static func formatFamilyCode(_ code: String) -> String {
        let cleaned = code.uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".contains($0) }
        return String(cleaned.prefix(8))
    }
}

// MARK: - ValidationResult

/// Result of a validation operation
struct ValidationResult {
    let isValid: Bool
    let message: String
    
    /// Returns success result
    static var success: ValidationResult {
        return ValidationResult(isValid: true, message: "Valid")
    }
    
    /// Returns failure result with message
    /// - Parameter message: Error message
    /// - Returns: Failure ValidationResult
    static func failure(_ message: String) -> ValidationResult {
        return ValidationResult(isValid: false, message: message)
    }
}