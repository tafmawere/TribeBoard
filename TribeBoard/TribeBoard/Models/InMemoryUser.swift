import Foundation

/// Simplified user model for in-memory storage during app session
struct InMemoryUser: Identifiable, Codable {
    let id: UUID
    var name: String
    let createdAt: Date
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
    
    init(id: UUID, name: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

// MARK: - Hashable Support
extension InMemoryUser: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: InMemoryUser, rhs: InMemoryUser) -> Bool {
        return lhs.id == rhs.id
    }
}