import SwiftUI

/// Example showing how to integrate mock error handling into existing views
struct ErrorHandlingIntegrationExample: View {
    
    @StateObject private var errorCoordinator = MockErrorHandlingCoordinator()
    @State private var familyName = ""
    @State private var isCreatingFamily = false
    @State private var showingErrorDemo = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Text("Family Creation with Error Handling")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("This example shows how to integrate comprehensive error handling into existing app flows.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Family Creation Form
                VStack(alignment: .leading, spacing: 16) {
                    Text("Create Your Family")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Family Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Enter family name", text: $familyName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Button(action: createFamily) {
                        HStack {
                            if isCreatingFamily {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isCreatingFamily ? "Creating..." : "Create Family")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isCreatingFamily || familyName.isEmpty)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                
                // Error Testing Controls
                VStack(alignment: .leading, spacing: 16) {
                    Text("Test Error Scenarios")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        Button("Simulate Network Error") {
                            simulateNetworkError()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        
                        Button("Simulate Validation Error") {
                            simulateValidationError()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        
                        Button("Simulate Permission Error") {
                            simulatePermissionError()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        
                        Button("Show Error Demo") {
                            showingErrorDemo = true
                        }
                        .buttonStyle(TertiaryButtonStyle())
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                
                Spacer()
            }
            .padding()
            .navigationTitle("Error Integration")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingErrorDemo) {
            MockErrorHandlingDemoView()
        }
        .overlay(
            // Error Display Overlay
            Group {
                if let currentError = errorCoordinator.currentError {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            // Allow dismissing by tapping background for non-critical errors
                            if currentError.severity <= .medium {
                                errorCoordinator.dismissCurrentError()
                            }
                        }
                    
                    EnhancedErrorStateView(
                        error: currentError,
                        recoveryManager: errorCoordinator.getRecoveryManager(),
                        onDismiss: {
                            errorCoordinator.dismissCurrentError()
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
        )
        .animation(.easeInOut(duration: 0.3), value: errorCoordinator.currentError != nil)
    }
    
    // MARK: - Family Creation Logic
    
    private func createFamily() {
        isCreatingFamily = true
        
        // Simulate family creation process with potential errors
        Task {
            // Simulate processing time
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Generate contextual error based on input
            let context = MockErrorContext(
                currentView: "family_creation_form",
                userRole: "admin",
                networkStatus: "connected",
                authenticationStatus: "authenticated",
                lastAction: "create_family",
                errorHistory: [],
                userPreferences: [:]
            )
            
            // Simulate different error scenarios based on input
            if let error = determineAppropriateError(for: familyName, context: context) {
                await MainActor.run {
                    errorCoordinator.displayError(error)
                    isCreatingFamily = false
                }
            } else {
                // Success case
                await MainActor.run {
                    isCreatingFamily = false
                    ToastManager.shared.success("Family '\(familyName)' created successfully!")
                    familyName = ""
                }
            }
        }
    }
    
    private func determineAppropriateError(for name: String, context: MockErrorContext) -> MockError? {
        // Simulate different error conditions based on input
        
        // Empty name (should be caught by UI, but simulate validation error)
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return MockError(
                category: .validation,
                type: .invalidInput,
                title: "Invalid Family Name",
                message: "Family name cannot be empty. Please enter a valid name.",
                severity: .medium,
                isRetryable: false,
                recoveryActions: [.editInput, .dismiss]
            )
        }
        
        // Names that trigger specific errors for demo
        if name.lowercased().contains("error") {
            return MockError(
                category: .network,
                type: .noConnection,
                title: "Connection Lost",
                message: "Unable to connect to TribeBoard servers. Please check your internet connection.",
                severity: .high,
                isRetryable: true,
                recoveryActions: [.checkConnection, .retry, .workOffline, .dismiss]
            )
        }
        
        if name.lowercased().contains("duplicate") {
            return MockError(
                category: .validation,
                type: .duplicateData,
                title: "Family Name Taken",
                message: "A family with the name '\(name)' already exists. Please choose a different name.",
                severity: .medium,
                isRetryable: false,
                recoveryActions: [.chooseDifferentName, .addSuffix, .editInput, .dismiss]
            )
        }
        
        if name.lowercased().contains("permission") {
            return MockError(
                category: .permission,
                type: .accessDenied,
                title: "Permission Required",
                message: "You need additional permissions to create a family. Please contact your administrator.",
                severity: .high,
                isRetryable: false,
                recoveryActions: [.contactAdmin, .requestPermission, .dismiss]
            )
        }
        
        // Random error generation (10% chance)
        if Double.random(in: 0...1) < 0.1 {
            return errorCoordinator.generateContextualError(context: context)
        }
        
        return nil // Success case
    }
    
    // MARK: - Error Simulation Methods
    
    private func simulateNetworkError() {
        let error = MockError(
            category: .network,
            type: .noConnection,
            title: "Network Unavailable",
            message: "Unable to connect to the internet. Please check your connection and try again.",
            severity: .high,
            isRetryable: true,
            recoveryActions: [.checkConnection, .retry, .workOffline, .dismiss],
            context: [
                "connection_type": "wifi",
                "last_successful_connection": Date().addingTimeInterval(-300),
                "retry_count": 0
            ]
        )
        
        errorCoordinator.displayError(error)
    }
    
    private func simulateValidationError() {
        let error = MockError(
            category: .validation,
            type: .invalidInput,
            title: "Invalid Input",
            message: "The family name contains invalid characters. Please use only letters, numbers, and spaces.",
            severity: .medium,
            isRetryable: false,
            recoveryActions: [.editInput, .generateNewCode, .dismiss],
            context: [
                "field": "family_name",
                "invalid_characters": ["@", "#", "$"],
                "suggested_name": "My Family"
            ]
        )
        
        errorCoordinator.displayError(error)
    }
    
    private func simulatePermissionError() {
        let error = MockError(
            category: .permission,
            type: .childRestriction,
            title: "Parental Permission Required",
            message: "Creating families requires parental permission. We'll send a request to your parents for approval.",
            severity: .medium,
            isRetryable: false,
            recoveryActions: [.requestPermission, .askParent, .contactAdmin, .dismiss],
            context: [
                "user_age": 15,
                "parent_contacts": ["mom@example.com", "dad@example.com"],
                "feature": "family_creation"
            ]
        )
        
        errorCoordinator.displayError(error)
    }
}

// MARK: - Integration Helper Extension

extension View {
    /// Modifier to add comprehensive error handling to any view
    func withErrorHandling(_ coordinator: MockErrorHandlingCoordinator) -> some View {
        self.overlay(
            Group {
                if let currentError = coordinator.currentError {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            if currentError.severity <= .medium {
                                coordinator.dismissCurrentError()
                            }
                        }
                    
                    EnhancedErrorStateView(
                        error: currentError,
                        recoveryManager: coordinator.getRecoveryManager(),
                        onDismiss: {
                            coordinator.dismissCurrentError()
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
        )
        .animation(.easeInOut(duration: 0.3), value: coordinator.currentError != nil)
    }
}

// MARK: - Usage Examples in ViewModels

/// Example of how to integrate error handling in ViewModels
class ExampleViewModelWithErrorHandling: ObservableObject {
    
    @Published var isLoading = false
    @Published var data: [String] = []
    
    private let errorCoordinator: MockErrorHandlingCoordinator
    
    init(errorCoordinator: MockErrorHandlingCoordinator) {
        self.errorCoordinator = errorCoordinator
    }
    
    func performOperation() async {
        isLoading = true
        
        do {
            // Simulate operation that might fail
            try await simulateNetworkOperation()
            
            // Success
            await MainActor.run {
                data.append("New item")
                isLoading = false
                ToastManager.shared.success("Operation completed successfully")
            }
            
        } catch {
            // Handle error using the error coordinator
            await MainActor.run {
                isLoading = false
                
                let mockError = MockError(
                    category: .network,
                    type: .serverUnavailable,
                    title: "Operation Failed",
                    message: "The operation could not be completed. Please try again.",
                    severity: .medium,
                    isRetryable: true,
                    recoveryActions: [.retry, .checkConnection, .workOffline, .dismiss],
                    context: [
                        "operation": "data_fetch",
                        "error_details": error.localizedDescription
                    ]
                )
                
                errorCoordinator.displayError(mockError)
            }
        }
    }
    
    private func simulateNetworkOperation() async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Simulate random failure (30% chance)
        if Double.random(in: 0...1) < 0.3 {
            throw NSError(domain: "NetworkError", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Server temporarily unavailable"
            ])
        }
    }
}

// MARK: - Preview

#Preview {
    ErrorHandlingIntegrationExample()
}