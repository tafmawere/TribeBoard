import SwiftUI

struct DayScheduleListView: View {
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var backendProfileContext: BackendProfileContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var backendHouseholdPeopleContext: BackendHouseholdPeopleContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext
    @EnvironmentObject private var backendSchedulesContext: BackendSchedulesContext
    @EnvironmentObject private var scheduleDataSource: ScheduleDataSource
    @EnvironmentObject private var runDataSource: RunDataSource

    let date: Date

    @State private var occurrences: [CalendarMockModel.UIScheduleOccurrence]
    @State private var editorMode: ScheduleEditorView.Mode = .create
    @State private var isShowingEditor = false
    @State private var isShowingCreator = false
    @State private var actionMessage: String?
    @State private var showConfigurationAlert = false

    init(date: Date, occurrences: [CalendarMockModel.UIScheduleOccurrence]) {
        self.date = date
        _occurrences = State(initialValue: occurrences.sorted { $0.date < $1.date })
    }

    var body: some View {
        ZStack {
            CalendarUITheme.offWhite.ignoresSafeArea()

            if occurrences.isEmpty {
                emptyState.padding(16)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        if backendHouseholdContext.hasActiveMembership, !backendHouseholdContext.canManageSchedules {
                            Text(
                                backendHouseholdContext.isCurrentUserDriver
                                    ? "Drivers can start runs but cannot edit schedules."
                                    : "Observers have view-only access."
                            )
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CalendarUITheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        if let actionMessage {
                            Text(actionMessage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(CalendarUITheme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        ForEach(Array(occurrences.enumerated()), id: \.element.id) { entry in
                            occurrenceCard(index: entry.offset, occurrence: entry.element)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle(formattedDate(date))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if backendHouseholdContext.canManageSchedules {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New") {
                        isShowingCreator = true
                    }
                }
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
        .sheet(isPresented: $isShowingEditor) {
            NavigationStack {
                ScheduleEditorView(mode: editorMode) { saved in
                    let newOccurrence = CalendarMockModel.UIScheduleOccurrence(
                        schedule: saved,
                        date: date,
                        status: .none,
                        subtitle: saved.recurrenceLabel
                    )
                    switch editorMode {
                    case .create:
                        occurrences.append(newOccurrence)
                    case let .edit(existing):
                        if let idx = occurrences.firstIndex(where: { $0.schedule.id == existing.id }) {
                            occurrences[idx].schedule = saved
                        } else {
                            occurrences.append(newOccurrence)
                        }
                    }
                    occurrences.sort { $0.date < $1.date }
                }
            }
        }
        .alert("Schedule Not Ready", isPresented: $showConfigurationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This schedule is not fully configured yet.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(CalendarUITheme.indigo)
            Text("No schedules for this day")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(CalendarUITheme.textPrimary)
            Text("No schedules yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CalendarUITheme.textSecondary)
                .multilineTextAlignment(.center)
            Text("Add your child's school or activity schedule to start generating runs.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CalendarUITheme.textSecondary)
                .multilineTextAlignment(.center)
            if backendHouseholdContext.canManageSchedules {
                UICalendarActionButton(title: "Add Schedule") {
                    isShowingCreator = true
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func occurrenceCard(index: Int, occurrence: CalendarMockModel.UIScheduleOccurrence) -> some View {
        let isPersistedCreated = isRunAlreadyCreated(for: occurrence)
        let hasDriver = !occurrence.schedule.driverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return VStack(alignment: .leading, spacing: 8) {
            if !hasDriver {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No driver assigned")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.orange)
                    if backendHouseholdContext.canManageSchedules {
                        Button("Assign Driver") {
                            editorMode = .edit(occurrence.schedule)
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
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            CalendarOccurrenceCard(
                title: occurrence.schedule.title,
                time: occurrence.schedule.timeString,
                driver: hasDriver ? occurrence.schedule.driverName : "Unassigned",
                passengers: occurrence.schedule.passengerNames,
                isCreated: occurrence.status == .alreadyCreated || isPersistedCreated,
                subtitle: occurrence.subtitle,
                onTap: {
                    guard backendHouseholdContext.canManageSchedules else {
                        actionMessage = "Only organisers can manage schedules."
                        return
                    }
                    editorMode = .edit(occurrence.schedule)
                    isShowingEditor = true
                },
                onCreateRunNow: {
                    Task { await createRunNow(for: index) }
                },
                canCreateRunNow: canCreateRunForOccurrence(occurrence)
            )
        }
    }

    private func createRunNow(for index: Int) async {
        guard occurrences.indices.contains(index) else { return }
        let occurrence = occurrences[index]
        guard canCreateRunForOccurrence(occurrence) else {
            showConfigurationAlert = true
            return
        }
        guard let template = templateForOccurrence(occurrence) else {
            showConfigurationAlert = true
            return
        }

        let created = await runDataSource.createRun(template: template, date: date)
        if created {
            occurrences[index].status = .alreadyCreated
            actionMessage = "Created run for \(template.name)."
        } else {
            actionMessage = runDataSource.lastError ?? "Run already exists for \(template.name)."
        }
    }

    private func isRunAlreadyCreated(for occurrence: CalendarMockModel.UIScheduleOccurrence) -> Bool {
        guard let template = templateForOccurrence(occurrence) else { return false }
        let dayRuns = runDataSource.runsForDay(date)
        return dayRuns.contains { $0.templateId == template.id }
    }

    private func templateForOccurrence(_ occurrence: CalendarMockModel.UIScheduleOccurrence) -> SystemDomain.ScheduleTemplate? {
        if let exact = scheduleDataSource.templates.first(where: { $0.id == occurrence.schedule.id }) {
            return exact
        }
#if DEBUG
        print("DayScheduleListView: missing template for occurrence \(occurrence.schedule.id)")
#endif
        return nil
    }

    private func canCreateRunForOccurrence(_ occurrence: CalendarMockModel.UIScheduleOccurrence) -> Bool {
        guard backendHouseholdContext.canStartRuns else { return false }
        guard let template = templateForOccurrence(occurrence) else { return false }
        if !authSession.isAuthenticated {
            return true
        }
        guard backendChildrenContext.children.contains(where: { $0.id == template.childId }) else { return false }
        guard let activeHouseholdId = backendHouseholdContext.activeHouseholdId else { return false }
        return template.householdId == activeHouseholdId
            && scheduleDataSource.templateExists(id: template.id, in: activeHouseholdId)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM"
        return formatter.string(from: date)
    }
}

private struct UICalendarActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(CalendarUITheme.indigo)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(minHeight: 44)
    }
}

#Preview {
    NavigationStack {
        DayScheduleListView(date: Date(), occurrences: [])
    }
}
