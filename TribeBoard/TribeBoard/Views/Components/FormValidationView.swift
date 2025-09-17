import SwiftUI

/// Enhanced text field with real-time validation and accessibility support
struct ValidatedTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let validation: ValidationRule?
    let keyboardType: UIKeyboardType
    let textInputAutocapitalization: TextInputAutocapitalization
    let autocorrectionDisabled: Bool
    let submitLabel: SubmitLabel
    let onSubmit: (() -> Void)?
    
    @FocusState private var isFocused: Bool
    @State private var hasBeenEdited = false
    
    init(
        title: String,
        placeholder: String,
        text: Binding<String>,
        validation: ValidationRule? = nil,
        keyboardType: UIKeyboardType = .default,
        textInputAutocapitalization: TextInputAutocapitalization = .sentences,
        autocorrectionDisabled: Bool = false,
        submitLabel: SubmitLabel = .done,
        onSubmit: (() -> Void)? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.validation = validation
        self.keyboardType = keyboardType
        self.textInputAutocapitalization = textInputAutocapitalization
        self.autocorrectionDisabled = autocorrectionDisabled
        self.submitLabel = submitLabel
        self.onSubmit = onSubmit
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .accessibilityLabel(title)
            
            // Text field
            TextField(placeholder, text: $text)
                .textFieldStyle(ValidatedTextFieldStyle(
                    isValid: validationState.isValid,
                    isFocused: isFocused,
                    hasError: hasValidationError
                ))
                .keyboardType(keyboardType)
                .textInputAutocapitalization(textInputAutocapitalization)
                .autocorrectionDisabled(autocorrectionDisabled)
                .submitLabel(submitLabel)
                .focused($isFocused)
                .onSubmit {
                    onSubmit?()
                }
                .onChange(of: text) { _, _ in
                    if !hasBeenEdited {
                        hasBeenEdited = true
                    }
                }
                .accessibilityLabel("\(title) input field")
                .accessibilityHint(placeholder)
                .accessibilityValue(text.isEmpty ? "Empty" : text)
            
            // Validation feedback
            if validation != nil, hasBeenEdited || !isFocused {
                ValidationFeedbackView(
                    state: validationState,
                    showSuccess: !isFocused && validationState.isValid && !text.isEmpty
                )
            }
        }
    }
    
    private var validationState: ValidationState {
        guard let validation = validation else {
            return ValidationState(isValid: true, message: nil)
        }
        return validation.validate(text)
    }
    
    private var hasValidationError: Bool {
        guard hasBeenEdited || !isFocused else { return false }
        return !validationState.isValid && !text.isEmpty
    }
}

/// Custom text field style with validation states
struct ValidatedTextFieldStyle: TextFieldStyle {
    let isValid: Bool
    let isFocused: Bool
    let hasError: Bool
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .cornerRadius(BrandStyle.cornerRadius)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            .animation(.easeInOut(duration: 0.2), value: hasError)
    }
    
    private var backgroundColor: Color {
        if hasError {
            return Color.red.opacity(0.05)
        } else if isFocused {
            return Color.brandPrimary.opacity(0.05)
        } else {
            return Color(.systemBackground)
        }
    }
    
    private var borderColor: Color {
        if hasError {
            return .red
        } else if isFocused {
            return .brandPrimary
        } else {
            return Color(.systemGray4)
        }
    }
    
    private var borderWidth: CGFloat {
        (isFocused || hasError) ? 2 : 1
    }
}

/// Validation feedback component
struct ValidationFeedbackView: View {
    let state: ValidationState
    let showSuccess: Bool
    
    var body: some View {
        if let message = state.message {
            HStack(spacing: 6) {
                Image(systemName: state.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(state.isValid ? .green : .red)
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(state.isValid ? .green : .red)
                    .multilineTextAlignment(.leading)
            }
            .transition(.scale.combined(with: .opacity))
            .accessibilityLabel(state.isValid ? "Valid: \(message)" : "Error: \(message)")
        } else if showSuccess && state.isValid {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                
                Text("Looks good!")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            .transition(.scale.combined(with: .opacity))
            .accessibilityLabel("Input is valid")
        }
    }
}

// MARK: - Validation System

/// Validation rule protocol
protocol ValidationRule {
    func validate(_ input: String) -> ValidationState
}

/// Validation state
struct ValidationState {
    let isValid: Bool
    let message: String?
}

/// Common validation rules
struct ValidationRules {
    
    /// Family name validation
    static let familyName = FamilyNameValidation()
    
    /// Family code validation
    static let familyCode = FamilyCodeValidation()
    
    /// Required field validation
    static func required(fieldName: String) -> RequiredValidation {
        RequiredValidation(fieldName: fieldName)
    }
    
    /// Length validation
    static func length(min: Int, max: Int, fieldName: String) -> LengthValidation {
        LengthValidation(min: min, max: max, fieldName: fieldName)
    }
}

// MARK: - Validation Implementations

struct FamilyNameValidation: ValidationRule {
    func validate(_ input: String) -> ValidationState {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return ValidationState(isValid: false, message: "Family name is required")
        }
        
        if trimmed.count < 2 {
            return ValidationState(isValid: false, message: "Family name must be at least 2 characters")
        }
        
        if trimmed.count > 50 {
            return ValidationState(isValid: false, message: "Family name must be less than 50 characters")
        }
        
        return ValidationState(isValid: true, message: "Perfect!")
    }
}

struct FamilyCodeValidation: ValidationRule {
    func validate(_ input: String) -> ValidationState {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return ValidationState(isValid: false, message: "Family code is required")
        }
        
        if trimmed.count < 4 || trimmed.count > 8 {
            return ValidationState(isValid: false, message: "Family code must be 4-8 characters")
        }
        
        let isAlphanumeric = trimmed.allSatisfy { $0.isLetter || $0.isNumber }
        if !isAlphanumeric {
            return ValidationState(isValid: false, message: "Family code can only contain letters and numbers")
        }
        
        return ValidationState(isValid: true, message: "Valid format")
    }
}

struct RequiredValidation: ValidationRule {
    let fieldName: String
    
    func validate(_ input: String) -> ValidationState {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return ValidationState(isValid: false, message: "\(fieldName) is required")
        }
        
        return ValidationState(isValid: true, message: nil)
    }
}

struct LengthValidation: ValidationRule {
    let min: Int
    let max: Int
    let fieldName: String
    
    func validate(_ input: String) -> ValidationState {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.count < min {
            return ValidationState(isValid: false, message: "\(fieldName) must be at least \(min) characters")
        }
        
        if trimmed.count > max {
            return ValidationState(isValid: false, message: "\(fieldName) must be less than \(max) characters")
        }
        
        return ValidationState(isValid: true, message: nil)
    }
}

// MARK: - Preview

#Preview("Validated Text Field") {
    VStack(spacing: 20) {
        ValidatedTextField(
            title: "Family Name",
            placeholder: "Enter your family name",
            text: .constant(""),
            validation: ValidationRules.familyName
        )
        
        ValidatedTextField(
            title: "Family Code",
            placeholder: "Enter family code",
            text: .constant("ABC123"),
            validation: ValidationRules.familyCode,
            textInputAutocapitalization: .characters,
            autocorrectionDisabled: true
        )
    }
    .padding()
}