import Foundation
import SwiftUI

/// Simplified family model for in-memory storage during app session
class InMemoryFamily: ObservableObject, Identifiable, Codable {
    let id: UUID
    @Published var name: String
    let code: String
    @Published var members: [InMemoryMember]
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, code, members, createdAt
    }
    
    init(name: String, code: String) {
        self.id = UUID()
        self.name = name
        self.code = code
        self.members = []
        self.createdAt = Date()
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.code = try container.decode(String.self, forKey: .code)
        self.members = try container.decode([InMemoryMember].self, forKey: .members)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(code, forKey: .code)
        try container.encode(members, forKey: .members)
        try container.encode(createdAt, forKey: .createdAt)
    }
    
    /// Add a member to this family
    func addMember(_ member: InMemoryMember) {
        members.append(member)
    }
    
    /// Remove a member from this family
    func removeMember(withUserId userId: UUID) {
        members.removeAll { $0.userId == userId }
    }
    
    /// Find a member by user ID
    func member(withUserId userId: UUID) -> InMemoryMember? {
        return members.first { $0.userId == userId }
    }
}