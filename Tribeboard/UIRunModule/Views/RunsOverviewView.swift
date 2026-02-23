import SwiftUI

enum RunsOverviewTab: String, CaseIterable, Identifiable {
    case today = "Today"
    case upcoming = "Upcoming"
    case history = "History"

    var id: String { rawValue }
}

struct RunsOverviewView: View {
    @Binding var selectedTab: RunsOverviewTab
    let todayRuns: [UIRun]
    let upcomingRuns: [UIRun]
    let historyRuns: [UIRun]
    let activeRun: UIRun?
    let onOpenRunDetails: (UIRun) -> Void
    let onOpenObserver: (UIRun) -> Void

    private var currentRuns: [UIRun] {
        switch selectedTab {
        case .today: return todayRuns
        case .upcoming: return upcomingRuns
        case .history: return historyRuns
        }
    }

    var body: some View {
        ZStack {
            UIRunDesignSystem.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    tabs

                    if selectedTab == .today, let activeRun {
                        Text("Active Run")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(UIRunDesignSystem.textPrimary)

                        activeRunCard(activeRun)

                        HStack(spacing: 10) {
                            observerButton(for: activeRun)
                            UIPrimaryButton(title: "Open Driver View", icon: "steeringwheel") {
                                onOpenRunDetails(activeRun)
                            }
                        }
                    }

                    Text(selectedTab == .history ? "Past Runs" : "Runs")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)

                    if currentRuns.isEmpty {
                        if selectedTab == .upcoming {
                            upcomingEmptyState
                        } else {
                            UICard {
                                VStack(spacing: 10) {
                                    Image(systemName: "car.fill")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(UIRunDesignSystem.primary)
                                    Text("No runs in \(selectedTab.rawValue.lowercased())")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(UIRunDesignSystem.textPrimary)
                                    Text("Create a run to coordinate pickups and dropoffs.")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(UIRunDesignSystem.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                        }
                    } else {
                        ForEach(currentRuns) { run in
                            UIRunCard(run: run) {
                                onOpenRunDetails(run)
                            }
                            .saturation(selectedTab == .history ? 0.72 : 1.0)
                            .opacity(selectedTab == .history ? 0.84 : 1.0)
                            .shadow(
                                color: selectedTab == .history ? Color.black.opacity(0.025) : Color.clear,
                                radius: selectedTab == .history ? 6 : 0,
                                x: 0,
                                y: selectedTab == .history ? 3 : 0
                            )
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Runs")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack {
            Text("Runs")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(UIRunDesignSystem.textPrimary)
            Spacer()
        }
    }

    private var tabs: some View {
        HStack(spacing: 8) {
            ForEach(RunsOverviewTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selectedTab == tab ? .white : UIRunDesignSystem.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedTab == tab ? UIRunDesignSystem.primary : Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var upcomingEmptyState: some View {
        UICard {
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.secondary)
                Text("No upcoming runs scheduled.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                Button {
                    selectedTab = .today
                } label: {
                    Text("Create Run")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(UIRunDesignSystem.primary.opacity(0.10))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }

    private func activeRunCard(_ run: UIRun) -> some View {
        Button {
            onOpenRunDetails(run)
        }
        label: {
            UICard {
                VStack(alignment: .leading, spacing: 11) {
                    Text(run.status.rawValue.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(UIRunDesignSystem.primary.opacity(0.16))
                        .clipShape(Capsule())

                    Text(run.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)

                    HStack(spacing: 14) {
                        Label(run.etaText, systemImage: "clock")
                        Label(run.distanceText, systemImage: "location")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)

                    HStack {
                        Text("Driver: \(run.driverName)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .background(UIRunDesignSystem.primary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: UIRunDesignSystem.primary.opacity(0.20), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private func observerButton(for run: UIRun) -> some View {
        Button {
            onOpenObserver(run)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "location.viewfinder")
                Text("Track as Observer")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(UIRunDesignSystem.primary.opacity(0.86))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white)
            .overlay {
                Capsule()
                    .stroke(UIRunDesignSystem.primary.opacity(0.34), lineWidth: 1.2)
            }
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        RunsOverviewView(
            selectedTab: .constant(.today),
            todayRuns: [UIRunMockData.scheduledRun],
            upcomingRuns: [UIRunMockData.scheduledRun],
            historyRuns: UIRunMockData.historyRuns,
            activeRun: UIRunMockData.activeRun,
            onOpenRunDetails: { _ in },
            onOpenObserver: { _ in }
        )
    }
}
