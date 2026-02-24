import SwiftUI

struct DestinationNavigationRouter: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                // Runs
                case let .runDetails(runId):
                    RunDetailsRouteView(runId: runId)

                case let .runEdit(runId):
                    RunEditRouteView(runId: runId)

                case let .runHistoryDetail(runId):
                    RunHistoryDetailRouteView(runId: runId)

                case let .cancelRun(runId):
                    CancelRunRouteView(runId: runId)

                // Calendar
                case .schedulesList:
                    SchedulesListView()

                case let .scheduleDetail(scheduleId):
                    ScheduleDetailPlaceholderView(scheduleId: scheduleId)

                case let .scheduleEditor(scheduleId):
                    ScheduleEditorRouteView(scheduleId: scheduleId)

                case let .dayScheduleList(date):
                    DayScheduleListView(date: date, occurrences: [])

                // Notifications
                case .notificationsInbox:
                    NotificationsInboxView()

                case .notificationSettings:
                    NotificationSettingsView()

                case .quickContact:
                    QuickContactView()

                // Safety & privacy
                case .locationSharing:
                    LocationSharingSettingsView()

                case .permissionsConsent:
                    PermissionsConsentView()

                case .emergencyContacts:
                    EmergencyContactsView()

                // General
                case .settings:
                    SettingsView()

                case let .error(message):
                    ShellMessageErrorView(message: message)
                }
            }
    }
}

extension View {
    func withNavigationRouter() -> some View {
        modifier(DestinationNavigationRouter())
    }
}

private struct RunDetailsRouteView: View {
    let runId: String

    private var resolvedRun: UIRun {
        let allRuns = [UIRunMockData.activeRun, UIRunMockData.scheduledRun] + UIRunMockData.historyRuns
        return allRuns.first(where: { $0.backingRunId == runId }) ?? UIRunMockData.activeRun
    }

    var body: some View {
        RunDetailView(run: resolvedRun)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text(runId)
                        .font(.caption2)
                        .foregroundStyle(GeneralUXTheme.textSecondary)
                }
            }
    }
}

private struct RunEditRouteView: View {
    let runId: String

    var body: some View {
        RunEditRescheduleView(run: RunDetailsData.scheduledRun) { _ in }
            .navigationTitle("Edit Run")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text(runId)
                        .font(.caption2)
                        .foregroundStyle(GeneralUXTheme.textSecondary)
                }
            }
    }
}

private struct RunHistoryDetailRouteView: View {
    let runId: String

    var body: some View {
        RunHistoryDetailView(run: RunDetailsData.completedRun)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text(runId)
                        .font(.caption2)
                        .foregroundStyle(GeneralUXTheme.textSecondary)
                }
            }
    }
}

private struct CancelRunRouteView: View {
    let runId: String

    var body: some View {
        CancelRunDemoHostView()
            .navigationTitle("Cancel Run")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text(runId)
                        .font(.caption2)
                        .foregroundStyle(GeneralUXTheme.textSecondary)
                }
            }
    }
}

private struct ScheduleEditorRouteView: View {
    let scheduleId: String?

    var body: some View {
        if scheduleId == nil {
            ScheduleEditorView(mode: .create) { _ in }
        } else {
            ScheduleEditorDestinationPlaceholder(scheduleId: scheduleId)
        }
    }
}
