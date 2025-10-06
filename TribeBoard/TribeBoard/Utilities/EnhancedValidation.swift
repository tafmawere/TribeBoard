import SwiftUI
import Combine

/// Enhanced validation system with SwiftUI integration and accessibility support
@MainActor
class ValidationPublisher: ObservableObject {
    @Published var familyNameValidation: ValidationState = .valid
    @Published var familyCodeValidation: ValidationState = .valid
    
    private var cancellables = Set<AnyCancellable>()
    
    /// Setup real-time validation for family name with debouncing for performance
    func setupFamilyNameValidation(for publisher: Published<String>.Publisher) {
        publisher
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .map { name in
                ValidationRules.familyName.validate(name)
            }
            .assign(to: &$familyNameValidation)
    }
    
    /// Setup real-time validation for family code with debouncing for performance
    func setupFamilyCodeValidation(for publisher: Published<String>.Publisher) {
        publisher
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .map { code in
                ValidationRules.familyCode.validate(code)
            }
            .assign(to: &$familyCodeValidation)
    }
}

/// Enhanced validation view modifier with accessibility support
struct ValidationModifier: ViewModifier {
    let validation: ValidationState
    let showValidation: Bool
    
    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: borderWidth)
                        .animation(.easeInOut(duration: 0.2), value: validation.isValid)
                )
            
            if showValidation, let errorMessage = validation.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .accessibilityHidden(true)
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .accessibilityLabel("Validation error: \(errorMessage)")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.3), value: errorMessage)
            }
        }
    }
    
    private var borderColor: Color {
        if !showValidation {
            return Color.clear
        }
        return validation.isValid ? .green.opacity(0.5) : .red.opacity(0.5)
    }
    
    private var borderWidth: CGFloat {
        showValidation ? 1 : 0
    }
}

extension View {
    /// Apply validation styling and feedback to any view
    func validation(_ validation: ValidationState, showValidation: Bool = true) -> some View {
        modifier(ValidationModifier(validation: validation, showValidation: showValidation))
    }
}

/// Enhanced validation rules with better error messages
extension ValidationRules {
    /// Validate family code with enhanced error messages
    static func validateFamilyCode(_ code: String) -> ValidationState {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return .valid // Don't show error for empty state
        }
        
        if trimmed.count != 6 {
            return .invalid("Code must be exactly 6 characters")
        }
        
        if !trimmed.allSatisfy({ $0.isLetter || $0.isNumber }) {
            return .invalid("Code can only contain letters and numbers")
        }
        
        return .valid
    }
}