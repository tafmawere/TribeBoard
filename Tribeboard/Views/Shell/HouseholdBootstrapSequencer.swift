import Foundation

/// Client-only shell sequencing after membership refresh.
/// Does not create memberships or change INSERT/accept rules.
enum HouseholdBootstrapPhase: Equatable {
    case idle
    case loading
    case resolved(hasHousehold: Bool)
    case loadFailed(message: String)
}

enum HouseholdBootstrapSequencer {
    /// Early exit after `refresh()`. `nil` means continue to household selection.
    static func phaseAfterMembershipRefresh(
        membershipCount: Int,
        lastError: String?,
        treatsErrorAsCancellation: Bool
    ) -> HouseholdBootstrapPhase? {
        guard membershipCount == 0 else { return nil }
        if let lastError, !lastError.isEmpty, !treatsErrorAsCancellation {
            return .loadFailed(message: lastError)
        }
        return .resolved(hasHousehold: false)
    }

    static func phaseAfterSelection(resolvedHouseholdId: UUID?) -> HouseholdBootstrapPhase {
        .resolved(hasHousehold: resolvedHouseholdId != nil)
    }

    static func showsCreateFlow(
        isAuthenticated: Bool,
        didRestoreSession: Bool,
        phase: HouseholdBootstrapPhase,
        hasActiveMembership: Bool
    ) -> Bool {
        guard isAuthenticated, didRestoreSession else { return false }
        if case .resolved(let hasHousehold) = phase {
            return !hasHousehold || !hasActiveMembership
        }
        return false
    }

    static func showsLoadFailure(
        isAuthenticated: Bool,
        didRestoreSession: Bool,
        phase: HouseholdBootstrapPhase
    ) -> Bool {
        guard isAuthenticated, didRestoreSession else { return false }
        if case .loadFailed = phase { return true }
        return false
    }

    static func loadFailureMessage(
        phase: HouseholdBootstrapPhase,
        fallback: String
    ) -> String {
        if case .loadFailed(let message) = phase { return message }
        return fallback
    }

    static func isContentLoading(
        isAuthenticated: Bool,
        didRestoreSession: Bool,
        phase: HouseholdBootstrapPhase,
        showsCreateFlow: Bool,
        restoredActiveHouseholdId: UUID?,
        activeHouseholdId: UUID?,
        isDependentDataLoading: Bool,
        dependentDataLoadedHouseholdId: UUID?
    ) -> Bool {
        guard isAuthenticated, didRestoreSession else { return false }
        if showsCreateFlow { return false }
        switch phase {
        case .idle:
            return true
        case .loading:
            return restoredActiveHouseholdId == nil
        case .loadFailed:
            return false
        case .resolved(let hasHousehold):
            guard hasHousehold else { return false }
            guard let activeHouseholdId else { return true }
            return isDependentDataLoading || dependentDataLoadedHouseholdId != activeHouseholdId
        }
    }
}
