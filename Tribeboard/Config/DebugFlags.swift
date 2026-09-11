import Foundation

enum DebugFlags {
#if DEBUG
    static let skipOnboarding: Bool = true
#else
    static let skipOnboarding: Bool = false
#endif

    /// Compile-time gate for demo/skip/mock launch paths. Always false in Release.
    static var allowsDebugBypasses: Bool {
#if DEBUG
        true
#else
        false
#endif
    }
}
