import SwiftUI

/// Comprehensive error recovery view for School Run errors
struct SchoolRunErrorRecoveryView: View {
    let error: SchoolRunError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void
    let onAlternativeAction: (() -> Void)?
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    init(
        error: SchoolRunError,
        onRetry: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void,
        onAlternativeAction: (() -> Void)? = nil
    ) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
        self.onAlternativeAction = onAlternativeAction
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Error icon and title
            errorHeader
            
            // Error message and description
            errorContent
            
            // Recovery suggestions
            if !recoverySuggestions.isEmpty {
                recoverySuggestionsSection
            }
            
            // Action buttons
            actionButtons
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .mediumShadow()
                .overlay(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .stroke(errorBorderColor, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error: \(error.userFriendlyMessage)")
        .dynamicTypeSupport()
    }
    
    // MARK: - Header Section
    
    private var errorHeader: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Error icon
            Image(systemName: errorIcon)
                .font(.system(size: 40))
                .foregroundColor(errorColor)
                .accessibilityHidden(true)
            
            // Error title
            Text(errorTitle)
                .titleMedium()
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits([.isHeader])
        }
    }
    
    // MARK: - Content Section
    
    private var errorContent: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Primary error message
            Text(error.userFriendlyMessage)
                .bodyMedium()
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            // Technical details (if available and appropriate)
            if let technicalDetails = error.recoverySuggestion, error.severity != .low {
                Text(technicalDetails)
                    .bodySmall()
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Recovery Suggestions Section
    
    private var recoverySuggestionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.orange)
                    .font(.caption)
                
                Text("Suggestions")
                    .captionLarge()
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                ForEach(Array(recoverySuggestions.enumerated()), id: \.offset) { index, suggestion in
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.xs) {
                        Text("\(index + 1).")
                            .captionLarge()
                            .foregroundColor(.secondary)
                            .frame(width: 16, alignment: .leading)
                        
                        Text(suggestion)
                            .captionLarge()
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Primary action (retry or alternative)
            if let onRetry = onRetry, error.isRetryable {
                Button(action: {
                    HapticManager.shared.lightImpact()
                    onRetry()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16))
                        
                        Text("Try Again")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel("Try the operation again")
            } else if let onAlternativeAction = onAlternativeAction {
                Button(action: {
                    HapticManager.shared.lightImpact()
                    onAlternativeAction()
                }) {
                    HStack {
                        Image(systemName: alternativeActionIcon)
                            .font(.system(size: 16))
                        
                        Text(alternativeActionTitle)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            
            // Secondary action (dismiss)
            Button(action: {
                HapticManager.shared.lightImpact()
                onDismiss()
            }) {
                Text("Dismiss")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityLabel("Dismiss error message")
        }
    }
    
    // MARK: - Computed Properties
    
    private var errorIcon: String {
        switch error.severity {
        case .low:
            return "info.circle"
        case .medium:
            return "exclamationmark.triangle"
        case .high:
            return "exclamationmark.octagon"
        case .critical:
            return "xmark.octagon"
        }
    }
    
    private var errorColor: Color {
        switch error.severity {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        case .critical:
            return .red
        }
    }
    
    private var errorBorderColor: Color {
        errorColor.opacity(0.3)
    }
    
    private var errorTitle: String {
        switch error.category {
        case .validation:
            return "Input Error"
        case .data:
            return "Data Error"
        case .state:
            return "Operation Error"
        case .network:
            return "Connection Error"
        case .system:
            return "System Error"
        case .user:
            return "Action Cancelled"
        case .authentication:
            return "Authentication Error"
        case .cloudKit:
            return "Cloud Sync Error"
        case .codeGeneration:
            return "Code Generation Error"
        case .localDatabase:
            return "Database Error"
        }
    }
    
    private var recoverySuggestions: [String] {
        let errorHandler = SchoolRunErrorHandler()
        return errorHandler.getRecoverySuggestions(for: error)
    }
    
    private var alternativeActionIcon: String {
        switch error.category {
        case .validation:
            return "pencil"
        case .data:
            return "arrow.clockwise"
        case .state:
            return "checkmark"
        case .network:
            return "wifi"
        case .system:
            return "gear"
        case .user:
            return "checkmark"
        case .authentication:
            return "person.circle"
        case .cloudKit:
            return "icloud"
        case .codeGeneration:
            return "qrcode"
        case .localDatabase:
            return "externaldrive"
        }
    }
    
    private var alternativeActionTitle: String {
        switch error.category {
        case .validation:
            return "Edit Input"
        case .data:
            return "Refresh Data"
        case .state:
            return "Continue"
        case .network:
            return "Check Connection"
        case .system:
            return "Settings"
        case .user:
            return "OK"
        case .authentication:
            return "Sign In"
        case .cloudKit:
            return "Sync Settings"
        case .codeGeneration:
            return "Generate New Code"
        case .localDatabase:
            return "Reset Database"
        }
    }
}

// MARK: - Inline Error Recovery View

/// Compact inline error recovery view for form fields
struct InlineSchoolRunErrorView: View {
    let error: SchoolRunError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.subheadline)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(error.userFriendlyMessage)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.leading)
                
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.8))
                        .multilineTextAlignment(.leading)
                }
            }
            
            Spacer()
            
            HStack(spacing: DesignSystem.Spacing.xs) {
                if let onRetry = onRetry, error.isRetryable {
                    Button(action: {
                        HapticManager.shared.lightImpact()
                        onRetry()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.red.opacity(0.7))
                            .font(.caption)
                    }
                    .accessibilityLabel("Retry")
                }
                
                Button(action: {
                    HapticManager.shared.lightImpact()
                    onDismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red.opacity(0.7))
                        .font(.subheadline)
                }
                .accessibilityLabel("Dismiss error")
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
        .transition(.scale.combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(error.userFriendlyMessage)")
    }
}

