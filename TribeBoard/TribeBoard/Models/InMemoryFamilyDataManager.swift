import Foundation
import SwiftUI

/// SwiftUI-compatible centralized data manager for in-memory family and user storage
/// Provides reactive updates through @Published properties for SwiftUI views
@MainActor
class InMemoryFamilyDataManager: ObservableObject {
    
    // MARK: - Published Properties for SwiftUI Reactivity
    
    /// All families stored in memory during app session
    @Published var families: [InMemoryFamily] = []
    
    /// All users stored in memory during app session
    @Published var users: [InMemoryUser] = []
    
    /// Current loading state for SwiftUI progress indicators
    @Published var isLoading: Bool = false
    
    /// Current error state for SwiftUI error handling
    @Published var lastError: Error?
    
    // MARK: - Singleton Instance
    
    /// Shared instance for app-wide access
    static let shared = InMemoryFamilyDataManager()
    
    private init() {
        // Private initializer to enforce singleton pattern
    }
    
    // MARK: - Family Operations
    
    /// Creates a new family with generated code and adds it to storage
    /// - Parameters:
    ///   - name: The name of the family
    ///   - createdByUserId: The ID of the user creating the family
    /// - Returns: The newly created InMemoryFamily
    func createFamily(name: String, createdByUserId: UUID) -> InMemoryFamily {
        isLoading = true
        defer { isLoading = false }
        
        // Generate unique family code
        var familyCode: String
        repeat {
            familyCode = FamilyCodeGenerator.generateCode()
        } while families.contains { $0.code == familyCode }
        
        // Create new family
        let newFamily = InMemoryFamily(name: name, code: familyCode)
        
        // Add to families array (triggers SwiftUI update)
        families.append(newFamily)
        
        return newFamily
    }
    
    /// Finds a family by its unique code
    /// - Parameter code: The family code to search for
    /// - Returns: The matching InMemoryFamily or nil if not found
    func findFamily(byCode code: String) -> InMemoryFamily? {
        return families.first { $0.code.uppercased() == code.uppercased() }
    }
    
    /// Adds a member to an existing family
    /// - Parameters:
    ///   - familyId: The ID of the family to add the member to
    ///   - user: The user to add as a member
    ///   - role: The role to assign to the user
    /// - Returns: True if successful, false if family not found or user already a member
    @discardableResult
    func addMemberToFamily(familyId: UUID, user: InMemoryUser, role: InMemoryRole) -> Bool {
        guard let familyIndex = families.firstIndex(where: { $0.id == familyId }) else {
            return false
        }
        
        let family = families[familyIndex]
        
        // Check if user is already a member
        if family.member(withUserId: user.id) != nil {
            return false
        }
        
        // Create new member
        let newMember = InMemoryMember(userId: user.id, familyId: familyId, role: role)
        
        // Add member to family (triggers SwiftUI update through family's @Published property)
        family.addMember(newMember)
        
        // Ensure user exists in users array
        if !users.contains(where: { $0.id == user.id }) {
            users.append(user)
        }
        
        return true
    }
    
    // MARK: - User Operations
    
    /// Creates a new user and adds it to storage
    /// - Parameter name: The name of the user
    /// - Returns: The newly created InMemoryUser
    func createUser(name: String) -> InMemoryUser {
        let newUser = InMemoryUser(name: name)
        
        // Add to users array (triggers SwiftUI update)
        users.append(newUser)
        
        return newUser
    }
    
    /// Updates a user's role in a specific family
    /// - Parameters:
    ///   - userId: The ID of the user whose role to update
    ///   - familyId: The ID of the family where the role should be updated
    ///   - newRole: The new role to assign
    /// - Returns: True if successful, false if user or family not found
    @discardableResult
    func updateUserRole(userId: UUID, familyId: UUID, newRole: InMemoryRole) -> Bool {
        guard let familyIndex = families.firstIndex(where: { $0.id == familyId }) else {
            return false
        }
        
        let family = families[familyIndex]
        
        // Find member in family
        guard let memberIndex = family.members.firstIndex(where: { $0.userId == userId }) else {
            return false
        }
        
        // Update role (triggers SwiftUI update through family's @Published property)
        family.members[memberIndex].role = newRole
        
        return true
    }
    
    // MARK: - Utility Methods
    
    /// Gets a user by ID
    /// - Parameter userId: The ID of the user to find
    /// - Returns: The matching InMemoryUser or nil if not found
    func getUser(byId userId: UUID) -> InMemoryUser? {
        return users.first { $0.id == userId }
    }
    
    /// Gets all members of a specific family with their user details
    /// - Parameter familyId: The ID of the family
    /// - Returns: Array of tuples containing member and user information
    func getFamilyMembersWithUserDetails(familyId: UUID) -> [(member: InMemoryMember, user: InMemoryUser?)] {
        guard let family = families.first(where: { $0.id == familyId }) else {
            return []
        }
        
        return family.members.map { member in
            let user = getUser(byId: member.userId)
            return (member: member, user: user)
        }
    }
    
    /// Validates if a family code format is correct
    /// - Parameter code: The code to validate
    /// - Returns: True if the code format is valid
    func isValidFamilyCodeFormat(_ code: String) -> Bool {
        return FamilyCodeGenerator.isValidCodeFormat(code)
    }
    
    /// Clears all stored data (useful for testing or app reset)
    func clearAllData() {
        families.removeAll()
        users.removeAll()
        lastError = nil
        isLoading = false
    }
    
    // MARK: - Error Handling
    
    /// Clears the last error state
    func clearError() {
        lastError = nil
    }
    
    /// Sets an error state for SwiftUI error handling
    /// - Parameter error: The error to set
    func setError(_ error: Error) {
        lastError = error
    }
}

// MARK: - Error Types

/// Errors that can occur during family data management
enum FamilyDataManagerError: LocalizedError {
    case familyNotFound
    case userNotFound
    case userAlreadyMember
    case invalidFamilyCode
    case familyCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .familyNotFound:
            return "Family not found"
        case .userNotFound:
            return "User not found"
        case .userAlreadyMember:
            return "User is already a member of this family"
        case .invalidFamilyCode:
            return "Invalid family code format"
        case .familyCreationFailed:
            return "Failed to create family"
        }
    }
}