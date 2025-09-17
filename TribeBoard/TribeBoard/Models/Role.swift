import Foundation

/// Represents the different roles a family member can have
enum Role: String, CaseIterable, Codable, Sendable {
    case parentAdmin = "parent_admin"
    case adult = "adult"
    case kid = "kid"
    case visitor = "visitor"
    
    /// Human-readable display name for the role
    var displayName: String {
        switch self {
        case .parentAdmin:
            return "Parent Admin"
        case .adult:
            return "Adult"
        case .kid:
            return "Kid"
        case .visitor:
            return "Visitor"
        }
    }
    
    /// Description of the role's capabilities
    var description: String {
        switch self {
        case .parentAdmin:
            return "Full access to manage family members and settings"
        case .adult:
            return "Standard family member with full app access"
        case .kid:
            return "Limited access appropriate for children"
        case .visitor:
            return "Temporary access with restricted permissions"
        }
    }
}

/// Represents the status of a family membership
enum MembershipStatus: String, Codable, Sendable {
    case active = "active"
    case invited = "invited"
    case removed = "removed"
    
    var displayName: String {
        switch self {
        case .active:
            return "Active"
        case .invited:
            return "Invited"
        case .removed:
            return "Removed"
        }
    }
}