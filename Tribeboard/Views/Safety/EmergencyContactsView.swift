import SwiftUI

struct EmergencyContactsView: View {
    @EnvironmentObject private var backendEmergencyContactsContext: BackendEmergencyContactsContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext

    @State private var draft = EmergencyContactDraft.empty
    @State private var editingContactId: UUID?
    @State private var showingEditor = false
    @State private var showingDeleteConfirmation = false
    @State private var isSaving = false

    private var canManageContacts: Bool {
        backendHouseholdContext.isCurrentUserOrganiser
    }

    private var contacts: [BackendEmergencyContact] {
        backendEmergencyContactsContext.contacts
    }

    var body: some View {
        Group {
            if backendEmergencyContactsContext.isLoading && contacts.isEmpty {
                loadingView
            } else if let error = backendEmergencyContactsContext.lastError, contacts.isEmpty {
                errorView(message: error)
            } else {
                contactsList
            }
        }
        .background(SafetyTheme.background)
        .navigationTitle("Emergency Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canManageContacts {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startAdd()
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .disabled(backendEmergencyContactsContext.isLoading)
                }
            }
        }
        .task {
            await backendEmergencyContactsContext.refreshForActiveHousehold()
        }
        .refreshable {
            await backendEmergencyContactsContext.refreshForActiveHousehold()
        }
        .sheet(isPresented: $showingEditor) {
            contactEditorSheet
        }
        .alert("Delete contact?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await confirmDelete() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the contact from your household emergency list.")
        }
    }

    private var contactsList: some View {
        List {
            Section {
                SafetyInfoCard(
                    iconName: "cross.case.fill",
                    title: "Emergency contact list",
                    detail: "Add trusted contacts your family can quickly reach during runs.",
                    accent: SafetyTheme.danger
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if contacts.isEmpty {
                Section {
                    emptyState
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            } else {
                Section("Contacts") {
                    ForEach(contacts) { contact in
                        contactRow(contact)
                    }
                }

                if let error = backendEmergencyContactsContext.lastError {
                    Section {
                        inlineErrorBanner(message: error)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .overlay {
            if backendEmergencyContactsContext.isLoading && !contacts.isEmpty {
                ProgressView()
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(SafetyTheme.tint.opacity(0.7))

            VStack(spacing: 6) {
                Text("No emergency contacts yet")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(SafetyTheme.textPrimary)
                Text("Add trusted people your family can reach during runs.")
                    .font(.system(size: 14))
                    .foregroundStyle(SafetyTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if canManageContacts {
                SafetyPrimaryButton(title: "Add Contact") {
                    startAdd()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 8)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading emergency contacts…")
                .font(.system(size: 14))
                .foregroundStyle(SafetyTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(SafetyTheme.warning)
            Text("Couldn’t load contacts")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SafetyTheme.textPrimary)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(SafetyTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            SafetyPrimaryButton(title: "Try Again") {
                Task {
                    await backendEmergencyContactsContext.refreshForActiveHousehold()
                }
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func inlineErrorBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(SafetyTheme.warning)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(SafetyTheme.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(SafetyTheme.warning.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func contactRow(_ contact: BackendEmergencyContact) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(SafetyTheme.tint.opacity(0.14))
                .frame(width: 38, height: 38)
                .overlay {
                    Text(contact.initials)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(SafetyTheme.tint)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(contact.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(SafetyTheme.textPrimary)
                    if contact.canPickUpChild {
                        SafetyBadge(text: "Pickup OK", color: SafetyTheme.success)
                    }
                }
                if let relationship = contact.relationship, !relationship.isEmpty {
                    Text(relationship)
                        .font(.system(size: 13))
                        .foregroundStyle(SafetyTheme.textSecondary)
                }
                Text(contact.phone)
                    .font(.system(size: 13))
                    .foregroundStyle(SafetyTheme.textSecondary)
                if let email = contact.email, !email.isEmpty {
                    Text(email)
                        .font(.system(size: 13))
                        .foregroundStyle(SafetyTheme.textSecondary)
                }
            }

            Spacer()

            if canManageContacts {
                Button("Edit") {
                    startEdit(contact)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SafetyTheme.tint)
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var contactEditorSheet: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $draft.name)
                        .textContentType(.name)
                    TextField("Relationship", text: $draft.relationship)
                    TextField("Phone", text: $draft.phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    TextField("Email", text: $draft.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    Toggle("Can pick up child", isOn: $draft.canPickUpChild)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if editingContactId != nil {
                    Section {
                        Button("Delete Contact", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .navigationTitle(editingContactId == nil ? "Add Contact" : "Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingEditor = false
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveDraft() }
                    }
                    .disabled(!draft.isValid || isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView()
                        .padding(16)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(isSaving)
    }

    private func startAdd() {
        editingContactId = nil
        draft = .empty
        showingEditor = true
    }

    private func startEdit(_ contact: BackendEmergencyContact) {
        editingContactId = contact.id
        draft = EmergencyContactDraft(contact: contact)
        showingEditor = true
    }

    private func saveDraft() async {
        guard draft.isValid else { return }
        isSaving = true
        defer { isSaving = false }

        let cleaned = draft.cleaned
        let success: Bool
        if let editingContactId, var existing = backendEmergencyContactsContext.contact(for: editingContactId) {
            existing.name = cleaned.name
            existing.relationship = cleaned.relationship.nilIfEmpty
            existing.phone = cleaned.phone
            existing.email = cleaned.email.nilIfEmpty
            existing.canPickUpChild = cleaned.canPickUpChild
            existing.notes = cleaned.notes.nilIfEmpty
            success = await backendEmergencyContactsContext.updateContact(existing)
        } else {
            success = await backendEmergencyContactsContext.createContact(
                name: cleaned.name,
                relationship: cleaned.relationship.nilIfEmpty,
                phone: cleaned.phone,
                email: cleaned.email.nilIfEmpty,
                canPickUpChild: cleaned.canPickUpChild,
                notes: cleaned.notes.nilIfEmpty
            )
        }

        if success {
            showingEditor = false
        }
    }

    private func confirmDelete() async {
        guard let editingContactId else { return }
        isSaving = true
        defer { isSaving = false }
        let success = await backendEmergencyContactsContext.deleteContact(id: editingContactId)
        if success {
            showingEditor = false
            self.editingContactId = nil
        }
    }
}

private struct EmergencyContactDraft: Equatable {
    var name: String
    var relationship: String
    var phone: String
    var email: String
    var canPickUpChild: Bool
    var notes: String

    static let empty = EmergencyContactDraft(
        name: "",
        relationship: "",
        phone: "",
        email: "",
        canPickUpChild: false,
        notes: ""
    )

    init(
        name: String,
        relationship: String,
        phone: String,
        email: String,
        canPickUpChild: Bool,
        notes: String
    ) {
        self.name = name
        self.relationship = relationship
        self.phone = phone
        self.email = email
        self.canPickUpChild = canPickUpChild
        self.notes = notes
    }

    init(contact: BackendEmergencyContact) {
        self.name = contact.name
        self.relationship = contact.relationship ?? ""
        self.phone = contact.phone
        self.email = contact.email ?? ""
        self.canPickUpChild = contact.canPickUpChild
        self.notes = contact.notes ?? ""
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var cleaned: EmergencyContactDraft {
        EmergencyContactDraft(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            relationship: relationship.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            canPickUpChild: canPickUpChild,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    let activeHouseholdStore = ActiveHouseholdStore()
    NavigationStack {
        EmergencyContactsView()
            .environmentObject(BackendEmergencyContactsContext(activeHouseholdStore: activeHouseholdStore))
            .environmentObject(
                BackendHouseholdContext(
                    localHouseholdContext: ActiveHouseholdContext(),
                    localHouseholdDataSource: HouseholdDataSource(
                        repository: LocalHouseholdRepository(),
                        activeContext: ActiveHouseholdContext(),
                        syncCoordinator: nil
                    ),
                    activeHouseholdStore: activeHouseholdStore
                )
            )
    }
}
