import Foundation

enum BackendConfig {
    static let supabaseURLKey = "SUPABASE_URL"
    static let supabaseAnonKeyKey = "SUPABASE_ANON_KEY"

    static var supabaseURL: String {
        (Bundle.main.object(forInfoDictionaryKey: supabaseURLKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var supabaseAnonKey: String {
        (Bundle.main.object(forInfoDictionaryKey: supabaseAnonKeyKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var isBackendConfigured: Bool {
        guard let url = URL(string: supabaseURL), !supabaseURL.isEmpty else { return false }
        return !supabaseAnonKey.isEmpty && url.scheme != nil
    }

    // Backward-compatible aliases used by existing call sites.
    static var supabaseURLString: String { supabaseURL }
    static var isSupabaseConfigured: Bool { isBackendConfigured }
    static var isBackendNotConfigured: Bool { !isBackendConfigured }

    static func readFromInfoPlist() -> (supabaseURL: String, supabaseAnonKey: String) {
        (supabaseURL, supabaseAnonKey)
    }
}
