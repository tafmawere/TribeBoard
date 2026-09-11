import Foundation

/// Production auth redirect targets for Supabase GoTrue (dashboard + signup/resend payloads).
enum AuthRedirectConfig {
    static let siteURL = "https://tribeboard.app"
    static let webCallbackURL = "https://tribeboard.app/auth/callback"
    static let appCallbackURL = "tribeboard://auth/callback"

    /// Values to allow in Supabase Dashboard → Authentication → URL Configuration → Redirect URLs.
    static let supabaseRedirectAllowList: [String] = [
        siteURL,
        webCallbackURL,
        appCallbackURL
    ]

    /// Passed as `options.email_redirect_to` on signup/resend (`POST /auth/v1/signup`, `/resend`).
    /// Must match a Supabase Dashboard redirect allow-list entry; produces `redirect_to` on confirmation links.
    static let emailConfirmationRedirectTo = "https://tribeboard.app/auth/callback"
}
