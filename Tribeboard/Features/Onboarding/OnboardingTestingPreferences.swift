import Foundation

/// Debug/testing controls for forcing onboarding to appear on the next authenticated launch.
enum OnboardingTestingPreferences {
    private static let forceOnboardingKey = "tb.testing.forceOnboardingOnNextLaunch"
    private static let onboardingDraftKey = "tb.onboarding.tribe.flow.v1"
    private static let fastFamilyDraftKey = "tb.onboarding.fastFamilySetup.v1"

    static var forceOnboardingOnNextLaunch: Bool {
        get {
#if DEBUG
            UserDefaults.standard.bool(forKey: forceOnboardingKey)
#else
            false
#endif
        }
        set {
#if DEBUG
            UserDefaults.standard.set(newValue, forKey: forceOnboardingKey)
#else
            UserDefaults.standard.removeObject(forKey: forceOnboardingKey)
#endif
        }
    }

    /// Marks onboarding incomplete in memory and persists a launch flag so RootFlowView routes to onboarding.
    static func resetForNextLaunch(flow: AppFlowState, userDefaults: UserDefaults = .standard) {
#if DEBUG
        userDefaults.set(true, forKey: forceOnboardingKey)
        flow.updateOnboardingSnapshot(membershipCount: 0, childCount: 0, onboardingComplete: false)
        OnboardingPreferences.clear(userDefaults: userDefaults)
        userDefaults.removeObject(forKey: onboardingDraftKey)
        userDefaults.removeObject(forKey: fastFamilyDraftKey)
        OnboardingInviteDismissalStore.clear(userDefaults: userDefaults)
#else
        _ = flow
        _ = userDefaults
#endif
    }

    static func clearForceOnboardingOnNextLaunch(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: forceOnboardingKey)
    }
}
