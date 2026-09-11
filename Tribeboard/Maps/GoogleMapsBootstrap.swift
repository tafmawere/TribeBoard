import Foundation
import GoogleMaps
import GooglePlaces

enum GoogleMapsBootstrap {
    private static let infoPlistKey = "GOOGLE_MAPS_API_KEY"
    private static let environmentKey = "GOOGLE_MAPS_API_KEY"
    private static let bootstrapLock = NSLock()

    /// `true` only after `GMSServices.provideAPIKey` ran with a non-empty key. Map views must not touch `GMSMapView` when this is `false`.
    private(set) static var isConfigured = false

    /// Reads `GOOGLE_MAPS_API_KEY` from the merged Info.plist (typically supplied via xcconfig) or from process environment.
    static func loadAPIKey() -> String {
        if let env = ProcessInfo.processInfo.environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty {
            return env
        }
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String {
            let trimmed = plistValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, trimmed != "$(\(infoPlistKey))" {
                return trimmed
            }
        }
        return ""
    }

    /// Thread-safe; safe to call from `App.init` only. `GMSServices.provideAPIKey` / `GMSPlacesClient.provideAPIKey` run at most once per process after a non-empty key is resolved.
    static func configureIfNeeded() {
        bootstrapLock.lock()
        defer { bootstrapLock.unlock() }

        guard !isConfigured else { return }

        let key = loadAPIKey()
        guard !key.isEmpty else {
            #if DEBUG
            NSLog("[GoogleMapsBootstrap] Missing GOOGLE_MAPS_API_KEY — add Secrets.xcconfig (see Secrets.xcconfig.example) or set the user-defined build setting.")
            #endif
            return
        }
        let mapsOk = GMSServices.provideAPIKey(key)
        GMSPlacesClient.provideAPIKey(key)
        isConfigured = true
        // Keeps one long-lived services connection; frequent map create/destroy (e.g. TabView) otherwise restarts the SDK connection and can delay or stall tiles.
        _ = GMSServices.sharedServices()
#if DEBUG
        if !mapsOk {
            NSLog("[GoogleMapsBootstrap] GMSServices.provideAPIKey returned false — key may be invalid or rejected.")
        }
        let bid = Bundle.main.bundleIdentifier ?? "(nil)"
        NSLog("[GoogleMapsBootstrap] Maps SDK %@ — bundle id for key restrictions: %@", GMSServices.sdkVersion(), bid)
#endif
    }
}
