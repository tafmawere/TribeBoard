import Foundation
import SwiftData

/// Configuration for SwiftData ModelContainer with CloudKit sync
struct ModelContainerConfiguration {
    
    /// Creates and configures the SwiftData ModelContainer
    static func create() throws -> ModelContainer {
        let schema = Schema([
            Family.self,
            UserProfile.self,
            Membership.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.tribeboard.TribeBoard")
        )
        
        return try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    }
    
    /// Creates an in-memory container for testing
    static func createInMemory() throws -> ModelContainer {
        let schema = Schema([
            Family.self,
            UserProfile.self,
            Membership.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        return try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    }
}

/// Extension to provide mock data for testing
extension ModelContainer {
    
    /// Seeds the container with mock data for testing
    @MainActor
    func seedMockData() throws {
        let context = mainContext
        
        // Create mock users
        let user1 = UserProfile(
            displayName: "Sarah Johnson",
            appleUserIdHash: "hash_sarah_123"
        )
        let user2 = UserProfile(
            displayName: "Mike Garcia", 
            appleUserIdHash: "hash_mike_456"
        )
        let user3 = UserProfile(
            displayName: "Emma Chen",
            appleUserIdHash: "hash_emma_789"
        )
        
        context.insert(user1)
        context.insert(user2)
        context.insert(user3)
        
        // Create mock family
        let family = Family(
            name: "The Johnson Family",
            code: "JOH123",
            createdByUserId: user1.id
        )
        context.insert(family)
        
        // Create memberships
        let membership1 = Membership(family: family, user: user1, role: .parentAdmin)
        let membership2 = Membership(family: family, user: user2, role: .adult)
        let membership3 = Membership(family: family, user: user3, role: .kid)
        
        context.insert(membership1)
        context.insert(membership2)
        context.insert(membership3)
        
        try context.save()
    }
}