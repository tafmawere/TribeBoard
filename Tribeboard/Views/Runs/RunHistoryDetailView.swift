import SwiftUI

struct RunHistoryDetailView: View {
    let run: RunDetailsData.UIRun

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                auditTrailCard
                routeCard
                actionsCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(RunStitchTheme.background.ignoresSafeArea())
        .navigationTitle("Run History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        StitchCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(run.title)
                    .font(.system(size: 22, weight: .bold))
                HStack {
                    Text(formattedDate(run.scheduledTime))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(RunStitchTheme.textSecondary)
                    Spacer()
                    StatusBadge(text: "Completed", color: RunStitchTheme.success)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var auditTrailCard: some View {
        StitchCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Audit Trail")
                ForEach(Array(run.timeline.enumerated()), id: \.element.id) { index, event in
                    TimelineRow(event: event, isLast: index == run.timeline.count - 1)
                }
            }
        }
    }

    private var routeCard: some View {
        StitchCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Route Recap")
                ForEach(run.stops) { stop in
                    HStack {
                        RoleChip(
                            text: stop.type,
                            color: stop.type == "Pickup" ? RunStitchTheme.indigo : RunStitchTheme.success
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stop.label)
                                .font(.system(size: 15, weight: .semibold))
                            Text(stop.address)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(RunStitchTheme.textSecondary)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private var actionsCard: some View {
        StitchCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Support")
                SecondaryButton(title: "Report issue") {
                    print("Report issue tapped")
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM • h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        RunHistoryDetailView(run: RunDetailsData.completedRun)
    }
}
