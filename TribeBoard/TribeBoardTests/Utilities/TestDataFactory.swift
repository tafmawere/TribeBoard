import Foundation
@testable import TribeBoard

/// Factory class for creating consistent test data across all tests
class TestDataFactory {
    
    // MARK: - User Profiles
    
    static func createTestUserProfile(
        id: UUID = UUID(),
        displayName: String = "Test User",
        appleUserIdHash: String = "test_hash_123",
        avatarUrl: URL? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> UserProfile {
        return UserProfile(
            id: id,
            displayName: displayName,
            appleUserIdHash: appleUserIdHash,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    static func createMultipleTestUserProfiles(count: Int = 3) -> [UserProfile] {
        return (1...count).map { index in
            createTestUserProfile(
                displayName: "Test User \(index)",
                appleUserIdHash: "test_hash_\(index)"
            )
        }
    }
    
    // MARK: - Families
    
    static func createTestFamily(
        id: UUID = UUID(),
        name: String = "Test Family",
        code: String = "TEST123",
        createdByUserId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> Family {
        let creatorId = createdByUserId ?? UUID()
        
        return Family(
            id: id,
            name: name,
            code: code,
            createdByUserId: creatorId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    static func createFamilyWithCreator(
        familyName: String = "Test Family",
        familyCode: String = "TEST123",
        creatorName: String = "Family Creator"
    ) -> (family: Family, creator: UserProfile) {
        let creator = createTestUserProfile(displayName: creatorName)
        let family = createTestFamily(
            name: familyName,
            code: familyCode,
            createdByUserId: creator.id
        )
        return (family, creator)
    }
    
    static func createMultipleTestFamilies(count: Int = 3) -> [Family] {
        return (1...count).map { index in
            createTestFamily(
                name: "Test Family \(index)",
                code: "FAM00\(index)",
                createdByUserId: UUID()
            )
        }
    }
    
    // MARK: - Memberships
    
    static func createTestMembership(
        id: UUID = UUID(),
        familyId: UUID? = nil,
        userId: UUID? = nil,
        role: Role = .parent,
        status: MembershipStatus = .active,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> Membership {
        return Membership(
            id: id,
            familyId: familyId ?? UUID(),
            userId: userId ?? UUID(),
            role: role,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    static func createFamilyWithMemberships(
        familyName: String = "Test Family",
        memberCount: Int = 3
    ) -> (family: Family, members: [UserProfile], memberships: [Membership]) {
        let family = createTestFamily(name: familyName)
        let members = createMultipleTestUserProfiles(count: memberCount)
        let memberships = members.enumerated().map { index, member in
            let role: Role = index == 0 ? .parentAdmin : .parent
            return createTestMembership(
                familyId: family.id,
                userId: member.id,
                role: role
            )
        }
        return (family, members, memberships)
    }
    
    // MARK: - Authentication Test Data
    
    static func createTestAppleUserId() -> String {
        return "test.apple.user.id.\(UUID().uuidString.prefix(8))"
    }
    
    static func createTestAppleUserIdHash() -> String {
        return "test_hash_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16))"
    }
    
    static func createTestKeychainData() -> [String: Data] {
        let appleUserId = createTestAppleUserId()
        let appleUserIdHash = createTestAppleUserIdHash()
        let familyId = UUID()
        
        return [
            KeychainService.appleUserIdKey: appleUserId.data(using: .utf8)!,
            KeychainService.appleUserIdHashKey: appleUserIdHash.data(using: .utf8)!,
            KeychainService.familyIdKey: familyId.uuidString.data(using: .utf8)!
        ]
    }
    
    // MARK: - Error Scenarios
    
    static func createAuthErrorScenarios() -> [AuthError] {
        return [
            .authorizationFailed,
            .userCancelled,
            .networkUnavailable,
            .invalidCredentials,
            .keychainError(KeychainService.KeychainError.itemNotFound),
            .dataServiceError(DataServiceError.invalidData("Test error")),
            .unknownError(NSError(domain: "TestDomain", code: 999, userInfo: [NSLocalizedDescriptionKey: "Test error"]))
        ]
    }
    
    static func createDataServiceErrorScenarios() -> [DataServiceError] {
        return [
            .validationFailed(["Test validation error"]),
            .invalidData("Test invalid data"),
            .notFound("Test not found"),
            .constraintViolation("Test constraint violation")
        ]
    }
    
    static func createKeychainErrorScenarios() -> [KeychainService.KeychainError] {
        return [
            .itemNotFound,
            .duplicateItem,
            .invalidData,
            .unexpectedError(errSecInternalError)
        ]
    }
    
    // MARK: - Complete Test Scenarios
    
    /// Creates a complete authentication scenario with user and keychain data
    static func createCompleteAuthScenario() -> AuthTestScenario {
        let appleUserId = createTestAppleUserId()
        let appleUserIdHash = createTestAppleUserIdHash()
        let userProfile = createTestUserProfile(
            displayName: "Authenticated User",
            appleUserIdHash: appleUserIdHash
        )
        let keychainData = [
            KeychainService.appleUserIdKey: appleUserId.data(using: .utf8)!,
            KeychainService.appleUserIdHashKey: appleUserIdHash.data(using: .utf8)!
        ]
        
        return AuthTestScenario(
            appleUserId: appleUserId,
            appleUserIdHash: appleUserIdHash,
            userProfile: userProfile,
            keychainData: keychainData
        )
    }
    
    /// Creates a complete family scenario with creator, members, and memberships
    static func createCompleteFamilyScenario() -> FamilyTestScenario {
        let (family, creator) = createFamilyWithCreator()
        let additionalMembers = createMultipleTestUserProfiles(count: 2)
        let allMembers = [creator] + additionalMembers
        
        let memberships = allMembers.enumerated().map { index, member in
            let role: Role = index == 0 ? .parentAdmin : .parent
            return createTestMembership(
                familyId: family.id,
                userId: member.id,
                role: role
            )
        }
        
        return FamilyTestScenario(
            family: family,
            creator: creator,
            allMembers: allMembers,
            memberships: memberships
        )
    }
    
    // MARK: - Mock Service Configuration
    
    /// Configure MockKeychainService with test data
    static func configureMockKeychain(_ mockKeychain: MockKeychainService, with scenario: AuthTestScenario) {
        for (key, data) in scenario.keychainData {
            mockKeychain.prePopulate(data: data, for: key)
        }
    }
    
    /// Configure MockDataService with test data
    static func configureMockDataService(_ mockDataService: MockDataService, with scenario: FamilyTestScenario) {
        // Pre-populate users
        for member in scenario.allMembers {
            mockDataService.prePopulateUser(member, withHash: member.appleUserIdHash)
        }
        
        // Pre-populate family
        mockDataService.prePopulateFamily(scenario.family)
    }
    
    /// Configure MockAuthService with test data
    static func configureMockAuthService(_ mockAuthService: MockAuthService, with scenario: AuthTestScenario) {
        mockAuthService.setMockUserProfile(scenario.userProfile)
        mockAuthService.mockAppleUserId = scenario.appleUserId
        mockAuthService.mockAppleUserIdHash = scenario.appleUserIdHash
    }
    
    // MARK: - Validation Helpers
    
    /// Validate that a user profile has all required fields
    static func validateUserProfile(_ userProfile: UserProfile) -> Bool {
        return !userProfile.displayName.isEmpty &&
               !userProfile.appleUserIdHash.isEmpty &&
               userProfile.createdAt <= Date() &&
               userProfile.updatedAt <= Date()
    }
    
    /// Validate that a family has all required fields
    static func validateFamily(_ family: Family) -> Bool {
        return !family.name.isEmpty &&
               family.code.count >= 6 &&
               family.code.count <= 8 &&
               family.createdAt <= Date() &&
               family.updatedAt <= Date()
    }
    
    /// Validate that a membership has all required fields
    static func validateMembership(_ membership: Membership) -> Bool {
        return membership.status == .active &&
               membership.createdAt <= Date() &&
               membership.updatedAt <= Date()
    }
    
    // MARK: - Random Data Generators
    
    /// Generate a random family code
    static func generateFamilyCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in letters.randomElement()! })
    }
    
    /// Generate a random display name
    static func generateDisplayName() -> String {
        let firstNames = ["Alex", "Bailey", "Casey", "Drew", "Emery", "Finley", "Gray", "Harper"]
        let lastNames = ["Johnson", "Smith", "Davis", "Wilson", "Brown", "Taylor", "Anderson", "Thomas"]
        
        let firstName = firstNames.randomElement()!
        let lastName = lastNames.randomElement()!
        return "\(firstName) \(lastName)"
    }
    
    /// Generate a random family name
    static func generateFamilyName() -> String {
        let familyNames = [
            "The Johnsons", "Smith Family", "Davis Household", "Wilson Clan", "Brown Family",
            "Taylor House", "Anderson Home", "Thomas Family", "Garcia Household", "Miller Clan"
        ]
        return familyNames.randomElement()!
    }
}

// MARK: - Test Scenario Models

struct AuthTestScenario {
    let appleUserId: String
    let appleUserIdHash: String
    let userProfile: UserProfile
    let keychainData: [String: Data]
}

struct FamilyTestScenario {
    let family: Family
    let creator: UserProfile
    let allMembers: [UserProfile]
    let memberships: [Membership]
}

// MARK: - Test Data Collections

extension TestDataFactory {
    
    /// Common test display names for consistent testing
    static let testDisplayNames = [
        "Alice Johnson", "Bob Smith", "Carol Davis", "David Wilson", "Emma Brown",
        "Frank Taylor", "Grace Anderson", "Henry Thomas", "Ivy Garcia", "Jack Miller"
    ]
    
    /// Common test family names
    static let testFamilyNames = [
        "The Johnsons", "Smith Family", "Davis Household", "Wilson Clan", "Brown Family",
        "Taylor House", "Anderson Home", "Thomas Family", "Garcia Household", "Miller Clan"
    ]
    
    /// Common test family codes
    static let testFamilyCodes = [
        "FAM001", "FAM002", "FAM003", "TEST01", "TEST02", "TEST03",
        "HOME01", "HOME02", "CLAN01", "CLAN02"
    ]
    
    /// Role distribution for testing
    static let testRoles: [Role] = [.parentAdmin, .parent, .child, .caregiver]
    
    /// Membership status options for testing
    static let testMembershipStatuses: [MembershipStatus] = [.active, .inactive, .pending]
}