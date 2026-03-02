import Foundation
import Combine

@MainActor
final class TermsAcceptanceStore: ObservableObject {
    private enum Keys {
        static let hasAcceptedTerms = "tribeboard_hasAcceptedTerms_v1"
        static let acceptedAt = "tribeboard_termsAcceptedAt_v1"
        static let termsVersion = "tribeboard_termsVersion_v1"
    }

    @Published private(set) var hasAcceptedTerms: Bool

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        userDefaults.register(defaults: [Keys.termsVersion: "v1"])
        self.hasAcceptedTerms = userDefaults.bool(forKey: Keys.hasAcceptedTerms)
    }

    func acceptTerms(version: String = "v1") {
        hasAcceptedTerms = true
        userDefaults.set(true, forKey: Keys.hasAcceptedTerms)
        userDefaults.set(Date(), forKey: Keys.acceptedAt)
        userDefaults.set(version, forKey: Keys.termsVersion)
    }

    private let userDefaults: UserDefaults
}
