import Foundation

enum HouseholdLocationBackfillService {
    struct BackfillResult: Equatable {
        let repairedStopCount: Int
        let linkedChildCount: Int
        let unresolvedStopLabels: [String]
    }

    static func backfillScheduleStops(
        _ stops: [SystemDomain.Stop],
        locations: [BackendHouseholdLocation],
        service: HouseholdLocationBackendService = SupabaseHouseholdLocationBackendService()
    ) -> ([SystemDomain.Stop], BackfillResult) {
        var repaired = 0
        var unresolved: [String] = []
        let updated = stops.map { stop -> SystemDomain.Stop in
            if HouseholdLocationCoordinateValidator.isValid(latitude: stop.latitude, longitude: stop.longitude),
               stop.locationId != nil {
                return stop
            }
            if let locationId = stop.locationId,
               let linked = locations.first(where: { $0.id == locationId }) {
                var hydrated = stop
                hydrated.name = linked.displayName
                hydrated.latitude = linked.latitude
                hydrated.longitude = linked.longitude
                repaired += 1
                return hydrated
            }
            if let match = service.findLocationByNameOrLabel(stop.name, in: locations, preferredType: nil) {
                var hydrated = stop
                hydrated.locationId = match.id
                hydrated.name = match.displayName
                hydrated.latitude = match.latitude
                hydrated.longitude = match.longitude
                repaired += 1
                return hydrated
            }
            if StopCoordinateHydrator.isPlaceholder(latitude: stop.latitude, longitude: stop.longitude) {
                unresolved.append(stop.name)
            }
            return stop
        }
        return (updated, BackfillResult(repairedStopCount: repaired, linkedChildCount: 0, unresolvedStopLabels: unresolved))
    }

    static func backfillChildrenSchoolLinks(
        children: [BackendChild],
        locations: [BackendHouseholdLocation],
        service: HouseholdLocationBackendService = SupabaseHouseholdLocationBackendService()
    ) -> ([BackendChild], Int) {
        var linked = 0
        let updated = children.map { child -> BackendChild in
            guard child.schoolLocationId == nil,
                  let schoolName = child.schoolName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                  let match = service.findLocationByNameOrLabel(
                    schoolName,
                    in: locations,
                    preferredType: .school
                  ) else {
                return child
            }
            var mutable = child
            mutable.schoolLocationId = match.id
            linked += 1
            return mutable
        }
        return (updated, linked)
    }

    static func applySchoolLinkIfNeeded(
        child: inout BackendChild,
        savedLocation: BackendHouseholdLocation
    ) {
        guard savedLocation.locationType == .school else { return }
        let schoolName = child.schoolName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let savedName = savedLocation.displayName.lowercased()
        if schoolName.isEmpty || schoolName == savedName || savedName.contains(schoolName) || schoolName.contains(savedName) {
            child.schoolLocationId = savedLocation.id
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
