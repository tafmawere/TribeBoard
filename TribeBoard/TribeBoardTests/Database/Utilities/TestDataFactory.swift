import Foundation
import SwiftData
@testable import TribeBoard

/// Factory for creating standardized test data with various configurations
class TestDataFactory {
    
    // MARK: - Family Creation
    
    /// Creates a valid family with default values
    static func createValidFamily(
        name: String = "Test Family",
        code: String = "TEST123",
        createdByUserId: UUID = UUID()
    ) -> Family {
        return Family(name: name, code: code, createdByUserId: createdByUserId)
    }
    
    /// Creates an invalid family based on the specified invalid field
    static func createInvalidFamily(invalidField: FamilyField) -> Family {
        switch invalidField {
        case .name:
            // Invalid name - empty
            return Family(name: "", code: "TEST123", createdByUserId: UUID())
        case .code:
            // Invalid code - too short
            return Family(name: "Test Family", code: "T1", createdByUserId: UUID())
        case .createdByUserId:
            // This is harder to make invalid since UUID() always creates valid UUIDs
            // We'll create a valid family but note this limitation
            return Family(name: "Test Family", code: "TEST123", createdByUserId: UUID())
        }
    }
    
    /// Creates a family with a specific code
    static func createFamilyWithCode(_ code: String) -> Family {
        return Family(name: "Test Family", code: code, createdByUserId: UUID())
    }
    
    /// Creates multiple families with unique codes
    static func createFamiliesWithUniqueCodes(count: Int) -> [Family] {
        var families: [Family] = []
        for i in 1...count {
            let code = String(format: "TEST%03d", i)
            let name = "Test Family \(i)"
            families.append(Family(name: name, code: code, createdByUserId: UUID()))
        }
        return families
    }
    
    // MARK: - UserProfile Creation
    
    /// Creates a valid user profile with default values
    static func createValidUserProfile(
        displayName: String = "Test User",
        appleUserIdHash: String = "test_hash_123456789",
        avatarUrl: URL? = nil
    ) -> UserProfile {
        return UserProfile(displayName: displayName, appleUserIdHash: appleUserIdHash, avatarUrl: avatarUrl)
    }
    
    /// Creates an invalid user profile based on the specified invalid field
    static func createInvalidUserProfile(invalidField: UserField) -> UserProfile {
        switch invalidField {
        case .displayName:
            // Invalid display name - empty
            return UserProfile(displayName: "", appleUserIdHash: "test_hash_123456789")
        case .appleUserIdHash:
            // Invalid Apple ID hash - too short
            return UserProfile(displayName: "Test User", appleUserIdHash: "short")
        }
    }
    
    /// Creates multiple user profiles with unique data
    static func createUniqueUserProfiles(count: Int) -> [UserProfile] {
        var users: [UserProfile] = []
        for i in 1...count {
            let displayName = "Test User \(i)"
            let appleUserIdHash = "test_hash_\(String(format: "%010d", i))"
            users.append(UserProfile(displayName: displayName, appleUserIdHash: appleUserIdHash))
        }
        return users
    }
    
    // MARK: - Membership Creation
    
    /// Creates a membership with proper relationships
    static func createMembership(
        family: Family,
        user: UserProfile,
        role: Role = .kid
    ) -> Membership {
        return Membership(family: family, user: user, role: role)
    }
    
    /// Creates a family with specified number of members
    static func createFamilyWithMembers(memberCount: Int) -> (Family, [UserProfile], [Membership]) {
        let family = createValidFamily()
        var users: [UserProfile] = []
        var memberships: [Membership] = []
        
        for i in 1...memberCount {
            let user = createValidUserProfile(
                displayName: "Family Member \(i)",
                appleUserIdHash: "member_hash_\(String(format: "%010d", i))"
            )
            users.append(user)
            
            // First member is parent admin, others are kids
            let role: Role = (i == 1) ? .parentAdmin : .kid
            let membership = createMembership(family: family, user: user, role: role)
            memberships.append(membership)
        }
        
        return (family, users, memberships)
    }
    
    /// Creates a family with members of different roles
    static func createFamilyWithMixedRoles() -> (Family, [UserProfile], [Membership]) {
        let family = createValidFamily(name: "Mixed Role Family")
        var users: [UserProfile] = []
        var memberships: [Membership] = []
        
        let roles: [Role] = [.parentAdmin, .adult, .kid, .visitor]
        
        for (index, role) in roles.enumerated() {
            let user = createValidUserProfile(
                displayName: "\(role.displayName) User",
                appleUserIdHash: "role_hash_\(String(format: "%010d", index + 1))"
            )
            users.append(user)
            
            let membership = createMembership(family: family, user: user, role: role)
            memberships.append(membership)
        }
        
        return (family, users, memberships)
    }
    
