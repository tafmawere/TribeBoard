import Foundation

extension SystemDomain {
    struct Stop: Identifiable, Codable {
        var id: UUID
        var name: String
        var latitude: Double
        var longitude: Double
        var order: Int
    }
}
