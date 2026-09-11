import Foundation

enum ProfileRoleKind: String, CaseIterable, Identifiable {
    case organiser
    case parent
    case driver

    var id: String { rawValue }

    var title: String {
        switch self {
        case .organiser: return "Organiser"
        case .parent: return "Parent"
        case .driver: return "Driver"
        }
    }

    var icon: String {
        switch self {
        case .organiser: return "crown.fill"
        case .parent: return "figure.2.and.child.holdinghands"
        case .driver: return "car.fill"
        }
    }
}

enum ProfileIdentityRoles {
    static func visibleRoles(
        membership: BackendHouseholdMembership?,
        isOrganiser: Bool,
        isDriver: Bool
    ) -> [ProfileRoleKind] {
        var roles: [ProfileRoleKind] = []
        if isOrganiser { roles.append(.organiser) }
        if isParent(membership) { roles.append(.parent) }
        if isDriver { roles.append(.driver) }

        if roles.isEmpty, let accessRole = membership?.normalizedAccessRole {
            switch accessRole {
            case .organiser:
                roles = [.organiser]
            case .driver:
                roles = [.driver]
            case .observer:
                break
            }
        }
        return roles
    }

    private static func isParent(_ membership: BackendHouseholdMembership?) -> Bool {
        let candidates = [membership?.relationshipLabel, membership?.familyRole]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        return candidates.contains { label in
            label.contains("parent")
                || label.contains("guardian")
                || label.contains("mother")
                || label.contains("father")
                || label.contains("mom")
                || label.contains("dad")
        }
    }

    static func joinedMonthYear(from raw: String?) -> String? {
        guard let raw,
              let date = BackendTimestampParser.parse(raw) else {
            return nil
        }
        return joinedMonthYearFormatter.string(from: date)
    }

    private static let joinedMonthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()
}
