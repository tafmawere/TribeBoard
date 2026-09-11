import CoreLocation
import Foundation

/// Resolves placeholder (0,0) schedule/run stop coordinates from household_locations and legacy quick places.
enum StopCoordinateHydrator {
    typealias PlaceCoordinate = (latitude: Double, longitude: Double)

    static func isPlaceholder(latitude: Double, longitude: Double) -> Bool {
        !RunRouteValidator.isPlausibleCoordinate(
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        )
    }

    static func buildLocationIndex(
        locations: [BackendHouseholdLocation]
    ) -> [UUID: BackendHouseholdLocation] {
        Dictionary(uniqueKeysWithValues: locations.map { ($0.id, $0) })
    }

    static func buildNameIndex(
        locations: [BackendHouseholdLocation]
    ) -> [String: BackendHouseholdLocation] {
        var index: [String: BackendHouseholdLocation] = [:]
        for location in locations {
            let keys = [
                location.displayName,
                location.label,
                location.formattedAddress
            ]
            for key in keys {
                let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !normalized.isEmpty else { continue }
                index[normalized] = location
            }
            index[location.locationType.rawValue] = location
        }
        return index
    }

    static func buildPlaceIndex(
        slotPlaces: [String: ResolvedFamilyPlace],
        namedPlaces: [ResolvedFamilyPlace],
        recentPlaces: [ResolvedFamilyPlace],
        homeLocation: BackendHouseholdLocation?,
        householdLocations: [BackendHouseholdLocation] = []
    ) -> [String: PlaceCoordinate] {
        var index: [String: PlaceCoordinate] = [:]

        func insert(_ key: String, _ coordinate: PlaceCoordinate) {
            let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty else { return }
            index[normalized] = coordinate
        }

        for location in householdLocations {
            insert(location.displayName, (location.latitude, location.longitude))
            insert(location.label, (location.latitude, location.longitude))
            insert(location.formattedAddress, (location.latitude, location.longitude))
            insert(location.locationType.rawValue, (location.latitude, location.longitude))
        }

        for (slotId, place) in slotPlaces {
            insert(slotId, (place.latitude, place.longitude))
            insert(place.locationName, (place.latitude, place.longitude))
            insert(place.formattedAddress, (place.latitude, place.longitude))
        }
        for place in namedPlaces + recentPlaces {
            insert(place.locationName, (place.latitude, place.longitude))
            insert(place.formattedAddress, (place.latitude, place.longitude))
        }
        if let homeLocation {
            insert("home", (homeLocation.latitude, homeLocation.longitude))
            insert(homeLocation.label, (homeLocation.latitude, homeLocation.longitude))
            insert(homeLocation.formattedAddress, (homeLocation.latitude, homeLocation.longitude))
        }
        return index
    }

    static func hydrate(
        _ stop: SystemDomain.Stop,
        locationsById: [UUID: BackendHouseholdLocation],
        locationsByName: [String: BackendHouseholdLocation],
        legacyPlaces: [String: PlaceCoordinate] = [:]
    ) -> SystemDomain.Stop {
        if let locationId = stop.locationId, let linked = locationsById[locationId] {
            return apply(location: linked, to: stop)
        }

        guard isPlaceholder(latitude: stop.latitude, longitude: stop.longitude) else {
            return stop
        }

        if let match = resolveLocation(label: stop.name, locationsByName: locationsByName) {
            NSLog(
                "[RunRoute] hydrated stop from household_location label=\(stop.name) " +
                "lat=\(match.latitude) lon=\(match.longitude)"
            )
            return apply(location: match, to: stop)
        }

        if let match = resolve(label: stop.name, places: legacyPlaces) {
            NSLog(
                "[RunRoute] hydrated stop from legacy place label=\(stop.name) " +
                "lat=\(match.latitude) lon=\(match.longitude)"
            )
            var updated = stop
            updated.latitude = match.latitude
            updated.longitude = match.longitude
            return updated
        }

        NSLog(
            "[RunRoute] unresolved placeholder stop label=\(stop.name) " +
            "lat=\(stop.latitude) lon=\(stop.longitude)"
        )
        return stop
    }

    static func hydrate(
        stops: [SystemDomain.Stop],
        locations: [BackendHouseholdLocation],
        legacyPlaces: [String: PlaceCoordinate] = [:]
    ) -> [SystemDomain.Stop] {
        let byId = buildLocationIndex(locations: locations)
        let byName = buildNameIndex(locations: locations)
        return stops.map {
            hydrate($0, locationsById: byId, locationsByName: byName, legacyPlaces: legacyPlaces)
        }
    }

    static func hydrate(
        _ stop: SystemDomain.Stop,
        places: [String: PlaceCoordinate]
    ) -> SystemDomain.Stop {
        hydrate(stop, locationsById: [:], locationsByName: [:], legacyPlaces: places)
    }

    static func hydrate(
        stops: [SystemDomain.Stop],
        places: [String: PlaceCoordinate]
    ) -> [SystemDomain.Stop] {
        stops.map { hydrate($0, places: places) }
    }

    private static func apply(location: BackendHouseholdLocation, to stop: SystemDomain.Stop) -> SystemDomain.Stop {
        var updated = stop
        updated.locationId = location.id
        if updated.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updated.name = location.displayName
        }
        updated.latitude = location.latitude
        updated.longitude = location.longitude
        return updated
    }

    private static func resolveLocation(
        label: String,
        locationsByName: [String: BackendHouseholdLocation]
    ) -> BackendHouseholdLocation? {
        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }

        if let exact = locationsByName[normalized] {
            return exact
        }

        for (key, location) in locationsByName where normalized.contains(key) || key.contains(normalized) {
            return location
        }

        if normalized.contains("home") || normalized.contains("house") {
            return locationsByName["home"]
        }
        if normalized.contains("school") {
            return locationsByName["school"]
        }
        return nil
    }

    private static func resolve(label: String, places: [String: PlaceCoordinate]) -> PlaceCoordinate? {
        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }

        if let exact = places[normalized] {
            return exact
        }

        for (key, coordinate) in places where normalized.contains(key) || key.contains(normalized) {
            return coordinate
        }

        if normalized.contains("home") || normalized.contains("house") {
            return places["home"]
        }
        if normalized.contains("school") {
            return places["school"]
        }
        if normalized.contains("work") {
            return places["work"]
        }
        return nil
    }
}
