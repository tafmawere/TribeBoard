import Foundation

/// Basic Family model for prototyping
struct Family: Identifiable, Codable {
    let id: UUID
    var name: String
    var code: String
    let createdByUserId: UUID
    let createdAt: Date
    
    init(name: String, code: String, createdByUserId: UUID) {
        self.id = UUID()
        self.name = name
        self.code = code
        self.createdByUserId = createdByUserId
        self.createdAt = Date()
    }
}

// MARK: - Mock Data Extension
extension Family {
    /// Creates a mock family for testing and prototyping
    static func mock(
        name: String = "The Smith Family",
        code: String = "ABC123",
        createdByUserId: UUID = UUID()
    ) -> Family {
        Family(
            name: name,
            code: code,
            createdByUserId: createdByUserId
        )
    }
    
    /// Sample families for UI testing
    static let sampleFamilies: [Family] = [
        Family.mock(name: "The Johnson Family", code: "JOH456"),
        Family.mock(name: "The Garcia Family", code: "GAR789"),
        Family.mock(name: "The Chen Family", code: "CHE012")
    ]
}