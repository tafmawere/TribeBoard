import SwiftUI

struct ChildSetupFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TribeStore
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var backendHouseholdPeopleContext: BackendHouseholdPeopleContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext

    @State private var stepIndex = 0

    @State private var childName = ""
    @State private var displayName = ""
    @State private var gradeOrClass = ""
    @State private var childDateOfBirth: Date?
    @State private var selectedAvatarKey = AvatarPresetCatalog.defaultChildKey
    @State private var hasCustomAvatarSelection = false
    @State private var isShowingAvatarPicker = false

    @State private var schoolName = ""
    @State private var schoolAddress = ""
    @State private var schoolLatitude: Double?
    @State private var schoolLongitude: Double?
    @State private var schoolDays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    @State private var schoolStartTime: DateComponents?
    @State private var schoolEndTime: DateComponents?
    @State private var dropoffDate = Calendar.current.date(from: DateComponents(hour: 7, minute: 45)) ?? Date()
    @State private var pickupDate = Calendar.current.date(from: DateComponents(hour: 14, minute: 30)) ?? Date()
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6]

    @State private var dropoffMemberIds: Set<UUID> = []
    @State private var pickupMemberIds: Set<UUID> = []
    @State private var isCreatingChild = false
    @State private var createErrorMessage: String?
    @FocusState private var focusedField: Field?
    @StateObject private var schoolSearchModel = LocationSearchModel()

    private struct SelectableAdult: Identifiable, Hashable {
        let id: UUID
        let displayName: String
        let relationship: String?
        let roleTag: String
        let isDriver: Bool
        let avatarIdentity: TribeAvatarIdentity
    }

    private enum Field: Hashable {
        case childName
        case displayName
        case grade
        case schoolName
        case schoolAddress
    }

    private var selectableAdults: [SelectableAdult] {
        if authSession.isAuthenticated, backendHouseholdContext.activeHouseholdId != nil {
            var results: [SelectableAdult] = []
            let membershipAdults = backendHouseholdContext.activeHouseholdMembers
                .filter { $0.normalizedStatus == .active || $0.status == nil }
                .map { membership in
                let profile = backendHouseholdContext.activeHouseholdProfilesByUserId[membership.userId]
                let resolvedName = AuthBackedMemberDisplayResolver.resolveName(
                    profile: profile,
                    relationshipLabel: membership.relationshipLabel
                )
                return SelectableAdult(
                    id: membership.userId,
                    displayName: resolvedName,
                    relationship: membership.relationshipLabel?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    roleTag: membership.normalizedAccessRole?.rawValue ?? HouseholdAccessRole.observer.rawValue,
                    isDriver: membership.normalizedAccessRole == .driver,
                    avatarIdentity: profile?.avatarIdentity(fallbackDisplayName: resolvedName)
                        ?? TribeAvatarIdentity(displayName: resolvedName)
                )
            }
            results.append(contentsOf: membershipAdults)
            let nonUserAdults = backendHouseholdPeopleContext.people.map { person in
                SelectableAdult(
                    id: person.id,
                    displayName: person.name,
                    relationship: person.relationship,
                    roleTag: person.role.lowercased(),
                    isDriver: person.isDriver || person.role.lowercased() == "driver",
                    avatarIdentity: person.avatarIdentity()
                )
            }
            results.append(contentsOf: nonUserAdults)
            return results.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
        return store.members
            .filter { $0.memberType == .adult }
            .map { member in
                SelectableAdult(
                    id: member.id,
                    displayName: member.fullName,
                    relationship: member.relationship,
                    roleTag: member.roles.contains(.driver) ? "driver" : (member.roles.contains(.parent) ? "parent" : "helper"),
                    isDriver: member.roles.contains(.driver) || member.roles.contains(.admin),
                    avatarIdentity: member.avatarIdentity
                )
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var parents: [SelectableAdult] {
        selectableAdults.filter { ["parent", "organiser", "guardian"].contains($0.roleTag) }
    }

    private var drivers: [SelectableAdult] {
        selectableAdults.filter { $0.roleTag == "driver" || $0.isDriver }
    }

    private var helpers: [SelectableAdult] {
        selectableAdults.filter { ["helper", "observer", "relative", "other"].contains($0.roleTag) && !$0.isDriver }
    }

    var body: some View {
        VStack(spacing: 0) {
            progressHeader
            ScrollView {
                VStack(spacing: 14) {
                    currentStepView
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            actionBar
        }
        .background(TribeTheme.background.ignoresSafeArea())
        .navigationTitle("Add Child")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if dropoffMemberIds.isEmpty {
                dropoffMemberIds = Set(selectableAdults.filter { $0.isDriver || $0.roleTag == "organiser" }.map(\.id))
            }
            if pickupMemberIds.isEmpty {
                pickupMemberIds = Set(selectableAdults.filter { $0.isDriver || $0.roleTag == "organiser" }.map(\.id))
            }
            applySuggestedAvatarIfNeeded()
        }
        .onChange(of: childDateOfBirth) { _, _ in
            applySuggestedAvatarIfNeeded()
        }
        .sheet(isPresented: $isShowingAvatarPicker) {
            ChildAvatarPickerSheet(selectedKey: $selectedAvatarKey) {
                hasCustomAvatarSelection = true
            }
        }
        .task {
            if authSession.isAuthenticated, backendHouseholdContext.activeHouseholdId != nil {
                await backendHouseholdPeopleContext.refreshForActiveHousehold()
            }
        }
        .alert("Unable to Create Child", isPresented: Binding(
            get: { createErrorMessage != nil },
            set: { newValue in
                if !newValue { createErrorMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) {
                createErrorMessage = nil
            }
        } message: {
            Text(createErrorMessage ?? "Child creation failed.")
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Step \(stepIndex + 1) of 4")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TribeTheme.textSecondary)
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(TribeTheme.primary.opacity(0.14))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(TribeTheme.primary)
                            .frame(width: geo.size.width * CGFloat(stepIndex + 1) / 4)
                    }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color(uiColor: .systemBackground))
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch stepIndex {
        case 0:
            basicsStep
        case 1:
            schoolStep
        case 2:
            mobilityStep
        default:
            reviewStep
        }
    }

    private var basicsStep: some View {
        TribeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Child Basics")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(TribeTheme.textPrimary)
                TextField("Child name", text: $childName)
                    .focused($focusedField, equals: .childName)
                    .modifier(ChildFlowFieldStyle(isFocused: focusedField == .childName))
                TextField("Preferred display name (optional)", text: $displayName)
                    .focused($focusedField, equals: .displayName)
                    .modifier(ChildFlowFieldStyle(isFocused: focusedField == .displayName))
                TextField("Grade/Class (optional)", text: $gradeOrClass)
                    .focused($focusedField, equals: .grade)
                    .modifier(ChildFlowFieldStyle(isFocused: focusedField == .grade))
                DatePicker(
                    "Date of birth (optional)",
                    selection: childDateOfBirthBinding,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)

                childAvatarPickerRow
            }
        }
    }

    private var childAvatarPickerRow: some View {
        Button {
            isShowingAvatarPicker = true
        } label: {
            HStack(spacing: 14) {
                TribeAvatarView(
                    identity: TribeAvatarIdentity(
                        avatarType: .preset,
                        avatarKey: selectedAvatarKey,
                        displayName: childName.isEmpty ? "Child" : childName
                    ),
                    size: .large
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Avatar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TribeTheme.textSecondary)
                    Text(childAvatarSelectionLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TribeTheme.textPrimary)
                    Text("Choose avatar")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TribeTheme.primary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TribeTheme.textSecondary)
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(TribeTheme.primary.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose avatar, currently \(childAvatarSelectionLabel)")
    }

    private var childAvatarSelectionLabel: String {
        if let option = AvatarPresetCatalog.childAvatarOption(for: selectedAvatarKey) {
            return option.accessibilityLabel.capitalized
        }
        return selectedAvatarKey.replacingOccurrences(of: "_", with: " ")
    }

    private func applySuggestedAvatarIfNeeded() {
        guard !hasCustomAvatarSelection else { return }
        selectedAvatarKey = AvatarPresetCatalog.defaultChildAvatarKey(for: childDateOfBirth)
    }

    private var schoolStep: some View {
        TribeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("School Setup")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(TribeTheme.textPrimary)
                Text("Add school details now, or skip and update later.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                LocationSearchField(
                    title: "School Search",
                    placeholder: "Search school",
                    model: schoolSearchModel,
                    onSelected: { result in
                        if schoolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            schoolName = result.title
                        }
                        schoolAddress = result.fullAddress
                        schoolLatitude = result.latitude
                        schoolLongitude = result.longitude
                    },
                    onCleared: {
                        schoolLatitude = nil
                        schoolLongitude = nil
                    }
                )
                TextField("School name", text: $schoolName)
                    .focused($focusedField, equals: .schoolName)
                    .modifier(ChildFlowFieldStyle(isFocused: focusedField == .schoolName))
                TextField("School address", text: $schoolAddress)
                    .focused($focusedField, equals: .schoolAddress)
                    .modifier(ChildFlowFieldStyle(isFocused: focusedField == .schoolAddress))
                Text("School routine (optional)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                schoolDaysPicker
                DatePicker(
                    "School start time",
                    selection: schoolStartTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                DatePicker(
                    "School end time",
                    selection: schoolEndTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                DatePicker("Default drop-off", selection: $dropoffDate, displayedComponents: .hourAndMinute)
                DatePicker("Default pickup", selection: $pickupDate, displayedComponents: .hourAndMinute)
                weekdayPicker
            }
        }
    }

    private var mobilityStep: some View {
        VStack(spacing: 12) {
            TribeCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Household Members")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Choose who can drop off and pick up.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            memberAssignmentCard(title: "Parents", members: parents)
            memberAssignmentCard(title: "Drivers", members: drivers)
            memberAssignmentCard(title: "Helpers", members: helpers)
        }
    }

    private var reviewStep: some View {
        TribeCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Review")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(TribeTheme.textPrimary)
                Text("Child: \(childName)")
                if !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Display name: \(displayName)")
                }
                if let childDateOfBirth {
                    Text("Age: \(age(from: childDateOfBirth)) years old")
                }
                HStack(spacing: 10) {
                    TribeAvatarView(
                        identity: TribeAvatarIdentity(
                            avatarType: .preset,
                            avatarKey: selectedAvatarKey,
                            displayName: childName.isEmpty ? "Child" : childName
                        ),
                        size: .small
                    )
                    Text("Avatar: \(childAvatarSelectionLabel)")
                }
                Text("School: \(schoolName.isEmpty ? "No school configured" : schoolName)")
                if !schoolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Routine: \(schoolRoutineSummary)")
                }
                Text("Drop-off: \(timeText(dropoffDate))")
                Text("Pickup: \(timeText(pickupDate))")
                Text("Weekdays: \(weekdayLabel)")
                Text("Drop-off: \(selectedNames(for: dropoffMemberIds))")
                Text("Pick-up: \(selectedNames(for: pickupMemberIds))")
                    .foregroundStyle(TribeTheme.textSecondary)
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(TribeTheme.textPrimary)
        }
    }

    private var weekdayPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekdays")
                .font(.system(size: 14, weight: .semibold))
            HStack {
                ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                    Button(shortDay(day)) {
                        if weekdays.contains(day) { weekdays.remove(day) } else { weekdays.insert(day) }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(weekdays.contains(day) ? .white : TribeTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(weekdays.contains(day) ? TribeTheme.primary : Color.gray.opacity(0.12))
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func memberAssignmentCard(title: String, members: [SelectableAdult]) -> some View {
        TribeCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                if members.isEmpty {
                    Text("No \(title.lowercased()) available.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(members) { member in
                        HStack(spacing: 10) {
                            TribeAvatarView(
                                identity: member.avatarIdentity,
                                size: .small,
                                accessToken: authSession.currentAccessToken
                            )
                            Text(member.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(TribeTheme.textPrimary)
                            Spacer()
                            selectionPill(title: "Drop-off", selected: dropoffMemberIds.contains(member.id)) {
                                if dropoffMemberIds.contains(member.id) {
                                    dropoffMemberIds.remove(member.id)
                                } else {
                                    dropoffMemberIds.insert(member.id)
                                }
                            }
                            selectionPill(title: "Pick-up", selected: pickupMemberIds.contains(member.id)) {
                                if pickupMemberIds.contains(member.id) {
                                    pickupMemberIds.remove(member.id)
                                } else {
                                    pickupMemberIds.insert(member.id)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
    }

    private func selectionPill(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selected ? .white : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selected ? TribeTheme.primary : Color(uiColor: .tertiarySystemBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button(stepIndex == 0 ? "Cancel" : "Back") {
                if stepIndex == 0 { dismiss() } else { stepIndex -= 1 }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(TribeTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(Capsule())

            Button(stepIndex == 3 ? "Create Child" : "Next") {
                if stepIndex < 3 {
                    stepIndex += 1
                } else {
                    Task {
                        await createChild()
                    }
                }
            }
            .disabled(!isCurrentStepValid || isCreatingChild)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isCurrentStepValid ? TribeTheme.primary : TribeTheme.primary.opacity(0.4))
            .clipShape(Capsule())
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private var isCurrentStepValid: Bool {
        switch stepIndex {
        case 0:
            return !childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1:
            return true
        case 2:
            return !dropoffMemberIds.isEmpty && !pickupMemberIds.isEmpty
        default:
            return true
        }
    }

    private func createChild() async {
        isCreatingChild = true
        defer { isCreatingChild = false }
        let childId = UUID()
        let draftMember = TribeMember(
            id: childId,
            fullName: childName.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarType: .preset,
            avatarKey: selectedAvatarKey,
            avatarImageName: selectedAvatarKey,
            memberType: .child,
            dateOfBirth: childDateOfBirth,
            displayName: displayName.nilIfEmpty,
            schoolName: schoolName.nilIfEmpty,
            schoolAddress: schoolAddress.nilIfEmpty,
            gradeOrClass: gradeOrClass.nilIfEmpty,
            schoolStartTime: schoolStartTime,
            schoolEndTime: schoolEndTime,
            schoolDays: schoolDays.isEmpty ? nil : schoolDays,
            roles: [.child, .passenger],
            isLocationSharingEnabled: true,
            isOnline: false
        )

        let didCreate = await backendChildrenContext.createChild(draftMember)
        guard didCreate else {
            createErrorMessage = backendChildrenContext.lastError ?? "Backend child creation failed."
            return
        }

        _ = store.createChildWithSchoolAndDefaultSchedules(
            childName: childName,
            avatarImageName: selectedAvatarKey,
            displayName: displayName.nilIfEmpty,
            dateOfBirth: childDateOfBirth,
            schoolName: schoolName,
            schoolAddress: schoolAddress,
            gradeOrClass: gradeOrClass.nilIfEmpty,
            schoolLatitude: schoolLatitude,
            schoolLongitude: schoolLongitude,
            schoolStartTime: schoolStartTime,
            schoolEndTime: schoolEndTime,
            schoolDays: schoolDays.isEmpty ? nil : schoolDays,
            dropoffTime: Calendar.current.dateComponents([.hour, .minute], from: dropoffDate),
            pickupTime: Calendar.current.dateComponents([.hour, .minute], from: pickupDate),
            weekdays: weekdays.isEmpty ? [2, 3, 4, 5, 6] : weekdays,
            allowedDriverIds: Array(dropoffMemberIds.union(pickupMemberIds)),
            trackerMemberIds: Array(pickupMemberIds),
            childId: childId
        )
        createErrorMessage = nil
        dismiss()
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func shortDay(_ weekday: Int) -> String {
        ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][max(0, min(6, weekday - 1))]
    }

    private var weekdayLabel: String {
        let ordered = [2, 3, 4, 5, 6, 7, 1]
        return ordered.filter { weekdays.contains($0) }.map(shortDay).joined(separator: ", ")
    }

    private func selectedNames(for ids: Set<UUID>) -> String {
        let names = selectableAdults.filter { ids.contains($0.id) }.map(\.displayName)
        return names.isEmpty ? "None" : names.joined(separator: ", ")
    }

    private var schoolStartTimeBinding: Binding<Date> {
        Binding(
            get: {
                let fallback = DateComponents(hour: 7, minute: 45)
                return Calendar.current.date(from: schoolStartTime ?? fallback) ?? Date()
            },
            set: { schoolStartTime = Calendar.current.dateComponents([.hour, .minute], from: $0) }
        )
    }

    private var schoolEndTimeBinding: Binding<Date> {
        Binding(
            get: {
                let fallback = DateComponents(hour: 13, minute: 45)
                return Calendar.current.date(from: schoolEndTime ?? fallback) ?? Date()
            },
            set: { schoolEndTime = Calendar.current.dateComponents([.hour, .minute], from: $0) }
        )
    }

    private var schoolRoutineSummary: String {
        let ordered = Weekday.allCases.filter { schoolDays.contains($0) }
        let daysText = ordered.map(\.shortLabel).joined(separator: ", ")
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let start = Calendar.current.date(from: schoolStartTime ?? DateComponents(hour: 7, minute: 45)).map { formatter.string(from: $0) } ?? "--:--"
        let end = Calendar.current.date(from: schoolEndTime ?? DateComponents(hour: 13, minute: 45)).map { formatter.string(from: $0) } ?? "--:--"
        return "\(daysText) • \(start)-\(end)"
    }

    private var schoolDaysPicker: some View {
        HStack(spacing: 8) {
            ForEach(Weekday.allCases, id: \.self) { day in
                let selected = schoolDays.contains(day)
                Button(day.shortLabel) {
                    if selected {
                        schoolDays.remove(day)
                    } else {
                        schoolDays.insert(day)
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? .white : TribeTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selected ? TribeTheme.primary : Color.gray.opacity(0.12))
                .clipShape(Capsule())
                .buttonStyle(.plain)
            }
        }
    }

    private var childDateOfBirthBinding: Binding<Date> {
        Binding(
            get: {
                childDateOfBirth ?? Calendar.current.date(byAdding: .year, value: -8, to: Date()) ?? Date()
            },
            set: { childDateOfBirth = $0 }
        )
    }

    private func age(from dateOfBirth: Date) -> Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }
}

struct LocationsManagementView: View {
    @ObservedObject var store: TribeStore
    @State private var searchText = ""
    @State private var selectedLocationId: SelectedLocation?
    @State private var isShowingAdd = false

    private var filteredLocations: [TribeLocation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return store.locations.sorted { $0.name < $1.name } }
        return store.locations.filter {
            $0.name.lowercased().contains(query) || $0.address.lowercased().contains(query)
        }.sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            section(.home)
            section(.school)
            section(.activity)
            section(.custom)
        }
        .searchable(text: $searchText, prompt: "Search locations")
        .navigationTitle("Locations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingAdd) {
            NavigationStack {
                LocationDetailSheet(
                    store: store,
                    location: TribeLocation(name: "", address: "", type: .custom),
                    isNewLocation: true
                )
            }
        }
        .sheet(item: $selectedLocationId) { selected in
            if let location = store.locations.first(where: { $0.id == selected.id }) {
                NavigationStack {
                    LocationDetailSheet(store: store, location: location)
                }
            }
        }
    }

    private func section(_ type: LocationType) -> some View {
        Section(type.title) {
            let rows = filteredLocations.filter { $0.type == type }
            if rows.isEmpty {
                Text("No \(type.title.lowercased()) locations")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows) { location in
                    Button {
                        selectedLocationId = SelectedLocation(id: location.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(location.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text(location.address)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.tribe?.homeLocationId == location.id {
                                Text("HOME")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(TribeTheme.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(TribeTheme.primary.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct SelectedLocation: Identifiable {
    let id: UUID
}

private struct LocationDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TribeStore
    let isNewLocation: Bool

    @State private var location: TribeLocation
    @State private var setAsHome: Bool
    @State private var linkedChildIds: Set<UUID>
    @StateObject private var addressSearchModel = LocationSearchModel()

    init(store: TribeStore, location: TribeLocation, isNewLocation: Bool = false) {
        self.store = store
        self.isNewLocation = isNewLocation
        _location = State(initialValue: location)
        _setAsHome = State(initialValue: store.tribe?.homeLocationId == location.id || location.type == .home)
        _linkedChildIds = State(initialValue: Set(location.linkedChildIds))
    }

    private var childMembers: [TribeMember] {
        store.members.filter { $0.memberType == .child }.sorted { $0.fullName < $1.fullName }
    }

    var body: some View {
        Form {
            Section("Location") {
                TextField("Name", text: $location.name)
                LocationSearchField(
                    title: "Address Search",
                    placeholder: "Search address",
                    model: addressSearchModel,
                    onSelected: { result in
                        location.name = result.title
                        location.address = result.fullAddress
                        if let lat = result.latitude, let lon = result.longitude {
                            location.notes = "lat=\(lat),lon=\(lon)"
                        }
                    }
                )
                TextField("Address", text: $location.address)
                Picker("Type", selection: $location.type) {
                    ForEach(LocationType.allCases, id: \.self) { type in
                        Text(type.title).tag(type)
                    }
                }
                Toggle("Set as Home", isOn: $setAsHome)
            }

            Section("Linked Children") {
                ForEach(childMembers) { child in
                    Button {
                        if linkedChildIds.contains(child.id) {
                            linkedChildIds.remove(child.id)
                        } else {
                            linkedChildIds.insert(child.id)
                        }
                    } label: {
                        HStack {
                            MemberAvatarView(member: child, size: 30)
                            Text(child.fullName)
                            Spacer()
                            Image(systemName: linkedChildIds.contains(child.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(linkedChildIds.contains(child.id) ? TribeTheme.primary : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(isNewLocation ? "Add Location" : "Location Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            addressSearchModel.applySelectedAddress(location.address)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    location.linkedChildIds = Array(linkedChildIds)
                    if setAsHome {
                        location.type = .home
                    }
                    store.addOrUpdateLocation(location, setAsHome: setAsHome)
                    dismiss()
                }
                .disabled(location.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || location.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChildSetupFlowView(store: TribeStore(demoFlow: true))
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct ChildFlowFieldStyle: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .foregroundStyle(.primary)
            .tint(TribeTheme.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(uiColor: .tertiarySystemBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isFocused ? TribeTheme.primary.opacity(0.7) : Color(uiColor: .separator).opacity(0.35),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
