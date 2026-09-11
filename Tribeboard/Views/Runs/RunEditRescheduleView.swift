import SwiftUI

private struct StopAddressSearchTarget: Identifiable {
    let id: UUID
}

enum RunEditSheetMode: Equatable {
    case create
    case edit(RunDetailsData.UIRun)
}

struct RunEditRescheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationService: LocationReadinessService
    @EnvironmentObject private var familyPlacesStore: FamilyQuickPlacesStore
    @EnvironmentObject private var runDataSource: RunDataSource
    @EnvironmentObject private var householdContext: ActiveHouseholdContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext
    @EnvironmentObject private var backendDriversContext: BackendDriversContext
    @EnvironmentObject private var backendHouseholdLocationsContext: BackendHouseholdLocationsContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var backendHouseholdPeopleContext: BackendHouseholdPeopleContext
    @EnvironmentObject private var authSession: AuthSessionContext

    let mode: RunEditSheetMode
    /// Child display name to preselect when the run is started from a child context (e.g. a child card).
    let preselectedPassenger: String?
    /// Return `true` when persistence finished successfully (create flow); edit flows typically return `true` after updating local state.
    let onSave: (RunDetailsData.UIRun) async -> Bool

    @State private var title: String
    @State private var date: Date
    @State private var driverName: String
    @State private var selectedPassengers: Set<String>
    @State private var stops: [RunDetailsData.UIStop]
    @State private var addressSearchTarget: StopAddressSearchTarget?
    @State private var isSaving = false
    @State private var saveSuccessBanner = false
    @State private var saveErrorMessage: String?
    @State private var isLoadingDrivers = true

    private var isCreateMode: Bool {
        if case .create = mode { return true }
        return false
    }

    private struct DriverChoice: Identifiable, Equatable {
        let id: UUID
        let name: String
        let role: String
        let source: String
        let userId: UUID?
        let personId: UUID?
    }

    private var driverChoices: [DriverChoice] {
        var choices: [DriverChoice] = backendDriversContext.drivers.compactMap { driver in
            let name = driver.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return DriverChoice(
                id: driver.id,
                name: name,
                role: driver.role.capitalized,
                source: driver.userId == nil ? "household_people" : "household_memberships",
                userId: driver.userId,
                personId: driver.userId == nil ? driver.id : nil
            )
        }
        // Edit mode: keep the currently assigned driver selectable even if no longer in the eligibility list.
        let current = driverName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isCreateMode, !current.isEmpty,
           !choices.contains(where: { $0.name.caseInsensitiveCompare(current) == .orderedSame }) {
            choices.insert(
                DriverChoice(
                    id: UUID(),
                    name: current,
                    role: "Current driver",
                    source: "existing_run",
                    userId: nil,
                    personId: nil
                ),
                at: 0
            )
        }
        return choices
    }

    private var selectedDriverChoice: DriverChoice? {
        let selected = driverName.trimmingCharacters(in: .whitespacesAndNewlines)
        return driverChoices.first { $0.name.caseInsensitiveCompare(selected) == .orderedSame }
    }

    private var selectedPassengerIds: [UUID] {
        backendChildrenContext.children.compactMap { child in
            guard child.householdId == householdContext.householdId else { return nil }
            let preferred = child.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let legal = child.legalName.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = (preferred?.isEmpty == false ? preferred : nil) ?? legal
            return selectedPassengers.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame })
                ? child.id
                : nil
        }
    }

    private var passengerOptions: [String] {
        var names = backendChildrenContext.children
            .filter { $0.householdId == householdContext.householdId }
            .compactMap { child -> String? in
                let preferred = child.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
                let legal = child.legalName.trimmingCharacters(in: .whitespacesAndNewlines)
                return (preferred?.isEmpty == false ? preferred : nil) ?? (legal.isEmpty ? nil : legal)
            }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        // Edit mode: keep already-selected passengers visible even if the child list changed.
        for selected in selectedPassengers.sorted()
        where !names.contains(where: { $0.caseInsensitiveCompare(selected) == .orderedSame }) {
            names.append(selected)
        }
        return names
    }

    private var baselineRun: RunDetailsData.UIRun {
        switch mode {
        case .create:
            return RunDetailsData.newRunTemplate
        case .edit(let run):
            return run
        }
    }

    private var navigationTitle: String {
        isCreateMode ? "Create Run" : "Edit Run"
    }

    private var primaryActionTitle: String {
        isCreateMode ? "Create Run" : "Save Changes"
    }

    init(
        mode: RunEditSheetMode,
        preselectedPassenger: String? = nil,
        onSave: @escaping (RunDetailsData.UIRun) async -> Bool
    ) {
        self.mode = mode
        self.preselectedPassenger = preselectedPassenger
        self.onSave = onSave
        let run: RunDetailsData.UIRun = {
            switch mode {
            case .create:
                return RunDetailsData.newRunTemplate
            case .edit(let r):
                return r
            }
        }()
        _title = State(initialValue: run.title)
        _date = State(initialValue: run.scheduledTime)
        _driverName = State(initialValue: run.driverName)
        _selectedPassengers = State(initialValue: Set(run.passengerNames))
        _stops = State(initialValue: run.stops)
    }

    /// Convenience for navigation into edit from an existing run.
    init(run: RunDetailsData.UIRun, onSave: @escaping (RunDetailsData.UIRun) async -> Bool) {
        self.init(mode: .edit(run), onSave: onSave)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if !isCreateMode {
                    editInfoBanner
                }
                basicInfoCard
                passengerCard
                driverCard
                routeCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(RunStitchTheme.background.ignoresSafeArea())
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .task {
            await refreshFormData()
        }
        .sheet(item: $addressSearchTarget) { target in
            StopAddressSearchSheet(
                resolvedSnapshot: resolvedSnapshotForStop(id: target.id),
                onSelect: { selection in
                    applyLocationSelection(stopId: target.id, selection)
                    addressSearchTarget = nil
                },
                onCancel: { addressSearchTarget = nil }
            )
            .environmentObject(locationService)
            .environmentObject(familyPlacesStore)
            .environmentObject(backendHouseholdLocationsContext)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground {
                RunStitchTheme.background
            }
        }
        .alert("Run saved successfully", isPresented: $saveSuccessBanner) {
            Button("OK") { dismiss() }
        }
        .alert("Could not save run", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: {
            if let saveErrorMessage {
                Text(saveErrorMessage)
            }
        }
    }

    // MARK: - Data loading

    /// Loads drivers from the same sources as the Tribe tab (household_memberships + household_people)
    /// via `AssignDriverEligibility`, mirroring `DriverPickerView.refreshCandidates`.
    private func refreshFormData() async {
        isLoadingDrivers = true
        defer { isLoadingDrivers = false }

        let householdId = householdContext.householdId
        NSLog("[CreateRun] driver load start householdId=%@", householdId.uuidString)

        await backendHouseholdContext.refreshMemberships()
        await backendHouseholdPeopleContext.refreshPeople(householdId: householdId)
        await backendHouseholdLocationsContext.refreshForActiveHousehold()
        if backendChildrenContext.children.isEmpty {
            await backendChildrenContext.refreshForActiveHousehold()
        }

        let memberships = backendHouseholdContext.activeHouseholdMembers
        let people = backendHouseholdPeopleContext.people
        let childIds = Set(backendChildrenContext.children.map(\.id))
        let currentUserId = authSession.currentUserId.flatMap(UUID.init(uuidString:))

        await backendDriversContext.refreshDrivers(
            householdId: householdId,
            memberships: memberships,
            profilesByUserId: backendHouseholdContext.activeHouseholdProfilesByUserId,
            householdPeople: people,
            childIds: childIds,
            currentUserId: currentUserId
        )

        let loadedDriverIds = Set(backendDriversContext.drivers.map(\.id))
        for membership in memberships {
            NSLog(
                "[CreateRun] membershipId=%@ userId=%@ role=%@ familyRole=%@ eligibleDriver=%@",
                membership.id.uuidString,
                membership.userId.uuidString,
                membership.normalizedAccessRole?.rawValue ?? membership.accessRole,
                membership.familyRole ?? "-",
                loadedDriverIds.contains(membership.userId) ? "yes" : "no"
            )
        }
        for person in people {
            NSLog(
                "[CreateRun] personId=%@ role=%@ isDriver=%@ eligibleDriver=%@",
                person.id.uuidString,
                person.role,
                person.isDriver ? "yes" : "no",
                loadedDriverIds.contains(person.id) ? "yes" : "no"
            )
        }
        NSLog("[CreateRun] loadedDriverCount=%d", backendDriversContext.drivers.count)

        applyDefaultSelections()
    }

    private func applyDefaultSelections() {
        // Passenger: preselect from child context; otherwise auto-select when there is exactly one child.
        if selectedPassengers.isEmpty {
            if let preselected = preselectedPassenger,
               let match = passengerOptions.first(where: { $0.caseInsensitiveCompare(preselected) == .orderedSame }) {
                selectedPassengers = [match]
            } else if isCreateMode, passengerOptions.count == 1, let only = passengerOptions.first {
                selectedPassengers = [only]
            }
        }
        // Driver: auto-select only when there is exactly one option; otherwise the parent chooses explicitly.
        let trimmedDriver = driverName.trimmingCharacters(in: .whitespacesAndNewlines)
        let driverIsValid = driverChoices.contains { $0.name.caseInsensitiveCompare(trimmedDriver) == .orderedSame }
        if !driverIsValid {
            if driverChoices.count == 1, let only = driverChoices.first {
                driverName = only.name
            } else if isCreateMode {
                driverName = ""
            }
        }
    }

    // MARK: - Location selection

    private func resolvedSnapshotForStop(id: UUID) -> StopLocationSelection? {
        guard let idx = stops.firstIndex(where: { $0.id == id }) else { return nil }
        let s = stops[idx]
        guard let la = s.latitude, let lo = s.longitude else { return nil }
        let title = s.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? s.placeName : s.label
        return StopLocationSelection(
            placeId: nil,
            placeName: title.isEmpty ? s.placeName : title,
            formattedAddress: s.address,
            latitude: la,
            longitude: lo,
            householdLocationId: s.locationId,
            provider: nil
        )
    }

    private func applyLocationSelection(stopId: UUID, _ selection: StopLocationSelection) {
        guard let idx = stops.firstIndex(where: { $0.id == stopId }) else { return }
        stops[idx].label = selection.placeName
        stops[idx].placeName = selection.placeName
        stops[idx].address = selection.formattedAddress
        stops[idx].latitude = selection.latitude
        stops[idx].longitude = selection.longitude
        stops[idx].locationId = selection.householdLocationId
        stops[idx].locationNameUserCustomized = false
        familyPlacesStore.recordRecent(from: selection)
    }

    // MARK: - Sections

    private var editInfoBanner: some View {
        StitchCard {
            HStack(spacing: 10) {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(RunStitchTheme.warning)
                Text("Changes will notify all members")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RunStitchTheme.textPrimary)
                Spacer()
            }
        }
    }

    private var basicInfoCard: some View {
        StitchCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Basic Info")
                labeledField("Title", text: $title)
                DatePicker("Date & Time", selection: $date)
                    .datePickerStyle(.compact)
                    .tint(RunStitchTheme.indigo)
            }
        }
    }

    private var passengerCard: some View {
        StitchCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Passenger")
                Text("Who is being picked up?")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(RunStitchTheme.textSecondary)

                if passengerOptions.isEmpty {
                    Text("No children in this household yet. Add a child in Tribe > Children.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(RunStitchTheme.textSecondary)
                } else {
                    selectableChipGrid(
                        options: passengerOptions,
                        isSelected: { selectedPassengers.contains($0) },
                        onTap: { passenger in
                            if selectedPassengers.contains(passenger) {
                                selectedPassengers.remove(passenger)
                            } else {
                                selectedPassengers.insert(passenger)
                            }
                        }
                    )
                }
            }
        }
    }

    private var driverCard: some View {
        StitchCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Driver")
                Text("Who is picking up?")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(RunStitchTheme.textSecondary)

                if driverChoices.isEmpty {
                    if isLoadingDrivers {
                        HStack(spacing: 10) {
                            ProgressView()
                                .scaleEffect(0.85)
                            Text("Loading drivers…")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(RunStitchTheme.textSecondary)
                        }
                    } else {
                        Text("No drivers available. Add a driver in Tribe > Family drivers.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(RunStitchTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    VStack(spacing: 8) {
                        ForEach(driverChoices) { choice in
                            driverRow(choice)
                        }
                    }
                }
            }
        }
    }

    private func driverRow(_ choice: DriverChoice) -> some View {
        let isSelected = driverName.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(choice.name) == .orderedSame
        return Button {
            driverName = choice.name
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(choice.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RunStitchTheme.textPrimary)
                    Text(choice.role)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RunStitchTheme.textSecondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? RunStitchTheme.indigo : Color.gray.opacity(0.35))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? RunStitchTheme.indigo.opacity(0.08) : Color.gray.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? RunStitchTheme.indigo.opacity(0.45) : Color.clear, lineWidth: 1.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func selectableChipGrid(
        options: [String],
        isSelected: @escaping (String) -> Bool,
        onTap: @escaping (String) -> Void
    ) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { option in
                let selected = isSelected(option)
                Button {
                    onTap(option)
                } label: {
                    HStack(spacing: 6) {
                        if selected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text(option)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selected ? Color.white : RunStitchTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(selected ? RunStitchTheme.indigo : Color.gray.opacity(0.10))
                    .clipShape(Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Route

    private var corePickupIndex: Int? {
        stops.firstIndex { $0.type == "Pickup" }
    }

    private var coreDropoffIndex: Int? {
        stops.firstIndex { $0.type == "Dropoff" }
    }

    private var extraStops: [RunDetailsData.UIStop] {
        let coreIds = Set([corePickupIndex, coreDropoffIndex].compactMap { $0 }.map { stops[$0].id })
        return stops.filter { !coreIds.contains($0.id) }
    }

    private var routeCard: some View {
        StitchCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(title: "Route")
                    Spacer()
                    Button("Add stop") {
                        stops.append(
                            .init(
                                type: "Dropoff",
                                label: "",
                                placeName: "",
                                address: "",
                                timeEstimate: "--"
                            )
                        )
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RunStitchTheme.indigo)
                }

                if let pickupIdx = corePickupIndex {
                    coreStopCard(stopIndex: pickupIdx)
                }
                if let dropoffIdx = coreDropoffIndex {
                    coreStopCard(stopIndex: dropoffIdx)
                }

                ForEach(extraStops) { stop in
                    if let idx = stops.firstIndex(where: { $0.id == stop.id }) {
                        advancedStopCard(stopIndex: idx)
                    }
                }
            }
        }
    }

    private func stopDisplayName(_ stop: RunDetailsData.UIStop) -> String {
        let label = stop.label.trimmingCharacters(in: .whitespacesAndNewlines)
        if !label.isEmpty { return label }
        return stop.placeName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isStopResolved(_ stop: RunDetailsData.UIStop) -> Bool {
        stop.latitude != nil && stop.longitude != nil && !stopDisplayName(stop).isEmpty
    }

    /// Simple pickup/dropoff card: type label, location name, address, and a single "Change" action.
    private func coreStopCard(stopIndex idx: Int) -> some View {
        let stop = stops[idx]
        let name = stopDisplayName(stop)
        let hasLocation = isStopResolved(stop)
        return Button {
            addressSearchTarget = StopAddressSearchTarget(id: stop.id)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    RoleChip(
                        text: stop.type,
                        color: stop.type == "Pickup" ? RunStitchTheme.indigo : RunStitchTheme.success
                    )
                    if hasLocation {
                        Text(name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(RunStitchTheme.textPrimary)
                            .multilineTextAlignment(.leading)
                        if !stop.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(stop.address)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(RunStitchTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                    } else {
                        Text("Choose a location")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(RunStitchTheme.textSecondary)
                    }
                }
                Spacer()
                Text(hasLocation ? "Change" : "Choose")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RunStitchTheme.indigo)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Advanced extra-stop card: keeps type control and delete for multi-stop routes.
    private func advancedStopCard(stopIndex idx: Int) -> some View {
        let stop = stops[idx]
        let name = stopDisplayName(stop)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                RoleChip(
                    text: "Extra stop",
                    color: RunStitchTheme.warning
                )
                Spacer()
                Button {
                    stops.removeAll { $0.id == stop.id }
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(RunStitchTheme.danger)
                }
            }

            Picker("Type", selection: stopTypeBinding(stopId: stop.id)) {
                Text("Pickup").tag("Pickup")
                Text("Dropoff").tag("Dropoff")
            }
            .pickerStyle(.segmented)

            Button {
                addressSearchTarget = StopAddressSearchTarget(id: stop.id)
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        if isStopResolved(stop) {
                            Text(name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(RunStitchTheme.textPrimary)
                            if !stop.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(stop.address)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(RunStitchTheme.textSecondary)
                            }
                        } else {
                            Text("Choose a location")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(RunStitchTheme.textSecondary)
                        }
                    }
                    Spacer()
                    Text(isStopResolved(stop) ? "Change" : "Choose")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RunStitchTheme.indigo)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func stopTypeBinding(stopId: UUID) -> Binding<String> {
        Binding(
            get: { stops.first(where: { $0.id == stopId })?.type ?? "Dropoff" },
            set: { newValue in
                guard let idx = stops.firstIndex(where: { $0.id == stopId }) else { return }
                stops[idx].type = newValue
            }
        )
    }

    // MARK: - Bottom bar & validation

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let reason = missingRequirementReason, !isSaving {
                Text(reason)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RunStitchTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }

            PrimaryButton(title: primaryActionTitle) {
                Task { @MainActor in
                    await performSave()
                }
            }
            .opacity(canSave && !isSaving ? 1 : 0.55)
            .disabled(!canSave || isSaving)

            SecondaryButton(title: isCreateMode ? "Cancel" : "Discard") {
                dismiss()
            }
            .disabled(isSaving)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    /// First unmet requirement, phrased as a short user-facing hint shown above the disabled action button.
    private var missingRequirementReason: String? {
        let verb = isCreateMode ? "create" : "save"
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Add a title to \(verb) this run."
        }
        if selectedPassengers.isEmpty {
            return "Choose a passenger to \(verb) this run."
        }
        if driverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Choose a driver to \(verb) this run."
        }
        guard let pickupIdx = corePickupIndex else {
            return "Add a pickup stop to \(verb) this run."
        }
        if !isStopResolved(stops[pickupIdx]) {
            return "Choose a pickup location to \(verb) this run."
        }
        guard let dropoffIdx = coreDropoffIndex else {
            return "Add a dropoff stop to \(verb) this run."
        }
        if !isStopResolved(stops[dropoffIdx]) {
            return "Choose a dropoff location to \(verb) this run."
        }
        if extraStops.contains(where: { !isStopResolved($0) }) {
            return "Set a location for every extra stop, or remove it."
        }
        return nil
    }

    private var canSave: Bool {
        missingRequirementReason == nil
    }

    @MainActor
    private func performSave() async {
        logPreSaveDiagnostics()
        print("[CreateRun] Create Run tapped")
        let hid = householdContext.householdId
        print("[CreateRun] activeHouseholdId=\(hid.uuidString)")
        print("[CreateRun] driver=\(driverName)")
        print("[CreateRun] passengers=\(selectedPassengers.sorted())")
        print("[CreateRun] stops.count=\(stops.count)")
        for stop in stops {
            print("[CreateRun] stop type=\(stop.type), name=\(stop.label), address=\(stop.address), lat=\(String(describing: stop.latitude)), lng=\(String(describing: stop.longitude))")
        }

        var updated = baselineRun
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.scheduledTime = date
        updated.driverName = driverName
        updated.passengerNames = selectedPassengers.sorted()
        updated.passengerStatuses = updated.passengerNames.map { _ in "Waiting" }
        updated.stops = stops
        if isCreateMode {
            updated = RunDetailsData.UIRun(
                id: UUID(),
                title: updated.title,
                scheduledTime: updated.scheduledTime,
                status: updated.status,
                driverName: updated.driverName,
                passengerNames: updated.passengerNames,
                passengerStatuses: updated.passengerStatuses,
                stops: updated.stops,
                timeline: [],
                canEdit: true,
                canCancel: true,
                isHistory: false
            )
        }

        print("[CreateRun] run object created (ui) id=\(updated.id.uuidString) title=\(updated.title)")

        isSaving = true
        defer { isSaving = false }

        if isCreateMode {
            let ok = await runDataSource.createRunFromManualForm(
                updated,
                children: backendChildrenContext.children,
                selectedDriverId: selectedDriverChoice?.id,
                selectedDriverSource: selectedDriverChoice?.source
            )
            if !ok {
                saveErrorMessage = runDataSource.lastError ?? "Unable to save this run."
                print("[CreateRun] save error -> \(saveErrorMessage ?? "")")
                return
            }
            print("[CreateRun] save success — showing confirmation (sheet stays open until OK)")
            saveSuccessBanner = true
            return
        }

        let editOk = await onSave(updated)
        if editOk {
            dismiss()
        } else {
            saveErrorMessage = runDataSource.lastError ?? "Unable to save changes."
        }
    }

    private func logPreSaveDiagnostics() {
        let selectedDriver = selectedDriverChoice
        NSLog(
            "[CreateRun] selectedDriver candidateId=%@ source=%@ userId=%@ personId=%@ displayName=%@",
            selectedDriver?.id.uuidString ?? "nil",
            selectedDriver?.source ?? "unknown",
            selectedDriver?.userId?.uuidString ?? "nil",
            selectedDriver?.personId?.uuidString ?? "nil",
            selectedDriver?.name ?? driverName
        )
        NSLog(
            "[CreateRun] pre_save authSessionExists=yes accessTokenPresent=%@ userId=%@ activeHouseholdId=%@ selectedPassengerIds=%@ stopCount=%d",
            authSession.currentAccessToken?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? "yes" : "no",
            authSession.currentUserId ?? "nil",
            householdContext.householdId.uuidString,
            selectedPassengerIds.map(\.uuidString).joined(separator: ","),
            stops.count
        )
    }

    private func labeledField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RunStitchTheme.textSecondary)
            TextField(title, text: text)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

#Preview("Create") {
    NavigationStack {
        RunFormPreviewShell {
            RunEditRescheduleView(mode: .create) { _ in true }
        }
    }
}

#Preview("Edit") {
    NavigationStack {
        RunFormPreviewShell {
            RunEditRescheduleView(run: RunDetailsData.scheduledRun) { _ in true }
        }
    }
}
