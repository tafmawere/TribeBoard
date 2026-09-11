import SwiftUI
import Combine

@MainActor
final class AppFlowState: ObservableObject {
    enum Route {
        case splash
        case auth
        case home
    }

    @Published var route: Route = .splash
    /// True once session restore and initial routing evaluation have finished (auth or home ready).
    @Published private(set) var isLaunchReady = false
    /// Splash overlay stays visible until crossfade to auth/home completes.
    @Published private(set) var isSplashOverlayVisible = true
    /// 0 → 1 while login/home rises in beneath the fading splash.
    @Published private(set) var destinationEntranceProgress: CGFloat = 0
    @Published var isAuthenticated: Bool = false
    @Published var onboardingComplete: Bool = false
    @Published var onboardingDestinationTab: AppTab = .home
    @Published var onboardingMembershipCount: Int = 0
    @Published var onboardingChildCount: Int = 0
    @Published var pendingPostOnboardingAddChild = false
    @Published var rootReloadToken: UUID = UUID()
    let tribeStore: TribeStore
    private let userDefaults: UserDefaults

    init(tribeStore: TribeStore, userDefaults: UserDefaults = .standard) {
        self.tribeStore = tribeStore
        self.userDefaults = userDefaults
        self.onboardingComplete = OnboardingPreferences.isCompletedOnboarding(userDefaults: userDefaults)
    }

    @MainActor
    convenience init() {
        self.init(tribeStore: TribeStore())
    }

    func markLaunchReady() {
        guard !isLaunchReady else { return }
        isLaunchReady = true
    }

    static let splashTransitionDuration: Double = 0.55

    func beginSplashTransition(reducedMotion: Bool = false) {
        route = isAuthenticated ? .home : .auth
        if reducedMotion {
            destinationEntranceProgress = 1
        } else {
            withAnimation(.easeInOut(duration: Self.splashTransitionDuration)) {
                destinationEntranceProgress = 1
            }
        }
    }

    func endSplashOverlay() {
        isSplashOverlayVisible = false
    }

    func completeSplash() {
        route = isAuthenticated ? .home : .auth
        destinationEntranceProgress = 1
        isSplashOverlayVisible = false
    }

    func syncAuthenticationState(_ authenticated: Bool) {
        isAuthenticated = authenticated
        if route != .splash {
            route = authenticated ? .home : .auth
        }
    }

    func signIn() {
        isAuthenticated = true
        route = .home
    }

    func signOut() {
        isAuthenticated = false
        route = .auth
        onboardingMembershipCount = 0
        onboardingChildCount = 0
        pendingPostOnboardingAddChild = false
        // Keep OnboardingPreferences intact — completion is revalidated from backend on next sign-in.
        rootReloadToken = UUID()
    }

    func completeOnboarding(startingTab: AppTab = .home) {
        onboardingDestinationTab = startingTab
        onboardingComplete = true
        OnboardingPreferences.setCompletedOnboarding(true, userDefaults: userDefaults)
        OnboardingTestingPreferences.clearForceOnboardingOnNextLaunch()
        route = .home
        rootReloadToken = UUID()
    }

    var isOnboarded: Bool {
        onboardingComplete
    }

    func updateOnboardingSnapshot(membershipCount: Int, childCount: Int, onboardingComplete: Bool? = nil) {
        onboardingMembershipCount = membershipCount
        onboardingChildCount = childCount
        if let onboardingComplete {
            self.onboardingComplete = onboardingComplete
            OnboardingPreferences.setCompletedOnboarding(onboardingComplete, userDefaults: userDefaults)
        } else {
            let complete = membershipCount > 0
            self.onboardingComplete = complete
            if complete {
                OnboardingPreferences.setCompletedOnboarding(true, userDefaults: userDefaults)
            }
        }
    }

    func updateOnboardingSnapshot(onboardingComplete: Bool) {
        self.onboardingComplete = onboardingComplete
        OnboardingPreferences.setCompletedOnboarding(onboardingComplete, userDefaults: userDefaults)
    }
}
