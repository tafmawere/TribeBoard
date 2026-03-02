import SwiftUI

struct SplashMockData {
    let appName: String
    let tagline: String
    let loadingMessage: String
    let progressValue: CGFloat
    let securityMessage: String

    static let preview = SplashMockData(
        appName: "TribeBoard",
        tagline: "The operating system for your family",
        loadingMessage: "Initializing dashboard",
        progressValue: 0.35,
        securityMessage: "SECURED & PRIVATE"
    )
}
