import SwiftUI

struct RootFlowView: View {
    @EnvironmentObject var flow: AppFlowState
    @StateObject private var termsStore = TermsAcceptanceStore()

    var body: some View {
        Group {
            switch flow.route {
            case .splash:
                SplashScreenView()
            case .auth:
                NavigationStack {
                    AuthLandingView()
                }
            case .home:
                if flow.isAuthenticated {
                    TermsGateView(termsStore: termsStore, onDecline: {
                        flow.signOut()
                    }) {
                        postAuthEntryView
                    }
                } else {
                    NavigationStack {
                        AuthLandingView()
                    }
                }
            }
        }
        .onAppear { applyDebugSkipOnboardingIfNeeded() }
    }

    @ViewBuilder
    private var postAuthEntryView: some View {
        if AppConfig.isDemoFlowEnabled && !flow.onboardingComplete {
            OnboardingFlowView()
        } else {
            DemoShellView(store: flow.tribeStore, initialTab: flow.onboardingDestinationTab)
        }
    }

    private func applyDebugSkipOnboardingIfNeeded() {
#if DEBUG
        guard DebugFlags.skipOnboarding else { return }
        if !flow.isAuthenticated {
            flow.signIn()
        }
        if !flow.onboardingComplete {
            // Reuse normal completion path so shell/tab state stays consistent.
            flow.completeOnboarding(startingTab: .home)
        }
#endif
    }
}

#Preview {
    RootFlowView()
        .environmentObject(AppFlowState())
}
