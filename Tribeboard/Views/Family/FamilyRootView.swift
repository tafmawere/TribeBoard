import SwiftUI
import UIKit

struct FamilyRootView: View {
    @StateObject private var store = TribeStore()
    @State private var selectedMemberID: UUID?
    @State private var isPresentingAddMember = false

    var body: some View {
        Group {
            if store.tribe == nil {
                FamilyCreateTribeView(store: store)
            } else {
                FamilyMembersListView(
                    store: store,
                    onSelectMember: { selectedMemberID = $0.id }
                )
            }
        }
        .navigationTitle("Family")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if store.tribe != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        isPresentingAddMember = true
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingAddMember) {
            FamilyAddMemberView(store: store)
        }
        .navigationDestination(item: selectedMemberBinding) { memberID in
            FamilyMemberDetailView(store: store, memberID: memberID)
        }
        .task {
            seedDemoDataIfNeeded()
        }
    }

    private var selectedMemberBinding: Binding<UUID?> {
        Binding(
            get: { selectedMemberID },
            set: { selectedMemberID = $0 }
        )
    }

    private func seedDemoDataIfNeeded() {
        guard AppConfig.isDemoFlowEnabled else { return }
        guard store.tribe == nil, store.members.isEmpty else { return }

        store.createTribe(name: "Mawere Tribe", tribeCode: "TRIBE-MWR1")
        for member in FamilySeed.members where !store.members.contains(where: { $0.id == member.id }) {
            store.addMember(member)
        }
    }
}

private enum FamilySeed {
    static let members: [TribeMember] = [
        TribeMember(
            id: UUID(uuidString: "A1111111-1111-1111-1111-111111111111") ?? UUID(),
            fullName: "Rue Mawere",
            memberType: .adult,
            relationship: "Parent",
            phone: "+263 77 100 0001",
            roles: [.parent, .admin, .observer],
            isLocationSharingEnabled: true,
            isOnline: true
        ),
        TribeMember(
            id: UUID(uuidString: "B2222222-2222-2222-2222-222222222222") ?? UUID(),
            fullName: "Tafadzwa Mawere",
            memberType: .adult,
            relationship: "Parent",
            phone: "+263 77 100 0002",
            roles: [.parent, .admin, .driver],
            isLocationSharingEnabled: true,
            isOnline: true
        ),
        TribeMember(
            id: UUID(uuidString: "C3333333-3333-3333-3333-333333333333") ?? UUID(),
            fullName: "TJ",
            memberType: .child,
            age: 10,
            roles: [.child, .passenger],
            isLocationSharingEnabled: true,
            isOnline: false
        ),
        TribeMember(
            id: UUID(uuidString: "D4444444-4444-4444-4444-444444444444") ?? UUID(),
            fullName: "Tawana",
            memberType: .child,
            age: 8,
            roles: [.child, .passenger],
            isLocationSharingEnabled: true,
            isOnline: false
        )
    ]
}

private struct FamilyCreateTribeView: View {
    @ObservedObject var store: TribeStore
    @State private var tribeName = ""
    @State private var homeAddress = ""

