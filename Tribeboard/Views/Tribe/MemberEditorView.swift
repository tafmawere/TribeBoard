import SwiftUI

private enum AdultAccessRole: String, CaseIterable, Identifiable {
    case parentGuardian = "Parent/Guardian"
    case driver = "Driver"
    case helper = "Helper"
    case observer = "Observer"
    case admin = "Admin"

    var id: String { rawValue }
}

struct AddPersonView: View {
    @Environment(\.dismiss) private var dismiss

    let existingMember: TribeMember?
    let defaultType: MemberType
    let onSave: (TribeMember) async -> Bool
    let saveErrorProvider: (() -> String?)?

    @State private var fullName: String
    @State private var relationship: String
    @State private var phone: String
    @State private var memberType: MemberType
    @State private var displayName: String
    @State private var dateOfBirth: Date?
    @State private var schoolName: String
    @State private var schoolAddress: String
    @State private var gradeOrClass: String
    @State private var schoolDays: Set<Weekday>
    @State private var schoolStartTime: DateComponents?
    @State private var schoolEndTime: DateComponents?
    @State private var selectedAdultRoles: Set<AdultAccessRole>
    @State private var showMoreRoles = false
    @State private var isSaving = false
    @State private var saveErrorMessage: String?
    @FocusState private var focusedField: Field?
    @StateObject private var schoolSearchModel = LocationSearchModel()

    private enum Field: Hashable {
        case fullName
        case phone
        case displayName
        case gradeOrClass
        case schoolName
        case schoolAddress
    }

    private let relationshipOptions = ["Mom", "Dad", "Guardian", "Helper", "Other"]

