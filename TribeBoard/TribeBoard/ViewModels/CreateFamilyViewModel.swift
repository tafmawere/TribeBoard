import SwiftUI
import Foundation

/// ViewModel for family creation with real CloudKit backend integration
@MainActor
class CreateFamilyViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Family name input by user
    @Published var familyName: String = ""
    
    /// Loading state during family creation
    @Published var isCreating: Bool = false
    
    /// Created family after successful creation
    @Published var createdFamily: Family?
    
    /// Generated QR code image for the family code
    @Published var qrCodeImage: Image?
    
    /// Error message for display
    @Published var errorMessage: String?
    
    /// Validation state for family name
    @Published var isValidFamilyName: Bool = false
    
    // MARK: - Dependencies
    
    private let dataService: DataService
    private let cloudKitService: CloudKitService
    private let qrCodeService: QRCodeService
    private let codeGenerator: CodeGenerator
    
    // MARK: - Computed Properties
    
    /// Validation state for family name using the new validation system
    var familyNameValidation: ValidationState {
        return ValidationRules.familyName.validate(familyName)
    }
    
    /// Whether the create button should be enabled
    var canCreateFamily: Bool {
        return isValidFamilyName && !isCreating && !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Initialization
    
    init(dataService: DataService, cloudKitService: CloudKitService, qrCodeService: QRCodeService = QRCodeService(), codeGenerator: CodeGenerator = CodeGenerator()) {
        self.dataService = dataService
        self.cloudKitService = cloudKitService
        self.qrCodeService = qrCodeService
        self.codeGenerator = codeGenerator
        
        // Set up validation
        setupValidation()
    }
    
    // MARK: - Public Methods
    
    /// Create a new family with real CloudKit backend integration
    func createFamily(with appState: AppState) async {
        guard canCreateFamily else { return }
        
        isCreating = true
        errorMessage = nil
        
        do {
            guard let currentUser = appState.currentUser else {
                throw CreateFamilyError.userNotAuthenticated
            }
            
            let trimmedName = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Generate unique family code with collision detection
            let familyCode = try await generateUniqueFamilyCode()
            
            // Create family in local storage first
            let family = try dataService.createFamily(
                name: trimmedName,
                code: familyCode,
                createdByUserId: currentUser.id
            )
            
            // Create membership for the creator as Parent Admin
            let membership = try dataService.createMembership(
                family: family,
                user: currentUser,
                role: .parentAdmin
            )
            
            // Generate QR code
            let qrImage = qrCodeService.generateQRCode(from: familyCode)
            
            // Sync to CloudKit
            try await syncToCloudKit(family: family, membership: membership)
            
            // Update state
            createdFamily = family
            qrCodeImage = qrImage
            
            // Success haptic feedback
            HapticManager.shared.success()
            
            // Show success toast
            ToastManager.shared.success("Family '\(trimmedName)' created successfully!")
            
            // Update app state and navigate to dashboard
            appState.setFamily(family, membership: membership)
            
        } catch {
            // Handle specific errors
            if let createError = error as? CreateFamilyError {
                errorMessage = createError.localizedDescription
            } else if let dataError = error as? DataServiceError {
                errorMessage = dataError.localizedDescription
            } else if let cloudKitError = error as? CloudKitError {
                errorMessage = "Sync failed: \(cloudKitError.localizedDescription). Changes saved locally."
            } else {
                errorMessage = "Failed to create family: \(error.localizedDescription)"
            }
            
            HapticManager.shared.error()
        }
        
        isCreating = false
    }
    
    /// Clear any error messages
    func clearError() {
        errorMessage = nil
    }
    
    /// Reset the form
    func resetForm() {
        familyName = ""
        createdFamily = nil
        qrCodeImage = nil
        errorMessage = nil
        isCreating = false
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
    
    /// Generate a unique family code with collision detection
    private func generateUniqueFamilyCode() async throws -> String {
        return try await codeGenerator.generateUniqueCode { [weak self] code in
            guard let self = self else { return false }
            
            // Check local storage first
            let localExists = try self.dataService.familyCodeExists(code)
            if localExists {
                return false // Code exists locally
            }
            
            // Check CloudKit for collision
            let cloudKitRecord = try await self.cloudKitService.fetchFamily(byCode: code)
            return cloudKitRecord == nil // Return true if code is unique (not found)
        }
    }
    
    /// Sync family and membership to CloudKit
    private func syncToCloudKit(family: Family, membership: Membership) async throws {
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
    }
}

// MARK: - Error Types

enum CreateFamilyError: LocalizedError {
    case userNotAuthenticated
    case invalidFamilyName
    case familyCodeExists
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated. Please sign in again."
        case .invalidFamilyName:
            return "Please enter a valid family name."
        case .familyCodeExists:
            return "Family code already exists. Please try again."
        case .networkUnavailable:
            return "Network unavailable. Please check your connection."
        }
    }
}