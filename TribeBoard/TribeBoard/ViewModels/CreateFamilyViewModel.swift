import SwiftUI
import Foundation
import Combine

/// ViewModel for family creation with SwiftUI in-memory storage
@MainActor
class CreateFamilyViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Family name input by user
    @Published var familyName: String = ""
    
    /// Current state of the family creation process
    @Published var creationState: FamilyCreationState = .idle
    
    /// Created family after successful creation
    @Published var createdFamily: InMemoryFamily?
    
    /// Generated QR code image for the family code
    @Published var qrCodeImage: Image?
    
    /// Current error, if any
    @Published var currentError: FamilyCreationError?
    
    /// Whether to show error alert
    @Published var showErrorAlert: Bool = false
    
    /// Whether to show success alert
    @Published var showSuccessAlert: Bool = false
    
    /// Validation state for family name
    @Published var isValidFamilyName: Bool = false
    
    /// Current retry count for the active operation
    @Published var retryCount: Int = 0
    
    /// Progress of the current operation (0.0 to 1.0)
    @Published var progress: Double = 0.0
    
    /// User-friendly status message
    @Published var statusMessage: String = "Ready to create family"
    
    // MARK: - Dependencies
    
    private let dataManager: InMemoryFamilyDataManager
    private let qrCodeService: QRCodeService
    
    // MARK: - State Management
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Retry Configuration
    
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 1.0
    
    // MARK: - Computed Properties
    
    /// Validation state for family name using the new validation system
    var familyNameValidation: ValidationState {
        return ValidationRules.familyName.validate(familyName)
    }
    
    /// Whether the create button should be enabled
    var canCreateFamily: Bool {
        return isValidFamilyName && 
               creationState == .idle && 
               !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Whether the creation process is currently active
    var isCreating: Bool {
        return creationState.isActive
    }
    
    /// Whether the creation process has completed successfully
    var isCompleted: Bool {
        return creationState == .completed
    }
    
    /// Whether the creation process has failed
    var isFailed: Bool {
        if case .failed = creationState {
            return true
        }
        return false
    }
    
    /// Whether the current state allows retry
    var canRetry: Bool {
        return isFailed && retryCount < maxRetryAttempts
    }
    
    /// Whether the current state is cancellable
    var canCancel: Bool {
        return isCreating
    }
    
    /// User-friendly error message for display
    var errorMessage: String? {
        return currentError?.errorDescription
    }
    
    /// Whether to show loading indicator
    var shouldShowLoadingIndicator: Bool {
        return isCreating
    }
    
    /// Whether to show progress details
    var shouldShowProgressDetails: Bool {
        return isCreating
    }
    
    // MARK: - Initialization
    
    init(dataManager: InMemoryFamilyDataManager? = nil, qrCodeService: QRCodeService = QRCodeService()) {
        self.dataManager = dataManager ?? InMemoryFamilyDataManager.shared
        self.qrCodeService = qrCodeService
        
        // Set up validation
        setupValidation()
    }
    
    // MARK: - Public Methods
    
    /// Create a new family with SwiftUI in-memory storage
    func createFamily(with appState: AppState) async {
        guard canCreateFamily else { return }
        
        // Reset state for new creation attempt
        resetCreationState()
        
        do {
            // Validate user authentication
            try await validateUserAuthentication(appState: appState)
            
            // Validate family input
            try await validateFamilyInput()
            
            // Create family in memory
            let family = try await createFamilyInMemory(
                name: familyName.trimmingCharacters(in: .whitespacesAndNewlines),
                appState: appState
            )
            
            // Generate QR code
            let qrImage = qrCodeService.generateQRCode(from: family.code)
            
            // Complete creation successfully
            await completeCreation(family: family, qrImage: qrImage, appState: appState)
            
        } catch let error as FamilyCreationError {
            await handleCreationError(error)
        } catch {
            await handleCreationError(.unknownError("Unknown error occurred"))
        }
    }
    
    /// Retry the current operation if possible
    func retryCreation(with appState: AppState) async {
        guard canRetry else { return }
        
        retryCount += 1
        
        // Apply exponential backoff
        let delay = baseRetryDelay * pow(2.0, Double(retryCount - 1))
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        // Reset to idle and retry
        updateState(.idle)
        await createFamily(with: appState)
    }
    
    /// Cancel the current operation if possible
    func cancelCreation() {
        guard canCancel else { return }
        
        updateState(.failed(.operationCancelled))
        HapticManager.shared.error()
    }
    
    /// Clear any error messages
    func clearError() {
        currentError = nil
        showErrorAlert = false
        if creationState.isFailed {
            updateState(.idle)
        }
    }
    
    /// Show error alert with the current error
    func showError(_ error: FamilyCreationError) {
        currentError = error
        showErrorAlert = true
    }
    
    /// Show success alert
    func showSuccess() {
        showSuccessAlert = true
    }
    
    /// Reset the form and state
    func resetForm() {
        familyName = ""
        createdFamily = nil
        qrCodeImage = nil
        resetCreationState()
    }
    
    /// Reset the creation state to idle
    func resetCreationState() {
        updateState(.idle)
        currentError = nil
        retryCount = 0
        progress = 0.0
        statusMessage = "Ready to create family"
    }
    

    
    // MARK: - Private Methods
    
    /// Set up real-time validation for family name
    private func setupValidation() {
        // Use Combine to validate family name in real-time
        $familyName
            .map { name in
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.count >= 2 && trimmed.count <= 50
            }
            .assign(to: &$isValidFamilyName)
    }
    
    /// Update the current state and related properties
    private func updateState(_ newState: FamilyCreationState) {
        creationState = newState
        
        // Update progress and status message based on state
        switch newState {
        case .idle:
            progress = 0.0
            statusMessage = "Ready to create family"
        case .validating:
            progress = 0.2
            statusMessage = "Validating input..."
        case .generatingCode:
            progress = 0.4
            statusMessage = "Generating family code..."
        case .creatingLocally:
            progress = 0.8
            statusMessage = "Creating family..."
        case .completed:
            progress = 1.0
            statusMessage = "Family created successfully!"
        case .failed(let error):
            progress = 0.0
            statusMessage = "Creation failed"
            currentError = error
        default:
            break
        }
    }
    
    // MARK: - Creation Steps
    
    /// Validate user authentication
    private func validateUserAuthentication(appState: AppState) async throws {
        updateState(.validating)
        
        guard let currentUser = appState.currentUser else {
            throw FamilyCreationError.userNotFound
        }
        
        // Additional user validation could go here
        print("✅ User authentication validated for: \(currentUser.id)")
    }
    
    /// Validate family input data
    private func validateFamilyInput() async throws {
        let trimmedName = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            throw FamilyCreationError.emptyFamilyName
        }
        
        guard trimmedName.count >= 2 else {
            throw FamilyCreationError.invalidFamilyName
        }
        
        guard trimmedName.count <= 50 else {
            throw FamilyCreationError.invalidFamilyName
        }
        
        print("✅ Family input validated: '\(trimmedName)'")
    }
    

    
    /// Create family in memory storage
    private func createFamilyInMemory(name: String, appState: AppState) async throws -> InMemoryFamily {
        updateState(.creatingLocally)
        
        guard let currentUser = appState.currentUser else {
            throw FamilyCreationError.userNotFound
        }
        
        // Create family in memory (code is generated automatically)
        let family = dataManager.createFamily(name: name, createdByUserId: currentUser.id)
        
        // Create user in memory if not exists
        let inMemoryUser = InMemoryUser(name: currentUser.displayName.isEmpty ? "Unknown User" : currentUser.displayName)
        
        // Add creator as parent member
        let success = dataManager.addMemberToFamily(
            familyId: family.id,
            user: inMemoryUser,
            role: .parent
        )
        
        guard success else {
            throw FamilyCreationError.unknownError("Failed to create family")
        }
        
        print("✅ Family created in memory: '\(name)' with code: \(family.code)")
        return family
    }
    

    
    /// Complete the creation process successfully
    private func completeCreation(family: InMemoryFamily, qrImage: Image?, appState: AppState) async {
        // Update state
        createdFamily = family
        qrCodeImage = qrImage
        
        // Update state to completed
        updateState(.completed)
        
        // Success haptic feedback
        HapticManager.shared.success()
        
        // Show success toast
        ToastManager.shared.success("Family '\(family.name)' created successfully!")
        
        // Add a small delay for UI feedback
        do {
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        } catch {
            // Sleep interruption is not critical, continue
        }
        
        // Navigate to role selection using AppState
        // Navigation will be handled by the view layer
        
        print("🎉 Family creation completed successfully")
    }
    
    /// Handle creation errors with appropriate recovery strategies
    private func handleCreationError(_ error: FamilyCreationError) async {
        print("❌ Family creation error: \(error.localizedDescription)")
        
        // Show error feedback
        HapticManager.shared.error()
        
        // Show error alert
        showError(error)
        
        // Show error toast
        ToastManager.shared.error(error.localizedDescription)
    }
}