    init(
        existingMember: TribeMember? = nil,
        defaultType: MemberType = .adult,
        onSave: @escaping (TribeMember) async -> Bool,
        saveErrorProvider: (() -> String?)? = nil
    ) {
        self.existingMember = existingMember
        self.defaultType = defaultType
        self.onSave = onSave
        self.saveErrorProvider = saveErrorProvider

        let initialType = existingMember?.memberType ?? defaultType
        let initialRoles = Self.adultAccessRoles(from: existingMember?.roles ?? [])

        _fullName = State(initialValue: existingMember?.fullName ?? "")
        _relationship = State(initialValue: existingMember?.relationship ?? "Guardian")
        _phone = State(initialValue: existingMember?.phone ?? "")
        _memberType = State(initialValue: initialType)
        _displayName = State(initialValue: existingMember?.displayName ?? "")
        _schoolName = State(initialValue: existingMember?.schoolName ?? "")
        _schoolAddress = State(initialValue: existingMember?.schoolAddress ?? "")
        _gradeOrClass = State(initialValue: existingMember?.gradeOrClass ?? "")
        _schoolDays = State(initialValue: existingMember?.schoolDays ?? [.monday, .tuesday, .wednesday, .thursday, .friday])
        _schoolStartTime = State(initialValue: existingMember?.schoolStartTime)
        _schoolEndTime = State(initialValue: existingMember?.schoolEndTime)
        if let existingAge = existingMember?.age,
           let estimatedDob = Calendar.current.date(byAdding: .year, value: -existingAge, to: Date()) {
            _dateOfBirth = State(initialValue: estimatedDob)
        } else {
            _dateOfBirth = State(initialValue: existingMember?.dateOfBirth)
        }
        _selectedAdultRoles = State(initialValue: initialType == .adult ? (initialRoles.isEmpty ? [.parentGuardian] : initialRoles) : [])
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TribeTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        identityCard
                        accessCard
                    }
                    .padding(20)
                    .padding(.bottom, 90)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Add member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            await savePerson()
                        }
                    }
                    .disabled(!isSaveEnabled || isSaving)
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomSaveBar
            }
            .onChange(of: relationship) { _, newValue in
                applySmartDefaults(for: newValue)
            }
            .onChange(of: memberType) { _, newValue in
                if newValue == .child {
                    selectedAdultRoles = []
                } else if selectedAdultRoles.isEmpty {
                    applySmartDefaults(for: relationship)
                    if selectedAdultRoles.isEmpty {
                        selectedAdultRoles = [.parentGuardian]
                    }
                }
            }
            .onChange(of: selectedAdultRoles) { _, newValue in
                if newValue.contains(.admin) && !newValue.contains(.parentGuardian) {
                    selectedAdultRoles.insert(.parentGuardian)
                }
            }
            .alert("Unable to Save", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { newValue in
                    if !newValue { saveErrorMessage = nil }
                }
            )) {
                Button("OK", role: .cancel) {
                    saveErrorMessage = nil
                }
            } message: {
                Text(saveErrorMessage ?? "Save failed.")
            }
        }
    }

    private var identityCard: some View {
        TribeCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Identity")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TribeTheme.textSecondary)

                TextField("Full name", text: $fullName)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .fullName)
                    .tint(TribeTheme.primary)
                    .foregroundStyle(.primary)
                    .modifier(FieldStyle(isFocused: focusedField == .fullName))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Relationship")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TribeTheme.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(relationshipOptions, id: \.self) { option in
                                chipButton(
                                    title: option,
                                    isSelected: relationship == option
                                ) {
                                    relationship = option
                                }
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }

                TextField("Phone (optional)", text: $phone)
                    .keyboardType(.phonePad)
                    .focused($focusedField, equals: .phone)
                    .tint(TribeTheme.primary)
                    .foregroundStyle(.primary)
                    .modifier(FieldStyle(isFocused: focusedField == .phone))
            }
        }
    }

    private var accessCard: some View {
        TribeCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Access")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TribeTheme.textSecondary)

                HStack(spacing: 8) {
                    chipButton(title: "Adult", isSelected: memberType == .adult) {
                        memberType = .adult
                    }
                    chipButton(title: "Child", isSelected: memberType == .child) {
                        memberType = .child
                    }
                }

                if memberType == .child {
                    Text("Basic Info")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TribeTheme.textSecondary)
                    childField("Preferred display name (optional)", text: $displayName, field: .displayName)
                    childField("Grade/Class (optional)", text: $gradeOrClass, field: .gradeOrClass)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date of birth")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TribeTheme.textSecondary)
                        Text("Optional, helps with age-aware planning.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        DatePicker(
                            "Date of birth",
                            selection: dateOfBirthBinding,
                            in: earliestDOB...Date(),
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        if let ageText = derivedChildAgeText {
                            Text(ageText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("School Info")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TribeTheme.textSecondary)
                    LocationSearchField(
                        title: "School Search",
                        placeholder: "Search school",
                        model: schoolSearchModel,
                        onSelected: { result in
                            if schoolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                schoolName = result.title
                            }
                            schoolAddress = result.fullAddress
                        }
                    )
                    childField("School name (optional)", text: $schoolName, field: .schoolName)
                    childField("School address (optional)", text: $schoolAddress, field: .schoolAddress)
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

                    if let age = derivedChildAge, age > 18 {
                        HStack(spacing: 8) {
                            Text("This looks like an adult—switch to Adult?")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            Button("Switch") {
                                memberType = .adult
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TribeTheme.primary)
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TribeTheme.primary)
                        Text("School and activities help Tribeboard plan logistics around your child.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 2)

                    Text("Schedule = repeating plan. Run = actual trip.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Roles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TribeTheme.textSecondary)

                        roleChipGroup(roles: [.parentGuardian, .driver, .helper, .observer])

                        DisclosureGroup("More roles") {
                            roleChipGroup(roles: [.admin])
                                .padding(.top, 8)
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TribeTheme.primary)

                        Text(adultRolesSummary)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }
            }
        }
    }

    private var bottomSaveBar: some View {
        VStack(spacing: 4) {
            Button {
                Task {
                    await savePerson()
                }
            } label: {
                Group {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Save")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(TribeTheme.primary)
                .clipShape(Capsule())
            }
            .disabled(!isSaveEnabled || isSaving)
            .opacity((isSaveEnabled && !isSaving) ? 1 : 0.6)

            if !isSaveEnabled {
                Text("Enter full name to continue.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(TribeTheme.background.ignoresSafeArea())
    }

    private var isSaveEnabled: Bool {
        let hasName = !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasName
    }

    private var adultRolesSummary: String {
        guard !selectedAdultRoles.isEmpty else { return "Select at least one role to define access." }
        if selectedAdultRoles.contains(.admin) { return "Can manage runs and members with elevated access." }
        if selectedAdultRoles.contains(.parentGuardian) && selectedAdultRoles.contains(.driver) { return "Can manage runs and drive scheduled trips." }
        if selectedAdultRoles.contains(.driver) { return "Can drive runs and update trip status." }
        if selectedAdultRoles.contains(.helper) { return "Can help with schedules and family coordination." }
        if selectedAdultRoles.contains(.observer) { return "Can view schedules and track progress." }
        return "Access configured."
    }

    private func chipButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? TribeTheme.primary : TribeTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? TribeTheme.primary.opacity(0.12) : Color.white)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(isSelected ? TribeTheme.primary.opacity(0.5) : Color.black.opacity(0.08), lineWidth: 1)
                }
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func roleChipGroup(roles: [AdultAccessRole]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
            ForEach(roles) { role in
                chipButton(
                    title: role.rawValue,
                    isSelected: selectedAdultRoles.contains(role)
                ) {
                    toggleAdultRole(role)
                }
            }
        }
    }

    private func toggleAdultRole(_ role: AdultAccessRole) {
        if selectedAdultRoles.contains(role) {
            selectedAdultRoles.remove(role)
        } else {
            selectedAdultRoles.insert(role)
        }

        if role == .admin && selectedAdultRoles.contains(.admin) {
            selectedAdultRoles.insert(.parentGuardian)
        }
    }

    private func applySmartDefaults(for relationship: String) {
        guard memberType == .adult else { return }

        if ["Mom", "Dad", "Guardian"].contains(relationship) {
            selectedAdultRoles = [.parentGuardian]
        } else if relationship == "Helper" {
            selectedAdultRoles = [.helper]
        }
    }

    private func savePerson() async {
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        print("[AddPersonView] Save tapped for memberType=\(memberType.rawValue), existingMember=\(existingMember != nil)")

        var roles: Set<Role>
        if memberType == .child {
            roles = [.child, .passenger]
        } else {
            roles = [.parent]
            if selectedAdultRoles.contains(.parentGuardian) { roles.insert(.observer) }
            if selectedAdultRoles.contains(.driver) { roles.insert(.driver) }
            if selectedAdultRoles.contains(.helper) { roles.insert(.observer) }
            if selectedAdultRoles.contains(.observer) { roles.insert(.observer) }
            if selectedAdultRoles.contains(.admin) {
                roles.insert(.admin)
                roles.insert(.parent)
            }
        }

        let trimmedRelationship = relationship.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let member = TribeMember(
            id: existingMember?.id ?? UUID(),
            fullName: trimmedName,
            memberType: memberType,
            relationship: trimmedRelationship.isEmpty ? nil : trimmedRelationship,
            dateOfBirth: memberType == .child ? dateOfBirth : nil,
            displayName: memberType == .child ? displayName.nilIfEmpty : nil,
            schoolName: memberType == .child ? schoolName.nilIfEmpty : nil,
            schoolAddress: memberType == .child ? schoolAddress.nilIfEmpty : nil,
            gradeOrClass: memberType == .child ? gradeOrClass.nilIfEmpty : nil,
            schoolStartTime: memberType == .child ? schoolStartTime : nil,
            schoolEndTime: memberType == .child ? schoolEndTime : nil,
            schoolDays: memberType == .child ? (schoolDays.isEmpty ? nil : schoolDays) : nil,
            activities: existingMember?.activities ?? [],
            phone: trimmedPhone.isEmpty ? nil : trimmedPhone,
            roles: roles,
            isLocationSharingEnabled: existingMember?.isLocationSharingEnabled ?? true,
            isOnline: existingMember?.isOnline ?? false
        )

        await MainActor.run {
            isSaving = true
            saveErrorMessage = nil
        }
        let didSave = await onSave(member)
        print("[AddPersonView] Save result didSave=\(didSave)")
        await MainActor.run {
            isSaving = false
            if didSave {
                dismiss()
            } else {
                let backendMessage = saveErrorProvider?()?.trimmingCharacters(in: .whitespacesAndNewlines)
                saveErrorMessage = (backendMessage?.isEmpty == false) ? backendMessage : "Backend save failed. Please try again."
            }
        }
    }

    private static func adultAccessRoles(from roles: Set<Role>) -> Set<AdultAccessRole> {
        var mapped: Set<AdultAccessRole> = []
        if roles.contains(.parent) { mapped.insert(.parentGuardian) }
        if roles.contains(.driver) { mapped.insert(.driver) }
        if roles.contains(.observer) { mapped.insert(.observer) }
        if roles.contains(.admin) {
            mapped.insert(.admin)
            mapped.insert(.parentGuardian)
        }
        return mapped
    }

    private var earliestDOB: Date {
        Calendar.current.date(byAdding: .year, value: -120, to: Date()) ?? Date.distantPast
    }

    private var dateOfBirthBinding: Binding<Date> {
        Binding<Date>(
            get: {
                dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -8, to: Date()) ?? Date()
            },
            set: { newValue in
                dateOfBirth = newValue
            }
        )
    }

    private var derivedChildAge: Int? {
        guard let dateOfBirth else { return nil }
        return age(from: dateOfBirth)
    }

    private var derivedChildAgeText: String? {
        guard let age = derivedChildAge else { return nil }
        let suffix = age == 1 ? "year" : "years"
        return "\(age) \(suffix) old"
    }

    private func age(from dateOfBirth: Date) -> Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }

    private func childField(_ title: String, text: Binding<String>, field: Field) -> some View {
        TextField(title, text: text)
            .focused($focusedField, equals: field)
            .tint(TribeTheme.primary)
            .foregroundStyle(.primary)
            .modifier(FieldStyle(isFocused: focusedField == field))
    }

    private var schoolStartTimeBinding: Binding<Date> {
        Binding(
            get: {
                let fallback = DateComponents(hour: 7, minute: 45)
                return Calendar.current.date(from: schoolStartTime ?? fallback) ?? Date()
            },
            set: {
                schoolStartTime = Calendar.current.dateComponents([.hour, .minute], from: $0)
            }
        )
    }

    private var schoolEndTimeBinding: Binding<Date> {
        Binding(
            get: {
                let fallback = DateComponents(hour: 13, minute: 45)
                return Calendar.current.date(from: schoolEndTime ?? fallback) ?? Date()
            },
            set: {
                schoolEndTime = Calendar.current.dateComponents([.hour, .minute], from: $0)
            }
        )
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
                .foregroundStyle(selected ? .white : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selected ? TribeTheme.primary : Color(uiColor: .tertiarySystemBackground))
                .clipShape(Capsule())
                .buttonStyle(.plain)
            }
        }
    }
}

private struct FieldStyle: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(uiColor: .tertiarySystemBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isFocused ? TribeTheme.primary.opacity(0.7) : Color(uiColor: .separator).opacity(0.35),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// Backward-compatible wrapper so existing references still compile.
struct MemberEditorView: View {
    let existingMember: TribeMember?
    let defaultType: MemberType
    let onSave: (TribeMember) async -> Bool
    let saveErrorProvider: (() -> String?)?

    init(
        existingMember: TribeMember? = nil,
        defaultType: MemberType = .adult,
        onSave: @escaping (TribeMember) async -> Bool,
        saveErrorProvider: (() -> String?)? = nil
    ) {
        self.existingMember = existingMember
        self.defaultType = defaultType
        self.onSave = onSave
        self.saveErrorProvider = saveErrorProvider
    }

    var body: some View {
        AddPersonView(
            existingMember: existingMember,
            defaultType: defaultType,
            onSave: onSave,
            saveErrorProvider: saveErrorProvider
        )
    }
}

#Preview {
    AddPersonView { _ in true }
}
