import Foundation

struct Household: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var createdAt: Date
}
