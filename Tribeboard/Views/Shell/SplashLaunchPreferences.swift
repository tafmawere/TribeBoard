import Foundation

/// Persists whether the user has seen the full first-launch splash sequence.
enum SplashLaunchPreferences {
    private static let hasCompletedFirstLaunchKey = "tb.splash.hasCompletedFirstLaunch"

    static var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: hasCompletedFirstLaunchKey)
    }

    static func markFirstLaunchComplete() {
        UserDefaults.standard.set(true, forKey: hasCompletedFirstLaunchKey)
    }
}
