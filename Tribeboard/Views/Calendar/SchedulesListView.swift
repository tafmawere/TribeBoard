import SwiftUI

// Legacy UI schedule models kept for compatibility with existing detail screens.
struct UIScheduleTemplate: Identifiable, Hashable {
    let id: UUID
    var title: String
    var timeString: String
    var recurrenceLabel: String
    var driverName: String
    var passengers: [String]
    var stopsSummary: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        title: String,
        timeString: String,
        recurrenceLabel: String,
        driverName: String,
        passengers: [String],
        stopsSummary: String,
        isEnabled: Bool
    ) {
        self.id = id
        self.title = title
        self.timeString = timeString
        self.recurrenceLabel = recurrenceLabel
        self.driverName = driverName
        self.passengers = passengers
        self.stopsSummary = stopsSummary
        self.isEnabled = isEnabled
    }
}

enum UIOccurrenceStatus: String, Hashable {
    case upcoming
    case created
}

struct UIOccurrence: Identifiable, Hashable {
    let id: UUID
    var date: Date
    var timeString: String
    var status: UIOccurrenceStatus

    init(id: UUID = UUID(), date: Date, timeString: String, status: UIOccurrenceStatus) {
        self.id = id
        self.date = date
        self.timeString = timeString
        self.status = status
    }
}

struct SchedulesListView: View {
    @EnvironmentObject private var activeHouseholdStore: ActiveHouseholdStore
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var backendProfileContext: BackendProfileContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var backendHouseholdPeopleContext: BackendHouseholdPeopleContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext
    @EnvironmentObject private var backendSchedulesContext: BackendSchedulesContext
    @EnvironmentObject private var scheduleDataSource: ScheduleDataSource
    @EnvironmentObject private var runDataSource: RunDataSource

    @State private var isShowingEditor = false
    @State private var isShowingCreator = false
    @State private var editingTemplate: SystemDomain.ScheduleTemplate?
    @State private var generationMessage: String?

    var body: some View {
        ZStack {
            CalendarUITheme.offWhite.ignoresSafeArea()

            if !hasHouseholdScope {
                emptyHouseholdState
                    .padding(16)
            } else if scopedTemplates.isEmpty && !scheduleDataSource.isLoading {
                emptyState
                    .padding(16)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        if backendHouseholdContext.hasActiveMembership,
                           !backendHouseholdContext.canManageSchedules {
                            generationBanner(
                                text: backendHouseholdContext.isCurrentUserDriver
                                    ? "Drivers can start runs but cannot edit schedules."
                                    : "Observers have view-only access."
                            )
                        }
                        if let generationMessage {
                            generationBanner(text: generationMessage)
                        }
                        ForEach(scopedTemplates) { template in
                            scheduleCard(template)
                        }
                    }
                    .padding(16)
                }
                .refreshable {
                    await scheduleDataSource.refresh()
                }
            }
        }
        .navigationTitle("Schedules")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
#if DEBUG
                Button("Clear Runs") {
                    Task {
                        try? await SystemBootstrap.clearAllRuns()
                        await runDataSource.refresh()
                        generationMessage = "Cleared all runs"
                    }
                }