    // MARK: - Bulk Data Creation for Performance Testing
    
    /// Creates bulk families for performance testing
    static func createBulkFamilies(count: Int) -> [Family] {
        var families: [Family] = []
        for i in 1...count {
            let name = "Bulk Family \(i)"
            let code = String(format: "BULK%04d", i)
            let family = Family(name: name, code: code, createdByUserId: UUID())
            families.append(family)
        }
        return families
    }
    
    /// Creates bulk users for performance testing
    static func createBulkUsers(count: Int) -> [UserProfile] {
        var users: [UserProfile] = []
        for i in 1...count {
            let displayName = "Bulk User \(i)"
            let appleUserIdHash = "bulk_hash_\(String(format: "%010d", i))"
            let user = UserProfile(displayName: displayName, appleUserIdHash: appleUserIdHash)
            users.append(user)
        }
        return users
    }
    
    /// Creates bulk memberships for performance testing
    static func createBulkMemberships(families: [Family], users: [UserProfile]) -> [Membership] {
        var memberships: [Membership] = []
        
        // Create memberships by pairing users with families
        let minCount = min(families.count, users.count)
        for i in 0..<minCount {
            let membership = Membership(family: families[i], user: users[i], role: .kid)
            memberships.append(membership)
        }
        
        return memberships
    }
    
    /// Creates a complete bulk dataset for performance testing
    static func createBulkDataset(familyCount: Int, userCount: Int) -> (families: [Family], users: [UserProfile], memberships: [Membership]) {
        let families = createBulkFamilies(count: familyCount)
        let users = createBulkUsers(count: userCount)
        let memberships = createBulkMemberships(families: families, users: users)
        
        return (families, users, memberships)
    }
    
    // MARK: - Edge Case Data Creation
    
    /// Creates families with edge case names
    static func createFamiliesWithEdgeCaseNames() -> [Family] {
        let edgeCaseNames = [
            "A",                    // Minimum length (invalid - too short)
            "AB",                   // Minimum valid length
            String(repeating: "A", count: 50),  // Maximum valid length
            String(repeating: "A", count: 51),  // Too long (invalid)
            "Family with spaces",   // Spaces
            "Family-with-dashes",   // Dashes
            "Family_with_underscores", // Underscores
            "Family123",            // Numbers
            "   Trimmed   ",        // Leading/trailing spaces
            ""                      // Empty (invalid)
        ]
        
        var families: [Family] = []
        for (index, name) in edgeCaseNames.enumerated() {
            let code = String(format: "EDGE%03d", index + 1)
            families.append(Family(name: name, code: code, createdByUserId: UUID()))
        }
        
        return families
    }
    
    /// Creates families with edge case codes
    static func createFamiliesWithEdgeCaseCodes() -> [Family] {
        let edgeCaseCodes = [
            "A",                    // Too short (invalid)
            "AB123",                // Too short (invalid)
            "ABC123",               // Minimum valid length (6 chars)
            "ABCD1234",             // Maximum valid length (8 chars)
            "ABCDE12345",           // Too long (invalid)
            "abc123",               // Lowercase
            "ABC123",               // Uppercase
            "123456",               // Numbers only
            "ABCDEF",               // Letters only
            "AB-123",               // Special characters (invalid)
            "AB 123",               // Spaces (invalid)
            ""                      // Empty (invalid)
        ]
        
        var families: [Family] = []
        for (index, code) in edgeCaseCodes.enumerated() {
            let name = "Edge Case Family \(index + 1)"
            families.append(Family(name: name, code: code, createdByUserId: UUID()))
        }
        
        return families
    }
    
    /// Creates user profiles with edge case display names
    static func createUsersWithEdgeCaseNames() -> [UserProfile] {
        let edgeCaseNames = [
            "",                     // Empty (invalid)
            "A",                    // Minimum valid length
            String(repeating: "A", count: 50),  // Maximum valid length
            String(repeating: "A", count: 51),  // Too long (invalid)
            "User with spaces",     // Spaces
            "User-with-dashes",     // Dashes
            "User_with_underscores", // Underscores
            "User123",              // Numbers
            "   Trimmed   ",        // Leading/trailing spaces
            "🙂 Emoji User",        // Emoji
            "Ñoñó Àccénts"          // Accented characters
        ]
        
        var users: [UserProfile] = []
        for (index, name) in edgeCaseNames.enumerated() {
            let hash = "edge_hash_\(String(format: "%010d", index + 1))"
            users.append(UserProfile(displayName: name, appleUserIdHash: hash))
        }
        
        return users
    }
    
