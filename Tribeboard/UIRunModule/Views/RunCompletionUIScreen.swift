import SwiftUI

struct RunCompletionUIScreen: View {
    let run: UIRun
    let timeline: [UITimelineItem]
    let onBackToDashboard: () -> Void
    let onViewHistory: () -> Void

    var body: some View {
        ZStack {
            UIRunDesignSystem.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    UICard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(UIRunDesignSystem.success)
                                Text("Run Completed")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                            }
                            Text("\(run.title) finished successfully.")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                        }
                    }

                    statsGrid

                    Text("Timeline Recap")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)

                    UICard {
                        VStack(spacing: 4) {
                            ForEach(Array(timeline.enumerated()), id: \.element.id) { index, item in
                                UITimelineRow(item: item, isCurrent: index == timeline.count - 1)
                            }
                        }
                    }

                    UIPrimaryButton(title: "Back to Dashboard", icon: "house.fill") {
                        onBackToDashboard()
                    }

                    UISecondaryButton(title: "View History", icon: "clock.arrow.circlepath") {
                        onViewHistory()
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Run Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statsGrid: some View {
        HStack(spacing: 10) {
            statCard(title: "Duration", value: "48 min")
            statCard(title: "Stops", value: "\(run.stops.count)")
            statCard(title: "Efficiency", value: "92%")
        }
    }

    private func statCard(title: String, value: String) -> some View {
        UICard {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    NavigationStack {
        RunCompletionUIScreen(
            run: UIRunMockData.activeRun,
            timeline: UIRunMockData.timeline,
            onBackToDashboard: {},
            onViewHistory: {}
        )
    }
}
