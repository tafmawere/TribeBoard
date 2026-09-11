import SwiftUI
import PhotosUI
import UIKit

struct MemberProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TribeStore
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var backendHouseholdPeopleContext: BackendHouseholdPeopleContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext
    @EnvironmentObject private var backendProfileContext: BackendProfileContext
    @EnvironmentObject private var backendHouseholdLocationsContext: BackendHouseholdLocationsContext
    let memberID: UUID
    var startInEditMode: Bool = false

    @State private var isShowingEditor = false
    @State private var showingAvatarPickerSheet = false
    @State private var showingPhotoLibrary = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingActivityEditor = false
    @State private var editingActivity: ChildActivity?
    @State private var isShowingDeleteConfirmation = false
    @State private var deleteErrorMessage: String?
    @State private var didAutoOpenEditor = false
    @State private var childName = ""
    @State private var childPreferredName = ""
    @State private var childDateOfBirth: Date?
    @State private var childIsPassenger = true
    @State private var childSchoolName = ""
    @State private var childSchoolAddress = ""
    @State private var childSchoolStartTime: DateComponents?
    @State private var childSchoolEndTime: DateComponents?
    @State private var childSchoolDays: Set<Weekday> = []
    @State private var dropoffDate = Calendar.current.date(from: DateComponents(hour: 7, minute: 45)) ?? Date()
    @State private var pickupDate = Calendar.current.date(from: DateComponents(hour: 14, minute: 30)) ?? Date()
    @State private var dropoffMemberIds: Set<UUID> = []
    @State private var pickupMemberIds: Set<UUID> = []
    @State private var isSavingChildProfile = false
    @State private var childSaveErrorMessage: String?
    @State private var isShowingSchoolAddressEditor = false

    private struct TransportAdult: Identifiable, Hashable {
        let id: UUID
        let displayName: String
    }

    private var member: TribeMember? {
        if let local = store.members.first(where: { $0.id == memberID }) {
            return local
        }
        if authSession.isAuthenticated,
           backendHouseholdContext.activeHouseholdId != nil,
           let person = backendHouseholdPeopleContext.person(for: memberID) {
            return backendHouseholdPeopleContext.mapToTribeMember(person)
        }
        return nil
    }

    private var backendPerson: BackendHouseholdPerson? {
        guard authSession.isAuthenticated, backendHouseholdContext.activeHouseholdId != nil else { return nil }
        return backendHouseholdPeopleContext.person(for: memberID)
    }

    private var backendChild: BackendChild? {
        backendChildrenContext.children.first(where: { $0.id == memberID })
    }

    private var needsSchoolAddressLink: Bool {
        guard let backendChild else { return false }
        let hasSchoolName = !(backendChild.schoolName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return hasSchoolName && backendChild.schoolLocationId == nil
    }

    private var isChildMember: Bool {
        member?.memberType == .child
    }

    private var canManageChildProfile: Bool {
        guard isChildMember else { return false }
        guard authSession.isAuthenticated else { return true }
        let role = backendHouseholdContext.roleForActiveHousehold()?.lowercased() ?? ""
        return role == "admin"
    }

    private var transportAdults: [TransportAdult] {
        if authSession.isAuthenticated, backendHouseholdContext.activeHouseholdId != nil {
            var adults: [TransportAdult] = []
            adults.append(contentsOf: backendHouseholdContext.activeHouseholdMembers
                .filter { $0.normalizedStatus == .active || $0.status == nil }
                .map { membership in
                let profile = backendHouseholdContext.activeHouseholdProfilesByUserId[membership.userId]
                let name = AuthBackedMemberDisplayResolver.resolveName(
                    profile: profile,
                    relationshipLabel: membership.relationshipLabel
                )
                return TransportAdult(id: membership.userId, displayName: name)
            })
            adults.append(contentsOf: backendHouseholdPeopleContext.people.map { person in
                TransportAdult(id: person.id, displayName: person.name)
            })
            let unique = Dictionary(adults.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            return unique.values.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        }
        return store.members
            .filter { $0.memberType == .adult }
            .map { TransportAdult(id: $0.id, displayName: $0.fullName) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TribeTheme.background.ignoresSafeArea()

                if let member {
                    ScrollView {
                        VStack(spacing: 16) {
                            headerCard(member)
                            if member.memberType == .child, canManageChildProfile {
                                childProfileSection
                                schoolSection
                                driversAndPickupSection
                                activityCard(member)
                                if let childSaveErrorMessage {
                                    Text(childSaveErrorMessage)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.red)
                                }
                                Button {
                                    Task {
                                        await saveChildProfileChanges()
                                    }
                                } label: {
                                    HStack {
                                        if isSavingChildProfile {
                                            ProgressView()
                                                .tint(.white)
                                        }
                                        Text(isSavingChildProfile ? "Saving..." : "Save Child Profile")
                                            .font(.system(size: 15, weight: .semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(TribeTheme.primary)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .disabled(isSavingChildProfile || childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            } else {
                                rolesCard(member)
                                permissionsCard(member)
                                locationCard(member)
                                contactCard(member)
                                activityCard(member)
                            }
                        }
                        .padding(20)
                    }
                } else {
                    ContentUnavailableView("Member unavailable", systemImage: "person.crop.circle.badge.exclamationmark")
                }
            }
            .navigationTitle("Member Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                if member != nil {
                    if !isChildMember {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Edit") {
                                isShowingEditor = true
                            }
                        }
                    }
                    if backendPerson != nil {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(role: .destructive) {
                                isShowingDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingEditor) {
                if let member {
                    MemberEditorView(existingMember: member, defaultType: member.memberType) { edited in
                        if edited.memberType == .child {
                            await backendChildrenContext.updateChildLocallyThenSync(edited)
                            return backendChildrenContext.lastError == nil
                        } else if authSession.isAuthenticated,
                                  backendHouseholdContext.activeHouseholdId != nil,
                                  let existing = backendHouseholdPeopleContext.person(for: edited.id) {
#if DEBUG
                            print("[MemberProfileView] selected member id=\(existing.id.uuidString), source=household_people")
#endif
                            let updated = BackendHouseholdPerson(
                                id: existing.id,
                                householdId: existing.householdId,
                                name: edited.fullName,
                                relationship: edited.relationship,
                                role: backendHouseholdPeopleContext.mapAdultMemberToBackendRole(edited),
                                phone: edited.phone,
                                isDriver: edited.roles.contains(.driver),
                                createdAt: existing.createdAt,
                                updatedAt: existing.updatedAt
                            )
                            let didUpdate = await backendHouseholdPeopleContext.updatePerson(updated)
#if DEBUG
                            print("[MemberProfileView] update \(didUpdate ? "success" : "failure") for id=\(existing.id.uuidString)")
#endif
                            return didUpdate
                        } else {
                            store.updateMember(edited)
                            return true
                        }
                    }
                }
            }
            .onAppear {
                guard startInEditMode, !didAutoOpenEditor else { return }
                didAutoOpenEditor = true
                isShowingEditor = true
            }
            .task(id: member?.id) {
                loadChildDraftFromMember()
            }
            .alert("Remove member?", isPresented: $isShowingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    Task {
                        await deleteCurrentBackendPerson()
                    }
                }
            } message: {
                Text("This removes this household person from your family.")
            }
            .alert("Unable to Remove Member", isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { newValue in
                    if !newValue { deleteErrorMessage = nil }
                }
            )) {
                Button("OK", role: .cancel) {
                    deleteErrorMessage = nil
                }
            } message: {
                Text(deleteErrorMessage ?? "Delete failed.")
            }
            .photosPicker(isPresented: $showingPhotoLibrary, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        updateMemberPhotoURL(AvatarPhotoStore.saveAvatarPhoto(from: image, memberId: memberID))
                    }
                    selectedPhotoItem = nil
                }
            }
            .sheet(isPresented: $showingAvatarPickerSheet) {
                avatarPickerSheetContent
            }
            .sheet(isPresented: $isShowingActivityEditor) {
                if let member, member.memberType == .child {
                    NavigationStack {
                        ChildActivityEditorView(
                            initialActivity: editingActivity,
                            onSave: { saved in
                                upsertActivity(saved)
                                isShowingActivityEditor = false
                            },
                            onCancel: {
                                isShowingActivityEditor = false
                            }
                        )
                    }
                }
            }
            .sheet(isPresented: $isShowingSchoolAddressEditor) {
                if let backendChild {
                    NavigationStack {
                        AddEditHouseholdLocationView(
                            prefilledDraft: HouseholdLocationDraft(
                                name: backendChild.schoolName ?? childSchoolName,
                                label: backendChild.schoolName ?? childSchoolName,
                                locationType: .school
                            ),
                            linkSchoolChildId: backendChild.id
                        )
                    }
                }
            }
        }
    }

    private func headerCard(_ member: TribeMember) -> some View {
        TribeCard {
            HStack(spacing: 14) {
                MemberAvatarView(
                    member: member,
                    size: 62,
                    accessToken: authSession.currentAccessToken
                )
                    .onTapGesture {
                        showingAvatarPickerSheet = true
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(member.preferredDisplayName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(TribeTheme.textPrimary)
                    if member.memberType == .child {
                        if let ageText = member.ageText {
                            Text(ageText)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(TribeTheme.textSecondary)
                        }
                        Text(member.schoolRoutineSummary)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(TribeTheme.textSecondary)
                            .lineLimit(2)
                    } else {
                        Text(member.subtitle)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(TribeTheme.textSecondary)
                    }
                    Button("Edit Photo") {
                        showingAvatarPickerSheet = true
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TribeTheme.primary)
                }
                Spacer()
            }
        }
    }

    private func rolesCard(_ member: TribeMember) -> some View {
        TribeCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Roles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TribeTheme.textPrimary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(member.roleBadges, id: \.self) { badge in
                        RoleBadge(title: badge)
                    }
                }
            }
        }
    }

    private func permissionsCard(_ member: TribeMember) -> some View {
        TribeCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Permissions")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TribeTheme.textPrimary)

                ForEach(member.derivedPermissions, id: \.self) { permission in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(TribeTheme.primary)
                        Text(permission)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(TribeTheme.textSecondary)
                    }
                }
            }
        }
    }

    private func locationCard(_ member: TribeMember) -> some View {
        TribeCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Location Sharing")
                        .font(.system(size: 16, weight: .semibold))
                    Text(member.isLocationSharingEnabled ? "Enabled" : "Disabled")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(member.isLocationSharingEnabled ? Color.green : Color.red)
                }
                Spacer()
                Image(systemName: member.isLocationSharingEnabled ? "location.fill" : "location.slash.fill")
                    .foregroundStyle(member.isLocationSharingEnabled ? Color.green : Color.red)
            }
        }
    }

    private func contactCard(_ member: TribeMember) -> some View {
        TribeCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Contact")
                    .font(.system(size: 16, weight: .semibold))

                Text(member.phone ?? "No phone number")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(TribeTheme.textSecondary)

                if member.isDriver, member.phone != nil {
                    Button {
                        // UI-only button.
                    } label: {
                        Text("Call Driver")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(TribeTheme.primary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func activityCard(_ member: TribeMember) -> some View {
        TribeCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(member.memberType == .child ? "Activities" : "Activity")
                    .font(.system(size: 16, weight: .semibold))
                if member.memberType == .child {
                    Text(member.activityCountText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TribeTheme.textSecondary)

                    if member.activities.isEmpty {
                        Text("No activities added yet. Add one to capture your child's routine.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(TribeTheme.textSecondary)
                    } else {
                        ForEach(Array(member.activities.enumerated()), id: \.element.id) { index, activity in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(activity.activitySummaryLine)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(TribeTheme.textPrimary)
                                    .lineLimit(2)
                                if let location = activity.activityLocationSummary {
                                    Text(location)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(TribeTheme.textSecondary)
                                        .lineLimit(2)
                                }
                                HStack(spacing: 10) {
                                    Button("Edit") {
                                        editingActivity = activity
                                        isShowingActivityEditor = true
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .buttonStyle(.plain)
                                    .foregroundStyle(TribeTheme.primary)

                                    Button("Remove") {
                                        removeActivity(activity.id)
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.red)
                                }
                            }
                            .padding(.vertical, 2)
                            if index < member.activities.count - 1 {
                                Divider()
                            }
                        }
                    }

                    Button {
                        editingActivity = nil
                        isShowingActivityEditor = true
                    } label: {
                        Label("Add Activity", systemImage: "plus.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(TribeTheme.primary)

                    ProductEducationCard(item: ProductEducationProvider.item(for: .schoolAndActivities))
                } else {
                    Text("Completed runs: 12")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(TribeTheme.textSecondary)
                    Text("Upcoming trips: 3")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(TribeTheme.textSecondary)
                }
            }
        }
    }

    private var childProfileSection: some View {
        TribeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Child Profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TribeTheme.textPrimary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Child Name")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TribeTheme.textSecondary)
                    TextField("Full name", text: $childName)
                        .textInputAutocapitalization(.words)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Preferred Name")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TribeTheme.textSecondary)
                    TextField("Preferred name", text: $childPreferredName)
                        .textInputAutocapitalization(.words)
                        .textFieldStyle(.roundedBorder)
                }

                DatePicker(
                    "Date of Birth",
                    selection: childDateOfBirthBinding,
                    in: ...Date(),
                    displayedComponents: .date
                )

                Toggle("Passenger role enabled", isOn: $childIsPassenger)
                    .toggleStyle(.switch)
            }
        }
    }

    private var schoolSection: some View {
        TribeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("School")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TribeTheme.textPrimary)

                if needsSchoolAddressLink {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("School address missing")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.orange)
                            Button("Add school address") {
                                isShowingSchoolAddressEditor = true
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TribeTheme.primary)
                        }
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                TextField("School name", text: $childSchoolName)
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)

                TextField("School location/address", text: $childSchoolAddress)
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)

                schoolDaysPicker

                DatePicker("School start time", selection: schoolStartTimeBinding, displayedComponents: .hourAndMinute)
                DatePicker("School end time", selection: schoolEndTimeBinding, displayedComponents: .hourAndMinute)
                DatePicker("Default drop-off", selection: $dropoffDate, displayedComponents: .hourAndMinute)
                DatePicker("Default pickup", selection: $pickupDate, displayedComponents: .hourAndMinute)
            }
        }
    }

    private var driversAndPickupSection: some View {
        TribeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Drivers & Pickup")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TribeTheme.textPrimary)

                if transportAdults.isEmpty {
                    Text("No available drivers/helpers yet.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(TribeTheme.textSecondary)
                } else {
                    Text("Who can drop off")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TribeTheme.textSecondary)
                    selectionRow(selectedIds: $dropoffMemberIds)

                    Text("Who can pick up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TribeTheme.textSecondary)
                    selectionRow(selectedIds: $pickupMemberIds)
                }
            }
        }
    }

    private func selectionRow(selectedIds: Binding<Set<UUID>>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(transportAdults) { adult in
                    let isSelected = selectedIds.wrappedValue.contains(adult.id)
                    Button(adult.displayName) {
                        if isSelected {
                            selectedIds.wrappedValue.remove(adult.id)
                        } else {
                            selectedIds.wrappedValue.insert(adult.id)
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : TribeTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(isSelected ? TribeTheme.primary : Color(uiColor: .tertiarySystemBackground))
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var schoolStartTimeBinding: Binding<Date> {
        Binding(
            get: {
                let fallback = DateComponents(hour: 7, minute: 45)
                return Calendar.current.date(from: childSchoolStartTime ?? fallback) ?? Date()
            },
            set: { childSchoolStartTime = Calendar.current.dateComponents([.hour, .minute], from: $0) }
        )
    }

    private var schoolEndTimeBinding: Binding<Date> {
        Binding(
            get: {
                let fallback = DateComponents(hour: 14, minute: 30)
                return Calendar.current.date(from: childSchoolEndTime ?? fallback) ?? Date()
            },
            set: { childSchoolEndTime = Calendar.current.dateComponents([.hour, .minute], from: $0) }
        )
    }

    private var childDateOfBirthBinding: Binding<Date> {
        Binding(
            get: { childDateOfBirth ?? Calendar.current.date(byAdding: .year, value: -8, to: Date()) ?? Date() },
            set: { childDateOfBirth = $0 }
        )
    }

    private var schoolDaysPicker: some View {
        HStack(spacing: 8) {
            ForEach(Weekday.allCases, id: \.self) { day in
                let selected = childSchoolDays.contains(day)
                Button(day.shortLabel) {
                    if selected {
                        childSchoolDays.remove(day)
                    } else {
                        childSchoolDays.insert(day)
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? .white : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selected ? TribeTheme.primary : Color(uiColor: .tertiarySystemBackground))
                .clipShape(Capsule())
                .buttonStyle(.plain)
            }
        }
    }

    private var canUploadAvatarPhoto: Bool {
        guard let member else { return false }
        if member.memberType == .child {
            return !authSession.isAuthenticated || backendHouseholdContext.isCurrentUserOrganiser
        }
        return true
    }

    private var avatarPickerSubject: AvatarSubjectKind? {
        guard authSession.isAuthenticated, let member else { return nil }
        if member.memberType == .child,
           backendChildrenContext.children.contains(where: { $0.id == member.id }) {
            return .child(member.id)
        }
        if backendHouseholdContext.activeHouseholdProfilesByUserId[member.id] != nil {
            return .profile(member.id)
        }
        if authSession.currentUserId?.lowercased() == member.id.uuidString.lowercased(),
           let profileId = backendProfileContext.currentUserProfile?.id {
            return .profile(profileId)
        }
        return nil
    }

    @ViewBuilder
    private var avatarPickerSheetContent: some View {
        if let member,
           let token = authSession.currentAccessToken,
           let subject = avatarPickerSubject {
            NavigationStack {
                AvatarPickerView(
                    subjectKind: subject,
                    displayName: member.preferredDisplayName,
                    memberType: member.memberType,
                    isDriver: member.roles.contains(.driver),
                    canUploadPhoto: canUploadAvatarPhoto,
                    initialIdentity: member.avatarIdentity,
                    accessToken: token,
                    onSaved: { saved in
                        syncMemberAvatar(saved)
                    }
                )
            }
        } else {
            AvatarPickerSheet(
                onUploadPhoto: {
                    showingPhotoLibrary = true
                },
                onSelectSymbol: { symbol in
                    updateMemberAvatarSymbol(symbol)
                },
                onRemovePhoto: member?.avatarURL != nil ? {
                    AvatarPhotoStore.deletePhoto(reference: member?.avatarURL)
                    updateMemberPhotoURL(nil)
                } : nil
            )
        }
    }

    private func syncMemberAvatar(_ saved: TribeAvatarIdentity) {
        guard var current = member else { return }
        current.avatarType = saved.avatarType
        current.avatarKey = saved.avatarKey
        current.avatarURL = saved.avatarURL
        store.updateMember(current)
    }

    private func updateMemberPhotoURL(_ photoURL: String?) {
        guard var current = member else { return }
        current.avatarURL = photoURL
        store.updateMember(current)
    }

    private func updateMemberAvatarSymbol(_ symbol: AvatarSymbol?) {
        guard var current = member else { return }
        current.avatarSymbol = symbol
        current.avatarImageName = symbol?.rawValue
        store.updateMember(current)
    }

    private func upsertActivity(_ activity: ChildActivity) {
        guard let current = member, current.memberType == .child else { return }
        Task {
            await backendChildrenContext.upsertActivityLocallyThenSync(childId: current.id, activity: activity)
        }
    }

    private func removeActivity(_ activityID: UUID) {
        guard let current = member, current.memberType == .child else { return }
        Task {
            await backendChildrenContext.deleteActivityLocallyThenSync(childId: current.id, activityId: activityID)
        }
    }

    private func loadChildDraftFromMember() {
        guard let current = member, current.memberType == .child else { return }
        childName = current.fullName
        childPreferredName = current.displayName ?? ""
        childDateOfBirth = current.dateOfBirth
        childIsPassenger = current.roles.contains(.passenger)
        childSchoolName = current.schoolName ?? ""
        childSchoolAddress = current.schoolAddress ?? ""
        childSchoolStartTime = current.schoolStartTime
        childSchoolEndTime = current.schoolEndTime
        childSchoolDays = current.schoolDays ?? []

        if let routine = store.routines.first(where: { $0.childId == current.id }) {
            dropoffDate = Calendar.current.date(from: routine.dropoffTime) ?? dropoffDate
            pickupDate = Calendar.current.date(from: routine.pickupTime) ?? pickupDate
        }

        if let profile = store.childProfiles.first(where: { $0.memberId == current.id }) {
            dropoffMemberIds = Set(profile.allowedDriverIds)
            pickupMemberIds = Set(profile.trackerMemberIds)
        } else {
            dropoffMemberIds = []
            pickupMemberIds = []
        }
    }

    private func saveChildProfileChanges() async {
        guard var current = member, current.memberType == .child else { return }
        let normalizedName = childName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            childSaveErrorMessage = "Child name is required."
            return
        }

        isSavingChildProfile = true
        childSaveErrorMessage = nil

        let normalizedPreferredName = childPreferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSchoolName = childSchoolName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSchoolAddress = childSchoolAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        current.fullName = normalizedName
        current.displayName = normalizedPreferredName.isEmpty ? nil : normalizedPreferredName
        current.dateOfBirth = childDateOfBirth
        current.schoolName = normalizedSchoolName.isEmpty ? nil : normalizedSchoolName
        current.schoolAddress = normalizedSchoolAddress.isEmpty ? nil : normalizedSchoolAddress
        current.schoolStartTime = childSchoolStartTime
        current.schoolEndTime = childSchoolEndTime
        current.schoolDays = childSchoolDays.isEmpty ? nil : childSchoolDays
        var updatedRoles: Set<Role> = [.child]
        if childIsPassenger {
            updatedRoles.insert(.passenger)
        }
        current.roles = updatedRoles

#if DEBUG
        print("[ChildProfileSave] child_id=\(current.id.uuidString), edited_fields=name,display_name,date_of_birth,school_name,school_address,school_start_time,school_end_time,school_days,passenger_role,dropoff,pickup,drivers")
#endif

        await backendChildrenContext.updateChildLocallyThenSync(current)
        let backendSaveSucceeded = backendChildrenContext.lastError == nil

        if backendSaveSucceeded {
            // Preserve local school/logistics fields that are not yet part of backend child columns.
            store.upsertMember(current)
            persistLocalChildLogistics(for: current.id)
            await backendChildrenContext.refreshActivities(childId: current.id)
#if DEBUG
            print("[ChildProfileSave] child_id=\(current.id.uuidString), save=success")
#endif
        } else {
            childSaveErrorMessage = backendChildrenContext.lastError ?? "Unable to save child profile."
#if DEBUG
            print("[ChildProfileSave] child_id=\(current.id.uuidString), save=failure, error=\(childSaveErrorMessage ?? "unknown")")
#endif
        }

        isSavingChildProfile = false
    }

    private func persistLocalChildLogistics(for childId: UUID) {
        let dropoffComponents = Calendar.current.dateComponents([.hour, .minute], from: dropoffDate)
        let pickupComponents = Calendar.current.dateComponents([.hour, .minute], from: pickupDate)

        if let routineIndex = store.routines.firstIndex(where: { $0.childId == childId }) {
            store.routines[routineIndex].weekdays = Set(childSchoolDays.map(\.rawValue))
            store.routines[routineIndex].dropoffTime = dropoffComponents
            store.routines[routineIndex].pickupTime = pickupComponents
        } else {
            store.routines.append(
                Routine(
                    childId: childId,
                    weekdays: Set(childSchoolDays.map(\.rawValue)),
                    dropoffTime: dropoffComponents,
                    pickupTime: pickupComponents
                )
            )
        }

        if let profileIndex = store.childProfiles.firstIndex(where: { $0.memberId == childId }) {
            store.childProfiles[profileIndex].allowedDriverIds = Array(dropoffMemberIds)
            store.childProfiles[profileIndex].trackerMemberIds = Array(pickupMemberIds)
        } else {
            let schoolLocationId = resolvePrimarySchoolLocationId(childId: childId)
            store.childProfiles.append(
                ChildProfile(
                    memberId: childId,
                    primarySchoolLocationId: schoolLocationId,
                    allowedDriverIds: Array(dropoffMemberIds),
                    trackerMemberIds: Array(pickupMemberIds)
                )
            )
        }
    }

    private func resolvePrimarySchoolLocationId(childId: UUID) -> UUID {
        if let existingProfile = store.childProfiles.first(where: { $0.memberId == childId }) {
            return existingProfile.primarySchoolLocationId
        }
        if let existingSchool = store.locations.first(where: { $0.childId == childId && $0.type == .school }) {
            return existingSchool.id
        }
        let created = TribeLocation(
            name: childSchoolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "School" : childSchoolName,
            address: childSchoolAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Address not set" : childSchoolAddress,
            type: .school,
            tribeId: store.tribe?.id,
            childId: childId,
            linkedChildIds: [childId]
        )
        store.addOrUpdateLocation(created)
        return created.id
    }

    private func deleteCurrentBackendPerson() async {
        guard let person = backendPerson else { return }
#if DEBUG
        print("[MemberProfileView] selected member id=\(person.id.uuidString), source=household_people")
#endif
        let didDelete = await backendHouseholdPeopleContext.deletePerson(id: person.id)
#if DEBUG
        print("[MemberProfileView] delete \(didDelete ? "success" : "failure") for id=\(person.id.uuidString)")
#endif
        guard didDelete else {
            deleteErrorMessage = backendHouseholdPeopleContext.lastError ?? "Unable to remove member. Please try again."
            return
        }
        await backendHouseholdPeopleContext.refreshForActiveHousehold()
        dismiss()
    }
}

private struct ChildActivityEditorView: View {
    let initialActivity: ChildActivity?
    let onSave: (ChildActivity) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var type: ChildActivityType
    @State private var locationName: String
    @State private var locationAddress: String
    @State private var days: Set<Weekday>
    @State private var startTime: DateComponents?
    @State private var endTime: DateComponents?
    @State private var notes: String
    @StateObject private var locationSearchModel = LocationSearchModel()

    init(initialActivity: ChildActivity?, onSave: @escaping (ChildActivity) -> Void, onCancel: @escaping () -> Void) {
        self.initialActivity = initialActivity
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: initialActivity?.name ?? "")
        _type = State(initialValue: initialActivity?.type ?? .external)
        _locationName = State(initialValue: initialActivity?.locationName ?? "")
        _locationAddress = State(initialValue: initialActivity?.locationAddress ?? "")
        _days = State(initialValue: initialActivity?.days ?? [])
        _startTime = State(initialValue: initialActivity?.startTime)
        _endTime = State(initialValue: initialActivity?.endTime)
        _notes = State(initialValue: initialActivity?.notes ?? "")
    }

    var body: some View {
        Form {
            Section("Basic Info") {
                TextField("Activity name", text: $name)
                    .foregroundStyle(.primary)
                    .tint(TribeTheme.primary)
                Picker("Type", selection: $type) {
                    ForEach(ChildActivityType.allCases, id: \.self) { option in
                        Text(option == .schoolBased ? "School-based" : "External").tag(option)
                    }
                }
            }

            Section("Timing") {
                weekdayPicker
                DatePicker("Start time", selection: startTimeBinding, displayedComponents: .hourAndMinute)
                DatePicker("End time", selection: endTimeBinding, displayedComponents: .hourAndMinute)
            }

            Section("Location") {
                LocationSearchField(
                    title: "Activity Search",
                    placeholder: "Search activity location",
                    model: locationSearchModel,
                    onSelected: { result in
                        locationName = result.title
                        locationAddress = result.fullAddress
                        if let lat = result.latitude, let lon = result.longitude {
                            notes = encodeCoordinates(in: notes, latitude: lat, longitude: lon)
                        }
                    }
                )
                TextField("Location name (optional)", text: $locationName)
                    .foregroundStyle(.primary)
                    .tint(TribeTheme.primary)
                TextField("Location address (optional)", text: $locationAddress)
                    .foregroundStyle(.primary)
                    .tint(TribeTheme.primary)
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .foregroundStyle(.primary)
                    .tint(TribeTheme.primary)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(initialActivity == nil ? "Add Activity" : "Edit Activity")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !locationAddress.isEmpty {
                locationSearchModel.applySelectedAddress(locationAddress)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    let activity = ChildActivity(
                        id: initialActivity?.id ?? UUID(),
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        type: type,
                        locationName: locationName,
                        locationAddress: locationAddress,
                        days: days,
                        startTime: startTime,
                        endTime: endTime,
                        notes: notes
                    )
                    onSave(activity)
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: {
                let fallback = DateComponents(hour: 15, minute: 30)
                return Calendar.current.date(from: startTime ?? fallback) ?? Date()
            },
            set: { startTime = Calendar.current.dateComponents([.hour, .minute], from: $0) }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding(
            get: {
                let fallback = DateComponents(hour: 16, minute: 30)
                return Calendar.current.date(from: endTime ?? fallback) ?? Date()
            },
            set: { endTime = Calendar.current.dateComponents([.hour, .minute], from: $0) }
        )
    }

    private var weekdayPicker: some View {
        HStack(spacing: 8) {
            ForEach(Weekday.allCases, id: \.self) { day in
                let selected = days.contains(day)
                Button(day.shortLabel) {
                    if selected { days.remove(day) } else { days.insert(day) }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? .white : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selected ? TribeTheme.primary : Color(uiColor: .tertiarySystemBackground))
                .clipShape(Capsule())
                .buttonStyle(.plain)
            }
        }
    }

    private func encodeCoordinates(in existingNotes: String, latitude: Double, longitude: Double) -> String {
        let prefix = existingNotes
            .split(separator: "|")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.hasPrefix("coords=") && !$0.isEmpty }
            .joined(separator: " | ")
        let coord = "coords=lat:\(latitude),lon:\(longitude)"
        return prefix.isEmpty ? coord : "\(prefix) | \(coord)"
    }
}

#Preview {
    let store = TribeStore(demoFlow: true)
    return MemberProfileView(store: store, memberID: store.members[0].id)
}
