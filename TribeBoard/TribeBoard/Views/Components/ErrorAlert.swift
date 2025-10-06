import SwiftUI

// MARK: - Error Alert View

struct ErrorAlert: View {
    let error: LocalizedError
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    
    init(error: LocalizedError, onDismiss: @escaping () -> Void, onRetry: (() -> Void)? = nil) {
        self.error = error
        self.onDismiss = onDismiss
        self.onRetry = onRetry
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Error Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            // Error Title
            Text("Error")
                .font(.title2)
                .fontWeight(.bold)
            
            // Error Message
            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            // Additional Details (if available)
            if let failureReason = error.failureReason {
                Text(failureReason)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            
            // Recovery Suggestion (if available)
            if let recoverySuggestion = error.recoverySuggestion {
                Text(recoverySuggestion)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.blue)
                    .padding(.top, 4)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                if let onRetry = onRetry {
                    Button("Retry") {
                        onRetry()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Button("OK") {
                    onDismiss()
                }
                .buttonStyle(.automatic)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
    }
}

// MARK: - Success Alert View

struct SuccessAlert: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Success Icon with Animation
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
                .scaleEffect(1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: true)
            
            // Success Title
            Text("Success!")
                .font(.title2)
                .fontWeight(.bold)
            
            // Success Message
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            // Dismiss Button
            Button("Continue") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
    }
}

// MARK: - Alert Overlay Modifier

struct AlertOverlay: ViewModifier {
    @Binding var showErrorAlert: Bool
    @Binding var showSuccessAlert: Bool
    let error: LocalizedError?
    let successMessage: String?
    let onErrorDismiss: () -> Void
    let onSuccessDismiss: () -> Void
    let onRetry: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if showErrorAlert, let error = error {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                showErrorAlert = false
                                onErrorDismiss()
                            }
                        
                        ErrorAlert(
                            error: error,
                            onDismiss: {
                                showErrorAlert = false
                                onErrorDismiss()
                            },
                            onRetry: onRetry
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    if showSuccessAlert, let message = successMessage {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                showSuccessAlert = false
                                onSuccessDismiss()
                            }
                        
                        SuccessAlert(
                            message: message,
                            onDismiss: {
                                showSuccessAlert = false
                                onSuccessDismiss()
                            }
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: showErrorAlert)
                .animation(.easeInOut(duration: 0.3), value: showSuccessAlert)
            )
    }
}

extension View {
    func alertOverlay(
        showErrorAlert: Binding<Bool>,
        showSuccessAlert: Binding<Bool>,
        error: LocalizedError?,
        successMessage: String?,
        onErrorDismiss: @escaping () -> Void,
        onSuccessDismiss: @escaping () -> Void,
        onRetry: (() -> Void)? = nil
    ) -> some View {
        modifier(AlertOverlay(
            showErrorAlert: showErrorAlert,
            showSuccessAlert: showSuccessAlert,
            error: error,
            successMessage: successMessage,
            onErrorDismiss: onErrorDismiss,
            onSuccessDismiss: onSuccessDismiss,
            onRetry: onRetry
        ))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ErrorAlert(
            error: FamilyCreationError.invalidFamilyName,
            onDismiss: {},
            onRetry: {}
        )
        
        SuccessAlert(
            message: "Family created successfully!",
            onDismiss: {}
        )
    }
    .padding()
}