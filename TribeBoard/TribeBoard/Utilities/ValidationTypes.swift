import Foundation

/// Validation state for form inputs
enum ValidationState {
    case valid
    case invalid(String)
    case pending
    
    var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }
    
    var errorMessage: String? {
        if case .invalid(let message) = self {
            return message
        }
        return nil
    }
    
    var message: String? {
        return errorMessage
    }
}

/// Generic validation rule
struct ValidationRuleType<T> {
    let validate: (T) -> ValidationState
    
    init(_ validate: @escaping (T) -> ValidationState) {
        self.validate = validate
    }
}

/// Validation rules for different input types
struct ValidationRules {
    
    /// Validation rule for family names
    static let familyName = ValidationRuleType { (input: String) -> ValidationState in
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return .invalid("Family name cannot be empty")
        }
        
        if trimmed.count < 2 {
            return .invalid("Family name must be at least 2 characters")
        }
        
        if trimmed.count > 50 {
            return .invalid("Family name cannot exceed 50 characters")
        }
        
        return .valid
    }
    
    /// Validation rule for family codes
    static let familyCode = ValidationRuleType { (input: String) -> ValidationState in
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return .invalid("Family code cannot be empty")
        }
        
        if !FamilyCodeGenerator.isValidCodeFormat(trimmed) {
            return .invalid("Code must be 6 characters with letters and numbers")
        }
        
        return .valid
    }
}