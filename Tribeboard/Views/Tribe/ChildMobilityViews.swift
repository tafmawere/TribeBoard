import SwiftUI

struct ChildSetupFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TribeStore

    @State private var stepIndex = 0

    @State private var childName = ""
    @State private var ageText = ""
    @State private var avatarImageName = ""

    @State private var schoolName = ""
    @State private var schoolAddress = ""
    @State private var dropoffDate = Calendar.current.date(from: DateComponents(hour: 7, minute: 45)) ?? Date()
    @State private var pickupDate = Calendar.current.date(from: DateComponents(hour: 14, minute: 30)) ?? Date()
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6]

    @State private var allowedDriverIds: Set<UUID> = []
    @State private var trackerMemberIds: Set<UUID> = []

    private var adults: [TribeMember] {
        store.members.filter { $0.memberType == .adult }.sorted { $0.fullName < $1.fullName }
    }

    private var childAge: Int? {
        Int(ageText.trimmingCharacters(in: .whitespacesAndNewlines))
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
            actionBar
        }
        .background(TribeTheme.background.ignoresSafeArea())
        .navigationTitle("Add Child")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if allowedDriverIds.isEmpty {
                allowedDriverIds = Set(adults.filter { $0.roles.contains(.driver) || $0.roles.contains(.admin) }.map(\.id))
            }
            if trackerMemberIds.isEmpty {
                trackerMemberIds = Set(adults.filter { $0.roles.contains(.observer) || $0.roles.contains(.admin) }.map(\.id))
            }
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
        .background(Color.white)
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
                    .textFieldStyle(.roundedBorder)
                TextField("Age (optional)", text: $ageText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                TextField("Avatar asset name (optional)", text: $avatarImageName)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 10) {
                    AvatarView(
                        name: childName.isEmpty ? "Child" : childName,
                        identity: childName.isEmpty ? "child-preview" : childName,
                        imageName: avatarImageName.isEmpty ? nil : avatarImageName,
                        size: 44
                    )
                    Text("Preview")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TribeTheme.textSecondary)
                }
            }
        }
    }

    private var schoolStep: some View {
        TribeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("School Setup")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(TribeTheme.textPrimary)
                TextField("School name", text: $schoolName)
                    .textFieldStyle(.roundedBorder)
                TextField("School address", text: $schoolAddress)
                    .textFieldStyle(.roundedBorder)
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
                    Text("Allowed Drivers")
                        .font(.system(size: 16, weight: .semibold))
                    ForEach(adults) { member in
                        rowToggle(member: member, selection: $allowedDriverIds)
                    }
                }
            }
            TribeCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Who Can Track")
                        .font(.system(size: 16, weight: .semibold))
                    ForEach(adults) { member in
                        rowToggle(member: member, selection: $trackerMemberIds)
                    }
                }
            }
        }
    }

    private var reviewStep: some View {
        TribeCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Review")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(TribeTheme.textPrimary)
                Text("Child: \(childName)")
                Text("School: \(schoolName)")
                Text("Drop-off: \(timeText(dropoffDate))")
                Text("Pickup: \(timeText(pickupDate))")
                Text("Weekdays: \(weekdayLabel)")
                Text("Drivers: \(selectedNames(for: allowedDriverIds))")
                Text("Trackers: \(selectedNames(for: trackerMemberIds))")
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

    private func rowToggle(member: TribeMember, selection: Binding<Set<UUID>>) -> some View {
        Button {
            if selection.wrappedValue.contains(member.id) {
                selection.wrappedValue.remove(member.id)
            } else {
                selection.wrappedValue.insert(member.id)
            }
        } label: {
            HStack {
                MemberAvatarView(member: member, size: 34)
                Text(member.fullName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TribeTheme.textPrimary)
                Spacer()
                Image(systemName: selection.wrappedValue.contains(member.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selection.wrappedValue.contains(member.id) ? TribeTheme.primary : .secondary)
            }
            .padding(.vertical, 6)
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
            .background(Color.white)
            .clipShape(Capsule())

            Button(stepIndex == 3 ? "Create Child" : "Next") {
                if stepIndex < 3 {
                    stepIndex += 1
                } else {
                    store.createChildWithSchoolAndDefaultSchedules(
                        childName: childName,
                        avatarImageName: avatarImageName.isEmpty ? nil : avatarImageName,
                        schoolName: schoolName,
                        schoolAddress: schoolAddress,
                        dropoffTime: Calendar.current.dateComponents([.hour, .minute], from: dropoffDate),
                        pickupTime: Calendar.current.dateComponents([.hour, .minute], from: pickupDate),
                        weekdays: weekdays.isEmpty ? [2, 3, 4, 5, 6] : weekdays,
                        allowedDriverIds: Array(allowedDriverIds),
                        trackerMemberIds: Array(trackerMemberIds)
                    )
                    dismiss()
                }
            }
            .disabled(!isCurrentStepValid)
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
            return !schoolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !schoolAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 2:
            return !allowedDriverIds.isEmpty && !trackerMemberIds.isEmpty
        default:
            return true
        }
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
        let names = adults.filter { ids.contains($0.id) }.map(\.fullName)
        return names.isEmpty ? "None" : names.joined(separator: ", ")
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
