import Foundation

enum ETAConfidenceLevel: String, Equatable {
    case low
    case medium
    case high
}

struct ETAQuality: Equatable {
    let confidence: ETAConfidenceLevel
    let sampleCount: Int
    let usedLiveSpeed: Bool
    let speedVariance: Double?
    let reason: String
}
