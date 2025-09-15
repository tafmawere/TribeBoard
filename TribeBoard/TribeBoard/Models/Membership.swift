import Foundation

/// Basic Membership model for prototyping
struct Membership: Identifiable, Codable {
    let id: UUID
    let familyId: UUID
    let userId: UUID
    var role: Role
    let joinedAt: Date
    var status: MembershipStatus
    
    init(familyId: UUID, userId: UUID, role: Role) {
        self.id = UUID()
        self.familyId = familyId
        self.userId = userId
        self.role = role
        self.joinedAt = Date()
        self.status = .active
    }
}

// MARK: - Mock Data Extension
extension Membership {
    /// Creates a mock membership for testing and prototyping
    static func mock(
        familyId: UUID = UUID(),
        userId: UUID = UUID(),
        role: Role = .adult,
        status: MembershipStatus = .active
    ) -> Membership {
        var membership = Membership(
            familyId: familyId,
            userId: userId,
            role: role
        )
        membership.status = status
        return membership
    }
    
    /// Sample memberships for UI testing
    static func sampleMemberships(for familyId: UUID) -> [Membership] {
        let userIds = (0..<4).map { _ in UUID() }
        
        return [
            Membership.mock(familyId: familyId, userId: userIds[0], role: .parentAdmin),
            Membership.mock(familyId: familyId, userId: userIds[1], role: .adult),
            Membership.mock(familyId: familyId, userId: userIds[2], role: .kid),
            Membership.mock(familyId: familyId, userId: userIds[3], role: .visitor, status: .invited)
        ]
    }
}