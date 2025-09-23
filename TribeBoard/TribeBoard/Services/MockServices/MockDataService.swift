import Foundation
import SwiftUI

/// Mock data service for UI/UX prototype with predefined family and user data
@MainActor
class MockDataService: ObservableObject {
    
    // MARK: - Mock Data Storage
    
    private var mockFamilies: [Family] = []
    private var mockUsers: [UserProfile] = []
    private var mockMemberships: [Membership] = []
    
    // MARK: - Initialization
    
    init() {
        setupMockData()
    }
    
    // MARK: - Mock Data Setup
    
    private func setupMockData() {
        // Create mock users
        let parentUser = UserProfile(
            displayName: "Sarah Mawere",
            appleUserIdHash: "mock_parent_hash_001"
        )
        
        let childUser = UserProfile(
            displayName: "Alex Mawere",
            appleUserIdHash: "mock_child_hash_002"
        )
        
        let guardianUser = UserProfile(
            displayName: "John Mawere",
            appleUserIdHash: "mock_guardian_hash_003"
        )
        
        mockUsers = [parentUser, childUser, guardianUser]
        
        // Create mock family
        let mockFamily = Family(
            name: "Mawere Family",
            code: "TRIBE123",
            createdByUserId: parentUser.id
        )
        
        mockFamilies = [mockFamily]
        
        // Create mock memberships
        let parentMembership = Membership(
            family: mockFamily,
            user: parentUser,
            role: .parentAdmin
        )
        
        let childMembership = Membership(
            family: mockFamily,
            user: childUser,
            role: .kid
        )
        
        let guardianMembership = Membership(
            family: mockFamily,
            user: guardianUser,
            role: .adult
        )
        
        mockMemberships = [parentMembership, childMembership, guardianMembership]
    }
    
    // MARK: - Family Operations
    
    /// Mock family creation - always succeeds with generated code
    func createFamily(name: String, code: String, createdByUserId: UUID) async throws -> Family {
        // Simulate brief loading
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        // Create new mock family
        let newFamily = Family(
            name: name,
            code: code,
            createdByUserId: createdByUserId
        )
        
        mockFamilies.append(newFamily)
        
        return newFamily
    }
    
    /// Mock fetch family by code
    func fetchFamily(byCode code: String) async throws -> Family? {
        // Simulate brief loading
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        return mockFamilies.first { $0.code == code }
    }
    
    /// Mock fetch family by ID
    func fetchFamily(byId id: UUID) async throws -> Family? {
        // Simulate brief loading
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        return mockFamilies.first { $0.id == id }
    }
    
    /// Mock fetch all families
    func fetchAllFamilies() async throws -> [Family] {
        // Simulate brief loading
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        return mockFamilies
    }
    
    /// Mock check if family code exists
    func familyCodeExists(_ code: String) async throws -> Bool {
        // Simulate brief loading
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        return mockFamilies.contains { $0.code == code }
    }
    
    /// Mock check if user can join family
    func canUserJoinFamily(user: UserProfile, family: Family) throws -> Bool {
        // Check if user is already a member
        let existingMembership = mockMemberships.first { 
            $0.family?.id == family.id && $0.user?.id == user.id && $0.status == .active 
        }
        
        return existingMembership == nil
    }
    
    /// Mock get active member count for family
    func getActiveMemberCount(for family: Family) throws -> Int {
        return mockMemberships.filter { 
            $0.family?.id == family.id && $0.status == .active 
        }.count
    }
    
    /// Mock fetch families for user
    func fetchUserFamilies(_ userId: UUID) async throws -> [Family] {
        // Simulate brief loading
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        // Find memberships for user, then return associated families
        let userMemberships = mockMemberships.filter { $0.user?.id == userId }
        return userMemberships.compactMap { $0.family }
    }
    
    // MARK: - UserProfile Operations
    
    /// Mock create user profile
    func createUserProfile(displayName: String, appleUserIdHash: String, avatarUrl: URL? = nil) async throws -> UserProfile {
        // Simulate brief loading
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        let newUser = UserProfile(
            displayName: displayName,
            appleUserIdHash: appleUserIdHash,
            avatarUrl: avatarUrl
        )
        
        mockUsers.append(newUser)
        
        return newUser
    }
    
    /// Mock fetch user profile by Apple ID hash
    func fetchUserProfile(byAppleUserIdHash hash: String) async throws -> UserProfile? {
        // Simulate brief loading
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        return mockUsers.first { $0.appleUserIdHash == hash }
    }
    
    /// Mock fetch user profile by ID
    func fetchUserProfile(byId id: UUID) async throws -> UserProfile? {
        // Simulate brief loading
        try await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
        
        return mockUsers.first { $0.id == id }
    }
    
    // MARK: - Membership Operations
    
