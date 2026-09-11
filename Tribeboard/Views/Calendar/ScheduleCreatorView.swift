import SwiftUI

struct ScheduleCreatorView: View {
    private struct DriverOption: Identifiable, Hashable {
        enum Source: Hashable {
            case membership
            case householdPerson
        }

        let id: UUID
        let name: String
        let subtitle: String
        let source: Source
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var activeHouseholdStore: ActiveHouseholdStore
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var backendHouseholdPeopleContext: BackendHouseholdPeopleContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext
    @EnvironmentObject private var backendSchedulesContext: BackendSchedulesContext
    @EnvironmentObject private var backendHouseholdLocationsContext: BackendHouseholdLocationsContext

    @State private var selectedChildId: UUID?
    @State private var scheduleTitle = ""
    @State private var selectedDays: Set<Int> = []
    @State private var selectedTime = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    @State private var selectedDriverId: UUID?
    @State private var originLocationId: UUID?
    @State private var destinationLocationId: UUID?
    @State private var isSaving = false
    @State private var validationMessage: String?

    private let weekdayItems: [(Int, String)] = [
        (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")
    ]
    private let quickTitles = ["School Dropoff", "School Pickup", "Activity Dropoff", "Activity Pickup"]

    init() {
#if DEBUG
        // Environment objects are resolved at runtime; this marks the new-screen dependency.
        assert(true, "BackendChildrenContext missing")
#endif
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if !backendHouseholdContext.canEditSchedules {
                    CalendarCard {
                        Text("Only organisers can create or edit schedules.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CalendarUITheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                childSection
                scheduleSection
                timingSection
                driverSection
                routeSection
            }
            .padding(16)
        }
        .background(CalendarUITheme.offWhite.ignoresSafeArea())
        .navigationTitle("Create Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? "Saving..." : "Save") {
                    Task { await save() }
                }
                .disabled(isSaving || !backendHouseholdContext.canEditSchedules)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .alert(
            "Could Not Save Schedule",
            isPresented: Binding(
                get: { validationMessage != nil || backendSchedulesContext.lastError != nil },
                set: { isPresented in
                    if !isPresented {
                        validationMessage = nil
                        backendSchedulesContext.lastError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                validationMessage = nil
                backendSchedulesContext.lastError = nil
            }
        } message: {
            Text(validationMessage ?? backendSchedulesContext.lastError ?? "Unknown schedule save error.")
        }
        .task {
#if DEBUG
            assert({ _ = backendChildrenContext; return true }(), "BackendChildrenContext missing")
#endif
            await backendChildrenContext.refreshForActiveHousehold()
            await backendHouseholdPeopleContext.refreshForActiveHousehold()
            await backendHouseholdLocationsContext.refreshForActiveHousehold()
            await backendHouseholdLocationsContext.refreshForActiveHousehold()
            if selectedChildId == nil {
                selectedChildId = backendChildrenContext.children.first?.id
            }
            prefillRouteLocations()
        }
        .onChange(of: selectedChildId) { _, _ in
            prefillRouteLocations()
        }
    }

    private func prefillRouteLocations() {
        if originLocationId == nil {
            originLocationId = backendHouseholdLocationsContext.homeLocation?.id
                ?? backendHouseholdLocationsContext.locations(ofType: .home).first?.id
        }
        if destinationLocationId == nil, let childId = selectedChildId,
           let child = backendChildrenContext.children.first(where: { $0.id == childId }) {
            if let schoolLocationId = child.schoolLocationId {
                destinationLocationId = schoolLocationId
            } else if let schoolName = child.schoolName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                      let match = backendHouseholdLocationsContext.findLocationByNameOrLabel(schoolName, preferredType: .school) {
                destinationLocationId = match.id
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button("Cancel") { dismiss() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(CalendarUITheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.black.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                Task { await save() }
            } label: {
                Text(isSaving ? "Saving..." : "Save Schedule")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(CalendarUITheme.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSaving || !backendHouseholdContext.canEditSchedules)
            .opacity(isSaving || !backendHouseholdContext.canEditSchedules ? 0.7 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private var childSection: some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("Child")
                Picker("Child", selection: Binding<UUID?>(
                    get: { selectedChildId },
                    set: { selectedChildId = $0 }
                )) {
                    Text("Select child").tag(nil as UUID?)
                    ForEach(backendChildrenContext.children) { child in
                        Text(child.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? child.legalName)
                            .tag(Optional(child.id))
                    }
                }
            }
        }
    }

    private var scheduleSection: some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("Schedule")
                TextField("Title", text: $scheduleTitle)
                    .textFieldStyle(.roundedBorder)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quickTitles, id: \.self) { title in
                            Button(title) { scheduleTitle = title }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(CalendarUITheme.indigo)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(CalendarUITheme.indigo.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private var timingSection: some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("Timing")
                DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                Text("Days")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CalendarUITheme.textSecondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                    ForEach(weekdayItems, id: \.0) { day, label in
                        dayChip(day: day, label: label)
                    }
                }
            }
        }
    }

    private var driverSection: some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("Driver")
                Picker("Driver (optional)", selection: Binding<UUID?>(
                    get: { selectedDriverId },
                    set: { selectedDriverId = $0 }
                )) {
                    Text("Unassigned").tag(nil as UUID?)
                    ForEach(driverOptions) { option in
                        Text("\(option.name) • \(option.subtitle)").tag(Optional(option.id))
                    }
                }
            }
        }
    }

    private var routeSection: some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Route")
                HouseholdLocationPickerField(
                    title: "Origin",
                    placeholder: "Select origin",
                    selectedLocationId: $originLocationId,
                    preferredTypes: [.home, .pickup, .custom, .relative]
                )
                HouseholdLocationPickerField(
                    title: "Destination",
                    placeholder: "Select destination",
                    selectedLocationId: $destinationLocationId,
                    preferredTypes: [.school, .activity, .dropoff, .custom]
                )
            }
        }
    }

    private var driverOptions: [DriverOption] {
        var options: [DriverOption] = []

        let memberships = backendHouseholdContext.activeHouseholdMembers
            .filter { $0.normalizedStatus == .active || $0.status == nil }
            .map { membership in
            let profile = backendHouseholdContext.activeHouseholdProfilesByUserId[membership.userId]
            let displayName = AuthBackedMemberDisplayResolver.resolveName(
                profile: profile,
                relationshipLabel: membership.relationshipLabel
            )
            return DriverOption(
                id: membership.userId,
                name: displayName,
                subtitle: (membership.normalizedAccessRole?.rawValue ?? HouseholdAccessRole.observer.rawValue).capitalized,
                source: .membership
            )
        }

        let householdPeople = backendHouseholdPeopleContext.people.map { person in
            DriverOption(
                id: person.id,
                name: person.name,
                subtitle: person.relationship?.nilIfEmpty ?? person.role.capitalized,
                source: .householdPerson
            )
        }

        options.append(contentsOf: memberships)
        options.append(contentsOf: householdPeople)
        var seen = Set<UUID>()
        return options
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.name < $1.name }
    }

    private func dayChip(day: Int, label: String) -> some View {
        let selected = selectedDays.contains(day)
        return Button {
            if selected { selectedDays.remove(day) } else { selectedDays.insert(day) }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? .white : CalendarUITheme.textPrimary)
                .frame(minWidth: 44)
                .frame(height: 36)
                .background(selected ? CalendarUITheme.indigo : Color(uiColor: .tertiarySystemBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(CalendarUITheme.textPrimary)
    }

    private func validate() -> String? {
        guard backendHouseholdContext.canEditSchedules else {
            return "Only organisers can create or edit schedules."
        }
        guard let householdId = activeHouseholdStore.activeHouseholdId else {
            return "Select a household before creating schedules."
        }
        guard !householdId.uuidString.isEmpty else {
            return "Invalid active household. Please switch household and try again."
        }
        guard selectedChildId != nil else {
            return "Select a child."
        }
        if scheduleTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Schedule title is required."
        }
        if selectedDays.isEmpty {
            return "Select at least one day."
        }
        guard originLocationId != nil else {
            return "Select an origin location with valid coordinates."
        }
        guard destinationLocationId != nil else {
            return "Select a destination location with valid coordinates."
        }
        return nil
    }

    private func stop(from locationId: UUID?, order: Int) -> SystemDomain.Stop? {
        guard let locationId,
              let location = backendHouseholdLocationsContext.location(id: locationId),
              location.readiness == .complete else {
            return nil
        }
        return SystemDomain.Stop(
            id: UUID(),
            name: location.displayName,
            latitude: location.latitude,
            longitude: location.longitude,
            order: order,
            locationId: location.id
        )
    }

    private func save() async {
        if let error = validate() {
            validationMessage = error
            return
        }
        guard
            let householdId = activeHouseholdStore.activeHouseholdId,
            let childId = selectedChildId
        else {
            validationMessage = "Select a household and child before saving."
            return
        }

        isSaving = true
        defer { isSaving = false }

        let timeParts = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        let originStop = stop(from: originLocationId, order: 0)
        let destinationStop = stop(from: destinationLocationId, order: 1)
        guard let originStop, let destinationStop else {
            validationMessage = "Each stop must use a saved family location with valid coordinates."
            return
        }
        let stops = [originStop, destinationStop]
        let template = SystemDomain.ScheduleTemplate(
            id: UUID(),
            householdId: householdId,
            name: scheduleTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            childId: childId,
            driverId: selectedDriverId,
            weekdays: selectedDays,
            hour: timeParts.hour ?? 7,
            minute: timeParts.minute ?? 0,
            stops: stops,
            isActive: true,
            createdAt: Date()
        )

#if DEBUG
        print(
            "[ScheduleCreatorView] save start household_id=\(householdId.uuidString), " +
            "child_id=\(childId.uuidString), title=\(template.name)"
        )
#endif
        let didSave = await backendSchedulesContext.createSchedule(from: template)
        guard didSave else {
            validationMessage = backendSchedulesContext.lastError ?? "Unable to save schedule. Please try again."
#if DEBUG
            print(
                "[ScheduleCreatorView] save failed household_id=\(householdId.uuidString), " +
                "child_id=\(childId.uuidString), title=\(template.name)"
            )
#endif
            return
        }

        await backendSchedulesContext.refreshSchedules(householdId: householdId)
#if DEBUG
        print(
            "[ScheduleCreatorView] save success household_id=\(householdId.uuidString), " +
            "child_id=\(childId.uuidString), title=\(template.name), created_template_id=\(template.id.uuidString)"
        )
#endif
        dismiss()
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
