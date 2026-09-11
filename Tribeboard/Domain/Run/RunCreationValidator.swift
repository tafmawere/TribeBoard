import Foundation

enum RunCreationValidator {
    enum ValidationError: LocalizedError, Equatable {
        case missingHouseholdId
        case missingRunDate
        case missingDepartureTime

        var errorDescription: String? {
            switch self {
            case .missingHouseholdId:
                return "A run must belong to a household."
            case .missingRunDate:
                return "A run must have a run date."
            case .missingDepartureTime:
                return "A run must have a departure time."
            }
        }
    }

    private static func hasValidRunDate(_ date: Date, calendar: Calendar = .current) -> Bool {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return components.year != nil && components.month != nil && components.day != nil
    }

    static func validate(_ run: SystemDomain.RunInstance) throws {
        if run.householdId.uuidString.isEmpty {
            throw ValidationError.missingHouseholdId
        }

        guard hasValidRunDate(run.date) else {
            throw ValidationError.missingRunDate
        }

        let trimmedDeparture = run.departureTime.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDeparture.isEmpty, RunScheduledTime.parse(trimmedDeparture) != nil else {
            throw ValidationError.missingDepartureTime
        }
    }

    static func validate(backendRun: BackendRun) throws {
        if backendRun.householdId.uuidString.isEmpty {
            throw ValidationError.missingHouseholdId
        }

        guard hasValidRunDate(backendRun.runDate) else {
            throw ValidationError.missingRunDate
        }

        let trimmedDeparture = backendRun.departureTime.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDeparture.isEmpty, RunScheduledTime.parse(trimmedDeparture) != nil else {
            throw ValidationError.missingDepartureTime
        }
    }
}
