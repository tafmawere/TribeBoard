import Foundation

/// Utility functions for converting between different model types
/// Used to bridge between SwiftData models and in-memory models
struct TypeConversionUtilities {
    
    // MARK: - Membership to InMemoryMember Conversion
    
    /// Converts a Membership object to an InMemoryMember
    /// - Parameter membership: The Membership object to convert
    /// - Returns: An InMemoryMember object, or nil if conversion fails
    static func convertToInMemoryMember(_ membership: Membership) -> InMemoryMember? {
        guard let userId = membership.userId,
              let familyId = membership.familyId else {
            return nil
        }
        
        let inMemoryRole = convertToInMemoryRole(membership.role)
        
        return InMemoryMember(
            id: membership.id,
            userId: userId,
            familyId: familyId,
            role: inMemoryRole,
            joinedAt: membership.joinedAt
        )
    }
    
    // MARK: - UserProfile to InMemoryUser Conversion
    
    /// Converts a UserProfile object to an InMemoryUser
    /// - Parameter userProfile: The UserProfile object to convert
    /// - Returns: An InMemoryUser object, or nil if conversion fails
    static func convertToInMemoryUser(_ userProfile: UserProfile?) -> InMemoryUser? {
        guard let userProfile = userProfile else {
            return nil
        }
        
        return InMemoryUser(
            id: userProfile.id,
            name: userProfile.displayName,
            createdAt: userProfile.createdAt
        )
    }
    
    // MARK: - Role Conversion
    
    /// Converts a Role to an InMemoryRole
    /// - Parameter role: The Role to convert
    /// - Returns: The corresponding InMemoryRole
    static func convertToInMemoryRole(_ role: Role) -> InMemoryRole {
        switch role {
        case .parentAdmin:
            return .parent
        case .adult:
            return .guardian
        case .kid:
            return .child
        case .visitor:
            return .helper
        }
    }
    
    /// Converts an InMemoryRole to a Role
    /// - Parameter inMemoryRole: The InMemoryRole to convert
    /// - Returns: The corresponding Role
    static func convertToRole(_ inMemoryRole: InMemoryRole) -> Role {
        switch inMemoryRole {
        case .parent:
            return .parentAdmin
        case .guardian:
            return .adult
        case .child:
            return .kid
        case .helper:
            return .visitor
        }
    }
    
    // MARK: - Error Handling for Edge Cases
    
    /// Validates that a Membership can be converted to InMemoryMember
    /// - Parameter membership: The Membership to validate
    /// - Returns: True if conversion is possible, false otherwise
    static func canConvertMembership(_ membership: Membership) -> Bool {
        return membership.userId != nil && membership.familyId != nil
    }
    
    /// Validates that a UserProfile can be converted to InMemoryUser
    /// - Parameter userProfile: The UserProfile to validate
    /// - Returns: True if conversion is possible, false otherwise
    static func canConvertUserProfile(_ userProfile: UserProfile?) -> Bool {
        guard let userProfile = userProfile else { return false }
        return !userProfile.displayName.isEmpty
    }
}

// MARK: - Convenience Extensions

extension Membership {
    /// Converts this Membership to an InMemoryMember
    /// - Returns: An InMemoryMember object, or nil if conversion fails
    func toInMemoryMember() -> InMemoryMember? {
        return TypeConversionUtilities.convertToInMemoryMember(self)
    }
}

extension UserProfile {
    /// Converts this UserProfile to an InMemoryUser
    /// - Returns: An InMemoryUser object, or nil if conversion fails
    func toInMemoryUser() -> InMemoryUser? {
        return TypeConversionUtilities.convertToInMemoryUser(self)
    }
}

extension Role {
    /// Converts this Role to an InMemoryRole
    /// - Returns: The corresponding InMemoryRole
    func toInMemoryRole() -> InMemoryRole {
        return TypeConversionUtilities.convertToInMemoryRole(self)
    }
}

extension InMemoryRole {
    /// Converts this InMemoryRole to a Role
    /// - Returns: The corresponding Role
    func toRole() -> Role {
        return TypeConversionUtilities.convertToRole(self)
    }
}