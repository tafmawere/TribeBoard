import SwiftUI

struct RootFlowView: View {
    @EnvironmentObject var flow: AppFlowState
    @StateObject private var termsStore = TermsAcceptanceStore()

    var body: some View {
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

    @ViewBuilder
    private var postAuthEntryView: some View {
        if AppConfig.isDemoFlowEnabled && !flow.onboardingComplete {
            OnboardingFlowView()
        } else {
            DemoShellView(store: flow.tribeStore, initialTab: flow.onboardingDestinationTab)
        }
    }
}

#Preview {
    RootFlowView()
        .environmentObject(AppFlowState())
}
