import Foundation

extension SystemDomain {
    struct Stop: Identifiable, Codable {
        var id: UUID
        var name: String
        var latitude: Double
        var longitude: Double
        var order: Int
        var locationId: UUID?
        /// Stop role sent to backend as `run_stops.label` — e.g. Pickup / Dropoff.
        var kind: String?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case latitude
            case longitude
            case order
            case locationId
            case kind
        }

        init(
            id: UUID,
            name: String,
            latitude: Double,
            longitude: Double,
            order: Int,
            locationId: UUID? = nil,
            kind: String? = nil
        ) {
            self.id = id
            self.name = name
            self.latitude = latitude
            self.longitude = longitude
            self.order = order
            self.locationId = locationId
            self.kind = kind
        }
    }
}
