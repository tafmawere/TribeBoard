import SwiftUI

enum DemoSheet: Identifiable, Equatable {
    case runCreation
    case scheduleEditor(scheduleId: String?)
    case runScheduledConfirmation(runId: String)

    var id: String {
        switch self {
        case .runCreation:
            return "runCreation"
        case let .scheduleEditor(scheduleId):
            return "scheduleEditor-\(scheduleId ?? "new")"
        case let .runScheduledConfirmation(runId):
            return "runScheduledConfirmation-\(runId)"
        }
    }
}

struct DemoShellView: View {
    @StateObject private var tribeStore: TribeStore
    @State private var selectedTab: AppTab
    @State private var runsOverviewTab: RunsOverviewTab = .today
    @State private var homePath = NavigationPath()
    @State private var runsPath = NavigationPath()
    @State private var calendarPath = NavigationPath()
    @State private var familyPath = NavigationPath()
    @State private var morePath = NavigationPath()
    @State private var presentedSheet: DemoSheet?

    init(store: TribeStore, initialTab: AppTab = .home) {
        _tribeStore = StateObject(wrappedValue: store)
        _selectedTab = State(initialValue: initialTab)
    }

    @MainActor
    init() {
        _tribeStore = StateObject(wrappedValue: TribeStore(demoFlow: true))
        _selectedTab = State(initialValue: .home)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: pathBinding(for: .home)) {
                HomeView(
                    onOpenRuns: { selectedTab = .runs },
                    onOpenCalendar: { selectedTab = .calendar },
                    onOpenFamily: { selectedTab = .family },
                    onCreateRun: { selectedTab = .runs },
                    onOpenSettings: {
                        homePath.append(Destination.settings)
                    }
                )
                    .withNavigationRouter()
            }
            .tabItem {
                Label(AppTab.home.title, systemImage: AppTab.home.systemImage)
            }
            .tag(AppTab.home)

            NavigationStack(path: pathBinding(for: .runs)) {
                RunsOverviewView(
                    selectedTab: $runsOverviewTab,
                    todayRuns: [UIRunMockData.scheduledRun],
                    upcomingRuns: [],
                    historyRuns: UIRunMockData.historyRuns,
                    activeRun: UIRunMockData.activeRun,
                    suggestedRuns: tribeStore.generateSuggestedRuns(now: Date()),
                    onOpenRunDetails: { run in
                        runsPath.append(Destination.runDetails(runId: run.backingRunId))
                    },
                    onOpenObserver: { run in
                        // Keep routing simple in shell demo.
                        runsPath.append(Destination.runDetails(runId: run.backingRunId))
                    },
                    onStartSuggestion: { suggestion in
                        _ = tribeStore.createRunInstanceFromSuggestion(suggestion, now: Date())
                    },
                    onSnoozeSuggestion: { suggestion in
                        tribeStore.snoozeSuggestion(suggestion, minutes: 10, now: Date())
                    },
                    onDismissSuggestion: { suggestion in
                        tribeStore.dismissSuggestion(suggestion)
                    },
                    onViewCalendar: {
                        selectedTab = .calendar
                    }
                )
                    .withNavigationRouter()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("New") {
                                presentSheet(.runCreation)
                            }
                        }
                    }
            }
            .tabItem {
                Label(AppTab.runs.title, systemImage: AppTab.runs.systemImage)
            }
            .tag(AppTab.runs)

            NavigationStack(path: pathBinding(for: .calendar)) {
                CalendarView(suggestedRunsProvider: {
                    tribeStore.generateSuggestedRuns(now: selectedDateProxy())
                })
                    .withNavigationRouter()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Schedules") {
                                calendarPath.append(Destination.schedulesList)
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("New") {
                                presentSheet(.scheduleEditor(scheduleId: nil))
                            }
                        }
                    }
            }
            .tabItem {
                Label(AppTab.calendar.title, systemImage: AppTab.calendar.systemImage)
            }
            .tag(AppTab.calendar)

            NavigationStack(path: pathBinding(for: .family)) {
                FamilyRootView(store: tribeStore)
                    .withNavigationRouter()
            }
            .tabItem {
                Label(AppTab.family.title, systemImage: AppTab.family.systemImage)
            }
            .tag(AppTab.family)

            NavigationStack(path: $morePath) {
                MainMenuView(path: $morePath)
                    .withNavigationRouter()
            }
            .tabItem {
                Label(AppTab.more.title, systemImage: AppTab.more.systemImage)
            }
            .tag(AppTab.more)
        }
        .sheet(item: $presentedSheet, onDismiss: dismissSheet) { sheet in
            sheetView(sheet)
        }
    }

    private func selectedDateProxy() -> Date {
        Date()
    }

    private func pathBinding(for tab: AppTab) -> Binding<NavigationPath> {
        switch tab {
        case .home:
            return $homePath
        case .runs:
            return $runsPath
        case .calendar:
            return $calendarPath
        case .family:
            return $familyPath
        case .more:
            return $morePath
        }
    }

    private func presentSheet(_ sheet: DemoSheet) {
        guard presentedSheet == nil else { return }
        presentedSheet = sheet
    }

    private func dismissSheet() {
        presentedSheet = nil
    }

    @ViewBuilder
    private func sheetView(_ sheet: DemoSheet) -> some View {
        switch sheet {
        case .runCreation:
            NavigationStack {
                RunEditRescheduleView(run: RunDetailsData.scheduledRun) { _ in
                    dismissSheet()
                }
            }
        case .scheduleEditor:
            ScheduleEditorView(mode: .create) { _ in
                dismissSheet()
            }
        case .runScheduledConfirmation:
            RunScheduledConfirmationView()
        }
    }
}

#Preview {
    DemoShellView()
}
