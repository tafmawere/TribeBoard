import SwiftUI

struct ScheduleEditorView: View {
    enum Mode {
        case create
        case edit(CalendarMockModel.UISchedule)
    }

    private struct EditableStop: Identifiable {
        let id: UUID
        var locationId: UUID?
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var activeHouseholdStore: ActiveHouseholdStore
    @EnvironmentObject private var scheduleDataSource: ScheduleDataSource
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext
    @EnvironmentObject private var backendSchedulesContext: BackendSchedulesContext
    @EnvironmentObject private var backendHouseholdLocationsContext: BackendHouseholdLocationsContext
    @EnvironmentObject private var runDataSource: RunDataSource

    let mode: Mode
    let isOnboardingContext: Bool
    let onSave: (CalendarMockModel.UISchedule) -> Void

    @State private var title: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var weekdays: Set<Int>
    @State private var stops: [EditableStop]
    @State private var isEnabled: Bool
    @State private var showDeleteAlert = false
    @State private var selectedChildId: UUID?
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var isShowingAddLocation = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title
    }

    private let weekdayItems: [(Int, String)] = [(2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")]
    private let templateId: UUID

    init(
        mode: Mode,
        isOnboardingContext: Bool = false,
        onSave: @escaping (CalendarMockModel.UISchedule) -> Void
    ) {
        self.mode = mode
        self.isOnboardingContext = isOnboardingContext
        self.onSave = onSave

        let defaultTime = Calendar.current.date(from: DateComponents(hour: 6, minute: 45)) ?? Date()

        switch mode {
        case .create:
            self.templateId = UUID()
            _title = State(initialValue: "")
            _startTime = State(initialValue: defaultTime)
            _endTime = State(initialValue: Calendar.current.date(byAdding: .minute, value: 45, to: defaultTime) ?? defaultTime)
            _weekdays = State(initialValue: [])
            _stops = State(initialValue: [
                EditableStop(id: UUID(), locationId: nil),
                EditableStop(id: UUID(), locationId: nil)
            ])
            _isEnabled = State(initialValue: true)
            _selectedChildId = State(initialValue: nil)
        case let .edit(schedule):
            self.templateId = schedule.id
            _title = State(initialValue: schedule.title)
            let parsedStart = Self.timeFromString(schedule.timeString) ?? defaultTime
            _startTime = State(initialValue: parsedStart)
            _endTime = State(initialValue: Calendar.current.date(byAdding: .minute, value: 45, to: parsedStart) ?? parsedStart)
            _weekdays = State(initialValue: Self.weekdaysFromRecurrence(schedule.recurrenceLabel))
            _stops = State(initialValue: schedule.stops.map { stop in
                EditableStop(id: UUID(), locationId: nil)
            })
            _isEnabled = State(initialValue: schedule.isEnabled)
            _selectedChildId = State(initialValue: nil)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !canEditSchedules {
                    CalendarCard {
                        Text("Only organisers can manage schedules.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CalendarUITheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                detailsCard
                weekdaysCard
                stopsCard
                enabledCard
                if case .edit = mode {
                    deleteCard
                }
            }
            .disabled(!canEditSchedules)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(CalendarUITheme.offWhite.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    performSave()
                }
                .disabled(scheduleDataSource.isWorking || !canSave || !canEditSchedules)
            }
        }
        .alert("Delete Schedule?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                guard canEditSchedules else { return }
                Task {
                    await runDataSource.invalidateRuns(templateId: templateId)
                    await scheduleDataSource.delete(id: templateId)
                    if let householdId = backendHouseholdContext.activeHouseholdId {
                        await backendSchedulesContext.deleteSchedule(id: templateId, householdId: householdId)
                    }
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the schedule template.")
        }
        .alert(
            "Could Not Save Schedule",
            isPresented: Binding(
                get: { scheduleDataSource.lastError != nil },
                set: { isPresented in
                    if !isPresented {
                        scheduleDataSource.lastError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                scheduleDataSource.lastError = nil
            }
        } message: {
            Text(scheduleDataSource.lastError ?? "Unknown validation error.")
        }
        .alert("Schedule Setup Needed", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(validationMessage)
        }
        .alert("Schedule Sync Issue", isPresented: Binding(
            get: { backendSchedulesContext.lastError != nil },
            set: { isPresented in
                if !isPresented {
                    backendSchedulesContext.lastError = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {
                backendSchedulesContext.lastError = nil
            }
        } message: {
            Text(backendSchedulesContext.lastError ?? "Unable to sync schedule.")
        }
        .onAppear {
            if selectedChildId == nil {
                if case .edit = mode {
                    selectedChildId = scheduleDataSource.templates.first(where: { $0.id == templateId })?.childId
                }
                if selectedChildId == nil {
                    selectedChildId = backendChildrenContext.children.first?.id
                }
            }
            hydrateStopsFromTemplateIfNeeded()
        }
        .task {
            await backendHouseholdLocationsContext.refreshForActiveHousehold()
            hydrateStopsFromTemplateIfNeeded()
        }
        .sheet(isPresented: $isShowingAddLocation) {
            NavigationStack {
                AddEditHouseholdLocationView()
            }
        }
    }

    private func hydrateStopsFromTemplateIfNeeded() {
        guard let template = scheduleDataSource.templates.first(where: { $0.id == templateId }) else { return }
        let templateStops = template.stops.sorted { $0.order < $1.order }
        guard !templateStops.isEmpty else { return }
        let alreadyHydrated = stops.contains { $0.locationId != nil }
        guard !alreadyHydrated else { return }
        stops = templateStops.map { stop in
            let resolvedLocationId = stop.locationId
                ?? backendHouseholdLocationsContext.findLocationByNameOrLabel(stop.name)?.id
            return EditableStop(id: stop.id, locationId: resolvedLocationId)
        }
    }

    private var bottomActionBar: some View {
        HStack(spacing: 10) {
            Button("Cancel") {
                dismiss()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(CalendarUITheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.black.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                performSave()
            } label: {
                HStack(spacing: 8) {
                    if scheduleDataSource.isWorking {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(scheduleDataSource.isWorking ? "Saving..." : "Save")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(CalendarUITheme.indigo)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(scheduleDataSource.isWorking || !canSave)
            .opacity(scheduleDataSource.isWorking || !canSave || !canEditSchedules ? 0.7 : 1.0)
            .disabled(scheduleDataSource.isWorking || !canSave || !canEditSchedules)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private var detailsCard: some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Schedule Details")
                textField("Title", text: $title, field: .title)
                Picker("Child", selection: Binding<UUID?>(
                    get: { selectedChildId },
                    set: { selectedChildId = $0 }
                )) {
                    Text("Select child").tag(nil as UUID?)
                    ForEach(backendChildrenContext.children) { child in
                        Text(child.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? child.displayName! : child.legalName)
                            .tag(Optional(child.id))
                    }
                }
                DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .tint(CalendarUITheme.indigo)
                DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .tint(CalendarUITheme.indigo)
                if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    validationText("Title is required.")
                }
                if selectedChildId == nil {
                    validationText("Select a child for this schedule.")
                }
                if !hasValidTimeRange {
                    validationText("End time must be after start time.")
                }
            }
        }
    }

    private var weekdaysCard: some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Weekdays")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                    ForEach(weekdayItems, id: \.0) { day, label in
                        weekdayChip(day: day, label: label)
                    }
                }
                if weekdays.isEmpty {
                    validationText("Select at least one weekday.")
                }
            }
        }
    }

    private var stopsCard: some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionTitle("Stops")
                    Spacer()
                    Button("Add Stop") {
                        guard stops.count < 3 else { return }
                        stops.append(EditableStop(id: UUID(), locationId: nil))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CalendarUITheme.indigo)
                    .disabled(stops.count >= 3)
                }

                ForEach(stops.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Stop \(index + 1)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(CalendarUITheme.textPrimary)
                            Spacer()
                            if stops.count > 2 {
                                Button {
                                    stops.remove(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        HouseholdLocationPickerField(
                            title: "Location",
                            placeholder: "Select saved location",
                            selectedLocationId: Binding(
                                get: { stops[index].locationId },
                                set: { stops[index].locationId = $0 }
                            ),
                            onAddLocation: { isShowingAddLocation = true }
                        )
                    }
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if let stopsValidationMessage {
                    validationText(stopsValidationMessage)
                }
            }
        }
    }

    private var enabledCard: some View {
        CalendarCard {
            Toggle("Enabled", isOn: $isEnabled)
                .font(.system(size: 15, weight: .semibold))
                .tint(CalendarUITheme.indigo)
        }
    }

    private var deleteCard: some View {
        CalendarCard {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Text("Delete Schedule")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.red.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var navTitle: String {
        switch mode {
        case .create:
            return "New Schedule"
        case .edit:
            return "Edit Schedule"
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !weekdays.isEmpty &&
        hasValidStops &&
        selectedChildId != nil &&
        hasValidTimeRange
    }

    private var hasValidStops: Bool {
        stopsValidationMessage == nil
    }

    private var stopsValidationMessage: String? {
        guard stops.count >= 2 else {
            return "Add at least 2 stops."
        }
        for stop in stops {
            guard let locationId = stop.locationId,
                  let location = backendHouseholdLocationsContext.location(id: locationId) else {
                return "Each stop must use a saved family location."
            }
            guard location.readiness == .complete else {
                return "\(location.displayName) is missing a valid address or map pin."
            }
        }
        return nil
    }

    private func saveTemplate() async -> Bool {
        guard canEditSchedules else {
            validationMessage = "Only organisers can manage schedules."
            showValidationAlert = true
            return false
        }
        guard let activeHouseholdId = activeHouseholdStore.activeHouseholdId else {
            validationMessage = "Select an active household before adding schedules."
            showValidationAlert = true
            return false
        }
        if weekdays.isEmpty {
            validationMessage = "Select at least one weekday before saving this schedule."
            showValidationAlert = true
            return false
        }
        guard let selectedChildId,
              backendChildrenContext.children.contains(where: { $0.id == selectedChildId }) else {
            validationMessage = "Select a valid child before saving this schedule."
            showValidationAlert = true
            return false
        }
        guard hasValidTimeRange else {
            validationMessage = "End time must be after start time."
            showValidationAlert = true
            return false
        }
        guard hasValidStops else {
            validationMessage = stopsValidationMessage ?? "Please fix schedule stops before saving."
            showValidationAlert = true
            return false
        }

        let existing = scheduleDataSource.templates.first(where: { $0.id == templateId })
        let validStops: [SystemDomain.Stop] = stops.enumerated().compactMap { index, stop in
            guard let locationId = stop.locationId,
                  let location = backendHouseholdLocationsContext.location(id: locationId),
                  location.readiness == .complete else {
                return nil
            }
            let existingStops = existing?.stops.sorted { $0.order < $1.order } ?? []
            let existingStopId = index < existingStops.count ? existingStops[index].id : stop.id
            return SystemDomain.Stop(
                id: existingStopId,
                name: location.displayName,
                latitude: location.latitude,
                longitude: location.longitude,
                order: index,
                locationId: location.id
            )
        }

        let components = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        let template = SystemDomain.ScheduleTemplate(
            id: templateId,
            householdId: activeHouseholdId,
            name: title.trimmingCharacters(in: .whitespacesAndNewlines),
            childId: selectedChildId,
            driverId: existing?.driverId,
            weekdays: weekdays,
            hour: components.hour ?? 6,
            minute: components.minute ?? 45,
            stops: validStops,
            isActive: isEnabled,
            createdAt: existing?.createdAt ?? Date()
        )
        
#if DEBUG
        print(
            "[ScheduleEditorView] save start household_id=\(activeHouseholdId.uuidString), " +
            "child_id=\(selectedChildId.uuidString), title=\(template.name)"
        )
#endif
        let didSave: Bool
        switch mode {
        case .create:
            didSave = await backendSchedulesContext.createSchedule(from: template)
        case .edit:
            didSave = await backendSchedulesContext.updateSchedule(from: template)
        }
        guard didSave else { return false }
        await backendSchedulesContext.refreshSchedules(householdId: activeHouseholdId)
#if DEBUG
        print("[ScheduleEditorView] save success template_id=\(template.id.uuidString)")
#endif
        onSave(template.asCalendarSchedule)
        return true
    }

    private func performSave() {
        guard canEditSchedules else {
            validationMessage = "Only organisers can manage schedules."
            showValidationAlert = true
            return
        }
        guard canSave else { return }
        Task {
            let saved = await saveTemplate()
            if saved {
                dismiss()
            }
        }
    }

    private var canEditSchedules: Bool {
        backendHouseholdContext.canEditSchedules
    }

    private var hasValidTimeRange: Bool {
        endTime > startTime
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(CalendarUITheme.textPrimary)
    }

    private func textField(_ title: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CalendarUITheme.textSecondary)
            TextField(title, text: text)
                .foregroundStyle(.primary)
                .tint(CalendarUITheme.indigo)
                .focused($focusedField, equals: field)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(uiColor: .tertiarySystemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            focusedField == field ? CalendarUITheme.indigo.opacity(0.7) : Color(uiColor: .separator).opacity(0.35),
                            lineWidth: focusedField == field ? 1.5 : 1
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func weekdayChip(day: Int, label: String) -> some View {
        let isSelected = weekdays.contains(day)
        return Button {
            if isSelected {
                weekdays.remove(day)
            } else {
                weekdays.insert(day)
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : CalendarUITheme.textPrimary)
                .frame(minWidth: 44)
                .frame(height: 36)
                .background(isSelected ? CalendarUITheme.indigo : Color(uiColor: .tertiarySystemBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func validationText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.red.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func timeFromString(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.date(from: value)
    }

    private static func weekdaysFromRecurrence(_ recurrenceLabel: String) -> Set<Int> {
        let lowered = recurrenceLabel.lowercased()
        if lowered.contains("weekday") || lowered.contains("school") {
            return [2, 3, 4, 5, 6]
        }
        return [2, 3, 4, 5, 6]
    }
}

extension SystemDomain.ScheduleTemplate {
    var asCalendarSchedule: CalendarMockModel.UISchedule {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return CalendarMockModel.UISchedule(
            id: id,
            title: name,
            timeString: formatter.string(from: date),
            recurrenceLabel: "Custom",
            driverName: driverId != nil ? "Assigned Driver" : "Unassigned",
            passengerNames: ["Passenger"],
            isEnabled: isActive,
            stops: stops.sorted { $0.order < $1.order }.map {
                CalendarMockModel.UIStop(
                    type: $0.order == 0 ? "Pickup" : "Dropoff",
                    label: $0.name,
                    address: "\($0.latitude), \($0.longitude)"
                )
            }
        )
    }
}

#Preview {
    NavigationStack {
        ScheduleEditorView(mode: .create) { _ in }
            .environmentObject(ScheduleDataSource())
    }
}
