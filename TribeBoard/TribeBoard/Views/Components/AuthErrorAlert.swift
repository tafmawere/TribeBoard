import SwiftUI

/// Reusable error alert component for authentication failures
struct AuthErrorAlert: ViewModifier {
    
    // MARK: - Properties
    
    @Binding var isPresented: Bool
    let error: AuthError?
    let onRetry: (() -> Void)?
    
    // MARK: - Body
    
    func body(content: Content) -> some View {
        content
            .alert("Authentication Error", isPresented: $isPresented) {
                alertButtons
            } message: {
                if let error = error {
                    Text(userFriendlyMessage(for: error))
                }
            }
    }
    
    // MARK: - Alert Buttons
    
    @ViewBuilder
    private var alertButtons: some View {
        // Always show OK button
        Button("OK") {
            isPresented = false
        }
        
        // Show retry button for recoverable errors
        if let error = error, isRecoverable(error), let onRetry = onRetry {
            if case .networkUnavailable = error {
                // For network errors, use smart retry that waits for connection
                Button("Retry when connected") {
                    isPresented = false
                    Task {
                        // Wait for network connection before retrying
                        let connected = await NetworkMonitor.shared.waitForConnection(timeout: 30.0)
                        if connected {
                            onRetry()
                        }
                    }
                }
            } else {
                Button("Retry") {
                    isPresented = false
                    onRetry()
                }
            }
        }
    }
    
    // MARK: - Error Message Mapping
    
    /// Maps AuthError types to user-friendly messages
    private func userFriendlyMessage(for error: AuthError) -> String {
        switch error {
        case .authorizationFailed:
            return "We couldn't sign you in with Apple ID. This might be due to a temporary issue with Apple's servers. Please try again."
            
        case .userCancelled:
            return "Sign in was cancelled. You can try again when you're ready."
            
        case .networkUnavailable:
            if NetworkMonitor.shared.isConnected {
                return "There seems to be a network issue preventing sign-in. Please check your connection and try again."
            } else {
                return "No internet connection detected. Please connect to Wi-Fi or cellular data and try again."
            }
            
        case .invalidCredentials:
            return "There was an issue with the credentials from Apple. Please try signing in again."
            
        case .keychainError(let underlyingError):
            return "There was a problem securely storing your sign-in information. Error: \(underlyingError.localizedDescription)"
            
        case .dataServiceError(let underlyingError):
            return "There was a problem setting up your account. Please try again. Error: \(underlyingError.localizedDescription)"
            
        case .unknownError(let underlyingError):
            return "An unexpected error occurred. Please try again. If the problem persists, please contact support. Error: \(underlyingError.localizedDescription)"
        }
    }
    
    // MARK: - Error Recovery
    
    /// Determines if an error is recoverable and should show a retry option
    private func isRecoverable(_ error: AuthError) -> Bool {
        switch error {
        case .authorizationFailed:
            return true
        case .userCancelled:
            return false // User chose to cancel, don't offer retry
        case .networkUnavailable:
            return true
        case .invalidCredentials:
            return true
        case .keychainError:
            return true
        case .dataServiceError:
            return true
        case .unknownError:
            return true
        }
    }
}

// MARK: - View Extension

extension View {
    /// Presents an authentication error alert with retry functionality
    /// - Parameters:
    ///   - isPresented: Binding to control alert presentation
    ///   - error: The authentication error to display
    ///   - onRetry: Optional closure to execute when user taps retry
    func authErrorAlert(
        isPresented: Binding<Bool>,
        error: AuthError?,
        onRetry: (() -> Void)? = nil
    ) -> some View {
        modifier(AuthErrorAlert(
            isPresented: isPresented,
            error: error,
            onRetry: onRetry
        ))
    }
}

// MARK: - Preview

#Preview("Auth Error Alert - Network") {
    VStack {
        Text("Tap to show network error")
            .padding()
    }
    .authErrorAlert(
        isPresented: .constant(true),
        error: .networkUnavailable,
        onRetry: {
            print("Retry tapped")
        }
    )
}

#Preview("Auth Error Alert - User Cancelled") {
    VStack {
        Text("Tap to show user cancelled error")
            .padding()
    }
    .authErrorAlert(
        isPresented: .constant(true),
        error: .userCancelled,
        onRetry: {
            print("Retry tapped")
        }
    )
}

#Preview("Auth Error Alert - Authorization Failed") {
    VStack {
        Text("Tap to show authorization failed error")
            .padding()
    }
    .authErrorAlert(
        isPresented: .constant(true),
        error: .authorizationFailed,
        onRetry: {
            print("Retry tapped")
        }
    )
}