    /// Mock create membership
    func createMembership(family: Family, user: UserProfile, role: Role) async throws -> Membership {
        // Simulate brief loading
        try await Task.sleep(nanoseconds: 700_000_000) // 0.7 seconds
        
        // Check for existing membership (mock validation)
        let existingMembership = mockMemberships.first { 
            $0.family?.id == family.id && $0.user?.id == user.id && $0.status == .active 
        }
        
        if existingMembership != nil {
            throw MockDataServiceError.constraintViolation("User is already a member of this family")
        }
        
        let newMembership = Membership(family: family, user: user, role: role)
        mockMemberships.append(newMembership)
        
        return newMembership
    }
    
    /// Mock fetch memberships for user
    func fetchMemberships(forUser user: UserProfile) async throws -> [Membership] {
        // Simulate brief loading
        try await Task.sleep(nanoseconds: 350_000_000) // 0.35 seconds
        
        return mockMemberships.filter { $0.user?.id == user.id }
    }
    
    /// Mock fetch family members
    func fetchFamilyMembers(_ familyId: UUID) async throws -> [Membership] {
        // Simulate brief loading
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        return mockMemberships.filter { $0.family?.id == familyId && $0.status == .active }
    }
    
    /// Mock check if family has parent admin
    func familyHasParentAdmin(_ family: Family) async throws -> Bool {
        // Simulate brief loading
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        return mockMemberships.contains { 
            $0.family?.id == family.id && $0.role == .parentAdmin && $0.status == .active 
        }
    }
    
    // MARK: - Validation Methods
    
    /// Mock family validation - always returns valid for prototype
    func validateFamily(name: String, code: String) async throws -> ValidationResult {
        // Simulate brief validation time
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Basic validation for demo purposes
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ValidationResult(isValid: false, message: "Family name cannot be empty")
        }
        
        if code.count < 6 || code.count > 8 {
            return ValidationResult(isValid: false, message: "Family code must be 6-8 characters")
        }
        
        // Check if code already exists
        if mockFamilies.contains(where: { $0.code == code }) {
            return ValidationResult(isValid: false, message: "Family code already exists")
        }
        
        return ValidationResult(isValid: true, message: "Valid")
    }
    
    /// Mock user profile validation
    func validateUserProfile(displayName: String, appleUserIdHash: String) async throws -> ValidationResult {
        // Simulate brief validation time
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ValidationResult(isValid: false, message: "Display name cannot be empty")
        }
        
        if appleUserIdHash.isEmpty {
            return ValidationResult(isValid: false, message: "Apple user ID hash cannot be empty")
        }
        
        return ValidationResult(isValid: true, message: "Valid")
    }
    
    // MARK: - Synchronous Methods (for compatibility with ViewModels)
    
    /// Synchronous family creation for ViewModel compatibility
    func createFamily(name: String, code: String, createdByUserId: UUID) throws -> Family {
        let newFamily = Family(
            name: name,
            code: code,
            createdByUserId: createdByUserId
        )
        
        mockFamilies.append(newFamily)
        return newFamily
    }
    
    /// Synchronous family code check for ViewModel compatibility
    func familyCodeExists(_ code: String) throws -> Bool {
        return mockFamilies.contains { $0.code == code }
    }
    
    /// Synchronous membership creation for ViewModel compatibility
    func createMembership(family: Family, user: UserProfile, role: Role) throws -> Membership {
        // Check for existing membership (mock validation)
        let existingMembership = mockMemberships.first { 
            $0.family?.id == family.id && $0.user?.id == user.id && $0.status == .active 
        }
        
        if existingMembership != nil {
            throw MockDataServiceError.constraintViolation("User is already a member of this family")
        }
        
        let newMembership = Membership(family: family, user: user, role: role)
        mockMemberships.append(newMembership)
        
        return newMembership
    }
    
    /// Synchronous save method for ViewModel compatibility (no-op for mock)
    func save() throws {
        // Mock save - no actual persistence needed for prototype
        print("📱 MockDataService: Mock save operation completed")
    }
    
    /// Synchronous fetch memberships for user
    func fetchMemberships(forUser user: UserProfile) throws -> [Membership] {
        return mockMemberships.filter { $0.user?.id == user.id }
    }
    
    /// Synchronous fetch family by ID
    func fetchFamily(byId id: UUID) throws -> Family? {
        return mockFamilies.first { $0.id == id }
    }
    
    // MARK: - Demo Helper Methods
    
    /// Get the default mock family for demo purposes
    func getDefaultMockFamily() -> Family? {
        return mockFamilies.first
    }
    
    /// Get mock users for demo purposes
    func getMockUsers() -> [UserProfile] {
        return mockUsers
    }
    
    /// Get mock memberships for demo purposes
    func getMockMemberships() -> [Membership] {
        return mockMemberships
    }
    
    /// Reset mock data to initial state
    func resetMockData() {
        setupMockData()
    }
}

// MARK: - Mock Data Service Errors

enum MockDataServiceError: LocalizedError {
    case validationFailed([String])
    case invalidData(String)
    case notFound(String)
    case constraintViolation(String)
    
    var errorDescription: String? {
        switch self {
        case .validationFailed(let errors):
            return "Validation failed: \(errors.joined(separator: ", "))"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .notFound(let message):
            return "Not found: \(message)"
        case .constraintViolation(let message):
            return "Constraint violation: \(message)"
        }
    }
}

