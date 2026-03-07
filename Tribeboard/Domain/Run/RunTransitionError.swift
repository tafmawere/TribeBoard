import Foundation

enum RunTransitionError: Error {
    case invalidTransition
    case invalidStopIndex
    case alreadyCompleted
    case alreadyCancelled
    case notStarted
}
