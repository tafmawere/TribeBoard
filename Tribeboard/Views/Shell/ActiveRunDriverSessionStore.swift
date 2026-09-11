import Combine
import Foundation

@MainActor
final class ActiveRunDriverSessionStore: ObservableObject {
    struct Presentation: Identifiable {
        let id: UUID
    }

    @Published var presentation: Presentation?

    func present(runId: UUID) {
        presentation = Presentation(id: runId)
    }

    func dismiss() {
        presentation = nil
    }
}
