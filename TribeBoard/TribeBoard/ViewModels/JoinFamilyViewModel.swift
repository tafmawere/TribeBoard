import SwiftUI
import Foundation

/// ViewModel for joining an existing family with mock data and search functionality
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
    
    /// Mock member count for found family
    @Published var memberCount: Int = 0
    
    // MARK: - Private Properties
    
    private let mockFamilies: [Family]
    private let mockMemberCounts: [UUID: Int]
    
    // MARK: - Initialization
    
    init() {
        // Initialize mock data
        let mockData = MockDataGenerator.mockMultipleFamilies()
        self.mockFamilies = mockData.map { $0.family }
        self.mockMemberCounts = Dictionary(
            uniqueKeysWithValues: mockData.map { ($0.family.id, $0.memberCount) }
        )
    }
    
    // MARK: - Public Methods
    
    /// Search for family by code with mock implementation
    func searchFamily(by code: String) async {
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a family code"
            return
        }
        
        isSearching = true
        errorMessage = nil
        foundFamily = nil
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Mock family search logic
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if let family = mockFamilies.first(where: { $0.code.uppercased() == trimmedCode }) {
            foundFamily = family
            memberCount = mockMemberCounts[family.id] ?? 0
            showConfirmation = true
        } else {
            // Mock some specific error scenarios
            switch trimmedCode {
            case "ERROR":
                errorMessage = "Network error occurred. Please try again."
            case "FULL":
                errorMessage = "This family is currently full and not accepting new members."
            default:
                errorMessage = "Family not found. Please check the code and try again."
            }
        }
        
        isSearching = false
    }
    
    /// Mock QR code scanning functionality
    func scanQRCode() async {
        isSearching = true
        errorMessage = nil
        
        // Simulate QR scanning delay
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Mock QR scan result - randomly select a family code
        let mockScannedCodes = ["SMI123", "GAR456", "CHE789", "DEMO01"]
        let scannedCode = mockScannedCodes.randomElement() ?? "SMI123"
        
        familyCode = scannedCode
        isSearching = false
        
        // Automatically search for the scanned code
        await searchFamily(by: scannedCode)
    }
    
    /// Join the found family with mock implementation
    func joinFamily() async {
        guard foundFamily != nil else {
            errorMessage = "No family selected to join"
            return
        }
        
        isJoining = true
        errorMessage = nil
        
        // Simulate join operation delay
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Mock join logic - always succeeds for demo
        // In real implementation, this would create a Membership record
        
        isJoining = false
        showConfirmation = false
        
        // Success - the view will handle navigation to role selection
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
    
    /// Check if family code format is valid
    var isValidCodeFormat: Bool {
        let trimmed = familyCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 4 && trimmed.count <= 8 && trimmed.allSatisfy { $0.isLetter || $0.isNumber }
    }
    
    /// Check if search can be performed
    var canSearch: Bool {
        return !familyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSearching
    }
}

// MARK: - Mock Error Scenarios

extension JoinFamilyViewModel {
    /// Test different error scenarios for development
    func testErrorScenario(_ scenario: String) async {
        familyCode = scenario
        await searchFamily(by: scenario)
    }
}