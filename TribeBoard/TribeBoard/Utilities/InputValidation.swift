import SwiftUI
import Combine

// MARK: - Validation State

enum InputValidationState {
    case idle
    case valid
    case invalid(String)
    
    var isValid: Bool {
        switch self {
        case .valid:
            return true
        default:
            return false
        }
    }
    
    var errorMessage: String? {
        switch self {
        case .invalid(let message):
            return message
        default:
            return nil
        }
    }
}

// MARK: - Validation Functions

/// Validate family name input
func validateFamilyName(_ name: String) -> InputValidationState {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    
    if trimmed.isEmpty {
        return .idle
    }
    
    if trimmed.count < 2 {
        return .invalid("Family name must be at least 2 characters")
    }
    
    if trimmed.count > 50 {
        return .invalid("Family name cannot exceed 50 characters")
    }
    
    // Check for invalid characters
    let allowedCharacters = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-_"))
    if trimmed.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
        return .invalid("Family name can only contain letters, numbers, spaces, hyphens, and underscores")
    }
    
    return .valid
}

/// Validate family code input
func validateFamilyCode(_ code: String) -> InputValidationState {
    let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
    
    if trimmed.isEmpty {
        return .idle
    }
    
    if !FamilyCodeGenerator.isValidCodeFormat(trimmed) {
        return .invalid("Code must be 6 characters with letters and numbers only")
    }
    
    return .valid
}



