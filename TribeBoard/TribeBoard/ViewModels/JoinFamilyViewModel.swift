import SwiftUI
import Foundation

/// ViewModel for joining an existing family with SwiftUI-compatible in-memory storage
@MainActor
class JoinFamilyViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Family code entered by user
    @Published var familyCode: String = ""
    
    /// Loading state for family search operations
    @Published var isSearching: Bool = false
    
    /// Loading state for join operations
    @Published var isJoining: Bool = false
    
    /// Found family from search
    @Published var foundFamily: InMemoryFamily?
    
    /// Show confirmation dialog
    @Published var showConfirmation: Bool = false
    
    /// Current error, if any
    @Published var currentError: FamilyJoinError?
    
    /// Real member count for found family
    @Published var memberCount: Int = 0
    
    /// Real-time validation state for family code
    @Published var isValidCode: Bool = false
    
    /// Show error alert
    @Published var showErrorAlert: Bool = false
    
    /// Show success alert
    @Published var showSuccessAlert: Bool = false
    
    // MARK: - Dependencies
    
    private let dataManager: InMemoryFamilyDataManager
    
    // MARK: - Initialization
    
    init(dataManager: InMemoryFamilyDataManager? = nil) {
        self.dataManager = dataManager ?? InMemoryFamilyDataManager.shared
        
        // Set up real-time validation for family code
        setupCodeValidation()
    }
    
    // MARK: - Private Setup Methods
    
    /// Sets up real-time validation for family code input
    private func setupCodeValidation() {
        // Monitor family code changes for real-time validation
        $familyCode
            .map { code in
                FamilyCodeGenerator.isValidCodeFormat(code.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            .assign(to: &$isValidCode)
    }
    
    // MARK: - Public Methods
    
    /// Search for family by code with SwiftUI-compatible in-memory storage
    func searchFamily(by code: String) async {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedCode.isEmpty else {
            showError(.emptyCode)
            return
        }
        
        guard FamilyCodeGenerator.isValidCodeFormat(trimmedCode) else {
            showError(.invalidCode)
            return
        }
        
        isSearching = true
        clearError()
        foundFamily = nil
        memberCount = 0
        
        // Simulate brief loading for better UX
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let uppercasedCode = trimmedCode.uppercased()
        
        if let family = dataManager.findFamily(byCode: uppercasedCode) {
            await handleFoundFamily(family)
        } else {
            showError(.familyNotFound)
        }
        
        isSearching = false
    }
    
    /// Handle scanned QR code from camera view
    func handleScannedCode(_ code: String) async {
        familyCode = code
        await searchFamily(by: code)
    }
    
    /// Join the found family with SwiftUI-compatible in-memory storage
    func joinFamily(with appState: AppState) async {
        guard let family = foundFamily else {
            showError(.familyNotFound)
            return
        }
        
        guard let currentUser = appState.currentUser else {
            showError(.userNotFound)
            return
        }
        
        isJoining = true
        clearError()
        
        // Simulate brief loading for better UX
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Convert UserProfile to InMemoryUser
        let inMemoryUser = InMemoryUser(
            id: currentUser.id,
            name: currentUser.displayName,
            createdAt: currentUser.createdAt
        )
        
        // Check if user is already a member
        if family.member(withUserId: inMemoryUser.id) != nil {
            showError(.alreadyMember)
            isJoining = false
            return
        }
        
        // Add user to family with default Parent role (role selection happens next)
        let success = dataManager.addMemberToFamily(
            familyId: family.id,
            user: inMemoryUser,
            role: .parent // Default role, will be changed in role selection
        )
        
        if success {
            // Update app state with the family
            appState.setFamily(family)
            
            isJoining = false
            showConfirmation = false
            showSuccess()
            
            // Show success toast
            ToastManager.shared.success("Successfully joined \(family.name)!")
            
            // Navigation to role selection will be handled by the view
        } else {
            showError(.unknownError)
            isJoining = false
        }
    }
    
    /// Cancel the join operation
    func cancelJoin() {
        showConfirmation = false
        foundFamily = nil
        memberCount = 0
        clearError()
    }
    
    /// Clear error message and alert state
    func clearError() {
        currentError = nil
        showErrorAlert = false
    }
    
    /// Show error alert with the specified error
    func showError(_ error: FamilyJoinError) {
        currentError = error
        showErrorAlert = true
        HapticManager.shared.error()
        ToastManager.shared.error(error.localizedDescription)
    }
    
    /// Show success alert
    func showSuccess() {
        showSuccessAlert = true
        HapticManager.shared.success()
    }
    
    /// Reset all state
    func reset() {
        familyCode = ""
        foundFamily = nil
        showConfirmation = false
        currentError = nil
        showErrorAlert = false
        showSuccessAlert = false
        memberCount = 0
        isSearching = false
        isJoining = false
        isValidCode = false
    }
    
    // MARK: - Validation
    
    /// Check if search can be performed
    var canSearch: Bool {
        return isValidCode && !isSearching && !familyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Get validation message for family code input
    var codeValidationMessage: String? {
        let trimmedCode = familyCode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedCode.isEmpty {
            return nil
        }
        
        if !isValidCode {
            return "Code must be 6 characters with letters and numbers"
        }
        
        return nil
    }
    
    /// Get current error message for display
    var errorMessage: String? {
        return currentError?.localizedDescription
    }
    
    // MARK: - Private Methods
    
    /// Handle found family and get member count
    private func handleFoundFamily(_ family: InMemoryFamily) async {
        foundFamily = family
        memberCount = family.members.count
        showConfirmation = true
    }
}

