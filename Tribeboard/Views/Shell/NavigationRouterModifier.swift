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
                    NotificationsView()

                case .notificationSettings:
                    NotificationSettingsView()

                case .quickContact:
                    QuickContactLiveRouteView()

                // Safety & privacy
                case .locationSharing:
                    LocationSharingSettingsView()

                case .permissionsConsent:
                    PermissionsConsentView()

                case .emergencyContacts:
                    EmergencyContactsView()

                // General
                case .profile:
                    ProfileView()

                case .calendarSync:
                    CalendarSyncView()

                case .settings:
                    SettingsView()

                case .helpSupport:
                    HelpSupportView()

                case .legalSafety:
                    LegalSafetyView()

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
    @EnvironmentObject private var runDataSource: RunDataSource
    @EnvironmentObject private var locationService: LocationReadinessService
    @EnvironmentObject private var familyQuickPlacesStore: FamilyQuickPlacesStore
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext

    var body: some View {
        if let uiRun = resolvedUIRun {
            RunEditRescheduleView(mode: .edit(uiRun)) { _ in true }
                .navigationTitle("Edit Run")
                .environmentObject(locationService)
                .environmentObject(familyQuickPlacesStore)
        } else {
            ErrorStateView(kind: .runNotFound)
                .navigationTitle("Edit Run")
        }
    }

    private var resolvedUIRun: RunDetailsData.UIRun? {
        RunDetailsUIMapper.resolve(
            runId: runId,
            run: runDataSource.run(withId:),
            childName: runDataSource.run(withId: runId).map {
                RunDisplayStrings.childName(for: $0, children: backendChildrenContext.children)
            }
        )
    }
}

private struct RunHistoryDetailRouteView: View {
    let runId: String
    @EnvironmentObject private var runDataSource: RunDataSource
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext

    var body: some View {
        if let uiRun = resolvedUIRun {
            RunHistoryDetailView(run: uiRun)
        } else {
            ErrorStateView(kind: .runNotFound)
                .navigationTitle("Run History")
        }
    }

    private var resolvedUIRun: RunDetailsData.UIRun? {
        RunDetailsUIMapper.resolve(
            runId: runId,
            run: runDataSource.run(withId:),
            childName: runDataSource.run(withId: runId).map {
                RunDisplayStrings.childName(for: $0, children: backendChildrenContext.children)
            }
        )
    }
}

private struct CancelRunRouteView: View {
    let runId: String
    @EnvironmentObject private var runDataSource: RunDataSource
    @EnvironmentObject private var locationService: LocationReadinessService

    var body: some View {
        if let run = runDataSource.run(withId: runId),
           run.status != .completed,
           run.status != .cancelled {
            CancelRunConfirmView { _ in
                Task {
                    await runDataSource.cancelRun(id: run.id, locationService: locationService)
                }
            }
            .navigationTitle("Cancel Run")
        } else {
            ErrorStateView(kind: .runNotFound)
                .navigationTitle("Cancel Run")
        }
    }
}

private struct QuickContactLiveRouteView: View {
    @EnvironmentObject private var backendHouseholdPeopleContext: BackendHouseholdPeopleContext

    var body: some View {
        let mapped = NotificationLiveContacts.from(people: backendHouseholdPeopleContext.people)
        QuickContactView(driverContacts: mapped.drivers, parentContacts: mapped.parents)
    }
}

private struct ScheduleEditorRouteView: View {
    let scheduleId: String?
    @EnvironmentObject private var backendProfileContext: BackendProfileContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext
    @EnvironmentObject private var backendSchedulesContext: BackendSchedulesContext
    @EnvironmentObject private var backendHouseholdPeopleContext: BackendHouseholdPeopleContext
    @EnvironmentObject private var scheduleDataSource: ScheduleDataSource

    var body: some View {
        if
            let scheduleId,
            let uuid = UUID(uuidString: scheduleId),
            let template = scheduleDataSource.templates.first(where: { $0.id == uuid })
        {
            ScheduleEditorView(mode: .edit(template.asCalendarSchedule)) { _ in }
                .environmentObject(backendProfileContext)
                .environmentObject(backendHouseholdContext)
                .environmentObject(backendChildrenContext)
                .environmentObject(backendSchedulesContext)
                .environmentObject(backendHouseholdPeopleContext)
        } else {
            ScheduleCreatorView()
                .environmentObject(backendProfileContext)
                .environmentObject(backendHouseholdContext)
                .environmentObject(backendChildrenContext)
                .environmentObject(backendSchedulesContext)
                .environmentObject(backendHouseholdPeopleContext)
        }
    }
}
