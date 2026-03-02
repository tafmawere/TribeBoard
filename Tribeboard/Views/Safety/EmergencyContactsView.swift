import SwiftUI

struct EmergencyContactsView: View {
    @State private var contacts: [EmergencyContact] = [
        EmergencyContact(name: "Rudo Mawere", relation: "Parent", phone: "+1 (555) 017-9812"),
        EmergencyContact(name: "Blessing Dube", relation: "Neighbor", phone: "+1 (555) 017-2244")
    ]

    @State private var draftContact = EmergencyContact.empty
    @State private var editingIndex: Int?
    @State private var showingEditor = false
    @State private var pendingDeleteIndex: Int?

    var body: some View {
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

            Section("Contacts") {
                if contacts.isEmpty {
                    Text("No emergency contacts yet.")
                        .font(.system(size: 14))
                        .foregroundStyle(SafetyTheme.textSecondary)
                } else {
                    ForEach(contacts.indices, id: \.self) { index in
                        contactRow(for: index)
                    }
                    .onDelete(perform: requestDelete)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(SafetyTheme.background)
        .navigationTitle("Emergency Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    startAdd()
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            contactEditorSheet
        }
        .alert("Delete contact?", isPresented: deleteAlertBinding) {
            Button("Delete", role: .destructive) {
                confirmDelete()
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteIndex = nil
            }
        } message: {
            Text("This removes the contact from your list in this demo UI.")
        }
    }

    private func contactRow(for index: Int) -> some View {
        let contact = contacts[index]
        return HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(SafetyTheme.tint.opacity(0.14))
                .frame(width: 38, height: 38)
                .overlay {
                    Text(contact.initials)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(SafetyTheme.tint)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SafetyTheme.textPrimary)
                Text(contact.relation)
                    .font(.system(size: 13))
                    .foregroundStyle(SafetyTheme.textSecondary)
                Text(contact.phone)
                    .font(.system(size: 13))
                    .foregroundStyle(SafetyTheme.textSecondary)
            }

            Spacer()

            Button("Edit") {
                startEdit(at: index)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(SafetyTheme.tint)
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var contactEditorSheet: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $draftContact.name)
                    TextField("Relation", text: $draftContact.relation)
                    TextField("Phone", text: $draftContact.phone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle(editingIndex == nil ? "Add Contact" : "Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingEditor = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveDraft()
                    }
                    .disabled(!draftContact.isValid)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteIndex != nil },
            set: { newValue in
                if !newValue {
                    pendingDeleteIndex = nil
                }
            }
        )
    }

    private func startAdd() {
        editingIndex = nil
        draftContact = .empty
        showingEditor = true
    }

    private func startEdit(at index: Int) {
        guard contacts.indices.contains(index) else { return }
        editingIndex = index
        draftContact = contacts[index]
        showingEditor = true
    }

    private func saveDraft() {
        let cleaned = draftContact.cleaned
        if let editingIndex, contacts.indices.contains(editingIndex) {
            contacts[editingIndex] = cleaned
        } else {
            contacts.append(cleaned)
        }
        showingEditor = false
    }

    private func requestDelete(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        pendingDeleteIndex = index
    }

    private func confirmDelete() {
        guard let index = pendingDeleteIndex, contacts.indices.contains(index) else { return }
        contacts.remove(at: index)
        pendingDeleteIndex = nil
    }
}

private struct EmergencyContact: Equatable {
    var name: String
    var relation: String
    var phone: String

    static let empty = EmergencyContact(name: "", relation: "", phone: "")

    var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }.map { String($0) }
        if letters.isEmpty { return "?" }
        return letters.joined().uppercased()
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !relation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var cleaned: EmergencyContact {
        EmergencyContact(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            relation: relation.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

#Preview {
    NavigationStack {
        EmergencyContactsView()
    }
}
