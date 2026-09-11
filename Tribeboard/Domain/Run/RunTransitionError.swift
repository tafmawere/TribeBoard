import Foundation

enum RunTransitionError: Error, Equatable {
    case invalidTransition
    case invalidStopIndex
    case alreadyCompleted
    case alreadyCancelled
    case notStarted
}
