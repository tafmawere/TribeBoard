import Foundation
import SwiftData

/// Provides mock data for testing UI components and prototyping
struct MockDataGenerator {
    
    // MARK: - Family Mock Data
    
    /// Generates a complete family with members for testing
    static func mockFamilyWithMembers() -> (family: Family, users: [UserProfile], memberships: [Membership]) {
        let users = [
            UserProfile(displayName: "Sarah Johnson", appleUserIdHash: "hash_sarah"),
            UserProfile(displayName: "Mike Johnson", appleUserIdHash: "hash_mike"),
            UserProfile(displayName: "Emma Johnson", appleUserIdHash: "hash_emma"),
            UserProfile(displayName: "Alex Johnson", appleUserIdHash: "hash_alex")
        ]
        
        let family = Family(name: "The Demo Family", code: "DEMO01", createdByUserId: users[0].id)
        
        let memberships = [
            Membership(family: family, user: users[0], role: .parentAdmin),
            Membership(family: family, user: users[1], role: .adult),
            Membership(family: family, user: users[2], role: .kid),
            Membership(family: family, user: users[3], role: .visitor)
        ]
        
        // Set the last membership as invited
        memberships[3].status = .invited
        
        return (family, users, memberships)
    }
    
    /// Generates multiple families for testing family selection
    static func mockMultipleFamilies() -> [(family: Family, memberCount: Int)] {
        let creatorId = UUID()
        return [
            (Family(name: "The Smith Family", code: "SMI123", createdByUserId: creatorId), 4),
            (Family(name: "The Garcia Family", code: "GAR456", createdByUserId: creatorId), 3),
            (Family(name: "The Chen Family", code: "CHE789", createdByUserId: creatorId), 5),
            (Family(name: "The Wilson Family", code: "WIL012", createdByUserId: creatorId), 2)
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
        let family = Family(name: "Test Family", code: "TEST01", createdByUserId: UUID())
        let users = [
            UserProfile(displayName: "User 1", appleUserIdHash: "hash1"),
            UserProfile(displayName: "User 2", appleUserIdHash: "hash2"),
            UserProfile(displayName: "User 3", appleUserIdHash: "hash3"),
            UserProfile(displayName: "User 4", appleUserIdHash: "hash4"),
            UserProfile(displayName: "User 5", appleUserIdHash: "hash5")
        ]
        
        let memberships = [
            Membership(family: family, user: users[0], role: .parentAdmin),
            Membership(family: family, user: users[1], role: .adult),
            Membership(family: family, user: users[2], role: .kid),
            Membership(family: family, user: users[3], role: .adult),
            Membership(family: family, user: users[4], role: .visitor)
        ]
        
        // Set different statuses
        memberships[3].status = .invited
        memberships[4].status = .removed
        
        return memberships
    }
    
    // MARK: - Authentication Testing
    
    /// Provides mock authenticated user for testing
    static func mockAuthenticatedUser() -> UserProfile {
        return UserProfile(
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