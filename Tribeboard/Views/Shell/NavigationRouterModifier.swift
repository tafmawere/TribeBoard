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
                case .calendarSync:
                    CalendarSyncView()

                case .settings:
                    SettingsView()

                case .helpSupport:
                    HelpSupportView()

                case .about:
                    AboutView()

                case .systemTools:
                    SystemToolsView()

                case .driverModeSelector:
                    DriverModeSelectorView()

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

    var body: some View {
        RunExecutionDetailView(runId: runId)
    }
}

private struct RunEditRouteView: View {
    let runId: String

    var body: some View {
        RunEditRescheduleView(run: RunDetailsData.scheduledRun) { _ in }
            .navigationTitle("Edit Run")
    }
}

private struct RunHistoryDetailRouteView: View {
    let runId: String

    var body: some View {
        RunHistoryDetailView(run: RunDetailsData.completedRun)
    }
}

private struct CancelRunRouteView: View {
    let runId: String

    var body: some View {
        CancelRunDemoHostView()
            .navigationTitle("Cancel Run")
    }
}

private struct ScheduleEditorRouteView: View {
    let scheduleId: String?
    @EnvironmentObject private var scheduleDataSource: ScheduleDataSource

    var body: some View {
        if
            let scheduleId,
            let uuid = UUID(uuidString: scheduleId),
            let template = scheduleDataSource.templates.first(where: { $0.id == uuid })
        {
            ScheduleEditorView(mode: .edit(template.asCalendarSchedule)) { _ in }
        } else {
            ScheduleEditorView(mode: .create) { _ in }
        }
    }
}
