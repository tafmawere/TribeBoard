import Foundation

/// Basic UserProfile model for prototyping
struct UserProfile: Identifiable, Codable {
    let id: UUID
    var displayName: String
    let appleUserIdHash: String
    var avatarUrl: URL?
    
    init(displayName: String, appleUserIdHash: String, avatarUrl: URL? = nil) {
        self.id = UUID()
        self.displayName = displayName
        self.appleUserIdHash = appleUserIdHash
        self.avatarUrl = avatarUrl
    }
}

// MARK: - Mock Data Extension
extension UserProfile {
    /// Creates a mock user profile for testing and prototyping
    static func mock(
        displayName: String = "John Doe",
        appleUserIdHash: String = "mock_hash_123",
        avatarUrl: URL? = nil
    ) -> UserProfile {
        UserProfile(
            displayName: displayName,
            appleUserIdHash: appleUserIdHash,
            avatarUrl: avatarUrl
        )
    }
    
    /// Sample user profiles for UI testing
    static let sampleUsers: [UserProfile] = [
        UserProfile.mock(displayName: "Sarah Johnson", appleUserIdHash: "hash_sarah"),
        UserProfile.mock(displayName: "Mike Garcia", appleUserIdHash: "hash_mike"),
        UserProfile.mock(displayName: "Emma Chen", appleUserIdHash: "hash_emma"),
        UserProfile.mock(displayName: "Alex Smith", appleUserIdHash: "hash_alex")
    ]
}