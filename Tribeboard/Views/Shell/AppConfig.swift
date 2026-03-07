import Foundation

enum AppConfig {
#if DEBUG
    static let isDemoFlowEnabled = true
#else
    static let isDemoFlowEnabled = false
#endif
}
