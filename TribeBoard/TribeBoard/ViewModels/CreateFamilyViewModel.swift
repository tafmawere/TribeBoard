import SwiftUI
import Foundation
import Combine

/// ViewModel for family creation with comprehensive state machine and error handling
@MainActor
class CreateFamilyViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Family name input by user
    @Published var familyName: String = ""
    
    /// Current state of the family creation process
    @Published var creationState: FamilyCreationState = .idle
    
    /// Created family after successful creation
    @Published var createdFamily: Family?
    
    /// Generated QR code image for the family code
    @Published var qrCodeImage: Image?
    
    /// Current error, if any
    @Published var currentError: FamilyCreationError?
    
    /// Validation state for family name
    @Published var isValidFamilyName: Bool = false
    
    /// Current retry count for the active operation
    @Published var retryCount: Int = 0
    
    /// Whether the app is in offline mode
    @Published var isOfflineMode: Bool = false
    
    /// Progress of the current operation (0.0 to 1.0)
    @Published var progress: Double = 0.0
    
    /// User-friendly status message
    @Published var statusMessage: String = "Ready to create family"
    
    // MARK: - Dependencies
    
    private let dataService: DataService
    private let cloudKitService: CloudKitService
    private let syncManager: SyncManager
    private let qrCodeService: QRCodeService
    private let codeGenerator: CodeGenerator
    
    // MARK: - State Management
    
    private let stateManager = FamilyCreationStateManager()
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
        return creationState.isCompleted
    }
    
    /// Whether the creation process has failed
    var isFailed: Bool {
        return creationState.isFailed
    }
    
    /// Whether the current state allows retry
    var canRetry: Bool {
        return creationState.allowsRetry && retryCount < maxRetryAttempts
    }
    
    /// Whether the current state is cancellable
    var canCancel: Bool {
        return creationState.isCancellable
    }
    
    /// User-friendly error message for display
    var errorMessage: String? {
        return currentError?.userFriendlyMessage
    }
    
    /// Whether to show loading indicator
    var shouldShowLoadingIndicator: Bool {
        return creationState.shouldShowLoadingIndicator
    }
    
    /// Whether to show progress details
    var shouldShowProgressDetails: Bool {
        return creationState.shouldShowProgressDetails
    }
    
    // MARK: - Initialization
    
    init(dataService: DataService, cloudKitService: CloudKitService, syncManager: SyncManager, qrCodeService: QRCodeService = QRCodeService(), codeGenerator: CodeGenerator = CodeGenerator()) {
        self.dataService = dataService
        self.cloudKitService = cloudKitService
        self.syncManager = syncManager
        self.qrCodeService = qrCodeService
        self.codeGenerator = codeGenerator
        
        // Set up validation and state management
        setupValidation()
        setupStateManagement()
        setupNetworkMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Create a new family with comprehensive state machine and error handling
    func createFamily(with appState: AppState) async {
        guard canCreateFamily else { return }
        
        // Reset state for new creation attempt
        resetCreationState()
        
        do {
            // Validate user authentication
            try await validateUserAuthentication(appState: appState)
            
            // Validate family input
            try await validateFamilyInput()
            
            // Generate unique family code
            let familyCode = try await generateUniqueFamilyCodeWithRetry()
            
            // Create family locally
            let (family, membership) = try await createFamilyLocally(
                name: familyName.trimmingCharacters(in: .whitespacesAndNewlines),
                code: familyCode,
                appState: appState
            )
            
            // Generate QR code
            let qrImage = qrCodeService.generateQRCode(from: familyCode)
            
            // Sync to CloudKit (with fallback to local-only)
            try await syncToCloudKitWithFallback(family: family, membership: membership)
            
            // Complete creation successfully
            await completeCreation(family: family, qrImage: qrImage, appState: appState)
            
        } catch let error as FamilyCreationError {
            await handleCreationError(error)
        } catch {
            await handleCreationError(.unknownError(error))
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
        if creationState.isFailed {
            updateState(.idle)
        }
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
    
    /// Set up state management bindings
    private func setupStateManagement() {
        // Bind state manager to published properties
        stateManager.$currentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.creationState = state
                self?.progress = state.progress
                self?.statusMessage = state.userDescription
                self?.currentError = state.error
            }
            .store(in: &cancellables)
    }
    
    /// Set up network monitoring for offline mode detection
    private func setupNetworkMonitoring() {
        // Use SyncManager for offline mode detection
        syncManager.$isOfflineMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isOffline in
                self?.isOfflineMode = isOffline
            }
            .store(in: &cancellables)
    }
    
    /// Update the current state
    private func updateState(_ newState: FamilyCreationState) {
        stateManager.transition(to: newState)
    }
    
    // MARK: - Creation Steps
    
    /// Validate user authentication
    private func validateUserAuthentication(appState: AppState) async throws {
        updateState(.validating)
        
        guard let currentUser = appState.currentUser else {
            throw FamilyCreationError.userNotAuthenticated
        }
        
        // Additional user validation could go here
        print("✅ User authentication validated for: \(currentUser.id)")
    }
    
    /// Validate family input data
    private func validateFamilyInput() async throws {
        let trimmedName = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            throw FamilyCreationError.invalidFamilyName("Family name cannot be empty")
        }
        
        guard trimmedName.count >= 2 else {
            throw FamilyCreationError.invalidFamilyName("Family name must be at least 2 characters")
        }
        
        guard trimmedName.count <= 50 else {
            throw FamilyCreationError.invalidFamilyName("Family name cannot exceed 50 characters")
        }
        
        print("✅ Family input validated: '\(trimmedName)'")
    }
    
    /// Generate a unique family code with retry logic
    private func generateUniqueFamilyCodeWithRetry() async throws -> String {
        updateState(.generatingCode)
        
        do {
            return try await codeGenerator.generateUniqueCodeSafely(
                checkLocal: { [weak self] code in
                    guard let self = self else { return false }
                    
                    // Check local storage first
                    let localExists = try self.dataService.familyCodeExists(code)
                    return !localExists // Return true if code is unique (not found locally)
                },
                checkRemote: { [weak self] code in
                    guard let self = self else { return false }
                    
                    // Check CloudKit for collision if online
                    if !self.isOfflineMode {
                        let cloudKitRecord = try await self.cloudKitService.fetchFamily(byCode: code)
                        return cloudKitRecord == nil // Return true if code is unique (not found)
                    }
                    
                    return true // Assume unique if offline
                }
            )
        } catch let error as FamilyCodeGenerationError {
            throw FamilyCreationError.codeGenerationFailed(error)
        } catch {
            throw FamilyCreationError.codeGenerationFailed(.generationAlgorithmFailed)
        }
    }
    
    /// Create family in local storage
    private func createFamilyLocally(name: String, code: String, appState: AppState) async throws -> (Family, Membership) {
        updateState(.creatingLocally)
        
        guard let currentUser = appState.currentUser else {
            throw FamilyCreationError.userNotAuthenticated
        }
        
        do {
            // Create family in local storage
            let family = try dataService.createFamily(
                name: name,
                code: code,
                createdByUserId: currentUser.id
            )
            
            // Create membership for the creator as Parent Admin
            let membership = try dataService.createMembership(
                family: family,
                user: currentUser,
                role: .parentAdmin
            )
            
            print("✅ Family created locally: '\(name)' with code: \(code)")
            return (family, membership)
            
        } catch let error as DataServiceError {
            throw FamilyCreationError.localCreationFailed(error)
        } catch {
            throw FamilyCreationError.localCreationFailed(.invalidData(error.localizedDescription))
        }
    }
    
    /// Sync family and membership to CloudKit with fallback
    private func syncToCloudKitWithFallback(family: Family, membership: Membership) async throws {
        guard !isOfflineMode else {
            // Mark for later sync using SyncManager
            syncManager.markRecordForSync(family)
            syncManager.markRecordForSync(membership)
            try dataService.save()
            print("📱 Offline mode: Family marked for later sync")
            return
        }
        
        updateState(.syncingToCloudKit)
        
        do {
            // Save family to CloudKit
            try await cloudKitService.save(family)
            
            // Save membership to CloudKit
            try await cloudKitService.save(membership)
            
            // Mark as synced in local storage
            family.needsSync = false
            family.lastSyncDate = Date()
            membership.needsSync = false
            membership.lastSyncDate = Date()
            
            try dataService.save()
            
            print("✅ Family synced to CloudKit successfully")
            
        } catch let error as CloudKitError {
            // Fallback to local-only mode using SyncManager
            syncManager.markRecordForSync(family)
            syncManager.markRecordForSync(membership)
            try dataService.save()
            
            print("⚠️ CloudKit sync failed, falling back to local-only: \(error.localizedDescription ?? "Unknown error")")
            
            // Don't throw error - this is a fallback scenario
            // The family is still created locally and will sync later
        } catch {
            // Handle other sync errors
            throw FamilyCreationError.cloudKitSyncFailed(.syncFailed(error))
        }
    }
    
    /// Complete the creation process successfully
    private func completeCreation(family: Family, qrImage: Image?, appState: AppState) async {
        // Update state
        createdFamily = family
        qrCodeImage = qrImage
        
        // Update state to completed
        updateState(.completed)
        
        // Success haptic feedback
        HapticManager.shared.success()
        
        // Show success toast
        let syncStatus = family.needsSync ? " (will sync when online)" : ""
        ToastManager.shared.success("Family '\(family.name)' created successfully!\(syncStatus)")
        
        // Update app state and navigate to dashboard
        if let memberships = family.memberships,
           let currentUserId = appState.currentUser?.id,
           let membership = memberships.first(where: { $0.user?.id == currentUserId }) {
            appState.setFamily(family, membership: membership)
        }
        
        print("🎉 Family creation completed successfully")
    }
    
    /// Handle creation errors with appropriate recovery strategies
    private func handleCreationError(_ error: FamilyCreationError) async {
        print("❌ Family creation error: \(error.technicalDescription)")
        
        // Update state to failed
        updateState(.failed(error))
        
        // Apply recovery strategy if appropriate
        if error.isRetryable && retryCount < maxRetryAttempts {
            print("🔄 Error is retryable, will attempt automatic retry")
            // Automatic retry will be handled by the retry mechanism
        } else {
            // Show error feedback
            HapticManager.shared.error()
            
            // Show error toast for non-retryable errors
            if !error.isRetryable {
                ToastManager.shared.error(error.userFriendlyMessage)
            }
        }
        
        // Record error for analytics
        FamilyCreationAnalytics.recordError(error, in: creationState)
    }
}