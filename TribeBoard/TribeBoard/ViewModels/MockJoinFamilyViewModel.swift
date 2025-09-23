import SwiftUI
import Foundation

/// Mock ViewModel for joining an existing family in UI/UX prototype with instant responses
@MainActor
class MockJoinFamilyViewModel: ObservableObject {
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
    
    /// Mock member count for found family
    @Published var memberCount: Int = 0
    
    // MARK: - Dependencies
    
    let mockDataService: MockDataService
    let mockCloudKitService: MockCloudKitService
    private let qrCodeService: QRCodeService
    
    // MARK: - Computed Properties
    
    /// Check if family code format is valid
    var isValidCodeFormat: Bool {
        let trimmed = familyCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 4 && trimmed.count <= 8 && 
               trimmed.allSatisfy { $0.isLetter || $0.isNumber }
    }
    
    /// Check if search can be performed
    var canSearch: Bool {
        return !familyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
               !isSearching && 
               isValidCodeFormat
    }
    
    // MARK: - Initialization
    
    init(mockDataService: MockDataService, mockCloudKitService: MockCloudKitService, qrCodeService: QRCodeService = QRCodeService()) {
        self.mockDataService = mockDataService
        self.mockCloudKitService = mockCloudKitService
        self.qrCodeService = qrCodeService
    }
    
    // MARK: - Public Methods
    
    /// Search for family by code with mock instant response
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
            
            // Simulate brief search time for realistic feel
            try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
            
            // Search in mock data service
            if let family = try await mockDataService.fetchFamily(byCode: trimmedCode) {
                await handleFoundFamily(family)
            } else {
                // For demo purposes, create some mock families that can be found
                if trimmedCode == "DEMO123" || trimmedCode == "TEST456" || trimmedCode == "FAMILY1" {
                    let mockFamily = Family(
                        name: getMockFamilyName(for: trimmedCode),
                        code: trimmedCode,
                        createdByUserId: UUID()
                    )
                    await handleFoundFamily(mockFamily)
                } else {
                    errorMessage = "Family not found. Please check the code and try again."
                    HapticManager.shared.error()
                }
            }
            
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            HapticManager.shared.error()
        }
        
        isSearching = false
    }
    
    /// Mock QR code scanning functionality
    func scanQRCode() async {
        isSearching = true
        errorMessage = nil
        
        // Simulate scanning time
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // For prototype, simulate finding a family via QR scan
        let mockQRCodes = ["TRIBE123", "DEMO123", "TEST456"]
        let randomCode = mockQRCodes.randomElement() ?? "TRIBE123"
        
        familyCode = randomCode
        await searchFamily(by: randomCode)
        
        isSearching = false
    }
    
    /// Handle scanned QR code from camera view
    func handleScannedCode(_ code: String) async {
        familyCode = code
        await searchFamily(by: code)
    }
    
    /// Join the found family with mock instant success
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
            // Simulate join time
            try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
            
            // Create membership with default Adult role
            let membership = try await mockDataService.createMembership(
                family: family,
                user: currentUser,
                role: .adult
            )
            
            // Mock CloudKit sync (always succeeds)
            try await mockCloudKitService.save(membership)
            
            // Success haptic feedback
            HapticManager.shared.success()
            
            // Show success toast
            ToastManager.shared.success("Joined \(family.name) successfully!")
            
            // Update app state
            appState.setFamily(family, membership: membership)
            
            isJoining = false
            showConfirmation = false
            
        } catch {
            if let mockError = error as? MockJoinFamilyError {
                errorMessage = mockError.userFriendlyMessage
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
    
    // MARK: - Private Methods
    
    /// Handle found family and set mock member count
    private func handleFoundFamily(_ family: Family) async {
        foundFamily = family
        
        // Set mock member count based on family
        memberCount = getMockMemberCount(for: family.code)
        
        showConfirmation = true
        HapticManager.shared.success()
    }
    
    /// Get mock family name for demo codes
    private func getMockFamilyName(for code: String) -> String {
        switch code {
        case "DEMO123":
            return "Demo Family"
        case "TEST456":
            return "Test Family"
        case "FAMILY1":
            return "Sample Family"
        default:
            return "Mock Family"
        }
    }
    
    /// Get mock member count for demo purposes
    private func getMockMemberCount(for code: String) -> Int {
        switch code {
        case "TRIBE123":
            return 3 // Matches the default mock family
        case "DEMO123":
            return 4
        case "TEST456":
            return 2
        case "FAMILY1":
            return 5
        default:
            return Int.random(in: 2...6)
        }
    }
}

// MARK: - Mock Error Types

enum MockJoinFamilyError: LocalizedError {
    case alreadyMember
    case familyNotFound
    case networkUnavailable
    case mockServiceError(String)
    
    var errorDescription: String? {
        switch self {
        case .alreadyMember:
            return "Already a member of this family"
        case .familyNotFound:
            return "Family not found"
        case .networkUnavailable:
            return "Network unavailable"
        case .mockServiceError(let message):
            return "Service error: \(message)"
        }
    }
    
    var userFriendlyMessage: String {
        switch self {
        case .alreadyMember:
            return "You are already a member of this family"
        case .familyNotFound:
            return "Family not found. Please check the code and try again."
        case .networkUnavailable:
            return "Network unavailable. Please check your connection."
        case .mockServiceError:
            return "Something went wrong. Please try again."
        }
    }
}