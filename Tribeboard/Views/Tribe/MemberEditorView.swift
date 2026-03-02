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
    let onSave: (TribeMember) -> Void

    @State private var fullName: String
    @State private var relationship: String
    @State private var phone: String
    @State private var memberType: MemberType
    @State private var nickname: String
    @State private var dateOfBirth: Date?
    @State private var selectedAdultRoles: Set<AdultAccessRole>
    @State private var showMoreRoles = false

    private let relationshipOptions = ["Mom", "Dad", "Guardian", "Helper", "Other"]

    init(
        existingMember: TribeMember? = nil,
        defaultType: MemberType = .adult,
        onSave: @escaping (TribeMember) -> Void
    ) {
        self.existingMember = existingMember
        self.defaultType = defaultType
        self.onSave = onSave

        let initialType = existingMember?.memberType ?? defaultType
        let initialRoles = Self.adultAccessRoles(from: existingMember?.roles ?? [])

        _fullName = State(initialValue: existingMember?.fullName ?? "")
        _relationship = State(initialValue: existingMember?.relationship ?? "Guardian")
        _phone = State(initialValue: existingMember?.phone ?? "")
        _memberType = State(initialValue: initialType)
        _nickname = State(initialValue: "")
        if let existingAge = existingMember?.age,
           let estimatedDob = Calendar.current.date(byAdding: .year, value: -existingAge, to: Date()) {
            _dateOfBirth = State(initialValue: estimatedDob)
        } else {
            _dateOfBirth = State(initialValue: nil)
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
                        savePerson()
                    }
                    .disabled(!isSaveEnabled)
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
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

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
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                    TextField("Nickname (optional)", text: $nickname)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Date of birth")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(TribeTheme.textPrimary)
                            Text("(required)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

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
                        .background(Color.white)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        if let age = derivedChildAge {
                            Text("Age: \(age) years")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }

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
                        Text("Child is a Passenger by default.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 2)
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
                savePerson()
            } label: {
                Text("Save")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(TribeTheme.primary)
                    .clipShape(Capsule())
            }
            .disabled(!isSaveEnabled)
            .opacity(isSaveEnabled ? 1 : 0.6)

            if !isSaveEnabled {
                Text(memberType == .child ? "Enter full name and date of birth to continue." : "Enter full name to continue.")
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
        if memberType == .child {
            return hasName && dateOfBirth != nil
        }
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

    private func savePerson() {
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

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
            phone: trimmedPhone.isEmpty ? nil : trimmedPhone,
            roles: roles,
            isLocationSharingEnabled: existingMember?.isLocationSharingEnabled ?? true,
            isOnline: existingMember?.isOnline ?? false
        )

        onSave(member)
        dismiss()
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

    private func age(from dateOfBirth: Date) -> Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }
}

// Backward-compatible wrapper so existing references still compile.
struct MemberEditorView: View {
    let existingMember: TribeMember?
    let defaultType: MemberType
    let onSave: (TribeMember) -> Void

    init(
        existingMember: TribeMember? = nil,
        defaultType: MemberType = .adult,
        onSave: @escaping (TribeMember) -> Void
    ) {
        self.existingMember = existingMember
        self.defaultType = defaultType
        self.onSave = onSave
    }

    var body: some View {
        AddPersonView(existingMember: existingMember, defaultType: defaultType, onSave: onSave)
    }
}

#Preview {
    AddPersonView { _ in }
}
