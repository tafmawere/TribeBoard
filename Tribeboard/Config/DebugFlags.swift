import Foundation

enum DebugFlags {
#if DEBUG
    static let skipOnboarding: Bool = true
#else
    static let skipOnboarding: Bool = false
#endif
}
