import SwiftUI

struct AuthLandingView: View {
    @EnvironmentObject private var authSession: AuthSessionContext
    @State private var isLoginSheetPresented = true
    @State private var loginSheetDetent: PresentationDetent = .height(520)

    var body: some View {
        if let pendingEmail = authSession.pendingVerificationEmail {
            EmailVerificationView(email: pendingEmail) {
                authSession.cancelPendingVerification()
            }
        } else {
            Color.white
                .ignoresSafeArea()
                .sheet(isPresented: $isLoginSheetPresented) {
                    LoginSheetView()
                        .presentationDetents([.height(520), .large], selection: $loginSheetDetent)
                        .presentationDragIndicator(.visible)
                        .interactiveDismissDisabled()
                }
                .onAppear {
                    isLoginSheetPresented = true
                }
        }
    }
}

#Preview {
    AuthLandingView()
        .environmentObject(AppFlowState())
        .environmentObject(AuthSessionContext(authService: SupabaseAuthService()))
}
