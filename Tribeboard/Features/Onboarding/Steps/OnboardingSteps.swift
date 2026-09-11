import SwiftUI

struct OnboardingInvitedAcceptanceStep: View {
    let invites: [PendingEmailInvitePresentation]
    @Binding var selectedInviteId: UUID?
    @Binding var profileDraft: OnboardingProfileDraft
    let requiresProfileFields: Bool
    let canAccept: Bool
    let isLoading: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    private var selectedInvite: PendingEmailInvitePresentation? {
        if let selectedInviteId,
           let match = invites.first(where: { $0.inviteId == selectedInviteId }) {
            return match
        }
        return invites.first
    }

    var body: some View {
        VStack(spacing: 12) {
            OnboardingCard {
                if let invite = selectedInvite {
                    Text("You've been invited to join \(invite.householdName)")
                        .font(.system(size: 26, weight: .bold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("You've been invited")
                        .font(.system(size: 26, weight: .bold))
                }
            }

            if let invite = selectedInvite {
                OnboardingCard {
                    VStack(alignment: .leading, spacing: 10) {
                        inviteDetailRow(label: "Email", value: invite.inviteeEmail)
                        inviteDetailRow(label: "Role", value: invite.displayAccessRole)
                        inviteDetailRow(label: "Relationship", value: invite.displayRelationship)
                    }
                    .font(.system(size: 15))
                }
            }

            if invites.count > 1 {
                OnboardingCard {
                    Text("You have \(invites.count) pending invitations. Select one to accept first — you can join more families later.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    ForEach(invites, id: \.inviteId) { invite in
                        Button {
                            selectedInviteId = invite.inviteId
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(invite.householdName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text("\(invite.displayAccessRole) · \(invite.displayRelationship)")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedInvite?.inviteId == invite.inviteId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        if invite.inviteId != invites.last?.inviteId {
                            Divider()
                        }
                    }
                }
            }

            if requiresProfileFields {
                OnboardingCard {
                    Text("Your name in the tribe")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Add how you want to appear before joining. Your organiser will see this on the Tribe screen.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    TextField("First name (required)", text: $profileDraft.firstName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .onChange(of: profileDraft.firstName) { _, newValue in
                            let trimmedFirst = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            if profileDraft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                               !trimmedFirst.isEmpty {
                                profileDraft.displayName = trimmedFirst
                            }
                        }
                    TextField("Last name (optional)", text: $profileDraft.lastName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    TextField("Display name (required)", text: $profileDraft.displayName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            OnboardingCard {
                VStack(spacing: 10) {
                    Button(action: onAccept) {
                        Group {
                            if isLoading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Accepting…")
                                }
                            } else {
                                Text("Accept invite")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || !canAccept)

                    Button("Not now", action: onDecline)
                        .buttonStyle(.bordered)
                        .disabled(isLoading)
                }
            }
        }
        .onAppear {
            if selectedInviteId == nil {
                selectedInviteId = invites.first?.inviteId
            }
        }
    }

    private func inviteDetailRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct OnboardingWelcomeStep: View {
    let onSelectSetup: () -> Void
    let onSelectJoin: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroIllustration
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .padding(.bottom, 20)

                VStack(spacing: 6) {
                    headline
                    bodyCopy
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)

                VStack(spacing: 14) {
                    onboardingPathCard(
                        icon: "person.3.fill",
                        title: "Create Tribe",
                        body: "Start a new tribe and invite parents, drivers and helpers.",
                        checklist: [
                            "Add children",
                            "Create school runs",
                            "Share responsibilities"
                        ],
                        action: onSelectSetup
                    )
                    onboardingPathCard(
                        icon: "key.fill",
                        title: "Join Tribe",
                        body: "Join an existing tribe using an invitation code.",
                        checklist: [
                            "Accept invitation",
                            "Complete profile",
                            "Start helping immediately"
                        ],
                        action: onSelectJoin
                    )
                }
                .padding(.horizontal, 20)

                inviteCodeShortcut
                    .padding(.top, 22)
                    .padding(.horizontal, 20)

                privacyFooter
                    .padding(.top, 28)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
            }
        }
        .background(Color.white)
    }

    private var heroIllustration: some View {
        Image("onboarding_family_logistics")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .accessibilityHidden(true)
    }

    private var headline: some View {
        (
            Text("Tribe logistics,\n")
                .foregroundStyle(OnboardingTheme.headlineNavy)
            +
            Text("made simple.")
                .foregroundStyle(OnboardingTheme.brandPurple)
        )
        .font(.system(size: 30, weight: .bold))
        .lineSpacing(2)
    }

    private var bodyCopy: some View {
        Text("Coordinate school runs, pickups, activities and trusted drivers from one place.")
            .font(.system(size: 16))
            .foregroundStyle(Color.secondary)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func onboardingPathCard(
        icon: String,
        title: String,
        body: String,
        checklist: [String],
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(OnboardingTheme.brandPurple.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.brandPurple)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(OnboardingTheme.headlineNavy)
                    Text(body)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(checklist, id: \.self) { item in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(OnboardingTheme.brandPurple)
                                Text(item)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 8)

                ZStack {
                    Circle()
                        .fill(OnboardingTheme.brandPurple.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(OnboardingTheme.brandPurple)
                }
                .padding(.top, 2)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(OnboardingTheme.brandPurple.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.05), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var inviteCodeShortcut: some View {
        Button(action: onSelectJoin) {
            HStack(spacing: 6) {
                Text("Have an invitation code?")
                    .foregroundStyle(.secondary)
                Text("Enter code")
                    .fontWeight(.semibold)
                    .foregroundStyle(OnboardingTheme.brandPurple)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.brandPurple)
            }
            .font(.system(size: 14))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var privacyFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(OnboardingTheme.brandPurple.opacity(0.8))
            Text("Privacy-first. Your tribe’s data stays secure.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct OnboardingJoinCodeStep: View {
    @Binding var joinCode: String
    var hasEmailPendingInvite: Bool = false

    var body: some View {
        OnboardingCard {
            Text("Join a tribe")
                .font(.system(size: 22, weight: .bold))
            Text(
                hasEmailPendingInvite
                    ? "We found a family invite for your email. Continue to your profile — you do not need to enter a code."
                    : "Paste your invite code from your tribe admin."
            )
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            TextField("Invite code", text: $joinCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

struct OnboardingProfileStep: View {
    @Binding var profile: OnboardingProfileDraft
    let title: String

    var body: some View {
        OnboardingCard {
            Text(title)
                .font(.system(size: 22, weight: .bold))
            Text("Tell us how your name should appear in your tribe.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            TextField("First name", text: $profile.firstName)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            TextField("Last name", text: $profile.lastName)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            TextField("Display name", text: $profile.displayName)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

struct OnboardingJoinResultStep: View {
    let status: OnboardingJoinResultStatus?
    let message: String
    let householdName: String

    var body: some View {
        OnboardingCard {
            Text(status == .active ? "You joined \(householdName)" : "Waiting for approval")
                .font(.system(size: 22, weight: .bold))
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            if status == .pending {
                Text("You can browse in restricted mode while an admin approves your request.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.orange)
            }
        }
    }
}

struct OnboardingSetupTribeStep: View {
    @Binding var tribe: TribeDraft

    var body: some View {
        OnboardingCard {
            Text("Set up your tribe")
                .font(.system(size: 22, weight: .bold))
            Text("Pick a name your family will recognize.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            TextField("Tribe name", text: $tribe.tribeName)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

struct OnboardingHomeStep: View {
    @Binding var selectedLocation: ResolvedLocationDraft?
    @StateObject private var locationModel = LocationSearchModel()

    var body: some View {
        OnboardingCard {
            Text("Home location")
                .font(.system(size: 22, weight: .bold))
            Text("Search and select your home so pickups can be routed correctly.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            LocationSearchField(
                title: "Home",
                placeholder: "Search home address",
                model: locationModel
            ) { result in
                selectedLocation = ResolvedLocationDraft(
                    title: result.title,
                    address: result.fullAddress,
                    latitude: result.latitude,
                    longitude: result.longitude
                )
            } onCleared: {
                selectedLocation = nil
            }
        }
        .onAppear {
            if let selectedLocation {
                locationModel.applySelectedAddress(selectedLocation.address)
            }
        }
    }
}

struct OnboardingChildrenStep: View {
    @Binding var children: [ChildDraft]
    let onAdd: () -> Void
    let onRemove: (UUID) -> Void

    var body: some View {
        OnboardingCard {
            Text("Add children")
                .font(.system(size: 22, weight: .bold))
            Text("Add everyone who needs rides. You can add more later too.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            ForEach($children) { $child in
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Display name", text: $child.displayName)
                        .textInputAutocapitalization(.words)
                    TextField("Legal name (optional)", text: $child.legalName)
                        .textInputAutocapitalization(.words)
                    TextField("Grade / class", text: $child.gradeOrClass)
                        .textInputAutocapitalization(.words)
                    DatePicker(
                        "Date of birth (optional)",
                        selection: Binding(
                            get: { child.dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -8, to: Date()) ?? Date() },
                            set: { child.dateOfBirth = $0 }
                        ),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    if children.count > 1 {
                        Button("Remove child", role: .destructive) {
                            onRemove(child.id)
                        }
                        .font(.system(size: 13, weight: .semibold))
                    }
                }
                .padding(12)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Button("Add another child", action: onAdd)
                .buttonStyle(.bordered)
        }
    }
}

struct OnboardingChildSetupListStep: View {
    let children: [ChildDraft]
    let onSelectChild: (UUID) -> Void

    var body: some View {
        OnboardingCard {
            Text("Child setup progress")
                .font(.system(size: 22, weight: .bold))
            Text("Complete school, routine, and optional activities for each child.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            ForEach(children) { child in
                Button {
                    onSelectChild(child.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(child.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unnamed child" : child.displayName)
                                .font(.system(size: 16, weight: .semibold))
                            Text(statusText(for: child))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if child.completedSchoolStep && child.completedRoutineStep {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func statusText(for child: ChildDraft) -> String {
        let school = child.completedSchoolStep ? "School done" : "School needed"
        let routine = child.completedRoutineStep ? "Routine done" : "Routine needed"
        return "\(school) • \(routine)"
    }
}

struct OnboardingChildSchoolStep: View {
    let child: ChildDraft
    let siblingSchools: [SchoolDraft]
    let onUpdate: (ChildDraft) -> Void
    @StateObject private var locationModel = LocationSearchModel()

    var body: some View {
        OnboardingCard {
            Text("School setup")
                .font(.system(size: 22, weight: .bold))
            Text("Select \(child.displayName.isEmpty ? "this child's" : "\(child.displayName)'s") school location.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            if !siblingSchools.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose from existing schools")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(siblingSchools, id: \.id) { school in
                        Button {
                            var updated = child
                            updated.school = school
                            updated.schoolId = school.id
                            onUpdate(updated)
                            if let address = school.location?.address {
                                locationModel.applySelectedAddress(address)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(school.schoolName)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text(school.location?.address ?? "Address unavailable")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text("Or search for a new school")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField(
                "School name",
                text: Binding(
                    get: { child.school.schoolName },
                    set: { value in
                        var updated = child
                        updated.school.schoolName = value
                        updated.schoolId = updated.school.id
                        onUpdate(updated)
                    }
                )
            )
            .textInputAutocapitalization(.words)
            .padding(12)
            .background(Color(uiColor: .tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            TextField(
                "Address / location",
                text: Binding(
                    get: { child.school.location?.address ?? "" },
                    set: { value in
                        var updated = child
                        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            updated.school.location = nil
                            updated.schoolId = nil
                        } else {
                            let existing = updated.school.location
                            updated.school.location = ResolvedLocationDraft(
                                id: existing?.id ?? UUID(),
                                title: existing?.title ?? updated.school.schoolName,
                                address: trimmed,
                                latitude: existing?.latitude,
                                longitude: existing?.longitude,
                                placeId: existing?.placeId
                            )
                            updated.schoolId = updated.school.id
                        }
                        onUpdate(updated)
                    }
                )
            )
            .textInputAutocapitalization(.words)
            .padding(12)
            .background(Color(uiColor: .tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            LocationSearchField(
                title: "School location",
                placeholder: "Search school address",
                model: locationModel
            ) { result in
                var updated = child
                if updated.school.schoolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    updated.school.schoolName = result.title
                }
                updated.school.location = ResolvedLocationDraft(
                    title: result.title,
                    address: result.fullAddress,
                    latitude: result.latitude,
                    longitude: result.longitude
                )
                updated.schoolId = updated.school.id
                onUpdate(updated)
                locationModel.applySelectedAddress(result.fullAddress)
            } onCleared: {
                var updated = child
                updated.school.location = nil
                updated.schoolId = nil
                onUpdate(updated)
            }
        }
        .onAppear {
            if let location = child.school.location {
                locationModel.applySelectedAddress(location.address)
            }
        }
    }
}

struct OnboardingChildRoutineStep: View {
    let child: ChildDraft
    let onUpdate: (ChildDraft) -> Void
    @State private var pickerContext: RoutinePickerContext?

    var body: some View {
        OnboardingCard {
            Text("School routine")
                .font(.system(size: 22, weight: .bold))
            Text("Enable weekdays and times for drop-off and pickup.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Text("Only enable days your child attends school")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            ForEach(child.routine.days) { day in
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(day.weekday.shortLabel, isOn: Binding(
                        get: { day.isEnabled },
                        set: { enabled in
                            updateDay(day.id) { $0.isEnabled = enabled }
                        }
                    ))
                    if day.isEnabled {
                        routineTimeRow(
                            label: "Drop-off",
                            timeText: formattedTime(hour: day.dropoffHour, minute: day.dropoffMinute)
                        ) {
                            pickerContext = RoutinePickerContext(
                                dayId: day.id,
                                kind: .dropoff,
                                selectedTime: dateFrom(hour: day.dropoffHour, minute: day.dropoffMinute)
                            )
                        }
                        routineTimeRow(
                            label: "Pickup",
                            timeText: formattedTime(hour: day.pickupHour, minute: day.pickupMinute)
                        ) {
                            pickerContext = RoutinePickerContext(
                                dayId: day.id,
                                kind: .pickup,
                                selectedTime: dateFrom(hour: day.pickupHour, minute: day.pickupMinute)
                            )
                        }
                        if isInvalidDay(day) {
                            Text("Pickup must be after drop-off")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(10)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .sheet(item: $pickerContext) { context in
            NavigationStack {
                VStack {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { context.selectedTime },
                            set: { updatedTime in
                                pickerContext?.selectedTime = updatedTime
                            }
                        ),
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    Spacer()
                }
                .padding(.top, 12)
                .navigationTitle(context.kind == .dropoff ? "Drop-off time" : "Pickup time")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { pickerContext = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { savePickerSelection() }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func updateDay(_ dayId: UUID, mutate: (inout RoutineDayDraft) -> Void) {
        var updatedChild = child
        guard let index = updatedChild.routine.days.firstIndex(where: { $0.id == dayId }) else { return }
        mutate(&updatedChild.routine.days[index])
        onUpdate(updatedChild)
    }

    private func routineTimeRow(label: String, timeText: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack {
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                Text(timeText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formattedTime(hour: Int, minute: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: dateFrom(hour: hour, minute: minute))
    }

    private func dateFrom(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    private func isInvalidDay(_ day: RoutineDayDraft) -> Bool {
        let dropoffMinutes = day.dropoffHour * 60 + day.dropoffMinute
        let pickupMinutes = day.pickupHour * 60 + day.pickupMinute
        return day.isEnabled && pickupMinutes <= dropoffMinutes
    }

    private func savePickerSelection() {
        guard let context = pickerContext else { return }
        let components = Calendar.current.dateComponents([.hour, .minute], from: context.selectedTime)
        guard let hour = components.hour, let minute = components.minute else {
            pickerContext = nil
            return
        }
        updateDay(context.dayId) { day in
            switch context.kind {
            case .dropoff:
                day.dropoffHour = hour
                day.dropoffMinute = minute
            case .pickup:
                day.pickupHour = hour
                day.pickupMinute = minute
            }
        }
        pickerContext = nil
    }
}

struct OnboardingChildActivitiesStep: View {
    let child: ChildDraft
    let onUpdate: (ChildDraft) -> Void

    @State private var title: String = ""
    @State private var weekday: Weekday = .monday
    @State private var hour: Int = 15
    @State private var minute: Int = 0
    @State private var activityTimeDraft: Date = Date()
    @State private var isTimePickerPresented = false
    @State private var atSchool: Bool = false
    @State private var selectedLocation: ResolvedLocationDraft?
    @StateObject private var activityLocationModel = LocationSearchModel()

    var body: some View {
        OnboardingCard {
            Text("Activities (optional)")
                .font(.system(size: 22, weight: .bold))
            Text("Add recurring activities. Off-school activities require a verified location.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            TextField("Activity name", text: $title)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Picker("Weekday", selection: $weekday) {
                ForEach(Weekday.allCases, id: \.self) { day in
                    Text(day.shortLabel).tag(day)
                }
            }
            .pickerStyle(.segmented)

            Button {
                activityTimeDraft = dateFrom(hour: hour, minute: minute)
                isTimePickerPresented = true
            } label: {
                HStack {
                    Text("Time")
                        .font(.system(size: 15, weight: .medium))
                    Spacer()
                    Text(formattedTime(hour: hour, minute: minute))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Toggle("At school", isOn: $atSchool)
            if !atSchool {
                LocationSearchField(
                    title: "Activity location",
                    placeholder: "Search activity location",
                    model: activityLocationModel
                ) { result in
                    selectedLocation = ResolvedLocationDraft(
                        title: result.title,
                        address: result.fullAddress,
                        latitude: result.latitude,
                        longitude: result.longitude
                    )
                } onCleared: {
                    selectedLocation = nil
                }
            }

            Button("Add activity") {
                addActivity()
            }
            .buttonStyle(.borderedProminent)

            if !child.activities.isEmpty {
                ForEach(child.activities) { activity in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(activity.title)
                                .font(.system(size: 14, weight: .semibold))
                            Text(activitySubtitle(activity))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            removeActivity(activity.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                    .padding(10)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .sheet(isPresented: $isTimePickerPresented) {
            NavigationStack {
                VStack {
                    DatePicker(
                        "",
                        selection: $activityTimeDraft,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    Spacer()
                }
                .padding(.top, 12)
                .navigationTitle("Activity time")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isTimePickerPresented = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let components = Calendar.current.dateComponents([.hour, .minute], from: activityTimeDraft)
                            hour = components.hour ?? hour
                            minute = components.minute ?? minute
                            isTimePickerPresented = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func addActivity() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !atSchool && selectedLocation == nil { return }
        var updated = child
        updated.activities.append(
            ActivityDraft(
                title: trimmed,
                weekday: weekday,
                hour: hour,
                minute: minute,
                atSchool: atSchool,
                location: atSchool ? nil : selectedLocation
            )
        )
        onUpdate(updated)
        title = ""
        atSchool = false
        selectedLocation = nil
        activityLocationModel.clearSelection()
    }

    private func removeActivity(_ id: UUID) {
        var updated = child
        updated.activities.removeAll { $0.id == id }
        onUpdate(updated)
    }

    private func activitySubtitle(_ activity: ActivityDraft) -> String {
        let locationText = activity.atSchool ? "At school" : (activity.location?.title ?? "Location required")
        return "\(activity.weekday.shortLabel) • \(String(format: "%02d:%02d", activity.hour, activity.minute)) • \(locationText)"
    }

    private func formattedTime(hour: Int, minute: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: dateFrom(hour: hour, minute: minute))
    }

    private func dateFrom(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}

struct OnboardingSupportPeopleStep: View {
    @Binding var people: [SupportPersonDraft]
    let onAddInviteMember: () -> Void
    let onRemove: (UUID) -> Void

    var body: some View {
        OnboardingCard {
            Text("Who can help with school runs?")
                .font(.system(size: 22, weight: .bold))
            Text("Optional. You can add more later.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Button("Invite member by email", action: onAddInviteMember)
                .buttonStyle(.borderedProminent)
            ForEach($people) { $person in
                VStack(alignment: .leading, spacing: 10) {
                    inviteMemberFields(person: $person)
                    Button("Remove", role: .destructive) {
                        onRemove(person.id)
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
                .padding(12)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func inviteMemberFields(person: Binding<SupportPersonDraft>) -> some View {
        let baseRelationshipOptions = [
            "Parent / Guardian",
            "Aunt",
            "Uncle",
            "Grandparent",
            "Helper / Nanny",
            "Relative",
            "Other"
        ]
        let currentRelationship = person.wrappedValue.relationshipLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let relationshipOptions: [String]
        if currentRelationship.isEmpty || baseRelationshipOptions.contains(currentRelationship) {
            relationshipOptions = baseRelationshipOptions
        } else {
            relationshipOptions = baseRelationshipOptions + [currentRelationship]
        }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Invite member")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            labeledField("Email") {
                TextField("Email", text: person.email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
            }
            labeledField("Access role") {
                Picker("Access role", selection: person.accessRole) {
                    Text("Organiser").tag("organiser")
                    Text("Driver").tag("driver")
                    Text("Observer").tag("observer")
                }
                .pickerStyle(.segmented)
            }
            labeledField("Relationship") {
                Picker("Relationship", selection: person.relationshipLabel) {
                    ForEach(relationshipOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }
            if !person.wrappedValue.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !isValidEmail(person.wrappedValue.email) {
                Text("Enter a valid email address")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.red)
            }
        }
    }

    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
                .padding(10)
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let regex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return trimmed.range(of: regex, options: .regularExpression) != nil
    }
}

private struct RoutinePickerContext: Identifiable {
    enum Kind {
        case dropoff
        case pickup
    }

    var dayId: UUID
    var kind: Kind
    var selectedTime: Date

    var id: String {
        "\(dayId.uuidString)-\(kind == .dropoff ? "dropoff" : "pickup")"
    }
}

struct OnboardingReviewStep: View {
    let profile: OnboardingProfileDraft
    let tribe: TribeDraft
    let homeLocation: ResolvedLocationDraft?
    let children: [ChildDraft]
    let supportPeople: [SupportPersonDraft]

    var body: some View {
        VStack(spacing: 12) {
            OnboardingCard {
                Text("Review")
                    .font(.system(size: 24, weight: .bold))
                reviewRow("Name", value: displayNameText)
                reviewRow("Tribe", value: tribe.tribeName)
                reviewRow("Home", value: homeLocation?.address ?? "Not set")
            }
            OnboardingCard {
                Text("Children")
                    .font(.system(size: 19, weight: .semibold))
                ForEach(children) { child in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(child.displayName.isEmpty ? "Unnamed child" : child.displayName)
                            .font(.system(size: 15, weight: .semibold))
                        Text(child.school.schoolName.isEmpty ? "School not set" : child.school.schoolName)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Text(child.activities.isEmpty ? "No activities" : "\(child.activities.count) activities")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            if !supportPeople.isEmpty {
                OnboardingCard {
                    Text("Invited members")
                        .font(.system(size: 19, weight: .semibold))
                    ForEach(supportPeople) { person in
                        VStack(alignment: .leading, spacing: 2) {
                            let email = person.email.trimmingCharacters(in: .whitespacesAndNewlines)
                            Text(email.isEmpty ? "Email missing" : email)
                                .font(.system(size: 14, weight: .semibold))
                            Text(displayAccessRole(person.accessRole))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            if !person.relationshipLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(person.relationshipLabel)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var displayNameText: String {
        let display = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !display.isEmpty { return display }
        return [profile.firstName, profile.lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func reviewRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 72, alignment: .leading)
            Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not set" : value)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func displayAccessRole(_ raw: String) -> String {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "organiser":
            return "Organiser"
        case "driver":
            return "Driver"
        case "observer":
            return "Observer"
        default:
            return "Observer"
        }
    }
}

struct OnboardingFinishingStep: View {
    var body: some View {
        OnboardingCard {
            Text("Finishing setup")
                .font(.system(size: 22, weight: .bold))
            Text("Saving your tribe and refreshing your data...")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            ProgressView()
        }
    }
}
