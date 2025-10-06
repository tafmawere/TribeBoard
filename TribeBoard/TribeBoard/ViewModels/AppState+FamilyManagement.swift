import SwiftUI
import Foundation

// MARK: - AppState Extension for Family Management
extension AppState {
    
    /// Convenience method to create a new in-memory user for family setup
    func createInMemoryUser(name: String) -> InMemoryUser {
        let user = InMemoryUser(name: name)
        setInMemoryUser(user)
        return user
    }
    
    /// Convenience method to validate family setup state
    func validateFamilySetupState() -> Bool {
        guard let family = currentInMemoryFamily,
              let user = currentInMemoryUser else {
            showFamilyError("Missing family or user information")
            return false
        }
        
        if family.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showFamilyError("Family name cannot be empty")
            return false
        }
        
        if user.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showFamilyError("User name cannot be empty")
            return false
        }
        
        return true
    }
    
    /// Get the current user's membership in the in-memory family
    func getCurrentUserMembership() -> InMemoryMember? {
        guard let user = currentInMemoryUser,
              let family = currentInMemoryFamily else { return nil }
        
        return family.member(withUserId: user.id)
    }
    
    /// Check if the current user can perform admin actions in the in-memory family
    func canCurrentUserPerformAdminActions() -> Bool {
        guard let membership = getCurrentUserMembership() else { return false }
        return membership.role == .parent
    }
    
    /// Get all family members except the current user
    func getOtherFamilyMembers() -> [InMemoryMember] {
        guard let currentUser = currentInMemoryUser else { return currentFamilyMembers }
        
        return currentFamilyMembers.filter { $0.userId != currentUser.id }
    }
    
    /// Format family code for display (adds spaces for readability)
    func formattedFamilyCode() -> String {
        let code = currentFamilyCode
        guard code.count == 6 else { return code }
        
        let index = code.index(code.startIndex, offsetBy: 3)
        return String(code[..<index]) + " " + String(code[index...])
    }
}