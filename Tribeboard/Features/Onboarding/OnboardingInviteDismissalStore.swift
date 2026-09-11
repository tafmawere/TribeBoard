import Foundation

/// Invite IDs the user chose "Decline / Not now" during onboarding (invite stays pending server-side).
enum OnboardingInviteDismissalStore {
    private static let key = "tb.onboarding.dismissedInviteIds"

    static func dismissedIds(userDefaults: UserDefaults = .standard) -> Set<UUID> {
        let raw = userDefaults.stringArray(forKey: key) ?? []
        return Set(raw.compactMap { UUID(uuidString: $0) })
    }

    static func dismiss(inviteId: UUID, userDefaults: UserDefaults = .standard) {
        var ids = dismissedIds(userDefaults: userDefaults)
        ids.insert(inviteId)
        userDefaults.set(Array(ids).map { $0.uuidString.lowercased() }, forKey: key)
    }

    static func dismissAll(_ inviteIds: [UUID], userDefaults: UserDefaults = .standard) {
        var ids = dismissedIds(userDefaults: userDefaults)
        inviteIds.forEach { ids.insert($0) }
        userDefaults.set(Array(ids).map { $0.uuidString.lowercased() }, forKey: key)
    }

    static func clear(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: key)
    }
}
