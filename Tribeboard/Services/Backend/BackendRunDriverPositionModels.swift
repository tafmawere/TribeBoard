import CoreLocation
import Foundation

struct BackendRunDriverPosition: Codable, Equatable, Identifiable {
    var runId: UUID
    var householdId: UUID
    var driverId: UUID?
    var latitude: Double
    var longitude: Double
    var speedMps: Double?
    var headingDegrees: Double?
    var updatedAt: Date

    var id: UUID { runId }

    enum CodingKeys: String, CodingKey {
        case runId = "run_id"
        case householdId = "household_id"
        case driverId = "driver_id"
        case latitude
        case longitude
        case speedMps = "speed_mps"
        case headingDegrees = "heading_degrees"
        case updatedAt = "updated_at"
    }
}

struct RunDriverPositionSnapshot: Equatable {
    let runId: UUID
    let coordinate: CLLocationCoordinate2D
    let speedMetersPerSecond: Double?
    let headingDegrees: Double?
    let updatedAt: Date

    var location: CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: 0,
            horizontalAccuracy: 25,
            verticalAccuracy: -1,
            course: headingDegrees ?? -1,
            speed: speedMetersPerSecond ?? -1,
            timestamp: updatedAt
        )
    }

    init(backend: BackendRunDriverPosition) {
        runId = backend.runId
        coordinate = CLLocationCoordinate2D(latitude: backend.latitude, longitude: backend.longitude)
        speedMetersPerSecond = backend.speedMps
        headingDegrees = backend.headingDegrees
        updatedAt = backend.updatedAt
    }
}
