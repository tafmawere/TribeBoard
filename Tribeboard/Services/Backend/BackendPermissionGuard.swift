import Foundation

enum BackendPermissionError: LocalizedError {
    case missingActiveMembership(action: String)
    case permissionDenied(action: String, role: String)

    var errorDescription: String? {
        switch self {
        case .missingActiveMembership(let action):
            return "Permission denied for \(action). No active household membership."
        case .permissionDenied(let action, let role):
            return "Permission denied for \(action). Role \(role) is not allowed."
        }
    }
}

enum BackendPermissionGuard {
    static func activeMembership(
        for householdId: UUID,
        memberships: [BackendHouseholdMembership]
    ) -> BackendHouseholdMembership? {
        memberships.first(where: { $0.householdId == householdId && $0.isActive })
    }

    @discardableResult
    static func requireActiveMembership(
        _ membership: BackendHouseholdMembership?,
        action: String
    ) throws -> HouseholdAccessRole {
        guard let membership, let role = membership.normalizedAccessRole else {
#if DEBUG
            print("[Permissions] denied action=\(action) role=none reason=missing_active_membership")
#endif
            throw BackendPermissionError.missingActiveMembership(action: action)
        }
        return role
    }

    static func requireOrganiser(
        _ membership: BackendHouseholdMembership?,
        action: String
    ) throws {
        let role = try requireActiveMembership(membership, action: action)
        guard role == .organiser else {
#if DEBUG
            print("[Permissions] denied action=\(action) role=\(role.rawValue)")
#endif
            throw BackendPermissionError.permissionDenied(action: action, role: role.rawValue)
        }
    }

    static func requireRunOperator(
        _ membership: BackendHouseholdMembership?,
        action: String
    ) throws {
        let role = try requireActiveMembership(membership, action: action)
        guard role == .organiser || role == .driver else {
#if DEBUG
            print("[Permissions] denied action=\(action) role=\(role.rawValue)")
#endif
            throw BackendPermissionError.permissionDenied(action: action, role: role.rawValue)
        }
    }
}
