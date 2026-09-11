import Foundation
import GoogleSignIn

enum GoogleSignInBootstrap {
    private static let bootstrapLock = NSLock()
    private(set) static var isConfigured = false

    static func configureIfNeeded() {
        bootstrapLock.lock()
        defer { bootstrapLock.unlock() }

        guard !isConfigured else { return }
        guard let clientID = GoogleSignInConfig.clientID else {
#if DEBUG
            NSLog("[GoogleSignInBootstrap] Missing GIDClientID — set GOOGLE_IOS_CLIENT_ID in Secrets.xcconfig (see Secrets.xcconfig.example).")
#endif
            return
        }

        let webClientID = GoogleSignInConfig.webClientID
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: clientID,
            serverClientID: webClientID
        )
        isConfigured = true
#if DEBUG
        if let webClientID {
            NSLog("[GoogleSignInBootstrap] Configured Google Sign-In (iOS + web server client).")
        } else {
            NSLog("[GoogleSignInBootstrap] Configured Google Sign-In for iOS only. Set GOOGLE_WEB_CLIENT_ID in Secrets.xcconfig for Supabase token exchange.")
        }
#endif
    }
}
