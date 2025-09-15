import Foundation

/// Provides mock data for testing UI components and prototyping
struct MockDataGenerator {
    
    // MARK: - Family Mock Data
    
    /// Generates a complete family with members for testing
    static func mockFamilyWithMembers() -> (family: Family, users: [UserProfile], memberships: [Membership]) {
        let family = Family.mock(name: "The Demo Family", code: "DEMO01")
        
        let users = [
            UserProfile.mock(displayName: "Sarah Johnson", appleUserIdHash: "hash_sarah"),
            UserProfile.mock(displayName: "Mike Johnson", appleUserIdHash: "hash_mike"),
            UserProfile.mock(displayName: "Emma Johnson", appleUserIdHash: "hash_emma"),
            UserProfile.mock(displayName: "Alex Johnson", appleUserIdHash: "hash_alex")
        ]
        
        let memberships = [
            Membership.mock(familyId: family.id, userId: users[0].id, role: .parentAdmin),
            Membership.mock(familyId: family.id, userId: users[1].id, role: .adult),
            Membership.mock(familyId: family.id, userId: users[2].id, role: .kid),
            Membership.mock(familyId: family.id, userId: users[3].id, role: .visitor, status: .invited)
        ]
        
        return (family, users, memberships)
    }
    
    /// Generates multiple families for testing family selection
    static func mockMultipleFamilies() -> [(family: Family, memberCount: Int)] {
        return [
            (Family.mock(name: "The Smith Family", code: "SMI123"), 4),
            (Family.mock(name: "The Garcia Family", code: "GAR456"), 3),
            (Family.mock(name: "The Chen Family", code: "CHE789"), 5),
            (Family.mock(name: "The Wilson Family", code: "WIL012"), 2)
        ]
    }
    
    // MARK: - Role Testing Data
    
    /// Provides all available roles for testing role selection UI
    static var allRoles: [Role] {
        return Role.allCases
    }
    
    /// Provides role constraints scenarios for testing
    static func roleConstraintScenarios() -> [(scenario: String, availableRoles: [Role])] {
        return [
            ("No Parent Admin exists", Role.allCases),
            ("Parent Admin already exists", [.adult, .kid, .visitor]),
            ("Full family", [.visitor]) // Only visitor slots available
        ]
    }
    
    // MARK: - Membership Status Testing
    
    /// Provides different membership status scenarios
    static func membershipStatusScenarios() -> [Membership] {
        let familyId = UUID()
        return [
            Membership.mock(familyId: familyId, role: .parentAdmin, status: .active),
            Membership.mock(familyId: familyId, role: .adult, status: .active),
            Membership.mock(familyId: familyId, role: .kid, status: .active),
            Membership.mock(familyId: familyId, role: .adult, status: .invited),
            Membership.mock(familyId: familyId, role: .visitor, status: .removed)
        ]
    }
    
    // MARK: - Authentication Testing
    
    /// Provides mock authenticated user for testing
    static func mockAuthenticatedUser() -> UserProfile {
        return UserProfile.mock(
            displayName: "Current User",
            appleUserIdHash: "current_user_hash"
        )
    }
    
    // MARK: - Family Code Testing
    
    /// Provides various family code formats for testing validation
    static var testFamilyCodes: [String] {
        return [
            "ABC123",    // Valid 6-character
            "DEMO01",    // Valid 6-character with numbers
            "FAMILY8",   // Valid 7-character
            "TESTCODE",  // Valid 8-character
            "AB12",      // Invalid - too short
            "TOOLONGCODE", // Invalid - too long
            "abc123",    // Valid but lowercase
            "123ABC"     // Valid numbers first
        ]
    }
    
    // MARK: - Error Scenarios
    
    /// Provides error scenarios for testing error handling
    static func errorScenarios() -> [(description: String, shouldSucceed: Bool)] {
        return [
            ("Valid family creation", true),
            ("Duplicate family code", false),
            ("Invalid family name", false),
            ("Network unavailable", false),
            ("Authentication failed", false),
            ("Parent Admin already exists", false)
        ]
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension MockDataGenerator {
    /// Quick access to mock data for SwiftUI previews
    static let previewFamily = mockFamilyWithMembers().family
    static let previewUsers = mockFamilyWithMembers().users
    static let previewMemberships = mockFamilyWithMembers().memberships
    static let previewCurrentUser = mockAuthenticatedUser()
}
#endif