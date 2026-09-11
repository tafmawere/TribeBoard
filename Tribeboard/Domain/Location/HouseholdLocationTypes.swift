import CoreLocation
import Foundation

enum HouseholdLocationType: String, Codable, CaseIterable, Identifiable, Hashable {
    case home
    case school
    case activity
    case pickup
    case dropoff
    case relative
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .school: return "School"
        case .activity: return "Activities"
        case .pickup: return "Pickup points"
        case .dropoff: return "Dropoff"
        case .relative: return "Relatives"
        case .custom: return "Custom places"
        }
    }

    var singularTitle: String {
        switch self {
        case .home: return "Home"
        case .school: return "School"
        case .activity: return "Activity"
        case .pickup: return "Pickup point"
        case .dropoff: return "Dropoff"
        case .relative: return "Relative"
        case .custom: return "Custom place"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .school: return "building.columns.fill"
        case .activity: return "sportscourt.fill"
        case .pickup: return "mappin.and.ellipse"
        case .dropoff: return "arrow.down.to.line"
        case .relative: return "person.2.fill"
        case .custom: return "mappin.circle.fill"
        }
    }

    static func from(raw: String?) -> HouseholdLocationType {
        guard let raw else { return .custom }
        return HouseholdLocationType(rawValue: raw.lowercased()) ?? .custom
    }
}

enum HouseholdLocationReadiness: Equatable {
    case complete
    case missingAddress
    case missingPin

    var label: String {
        switch self {
        case .complete: return "Complete"
        case .missingAddress: return "Missing address"
        case .missingPin: return "Missing pin"
        }
    }

    var tint: String {
        switch self {
        case .complete: return "green"
        case .missingAddress, .missingPin: return "orange"
        }
    }
}

enum HouseholdLocationCoordinateValidator {
    static func validate(latitude: Double?, longitude: Double?) throws {
        guard let latitude, let longitude else {
            throw HouseholdLocationValidationError.missingCoordinates
        }
        try validate(latitude: latitude, longitude: longitude)
    }

    static func validate(latitude: Double, longitude: Double) throws {
        guard (-90.0...90.0).contains(latitude) else {
            throw HouseholdLocationValidationError.invalidLatitude
        }
        guard (-180.0...180.0).contains(longitude) else {
            throw HouseholdLocationValidationError.invalidLongitude
        }
        guard RunRouteValidator.isPlausibleCoordinate(
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        ) else {
            throw HouseholdLocationValidationError.placeholderCoordinates
        }
    }

    static func isValid(latitude: Double, longitude: Double) -> Bool {
        (try? validate(latitude: latitude, longitude: longitude)) != nil
    }
}

enum HouseholdLocationValidationError: LocalizedError {
    case missingCoordinates
    case invalidLatitude
    case invalidLongitude
    case placeholderCoordinates

    var errorDescription: String? {
        switch self {
        case .missingCoordinates:
            return "Coordinates are required."
        case .invalidLatitude:
            return "Latitude must be between -90 and 90."
        case .invalidLongitude:
            return "Longitude must be between -180 and 180."
        case .placeholderCoordinates:
            return "A valid map pin is required (0,0 is not allowed)."
        }
    }
}

extension BackendHouseholdLocation {
    var locationType: HouseholdLocationType {
        HouseholdLocationType.from(raw: locationTypeRaw)
    }

    var displayName: String {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedName.isEmpty { return trimmedName }
        return label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var readiness: HouseholdLocationReadiness {
        let address = formattedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if address.isEmpty { return .missingAddress }
        if !HouseholdLocationCoordinateValidator.isValid(latitude: latitude, longitude: longitude) {
            return .missingPin
        }
        return .complete
    }

    func toStopLocationSelection() -> StopLocationSelection {
        StopLocationSelection(
            placeId: placeId,
            placeName: displayName,
            formattedAddress: formattedAddress,
            latitude: latitude,
            longitude: longitude,
            householdLocationId: id,
            provider: provider
        )
    }
}
