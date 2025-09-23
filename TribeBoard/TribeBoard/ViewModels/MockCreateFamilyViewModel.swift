import SwiftUI
import Foundation

/// Mock ViewModel for family creation in UI/UX prototype with instant success responses
@MainActor
class MockCreateFamilyViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Family name input by user
    @Published var familyName: String = ""
    
    /// Whether the creation process is currently active
    @Published var isCreating: Bool = false
    
    /// Created family after successful creation
    @Published var createdFamily: Family?
    
    /// Generated QR code image for the family code
    @Published var qrCodeImage: Image?
    
    /// Current error message for display
    @Published var errorMessage: String?
    
    /// Validation state for family name
    @Published var isValidFamilyName: Bool = false
    
    // MARK: - Dependencies
    
    let mockDataService: MockDataService
    let mockCloudKitService: MockCloudKitService
    private let qrCodeService: QRCodeService
    private let codeGenerator: CodeGenerator
    
    // MARK: - Computed Properties
    
    /// Whether the create button should be enabled
    var canCreateFamily: Bool {
        return isValidFamilyName && 
               !isCreating && 
               !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Whether the creation process has completed successfully
    var isCompleted: Bool {
        return createdFamily != nil
    }
    
    // MARK: - Initialization
    
    init(mockDataService: MockDataService, mockCloudKitService: MockCloudKitService, qrCodeService: QRCodeService = QRCodeService(), codeGenerator: CodeGenerator = CodeGenerator()) {
        self.mockDataService = mockDataService
        self.mockCloudKitService = mockCloudKitService
        self.qrCodeService = qrCodeService
        self.codeGenerator = codeGenerator
        
        // Set up validation
        setupValidation()
    }
    
    // MARK: - Public Methods
    
    /// Create a new family with mock operations and instant success
    func createFamily(with appState: AppState) async {
        guard canCreateFamily else { return }
        
        // Clear any previous errors
        errorMessage = nil
        isCreating = true
        
        do {
            // Validate user authentication
            guard let currentUser = appState.currentUser else {
                throw MockFamilyCreationError.userNotAuthenticated
            }
            
            // Generate unique family code
            let familyCode = try await generateMockFamilyCode()
            
            // Create family with mock service
            let family = try await mockDataService.createFamily(
                name: familyName.trimmingCharacters(in: .whitespacesAndNewlines),
                code: familyCode,
                createdByUserId: currentUser.id
            )
            
            // Create membership for the creator as Parent Admin
            let membership = try await mockDataService.createMembership(
                family: family,
                user: currentUser,
                role: .parentAdmin
            )
            
            // Generate QR code
            let qrImage = qrCodeService.generateQRCode(from: familyCode)
            
            // Mock CloudKit sync (always succeeds)
            try await mockCloudKitService.save(family)
            try await mockCloudKitService.save(membership)
            
            // Complete creation successfully
            await completeCreation(family: family, qrImage: qrImage, appState: appState)
            
        } catch {
            await handleCreationError(error)
        }
        
        isCreating = false
    }
    
    /// Clear any error messages
    func clearError() {
        errorMessage = nil
    }
    
    /// Reset the form and state
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
    
    /// Generate a mock family code that's guaranteed to be unique
    private func generateMockFamilyCode() async throws -> String {
        // For the prototype, generate codes that look realistic but are guaranteed unique
        let baseCode = codeGenerator.generateRandomCode()
        
        // Check if code exists in mock data
        let codeExists = try await mockDataService.familyCodeExists(baseCode)
        
        if codeExists {
            // Generate a new code with a suffix to ensure uniqueness
            let uniqueCode = baseCode.prefix(4) + String(format: "%02d", Int.random(in: 10...99))
            return String(uniqueCode)
        }
        
        return baseCode
    }
    
    /// Complete the creation process successfully
    private func completeCreation(family: Family, qrImage: Image?, appState: AppState) async {
        // Update state
        createdFamily = family
        qrCodeImage = qrImage
        
        // Success haptic feedback
        HapticManager.shared.success()
        
        // Show success toast
        ToastManager.shared.success("Family '\(family.name)' created successfully!")
        
        // Add a small delay for UI smoothness
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Update app state and navigate to role selection
        let membership = Membership(family: family, user: appState.currentUser!, role: .parentAdmin)
        appState.setFamily(family, membership: membership)
        appState.navigateTo(.roleSelection)
        
        print("🎉 Mock family creation completed successfully")
    }
    
    /// Handle creation errors with appropriate feedback
    private func handleCreationError(_ error: Error) async {
        print("❌ Mock family creation error: \(error.localizedDescription)")
        
        // Set error message for display
        if let mockError = error as? MockFamilyCreationError {
            errorMessage = mockError.userFriendlyMessage
        } else {
            errorMessage = "Failed to create family. Please try again."
        }
        
        // Show error feedback
        HapticManager.shared.error()
        ToastManager.shared.error(errorMessage ?? "Creation failed")
    }
}

// MARK: - Mock Error Types

enum MockFamilyCreationError: LocalizedError {
    case userNotAuthenticated
    case invalidFamilyName(String)
    case codeGenerationFailed
    case mockServiceError(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated"
        case .invalidFamilyName(let message):
            return "Invalid family name: \(message)"
        case .codeGenerationFailed:
            return "Failed to generate family code"
        case .mockServiceError(let message):
            return "Service error: \(message)"
        }
    }
    
    var userFriendlyMessage: String {
        switch self {
        case .userNotAuthenticated:
            return "Please sign in to create a family"
        case .invalidFamilyName:
            return "Please enter a valid family name (2-50 characters)"
        case .codeGenerationFailed:
            return "Unable to generate family code. Please try again."
        case .mockServiceError:
            return "Something went wrong. Please try again."
        }
    }
}