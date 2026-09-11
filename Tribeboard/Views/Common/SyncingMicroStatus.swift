import SwiftUI

/// Soft "Syncing..." label that appears only after loading exceeds a delay threshold.
struct SyncingMicroStatus: View {
    let isActive: Bool
    var delaySeconds: TimeInterval = 2

    @State private var showLabel = false

    var body: some View {
        Group {
            if showLabel {
                Text("Syncing...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showLabel)
        .task(id: isActive) {
            showLabel = false
            guard isActive else { return }
            let delay = UInt64(max(0, delaySeconds) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled, isActive else { return }
            showLabel = true
        }
    }
}
