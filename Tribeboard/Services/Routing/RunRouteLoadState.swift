import Foundation

enum RunRouteLoadState: Equatable {
    case idle
    case loading
    case ready
    case failed(message: String)

    var userFacingMessage: String? {
        switch self {
        case .failed(let message): return message
        case .loading: return nil
        case .ready, .idle: return nil
        }
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}
