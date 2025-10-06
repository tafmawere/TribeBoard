import Foundation

/// Simplified member model representing a user's membership in a family
struct InMemoryMember: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let familyId: UUID
    var role: InMemoryRole
    let joinedAt: Date
    
    init(userId: UUID, familyId: UUID, role: InMemoryRole) {
        self.id = UUID()
        self.userId = userId
        self.familyId = familyId
        self.role = role
        self.joinedAt = Date()
    }
    
    init(id: UUID, userId: UUID, familyId: UUID, role: InMemoryRole, joinedAt: Date) {
        self.id = id
        self.userId = userId
        self.familyId = familyId
        self.role = role
        self.joinedAt = joinedAt
    }
}

// MARK: - Hashable Support
extension InMemoryMember: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: InMemoryMember, rhs: InMemoryMember) -> Bool {
        return lhs.id == rhs.id
    }
}