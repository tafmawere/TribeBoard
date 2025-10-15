import Foundation
import os.log

/// Comprehensive input validation and format checking utility for TribeBoard
///
/// This utility provides centralized validation logic for all user inputs throughout
/// the application. It ensures data integrity, security, and consistent user experience
/// by applying standardized validation rules.
///
/// ## Features
/// - Family name and code validation
/// - Display name validation with accessibility considerations
/// - URL format validation
/// - Input sanitization and formatting
/// - Comprehensive error messaging
/// - Security-focused character filtering
/// - Internationalization support
///
/// ## Usage
/// ```swift
/// let result = Validation.validateFamilyName("My Family")
/// if result.isValid {
///     // Proceed with valid input
/// } else {
///     // Show error: result.message
/// }
/// ```
///
/// ## Validation Philosophy
/// - Be permissive where safe, restrictive where necessary
/// - Provide clear, actionable error messages
/// - Support international characters where appropriate
/// - Maintain consistent validation rules across the app
/// - Fail securely by default
struct Validation {
    
    /// Logger for validation events and errors
    private static let logger = Logger(subsystem: "com.tribeboard.app", category: "Validation")
    
    // MARK: - Family Name Validation
    
    /// Validates family name input with comprehensive error handling
    ///
    /// Validates family names according to TribeBoard's naming conventions:
    /// - Must be 2-50 characters long
    /// - Allows letters, numbers, spaces, and basic punctuation
    /// - Trims whitespace automatically
    /// - Supports international characters
    ///
    /// - Parameter name: Family name to validate
    /// - Returns: ValidationResult with success/failure and user-friendly message
    ///
    /// ## Example
    /// ```swift
    /// let result = Validation.validateFamilyName("The Smith Family")
    /// if result.isValid {
    ///     // Name is valid
    /// } else {
    ///     // Show error: result.message
    /// }
    /// ```
    static func validateFamilyName(_ name: String) -> ValidationResult {
        logger.debug("Validating family name: \(name.prefix(10))...")
        
        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check for empty input
            guard !trimmedName.isEmpty else {
                logger.info("Family name validation failed: empty input")
                return ValidationResult(
                    isValid: false, 
                    message: "Family name cannot be empty"
                )
            }
            
            // Check minimum length
            guard trimmedName.count >= 2 else {
                logger.info("Family name validation failed: too short (\(trimmedName.count) characters)")
                return ValidationResult(
                    isValid: false, 
                    message: "Family name must be at least 2 characters"
                )
            }
            
            // Check maximum length
            guard trimmedName.count <= 50 else {
                logger.info("Family name validation failed: too long (\(trimmedName.count) characters)")
                return ValidationResult(
                    isValid: false, 
                    message: "Family name cannot exceed 50 characters"
                )
            }
            
            // Check for valid characters (letters, numbers, spaces, basic punctuation)
            let allowedCharacterSet = CharacterSet.alphanumerics
                .union(.whitespaces)
                .union(CharacterSet(charactersIn: "'-.,"))
            
            guard trimmedName.unicodeScalars.allSatisfy({ allowedCharacterSet.contains($0) }) else {
                logger.info("Family name validation failed: invalid characters")
                return ValidationResult(
                    isValid: false, 
                    message: "Family name can only contain letters, numbers, spaces, and basic punctuation"
                )
            }
            
            logger.debug("Family name validation successful")
            return ValidationResult(isValid: true, message: "Valid family name")
            
        } catch {
            logger.error("Family name validation error: \(error.localizedDescription)")
            return ValidationResult(
                isValid: false, 
                message: "Unable to validate family name. Please try again."
            )
        }
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

/// Result of a validation operation with comprehensive error information
///
/// This struct encapsulates the result of any validation operation, providing
/// both the validation status and user-friendly messaging for display.
///
/// ## Usage
/// ```swift
/// let result = Validation.validateFamilyName(input)
/// if result.isValid {
///     // Proceed with valid input
/// } else {
///     // Display result.message to user
/// }
/// ```
// Note: ValidationResult is now defined in CalendarService.swift

/// Error codes for programmatic validation error handling
enum ValidationErrorCode: String, CaseIterable {
    case empty = "EMPTY_INPUT"
    case tooShort = "TOO_SHORT"
    case tooLong = "TOO_LONG"
    case invalidCharacters = "INVALID_CHARACTERS"
    case invalidFormat = "INVALID_FORMAT"
    case systemError = "SYSTEM_ERROR"
    
    /// User-friendly description of the error
    var description: String {
        switch self {
        case .empty:
            return "Input cannot be empty"
        case .tooShort:
            return "Input is too short"
        case .tooLong:
            return "Input is too long"
        case .invalidCharacters:
            return "Input contains invalid characters"
        case .invalidFormat:
            return "Input format is invalid"
        case .systemError:
            return "System error occurred during validation"
        }
    }
}