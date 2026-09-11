import SwiftUI

struct FastFamilySetupWizardView: View {
    @EnvironmentObject private var flow: AppFlowState
    @StateObject private var state = FastFamilySetupWizardState()

    @State private var activityTitle: String = ""
    @State private var activityWeekday: Weekday = .monday
    @State private var activityHour: Int = 15
    @State private var activityMinute: Int = 0
    @State private var activityLocation: String = ""
    @State private var activityAtSchool: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                progressHeader
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        stepContent
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 24)
                }

                footerActions
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .navigationTitle(state.step.title)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await state.bootstrap()
            }
            .alert("Setup issue", isPresented: Binding(
                get: { state.errorMessage != nil },
                set: { if !$0 { state.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { state.errorMessage = nil }
            } message: {
                Text(state.errorMessage ?? "Unable to continue.")
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Step \(state.step.rawValue + 1) of \(state.totalSteps)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            GeometryReader { proxy in
                let total = CGFloat(max(1, state.totalSteps))
                let progress = CGFloat(state.step.rawValue + 1) / total
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemFill))
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.indigo)
                        .frame(width: max(8, proxy.size.width * progress))
                }
            }
            .frame(height: 8)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch state.step {
        case .welcome:
            wizardCard {
                Text("Fast family setup")
                    .font(.system(size: 28, weight: .bold))
                Text("We will get your family, first child, school routine, and optional helpers configured in a few quick steps.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
        case .familyPath:
            familyPathStep
        case .addChild:
            addChildStep
        case .school:
            schoolStep
        case .routine:
            routineStep
        case .activities:
            activitiesStep
        case .assignment:
            assignmentStep
        case .review:
            reviewStep
        }
    }

    private var familyPathStep: some View {
        VStack(spacing: 12) {
            if state.hasExistingHousehold {
                wizardCard {
                    Text("You are already in a household.")
                        .font(.system(size: 17, weight: .semibold))
                    Text(state.existingHouseholdName ?? "Active household detected")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("This step is auto-skipped for setup.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            } else {
                wizardCard {
                    Text("Create or join a family")
                        .font(.system(size: 21, weight: .bold))
                    Picker("Family path", selection: $state.familyPathChoice) {
                        Text("Create").tag(FastFamilyPathChoice.create)
                        Text("Join").tag(FastFamilyPathChoice.join)
                    }
                    .pickerStyle(.segmented)
                    if state.familyPathChoice == .create {
                        TextField("Family name", text: $state.familyName)
                            .textInputAutocapitalization(.words)
                            .padding(12)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        TextField("Family code (e.g. H-XXXXXXXX)", text: $state.joinCode)
                            .textInputAutocapitalization(.characters)
                            .padding(12)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }

    private var addChildStep: some View {
        wizardCard {
            Text("Add first child")
                .font(.system(size: 21, weight: .bold))

            TextField("Display name", text: $state.childDisplayName)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            TextField("Legal name (optional)", text: $state.childLegalName)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            DatePicker(
                "Date of birth (optional)",
                selection: Binding(
                    get: { state.childDateOfBirth ?? Calendar.current.date(byAdding: .year, value: -8, to: Date()) ?? Date() },
                    set: { state.childDateOfBirth = $0 }
                ),
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)

            TextField("Grade / class", text: $state.childGradeOrClass)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var schoolStep: some View {
        wizardCard {
            Text("School")
                .font(.system(size: 21, weight: .bold))

            TextField("Search existing school", text: $state.schoolSearchQuery)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if !state.filteredSchoolSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggestions")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(state.filteredSchoolSuggestions) { suggestion in
                        Button {
                            state.selectSchoolSuggestion(suggestion)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.schoolName)
                                        .font(.system(size: 14, weight: .semibold))
                                    if let address = suggestion.schoolAddress {
                                        Text(address)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            TextField("School name", text: $state.schoolName)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            TextField("Address / location", text: $state.schoolAddress)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack {
                Text("Default start")
                Spacer()
                TimeWheel(hour: $state.schoolStartHour, minute: $state.schoolStartMinute)
            }
            HStack {
                Text("Default end")
                Spacer()
                TimeWheel(hour: $state.schoolEndHour, minute: $state.schoolEndMinute)
            }
        }
    }

    private var routineStep: some View {
        wizardCard {
            Text("Weekly school routine")
                .font(.system(size: 21, weight: .bold))
            Text("Mon-Fri defaults are enabled. Edit any day as needed.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            ForEach(state.routineDays) { day in
                VStack(spacing: 8) {
                    HStack {
                        Toggle(day.weekday.shortLabel, isOn: Binding(
                            get: { day.isEnabled },
                            set: { state.setRoutineDayEnabled(day.id, enabled: $0) }
                        ))
                    }
                    if day.isEnabled {
                        HStack {
                            Text("Start")
                            Spacer()
                            TimeWheel(
                                hour: Binding(
                                    get: { day.startHour },
                                    set: { state.updateRoutineDayTime(day.id, startHour: $0, startMinute: day.startMinute, endHour: day.endHour, endMinute: day.endMinute) }
                                ),
                                minute: Binding(
                                    get: { day.startMinute },
                                    set: { state.updateRoutineDayTime(day.id, startHour: day.startHour, startMinute: $0, endHour: day.endHour, endMinute: day.endMinute) }
                                )
                            )
                        }
                        HStack {
                            Text("End")
                            Spacer()
                            TimeWheel(
                                hour: Binding(
                                    get: { day.endHour },
                                    set: { state.updateRoutineDayTime(day.id, startHour: day.startHour, startMinute: day.startMinute, endHour: $0, endMinute: day.endMinute) }
                                ),
                                minute: Binding(
                                    get: { day.endMinute },
                                    set: { state.updateRoutineDayTime(day.id, startHour: day.startHour, startMinute: day.startMinute, endHour: day.endHour, endMinute: $0) }
                                )
                            )
                        }
                    }
                }
                .padding(10)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var activitiesStep: some View {
        wizardCard {
            Text("Activities (optional)")
                .font(.system(size: 21, weight: .bold))

            TextField("Activity title", text: $activityTitle)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Picker("Weekday", selection: $activityWeekday) {
                ForEach(Weekday.allCases, id: \.self) { day in
                    Text(day.shortLabel).tag(day)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Time")
                Spacer()
                TimeWheel(hour: $activityHour, minute: $activityMinute)
            }

            Toggle("At school", isOn: $activityAtSchool)
            if !activityAtSchool {
                TextField("Location", text: $activityLocation)
                    .textInputAutocapitalization(.words)
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Button("Add activity") {
                state.addActivity(
                    title: activityTitle,
                    weekday: activityWeekday,
                    hour: activityHour,
                    minute: activityMinute,
                    location: activityLocation,
                    atSchool: activityAtSchool
                )
                activityTitle = ""
                activityLocation = ""
                activityAtSchool = false
            }
            .buttonStyle(.borderedProminent)

            if !state.activities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Saved activities")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(state.activities) { activity in
                        HStack {
                            Text("\(activity.title) • \(activity.weekday.shortLabel)")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Button(role: .destructive) {
                                state.removeActivity(activity.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                        .padding(8)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }

    private var assignmentStep: some View {
        wizardCard {
            Text("Driver/helper assignment (optional)")
                .font(.system(size: 21, weight: .bold))

            if !state.memberOptions.isEmpty {
                Picker("Existing member", selection: $state.selectedMemberId) {
                    Text("None").tag(UUID?.none)
                    ForEach(state.memberOptions) { member in
                        Text(member.displayName).tag(UUID?.some(member.id))
                    }
                }
            }

            if !state.personOptions.isEmpty {
                Picker("Existing household person", selection: $state.selectedPersonId) {
                    Text("None").tag(UUID?.none)
                    ForEach(state.personOptions) { person in
                        Text(person.name).tag(UUID?.some(person.id))
                    }
                }
            }

            Divider()

            Text("Add new household person")
                .font(.system(size: 14, weight: .semibold))

            TextField("Name", text: $state.newPersonName)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            TextField("Relationship", text: $state.newPersonRelationship)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Picker("Role suggestion", selection: $state.newPersonRoleSuggestion) {
                ForEach(FastRoleSuggestion.allCases) { role in
                    Text(role.rawValue.capitalized).tag(role)
                }
            }
            .pickerStyle(.segmented)

            TextField("Phone (optional)", text: $state.newPersonPhone)
                .keyboardType(.phonePad)
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var reviewStep: some View {
        wizardCard {
            Text("Review and finish")
                .font(.system(size: 24, weight: .bold))

            summaryRow("Child", state.childDisplayName)
            summaryRow("School", state.schoolName)
            summaryRow("Routine days", "\(state.routineDays.filter { $0.isEnabled }.count)")
            summaryRow("Activities", "\(state.activities.count)")
            summaryRow("Assigned member", assignedMemberName)
            summaryRow("Assigned person", assignedPersonName)

            Text("Finish will persist to backend, then open your main app with refreshed household data.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var footerActions: some View {
        VStack(spacing: 10) {
            if state.step != .welcome {
                Button("Back") {
                    state.goBack()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            }

            if state.step == .review {
                Button {
                    Task {
                        _ = await state.complete(flow: flow)
                    }
                } label: {
                    if state.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Text("Finish setup")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(Color.indigo)
                .clipShape(Capsule())
            } else {
                Button {
                    Task { await state.goNext() }
                } label: {
                    Text(primaryCTA(for: state.step))
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(state.canMoveForward ? Color.indigo : Color.gray)
                .clipShape(Capsule())
                .disabled(!state.canMoveForward || state.isLoading)

                if state.step == .activities || state.step == .assignment {
                    Button("Skip for now") {
                        Task { await state.goNext() }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func primaryCTA(for step: FastFamilySetupStep) -> String {
        switch step {
        case .welcome: return "Start setup"
        case .familyPath: return state.hasExistingHousehold ? "Continue" : "Save and continue"
        case .addChild: return "Continue to school"
        case .school: return "Continue to routine"
        case .routine: return "Continue to activities"
        case .activities: return "Continue"
        case .assignment: return "Continue to review"
        case .review: return "Finish setup"
        }
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 14, weight: .semibold))
        }
    }

    private var assignedMemberName: String {
        guard let selectedMemberId = state.selectedMemberId,
              let member = state.memberOptions.first(where: { $0.id == selectedMemberId }) else {
            return "None"
        }
        return member.displayName
    }

    private var assignedPersonName: String {
        guard let selectedPersonId = state.selectedPersonId,
              let person = state.personOptions.first(where: { $0.id == selectedPersonId }) else {
            return "None"
        }
        return person.name
    }

    private func wizardCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct TimeWheel: View {
    @Binding var hour: Int
    @Binding var minute: Int

    var body: some View {
        HStack(spacing: 6) {
            Picker("Hour", selection: $hour) {
                ForEach(0..<24, id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .labelsHidden()
            .frame(width: 70, height: 80)
            .clipped()

            Text(":")
                .font(.system(size: 16, weight: .bold))

            Picker("Minute", selection: $minute) {
                ForEach([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .labelsHidden()
            .frame(width: 70, height: 80)
            .clipped()
        }
    }
}

#Preview {
    FastFamilySetupWizardView()
        .environmentObject(AppFlowState())
}
