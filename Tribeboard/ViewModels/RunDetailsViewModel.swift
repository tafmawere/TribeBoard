import Foundation
import SwiftUI
import Combine

@MainActor
final class RunDetailsViewModel: ObservableObject {
    @Published var run: SystemDomain.RunInstance?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showAlert = false
    @Published var alertMessage = ""

    let runId: String
    let currentUserId: String

    var onOpenDriverLive: (() -> Void)?
    var onOpenObserverLive: (() -> Void)?
    var onOpenCompletionSummary: (() -> Void)?

    private weak var runDataSource: RunDataSource?
    private let startRunHandler: ((String) async throws -> Void)?

    init(
        runId: String,
        currentUserId: String,
        runDataSource: RunDataSource? = nil,
        startRunHandler: ((String) async throws -> Void)? = nil
    ) {
        self.runId = runId
        self.currentUserId = currentUserId
        self.runDataSource = runDataSource
        self.startRunHandler = startRunHandler
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        guard let runDataSource else {
            run = nil
            errorMessage = "Run data is unavailable."
            return
        }
        await runDataSource.refresh()
        let found = runDataSource.run(withId: runId)
        run = found
        if found == nil {
            errorMessage = "Run not found."
        } else {
            errorMessage = nil
        }
    }

    func startRun() async {
        guard let run else { return }
        guard run.driverId?.uuidString == currentUserId else {
            alertMessage = "Only the assigned driver can start this run."
            showAlert = true
            return
        }

        if let startRunHandler {
            do {
                try await startRunHandler(run.id.uuidString)
                onOpenDriverLive?()
            } catch {
                alertMessage = "Unable to start run right now."
                showAlert = true
            }
        } else {
            // Fallback for current UI-only project state where run intent services are not present.
            alertMessage = "Run started (mock). Intent pipeline wiring pending."
            showAlert = true
            onOpenDriverLive?()
        }
    }

    func openInMaps() {
        guard
            let run,
            let firstStop = run.stopSnapshots.first
        else { return }

        let lat = firstStop.latitude
        let lng = firstStop.longitude
        if let url = URL(string: "http://maps.apple.com/?daddr=\(lat),\(lng)") {
            UIApplication.shared.open(url)
        }
    }

    func primaryAction() {
        guard let run else { return }
        switch run.status {
        case .scheduled:
            // Scheduled uses explicit Start Run button.
            break
        case .inProgress:
            if run.driverId?.uuidString == currentUserId {
                onOpenDriverLive?()
            } else {
                onOpenObserverLive?()
            }
        case .completed:
            onOpenCompletionSummary?()
        case .cancelled:
            alertMessage = "This run is cancelled."
            showAlert = true
        }
    }
}