    /// Creates user profiles with edge case Apple ID hashes
    static func createUsersWithEdgeCaseHashes() -> [UserProfile] {
        let edgeCaseHashes = [
            "",                     // Empty (invalid)
            "short",                // Too short (invalid)
            "1234567890",           // Minimum valid length (10 chars)
            String(repeating: "A", count: 100), // Very long hash
            "hash_with_underscores_123456789",
            "hash-with-dashes-123456789",
            "UPPERCASE_HASH_123456789",
            "lowercase_hash_123456789",
            "MiXeD_cAsE_hAsH_123456789"
        ]
        
        var users: [UserProfile] = []
        for (index, hash) in edgeCaseHashes.enumerated() {
            let name = "Edge Case User \(index + 1)"
            users.append(UserProfile(displayName: name, appleUserIdHash: hash))
        }
        
        return users
    }
    
    // MARK: - Validation Test Data
    
    /// Creates data specifically for validation testing
    static func createValidationTestData() -> ValidationTestData {
        return ValidationTestData(
            validFamilies: [
                createValidFamily(name: "Valid Family 1", code: "VALID01"),
                createValidFamily(name: "Valid Family 2", code: "VALID02")
            ],
            invalidFamilies: [
                createInvalidFamily(invalidField: .name),
                createInvalidFamily(invalidField: .code)
            ],
            validUsers: [
                createValidUserProfile(displayName: "Valid User 1", appleUserIdHash: "valid_hash_1234567890"),
                createValidUserProfile(displayName: "Valid User 2", appleUserIdHash: "valid_hash_0987654321")
            ],
            invalidUsers: [
                createInvalidUserProfile(invalidField: .displayName),
                createInvalidUserProfile(invalidField: .appleUserIdHash)
            ],
            edgeCaseFamilies: createFamiliesWithEdgeCaseNames(),
            edgeCaseUsers: createUsersWithEdgeCaseNames()
        )
    }
}

// MARK: - Supporting Types

/// Enum for specifying which family field should be invalid
enum FamilyField {
    case name
    case code
    case createdByUserId
}

/// Enum for specifying which user field should be invalid
enum UserField {
    case displayName
    case appleUserIdHash
}

/// Container for validation test data
struct ValidationTestData {
    let validFamilies: [Family]
    let invalidFamilies: [Family]
    let validUsers: [UserProfile]
    let invalidUsers: [UserProfile]
    let edgeCaseFamilies: [Family]
    let edgeCaseUsers: [UserProfile]
}

// MARK: - Performance Test Data Configuration

/// Configuration for performance test data generation
struct PerformanceTestDataConfig {
    let familyCount: Int
    let userCount: Int
    let membershipsPerFamily: Int
    
    static let small = PerformanceTestDataConfig(familyCount: 10, userCount: 20, membershipsPerFamily: 2)
    static let medium = PerformanceTestDataConfig(familyCount: 100, userCount: 200, membershipsPerFamily: 5)
    static let large = PerformanceTestDataConfig(familyCount: 1000, userCount: 2000, membershipsPerFamily: 10)
}

extension TestDataFactory {
    
    /// Creates performance test data based on configuration
    static func createPerformanceTestData(config: PerformanceTestDataConfig) -> (families: [Family], users: [UserProfile], memberships: [Membership]) {
        let families = createBulkFamilies(count: config.familyCount)
        let users = createBulkUsers(count: config.userCount)
        
        var memberships: [Membership] = []
        
        // Create memberships with specified ratio
        for (familyIndex, family) in families.enumerated() {
            let startUserIndex = (familyIndex * config.membershipsPerFamily) % users.count
            
            for memberIndex in 0..<config.membershipsPerFamily {
                let userIndex = (startUserIndex + memberIndex) % users.count
                let user = users[userIndex]
                
                // First member is parent admin, others are kids
                let role: Role = (memberIndex == 0) ? .parentAdmin : .kid
                let membership = Membership(family: family, user: user, role: role)
                memberships.append(membership)
            }
        }
        
        return (families, users, memberships)
    }
}