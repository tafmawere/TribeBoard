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
    @Published var isAuthenticated: Bool = false
    @Published var onboardingComplete: Bool = false
    @Published var onboardingDestinationTab: AppTab = .home
    let tribeStore: TribeStore

    init(tribeStore: TribeStore) {
        self.tribeStore = tribeStore
    }

    @MainActor
    convenience init() {
        self.init(tribeStore: TribeStore())
    }

    func completeSplash() {
        route = isAuthenticated ? .home : .auth
    }

    func signIn() {
        isAuthenticated = true
        route = .home
    }

    func signOut() {
        isAuthenticated = false
        route = .auth
    }

    func completeOnboarding(startingTab: AppTab = .home) {
        onboardingDestinationTab = startingTab
        onboardingComplete = true
        route = .home
    }
}