#endif
                Button("Generate Runs") {
                    Task {
                        guard backendHouseholdContext.canStartRuns else {
                            generationMessage = "Only organisers and drivers can start runs."
                            return
                        }
                        let newRuns = await scheduleDataSource.generateRuns(daysAhead: 14)
                        await runDataSource.refresh()
                        generationMessage = newRuns == 0
                            ? "No new runs (already up to date)"
                            : "Generated \(newRuns) new runs"
                    }
                }
                .disabled(scheduleDataSource.isWorking || !backendHouseholdContext.canStartRuns)

                if backendHouseholdContext.canManageSchedules {
                    Button("New Schedule") {
                        isShowingCreator = true
                    }
                    .disabled(!hasHouseholdScope || !backendHouseholdContext.canManageSchedules)
                }
            }
        }
        .task {
            guard hasHouseholdScope else { return }
            await scheduleDataSource.refresh()
        }
        .onChange(of: activeHouseholdStore.activeHouseholdId) { _, _ in
            Task {
                await backendChildrenContext.refreshForActiveHousehold()
                await scheduleDataSource.refresh()
                await runDataSource.refresh()
            }
        }
        .sheet(isPresented: $isShowingCreator, onDismiss: {
            Task { await scheduleDataSource.refresh() }
        }) {
            NavigationStack {
                ScheduleCreatorView()
                    .environmentObject(backendProfileContext)
                    .environmentObject(backendHouseholdContext)
                    .environmentObject(backendChildrenContext)
                    .environmentObject(backendSchedulesContext)
                    .environmentObject(backendHouseholdPeopleContext)
            }
        }
        .sheet(isPresented: $isShowingEditor, onDismiss: {
            Task { await scheduleDataSource.refresh() }
        }) {
            NavigationStack {
                ScheduleEditorView(mode: editorMode) { _ in
                    // Real persistence happens in ScheduleDataSource.
                }
            }
        }
    }

    private var hasHouseholdScope: Bool {
        if !authSession.isAuthenticated {
            return true
        }
        return backendHouseholdContext.hasActiveMembership && activeHouseholdStore.activeHouseholdId != nil
    }

    private var emptyHouseholdState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3.sequence")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(CalendarUITheme.indigo)

            Text("No active tribe selected")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(CalendarUITheme.textPrimary)

            Text("Join or create a tribe to see schedules.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CalendarUITheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var editorMode: ScheduleEditorView.Mode {
        guard let editingTemplate else { return .create }
        return .edit(editingTemplate.asCalendarSchedule)
    }

    private var scopedTemplates: [SystemDomain.ScheduleTemplate] {
        let validChildIds = Set(backendChildrenContext.children.map(\.id))
        return scheduleDataSource.templates.filter { template in
            if authSession.isAuthenticated, let activeHouseholdId = activeHouseholdStore.activeHouseholdId {
                guard template.householdId == activeHouseholdId else { return false }
            }
            return validChildIds.contains(template.childId)
        }
    }

    @ViewBuilder
    private func scheduleCard(_ template: SystemDomain.ScheduleTemplate) -> some View {
        let assignment = driverAssignment(for: template)
        CalendarCard {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    guard backendHouseholdContext.canManageSchedules else {
                        generationMessage = "Only organisers can manage schedules."
                        return
                    }
                    editingTemplate = template
                    isShowingEditor = true
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(template.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(CalendarUITheme.textPrimary)

                        Text("\(timeText(template)) • \(weekdaysLabel(template.weekdays))")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(CalendarUITheme.textSecondary)

                        Text("\(template.stops.count) stops")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(CalendarUITheme.textSecondary)

                        HStack(spacing: 8) {
                            Image(systemName: assignment.isAssigned ? "steeringwheel" : "person.crop.circle.badge.exclamationmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(assignment.isAssigned ? CalendarUITheme.indigo : Color.orange)
                            Text(assignment.label)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(assignment.isAssigned ? CalendarUITheme.textPrimary : Color.orange)
                                .lineLimit(1)
                        }

                        if !assignment.isAssigned {
                            if backendHouseholdContext.canManageSchedules {
                                Button("Assign Driver") {
                                    editingTemplate = template
                                    isShowingEditor = true
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .buttonStyle(.borderedProminent)
                                .tint(CalendarUITheme.indigo)
                            } else {
                                Text("Driver assignment is managed by organisers.")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(CalendarUITheme.textSecondary)
                            }
                        }

                        AppBadge(
                            text: template.isActive ? "ENABLED" : "DISABLED",
                            style: template.isActive ? .success : .neutral
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                Toggle("Enabled", isOn: Binding(
                    get: { template.isActive },
                    set: { newValue in
                        guard backendHouseholdContext.canManageSchedules else {
                            generationMessage = "Only organisers can manage schedules."
                            return
                        }
                        Task { await scheduleDataSource.toggleEnabled(id: template.id, enabled: newValue) }
                    }
                ))
                .font(.system(size: 15, weight: .semibold))
                .tint(CalendarUITheme.indigo)
                .disabled(!backendHouseholdContext.canManageSchedules)
            }
        }
    }

    private func generationBanner(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(CalendarUITheme.indigo)
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CalendarUITheme.textPrimary)
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(CalendarUITheme.indigo)

            Text("No schedules yet")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(CalendarUITheme.textPrimary)

            Text("Create a schedule to generate recurring runs.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CalendarUITheme.textSecondary)
                .multilineTextAlignment(.center)

            Button("Create Schedule") {
                isShowingCreator = true
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(CalendarUITheme.indigo)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func weekdaysLabel(_ weekdays: Set<Int>) -> String {
        let ordered = [2, 3, 4, 5, 6, 7, 1]
        let labels: [Int: String] = [1: "Sun", 2: "Mon", 3: "Tue", 4: "Wed", 5: "Thu", 6: "Fri", 7: "Sat"]
        let names = ordered.compactMap { day in
            weekdays.contains(day) ? labels[day] : nil
        }
        if names == ["Mon", "Tue", "Wed", "Thu", "Fri"] { return "Weekdays" }
        return names.joined(separator: ", ")
    }

    private func timeText(_ template: SystemDomain.ScheduleTemplate) -> String {
        var components = DateComponents()
        components.hour = template.hour
        components.minute = template.minute
        let date = Calendar.current.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func driverAssignment(for template: SystemDomain.ScheduleTemplate) -> (label: String, isAssigned: Bool) {
        guard let driverId = template.driverId else {
            return ("No driver assigned", false)
        }
        if let profile = backendHouseholdContext.activeHouseholdProfilesByUserId[driverId] {
            let name = AuthBackedMemberDisplayResolver.resolveName(profile: profile, relationshipLabel: nil)
            return ("Driver: \(name)", true)
        }
        if let person = backendHouseholdPeopleContext.people.first(where: { $0.id == driverId }) {
            return ("Driver: \(person.name)", true)
        }
        return ("Driver assigned", true)
    }
}

extension UIScheduleTemplate {
    init(savedSchedule: CalendarMockModel.UISchedule) {
        self.init(
            id: savedSchedule.id,
            title: savedSchedule.title,
            timeString: savedSchedule.timeString,
            recurrenceLabel: savedSchedule.recurrenceLabel,
            driverName: savedSchedule.driverName,
            passengers: savedSchedule.passengerNames,
            stopsSummary: savedSchedule.stops.map(\.label).joined(separator: " -> "),
            isEnabled: savedSchedule.isEnabled
        )
    }

    var asCalendarSchedule: CalendarMockModel.UISchedule {
        let stopLabels = stopsSummary
            .components(separatedBy: "->")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let normalizedStops = stopLabels.enumerated().map { index, label in
            CalendarMockModel.UIStop(
                type: index == 0 ? "Pickup" : "Dropoff",
                label: label,
                address: ""
            )
        }

        return CalendarMockModel.UISchedule(
            id: id,
            title: title,
            timeString: timeString,
            recurrenceLabel: recurrenceLabel,
            driverName: driverName,
            passengerNames: passengers,
            isEnabled: isEnabled,
            stops: normalizedStops
        )
    }
}

#Preview {
    NavigationStack {
        SchedulesListView()
            .environmentObject(ScheduleDataSource())
            .environmentObject(RunDataSource())
    }
}