    var body: some View {
        Form {
            Section("Create Tribe") {
                TextField("Tribe name", text: $tribeName)
                TextField("Home address (optional)", text: $homeAddress)
            }

            Section {
                Button("Create Tribe") {
                    store.createTribe(name: tribeName, tribeCode: nil)
                }
                .disabled(tribeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

private struct FamilyMembersListView: View {
    @ObservedObject var store: TribeStore
    let onSelectMember: (TribeMember) -> Void
    @State private var didCopyInviteCode = false

    private var allMembersSorted: [TribeMember] {
        store.members.sorted { $0.fullName < $1.fullName }
    }

    private var admins: [TribeMember] {
        store.members
            .filter { $0.roles.contains(.admin) }
            .sorted { $0.fullName < $1.fullName }
    }

    private var parents: [TribeMember] {
        store.members
            .filter { $0.memberType == .adult && !$0.roles.contains(.admin) }
            .sorted { $0.fullName < $1.fullName }
    }

    private var children: [TribeMember] {
        store.members
            .filter { $0.memberType == .child }
            .sorted { $0.fullName < $1.fullName }
    }

    var body: some View {
        List {
            if let tribe = store.tribe {
                Section {
                    tribeHeaderCard(tribe: tribe)
                }
            }

            Section("Admins") {
                ForEach(admins) { member in
                    Button {
                        onSelectMember(member)
                    } label: {
                        memberRow(member)
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Parents") {
                ForEach(parents) { member in
                    Button {
                        onSelectMember(member)
                    } label: {
                        memberRow(member)
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Children") {
                ForEach(children) { member in
                    Button {
                        onSelectMember(member)
                    } label: {
                        memberRow(member)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func tribeHeaderCard(tribe: Tribe) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tribe.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)

            HStack(spacing: 7) {
                MemberAvatarStackView(members: allMembersSorted, maxVisible: 3, avatarSize: 28, overlap: 10)
                Text("\(store.members.count) Members")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Image(systemName: "qrcode")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .background(Color.gray.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button {
                    copyInviteCode(tribe.tribeCode)
                } label: {
                    Text(tribe.tribeCode)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Copy") {
                    copyInviteCode(tribe.tribeCode)
                }
                .font(.system(size: 13, weight: .semibold))
                .buttonStyle(.plain)

                ShareLink(item: tribe.tribeCode) {
                    Text("Share")
                        .font(.system(size: 13, weight: .semibold))
                }
            }

            if didCopyInviteCode {
                Text("Invite code copied")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.green.opacity(0.85))
            }
        }
        .padding(.vertical, 6)
    }

    private func memberRow(_ member: TribeMember) -> some View {
        HStack(spacing: 10) {
            MemberAvatarView(member: member, size: 44)
                .onTapGesture {
                    onSelectMember(member)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(member.fullName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                if member.memberType == .child {
                    Text(member.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    ForEach(member.roles.sorted(by: { $0.sortOrder < $1.sortOrder }).map(\.rawValue), id: \.self) { role in
                        Text(role)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.indigo)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.indigo.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(minHeight: 48)
    }

    private func copyInviteCode(_ code: String) {
        UIPasteboard.general.string = code
        withAnimation(.easeInOut(duration: 0.2)) {
            didCopyInviteCode = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 0.2)) {
                didCopyInviteCode = false
            }
        }
    }
}

private struct FamilyAddMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TribeStore

    @State private var name = ""
    @State private var relationship = ""
    @State private var role: Role = .passenger
    @State private var phone = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Member") {
                    TextField("Name", text: $name)
                    TextField("Relationship (optional)", text: $relationship)
                    Picker("Role", selection: $role) {
                        Text("Admin").tag(Role.admin)
                        Text("Driver").tag(Role.driver)
                        Text("Observer").tag(Role.observer)
                        Text("Parent").tag(Role.parent)
                        Text("Child").tag(Role.child)
                        Text("Passenger").tag(Role.passenger)
                    }
                    TextField("Phone (optional)", text: $phone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let type: MemberType = role == .child ? .child : .adult
                        let newMember = TribeMember(
                            fullName: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            memberType: type,
                            relationship: relationship.nilIfEmpty,
                            phone: phone.nilIfEmpty,
                            roles: [role],
                            isLocationSharingEnabled: true,
                            isOnline: false
                        )
                        store.addMember(newMember)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct FamilyMemberDetailView: View {
    @ObservedObject var store: TribeStore
    let memberID: UUID

    var body: some View {
        Group {
            if let member = store.members.first(where: { $0.id == memberID }) {
                List {
                    Section("Member") {
                        Text(member.fullName)
                        Text(member.subtitle).foregroundStyle(.secondary)
                        if let phone = member.phone {
                            Text(phone).foregroundStyle(.secondary)
                        }
                    }
                    Section("Roles") {
                        Text(member.roleBadges.joined(separator: ", "))
                            .foregroundStyle(.secondary)
                    }
                    Section {
                        NavigationLink("Edit Role/Privileges") {
                            FamilyRolePrivilegesView(store: store, memberID: memberID)
                        }
                    }
                }
            } else {
                ContentUnavailableView("Member not found", systemImage: "person.crop.circle.badge.exclamationmark")
            }
        }
        .navigationTitle("Member Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FamilyRolePrivilegesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TribeStore
    let memberID: UUID

    @State private var role: Role = .passenger
    @State private var canCreateRuns = false
    @State private var canDriveRuns = false
    @State private var canSeeAllRuns = false
    @State private var canManageFamily = false

    var body: some View {
        Form {
            Section("Role") {
                Picker("Role", selection: $role) {
                    Text("Admin").tag(Role.admin)
                    Text("Driver").tag(Role.driver)
                    Text("Observer").tag(Role.observer)
                    Text("Parent").tag(Role.parent)
                    Text("Child").tag(Role.child)
                    Text("Passenger").tag(Role.passenger)
                }
            }

            Section("Privileges") {
                Toggle("Can create runs", isOn: $canCreateRuns)
                Toggle("Can drive runs", isOn: $canDriveRuns)
                Toggle("Can see all runs", isOn: $canSeeAllRuns)
                Toggle("Can manage family", isOn: $canManageFamily)
            }

            Section {
                Button("Save") {
                    save()
                    dismiss()
                }
            }
        }
        .navigationTitle("Role & Privileges")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            load()
        }
    }

    private func load() {
        guard let member = store.members.first(where: { $0.id == memberID }) else { return }
        role = member.roles.first ?? .passenger
        canCreateRuns = member.roles.contains(.admin) || member.roles.contains(.parent)
        canDriveRuns = member.roles.contains(.driver)
        canSeeAllRuns = member.roles.contains(.observer) || member.roles.contains(.admin)
        canManageFamily = member.roles.contains(.admin)
    }

    private func save() {
        guard var member = store.members.first(where: { $0.id == memberID }) else { return }

        var roles: Set<Role> = [role]
        if canCreateRuns { roles.insert(.parent) }
        if canDriveRuns { roles.insert(.driver) }
        if canSeeAllRuns { roles.insert(.observer) }
        if canManageFamily { roles.insert(.admin) }
        if role == .child { roles.insert(.child) }
        if role == .passenger { roles.insert(.passenger) }

        member.roles = roles
        store.updateMember(member)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    NavigationStack {
        FamilyRootView()
    }
}
