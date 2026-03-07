import SwiftUI

private enum UIRunRoute: Hashable {
    case runDetails(String)
    case runFocus(UIRun)
    case driverMode(UIRun)
    case observer(UIRun)
    case completion(UIRun)
}

struct UIRunModuleRootView: View {
    @State private var path: [UIRunRoute] = []
    @State private var selectedTab: RunsOverviewTab = .today
    @State private var boardMode: RunsBoardMode = .runs
    @StateObject private var runDataSource = RunDataSource()
    @StateObject private var driverDataSource = DriverDataSource()

    var body: some View {
        NavigationStack(path: $path) {
            RunsOverviewView(
                selectedTab: $selectedTab,
                boardMode: $boardMode,
                todayRuns: todayRuns,
                upcomingRuns: upcomingRuns,
                historyRuns: historyRuns,
                activeRun: activeRun,
                suggestedRuns: [],
                onOpenRunDetails: { run in
                    path.append(.runDetails(run.backingRunId))
                },
                onOpenObserver: { run in
                    path.append(.observer(run))
                },
                onStartSuggestion: { _ in },
                onSnoozeSuggestion: { _ in },
                onDismissSuggestion: { _ in }
            )
            .environmentObject(runDataSource)
            .environmentObject(driverDataSource)
            .navigationDestination(for: UIRunRoute.self) { route in
                switch route {
                case let .runDetails(runId):
                    runDetailsDestination(runId: runId)
                case let .runFocus(run):
                    RunFocusUIScreen(run: run, isDriver: true) {
                        path.append(.driverMode(run))
                    }
                case let .driverMode(run):
                    DriverModeUIScreen(run: run) {
                        path.append(.completion(run))
                    }
                case let .observer(run):
                    ObserverTrackingUIScreen(run: run, timeline: UIRunMockData.timeline)
                case let .completion(run):
                    RunCompletionUIScreen(
                        run: run,
                        timeline: UIRunMockData.timeline,
                        onBackToDashboard: { path.removeAll() },
                        onViewHistory: {
                            selectedTab = .history
                            path.removeAll()
                        }
                    )
                }
            }
        }
        .task {
            await runDataSource.bootstrapIfNeeded()
            await driverDataSource.bootstrapIfNeeded()
        }
    }

    private var allSystemRuns: [SystemDomain.RunInstance] {
        runDataSource.runs.sorted { $0.date < $1.date }
    }

    private var allUIRuns: [UIRun] {
        allSystemRuns.map(RunUIAdapter.mapToUIRun)
    }

    private var activeRun: UIRun? {
        allUIRuns.first(where: { $0.status == .active })
    }

    private var todayRuns: [UIRun] {
        let calendar = Calendar.current
        let today = Date()
        return allSystemRuns.filter { run in
            let isTerminal = run.status == .completed || run.status == .cancelled
            return calendar.isDate(run.date, inSameDayAs: today) && !isTerminal
        }.map(RunUIAdapter.mapToUIRun)
    }

    private var upcomingRuns: [UIRun] {
        let calendar = Calendar.current
        let today = Date()
        return allSystemRuns.filter { run in
            run.status == .scheduled && !calendar.isDate(run.date, inSameDayAs: today) && run.date > today
        }.map(RunUIAdapter.mapToUIRun)
    }

    private var historyRuns: [UIRun] {
        allSystemRuns.filter { run in
            run.status == .completed || run.status == .cancelled
        }.map(RunUIAdapter.mapToUIRun)
    }

    private func runForRunId(_ runId: String) -> UIRun? {
        allUIRuns.first { $0.backingRunId == runId }
    }

    private func runDetailsDestination(runId: String) -> some View {
        let mapped = mapUIRunToRunDetails(runForRunId(runId))
        return RunDetailsView(run: mapped)
    }

    private func mapUIRunToRunDetails(_ run: UIRun?) -> RunDetailsData.UIRun {
        guard let run else { return RunDetailsData.scheduledRun }
        let now = Date()
        let timeline: [RunDetailsData.UITimelineEvent] = [
            .init(time: now.addingTimeInterval(-1800), title: "Scheduled", detail: "Run prepared", iconName: "calendar", severity: .normal),
            .init(time: now.addingTimeInterval(-900), title: "Reminder", detail: "Family notified", iconName: "bell", severity: .normal)
        ]
        let statusLabel: String = {
            switch run.status {
            case .scheduled: return "Scheduled"
            case .active: return "Active"
            case .completed: return "Completed"
            }
        }()

        return RunDetailsData.UIRun(
            title: run.title,
            scheduledTime: now,
            status: statusLabel,
            driverName: run.driverName,
            passengerNames: run.passengers.map(\.name),
            passengerStatuses: run.passengers.map { $0.status.rawValue.capitalized },
            stops: run.stops.map {
                .init(
                    type: $0.type.rawValue.capitalized,
                    label: $0.label,
                    address: $0.passengerNames.joined(separator: ", "),
                    timeEstimate: run.etaText
                )
            },
            timeline: timeline,
            canEdit: run.status == .scheduled,
            canCancel: run.status == .scheduled,
            isHistory: run.status == .completed
        )
    }
}

#Preview {
    UIRunModuleRootView()
}
