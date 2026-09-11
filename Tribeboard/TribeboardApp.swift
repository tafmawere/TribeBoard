import SwiftUI

@main
struct TribeboardApp: App {
    @StateObject private var flow = AppFlowState()
    @StateObject private var backendProfileContext: BackendProfileContext
    @StateObject private var authSession: AuthSessionContext

    init() {
        // Sole entry point for Maps/Places SDK keys — do not call `GoogleMapsBootstrap.configureIfNeeded()` from views (duplicate `provideAPIKey` triggers Clearcut warnings and undefined SDK state).
        GoogleMapsBootstrap.configureIfNeeded()
        GoogleSignInBootstrap.configureIfNeeded()
        let profileContext = BackendProfileContext()
        _backendProfileContext = StateObject(wrappedValue: profileContext)
        _authSession = StateObject(
            wrappedValue: AuthSessionContext(
                authService: SupabaseAuthService(),
                backendProfileContext: profileContext
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if MapDebugLaunchGate.launchStraightIntoMapDebug {
                MapDebugView()
            } else {
                RootFlowView()
                    .environmentObject(flow)
                    .environmentObject(authSession)
                    .environmentObject(backendProfileContext)
            }
            #else
            RootFlowView()
                .environmentObject(flow)
                .environmentObject(authSession)
                .environmentObject(backendProfileContext)
            #endif
        }
    }
}