// MARK: - Error Alert Modifier

/// View modifier for showing error alerts with recovery options
struct SchoolRunErrorAlert: ViewModifier {
    @Binding var error: SchoolRunError?
    let onRetry: (() -> Void)?
    let onAlternativeAction: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: .constant(error != nil)) {
                // Retry button
                if let onRetry = onRetry, error?.isRetryable == true {
                    Button("Try Again") {
                        onRetry()
                        error = nil
                    }
                }
                
                // Alternative action button
                if let onAlternativeAction = onAlternativeAction {
                    Button("Continue") {
                        onAlternativeAction()
                        error = nil
                    }
                }
                
                // Dismiss button
                Button("OK", role: .cancel) {
                    error = nil
                }
            } message: {
                if let error = error {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error.userFriendlyMessage)
                        
                        if let suggestion = error.recoverySuggestion {
                            Text(suggestion)
                                .font(.caption)
                        }
                    }
                }
            }
    }
}

extension View {
    /// Add School Run error alert with recovery options
    func schoolRunErrorAlert(
        error: Binding<SchoolRunError?>,
        onRetry: (() -> Void)? = nil,
        onAlternativeAction: (() -> Void)? = nil
    ) -> some View {
        modifier(SchoolRunErrorAlert(
            error: error,
            onRetry: onRetry,
            onAlternativeAction: onAlternativeAction
        ))
    }
}

// MARK: - Preview

#Preview("Validation Error") {
    SchoolRunErrorRecoveryView(
        error: .invalidRunTitle("Title must be at least 3 characters"),
        onRetry: {},
        onDismiss: {}
    )
    .padding()
}

#Preview("Network Error") {
    SchoolRunErrorRecoveryView(
        error: .networkUnavailable,
        onRetry: {},
        onDismiss: {},
        onAlternativeAction: {}
    )
    .padding()
}

#Preview("Critical Error") {
    SchoolRunErrorRecoveryView(
        error: .dataCorruption("Database schema mismatch"),
        onRetry: nil,
        onDismiss: {}
    )
    .padding()
}

#Preview("Inline Error") {
    VStack(spacing: 16) {
        InlineSchoolRunErrorView(
            error: .duplicateStopNames,
            onRetry: {},
            onDismiss: {}
        )
        
        InlineSchoolRunErrorView(
            error: .invalidStopTiming("Stops must be at least 5 minutes apart"),
            onRetry: {},
            onDismiss: {}
        )
    }
    .padding()
}