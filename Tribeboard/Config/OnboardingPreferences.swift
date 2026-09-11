import Foundation

/// Persists onboarding completion so returning users can enter the app shell instantly.
enum OnboardingPreferences {
    private static let completedOnboardingKey = "tb.onboarding.completed"

    struct BackendSnapshot: Equatable {
        let profileExists: Bool
        let householdExists: Bool
        let membershipExists: Bool
        let activeMembershipExists: Bool
        let activeHouseholdId: UUID?
        let childCount: Int

        /// Onboarding is complete when the user has a profile, household membership, and household.
        /// Child setup is optional for returning users — it can continue inside the main app.
        var isComplete: Bool {
            profileExists && householdExists && membershipExists && activeMembershipExists
        }
    }

    static func isCompletedOnboarding(userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.bool(forKey: completedOnboardingKey)
    }

    static func setCompletedOnboarding(_ completed: Bool, userDefaults: UserDefaults = .standard) {
        userDefaults.set(completed, forKey: completedOnboardingKey)
    }

    /// Fast path for returning users. Household id is rehydrated from backend during bootstrap.
    static func hasReturningUserCache(userDefaults: UserDefaults = .standard) -> Bool {
        isCompletedOnboarding(userDefaults: userDefaults)
    }

    /// Clears only the local completion flag (e.g. debug reset). Sign-out should not call this.
    static func clear(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: completedOnboardingKey)
    }

    static func evaluateBackendCompletion(
        profile: BackendProfile?,
        memberships: [BackendHouseholdMembership],
        activeHouseholdId: UUID?,
        childCount: Int = 0
    ) -> BackendSnapshot {
        let profileExists = hasMinimumProfile(profile)
        let activeMemberships = memberships.filter(\.isActiveMembership)
        let membershipExists = !memberships.isEmpty
        let activeMembershipExists = !activeMemberships.isEmpty
        let householdIds = Set(memberships.map(\.householdId))
        let householdExists = !householdIds.isEmpty
        let resolvedActiveHouseholdId: UUID? = {
            if let activeHouseholdId, householdIds.contains(activeHouseholdId) {
                return activeHouseholdId
            }
            return householdIds.first
        }()

        return BackendSnapshot(
            profileExists: profileExists,
            householdExists: householdExists,
            membershipExists: membershipExists,
            activeMembershipExists: activeMembershipExists,
            activeHouseholdId: resolvedActiveHouseholdId,
            childCount: childCount
        )
    }

    static func hasMinimumProfile(_ profile: BackendProfile?) -> Bool {
        guard let profile else { return false }
        let first = profile.first_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let last = profile.last_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !first.isEmpty, !last.isEmpty {
            return true
        }
        let display = profile.display_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !display.isEmpty
    }

#if DEBUG
    static func logBackendSnapshot(_ snapshot: BackendSnapshot, routingTo: String) {
        print(
            "[OnboardingCheck] profileExists=\(snapshot.profileExists), " +
            "householdExists=\(snapshot.householdExists), " +
            "membershipExists=\(snapshot.membershipExists), " +
            "activeMembershipExists=\(snapshot.activeMembershipExists), " +
            "activeHouseholdId=\(snapshot.activeHouseholdId?.uuidString ?? "nil"), " +
            "childCount=\(snapshot.childCount), " +
            "routingTo=\(routingTo)"
        )
    }
#endif
}
