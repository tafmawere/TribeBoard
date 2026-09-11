import SwiftUI
import UIKit

struct AddMembersView: View {
    @ObservedObject var store: TribeStore
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var backendHouseholdPeopleContext: BackendHouseholdPeopleContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext
    @EnvironmentObject private var realtimeService: SupabaseRealtimeService
    let onContinue: () -> Void

    @State private var editorType: MemberType = .adult
    @State private var editingMember: TribeMember?
    @State private var isShowingAddPerson = false
    @State private var isShowingJoinFamily = false
    @State private var generatedJoinCode: String?
    @State private var showInviteGeneratedToast = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var addPersonSaveErrorMessage: String?

    private var displayedAdults: [TribeMember] {
        if authSession.isAuthenticated, backendHouseholdContext.activeHouseholdId != nil {
            return backendHouseholdPeopleContext.people
                .map(backendHouseholdPeopleContext.mapToTribeMember)
                .sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
        }
        return store.adults()
    }

    var body: some View {
        ZStack {
            TribeTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header

                    TribeCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Invite someone to your family")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(TribeTheme.textPrimary)

                            Button {
                                Task {
                                    if let code = latestJoinCode {
                                        generatedJoinCode = code
                                        showInviteGeneratedToast = true
                                        try? await Task.sleep(nanoseconds: 1_400_000_000)
                                        showInviteGeneratedToast = false
                                    }
                                }
                            } label: {
                                HStack {
                                    Text("Show Family Code")
                                        .font(.system(size: 15, weight: .semibold))
                                    Spacer()
                                    if backendHouseholdContext.isLoading {
                                        ProgressView()
                                    }
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 12)
                                .background(canGenerateInvite ? TribeTheme.primary : Color.gray)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(!canGenerateInvite || backendHouseholdContext.isLoading)

                            if let latestJoinCode {
                                inviteCard(code: latestJoinCode)
                            }

                            if showInviteGeneratedToast {
                                Text("Family code ready")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.green)
                            }

                            inviteMethodRow(
                                icon: "envelope.fill",
                                title: "Invite by email",
                                subtitle: "Coming soon",
                                enabled: false,
                                action: {}
                            )
                            inviteMethodRow(
                                icon: "phone.fill",
                                title: "Invite by phone",
                                subtitle: "Coming soon",
                                enabled: false,
                                action: {}
                            )
                            inviteMethodRow(
                                icon: "qrcode",
                                title: "Invite by code",
                                subtitle: "Join an existing family using a family code.",
                                enabled: true,
                                action: { isShowingJoinFamily = true }
                            )

                            Button {
                                openAddPerson(type: .adult)
                            } label: {
                                Text("Add person")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(TribeTheme.primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Text("Adults can manage or drive Runs. Kids are passengers.")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                    }

                    sectionHeader(title: "Adults", count: displayedAdults.count)
                    if displayedAdults.isEmpty {
                        emptyStateCard(
                            icon: "person.2.fill",
                            text: "No adults yet. Add a parent, guardian, or helper."
                        )
                    } else {
                        ForEach(displayedAdults) { member in
                            onboardingMemberRow(member: member)
                        }
                    }

                    sectionHeader(title: "Kids", count: store.children().count)
                    if store.children().isEmpty {
                        emptyStateCard(
                            icon: "figure.2.and.child.holdinghands",
                            text: "No kids yet. Add your children so they can be assigned to Runs."
                        )
                    } else {
                        ForEach(store.children()) { member in
                            onboardingMemberRow(member: member)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 74)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Add members")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isShowingJoinFamily) {
            JoinHouseholdView()
                .environmentObject(backendHouseholdContext)
                .environmentObject(backendChildrenContext)
                .environmentObject(realtimeService)
        }
        .fullScreenCover(isPresented: $isShowingAddPerson) {
            AddPersonView(
                existingMember: editingMember,
                defaultType: editorType,
                onSave: { member in
                    addPersonSaveErrorMessage = nil
                    if editingMember == nil {
                        if member.memberType == .child {
                            return await backendChildrenContext.createChild(member)
                        } else {
                            return await saveAdultMember(member)
                        }
                    } else {
                        if member.memberType == .child {
                            await backendChildrenContext.updateChildLocallyThenSync(member)
                            return backendChildrenContext.lastError == nil
                        } else {
                            return await saveAdultMember(member)
                        }
                    }
                },
                saveErrorProvider: {
                    let localMessage = addPersonSaveErrorMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
                    if localMessage?.isEmpty == false {
                        return localMessage
                    }
                    return backendHouseholdPeopleContext.lastError
                }
            )
        }
        .safeAreaInset(edge: .bottom) {
            bottomContinueBar
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: shareItems)
        }
        .task {
            await backendHouseholdContext.refreshInvites()
            await backendHouseholdPeopleContext.refreshForActiveHousehold()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Step 3 of 6")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Add your family")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(TribeTheme.textPrimary)

            Text("Add the people who help with Runs and schedules.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .padding(.top, -2)
    }

    private var canContinue: Bool {
        !displayedAdults.isEmpty
    }

    private var bottomContinueBar: some View {
        VStack(spacing: 4) {
            Button {
                onContinue()
            } label: {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(TribeTheme.primary)
                    .clipShape(Capsule())
            }
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.6)

            Text(continueHint)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(
            Color(red: 0.976, green: 0.980, blue: 0.984)
                .ignoresSafeArea()
        )
    }

    private var continueHint: String {
        "Add at least one adult to continue."
    }

    private var latestJoinCode: String? {
        if let generatedJoinCode {
            return generatedJoinCode
        }
        guard let householdId = backendHouseholdContext.activeHouseholdId else {
            return nil
        }
        return formatHouseholdJoinCode(householdId: householdId)
    }

    private var canGenerateInvite: Bool {
        guard authSession.isAuthenticated else { return false }
        guard backendHouseholdContext.activeHouseholdId != nil else { return false }
        let role = (backendHouseholdContext.roleForActiveHousehold() ?? "").lowercased()
        return role == "admin" || role == "parent"
    }

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(TribeTheme.textPrimary)

            Text("\(count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TribeTheme.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(TribeTheme.primary.opacity(0.12))
                .clipShape(Capsule())

            Spacer()
        }
    }

    private func openAddPerson(type: MemberType) {
        editorType = type
        editingMember = nil
        isShowingAddPerson = true
    }

    private func onboardingMemberRow(member: TribeMember) -> some View {
        Button {
            editorType = member.memberType
            editingMember = member
            isShowingAddPerson = true
        } label: {
            HStack(spacing: 12) {
                MemberAvatarView(member: member, size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(member.fullName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(TribeTheme.textPrimary)

                    Text(member.relationship?.isEmpty == false ? member.relationship! : (member.memberType == .adult ? "Adult" : "Child"))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ForEach(displayBadges(for: member), id: \.self) { badge in
                            badgeView(title: badge)
                        }
                        let overflow = member.roleBadges.count - min(member.roleBadges.count, 2)
                        if overflow > 0 {
                            badgeView(title: "+\(overflow)")
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func emptyStateCard(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(TribeTheme.primary)

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 54)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.03), lineWidth: 0.5)
        }
    }

    private func inviteMethodRow(
        icon: String,
        title: String,
        subtitle: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if enabled {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundStyle(enabled ? TribeTheme.primary : TribeTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background((enabled ? TribeTheme.primary.opacity(0.08) : Color.gray.opacity(0.12)))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func inviteCard(code: String) -> some View {
        return VStack(alignment: .leading, spacing: 8) {
            Text("Family Code")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(TribeTheme.textPrimary)
            Text(code)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(TribeTheme.primary)
            Text("Share this code to let someone join your family.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button("Copy Code") {
                    UIPasteboard.general.string = code
                }
                .font(.system(size: 12, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundStyle(TribeTheme.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(TribeTheme.primary.opacity(0.1))
                .clipShape(Capsule())

                Button("Share Code") {
                    shareItems = ["Join my family on TribeBoard. Family code: \(code)"]
                    showShareSheet = true
                }
                .font(.system(size: 12, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundStyle(TribeTheme.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(TribeTheme.primary.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func displayBadges(for member: TribeMember) -> [String] {
        Array(member.roleBadges.prefix(2))
    }

    private func saveAdultMember(_ member: TribeMember) async -> Bool {
        print("[AddMembersView] saveAdultMember started for \(member.fullName), editing=\(editingMember != nil), authenticated=\(authSession.isAuthenticated)")

        guard authSession.isAuthenticated else {
            if editingMember == nil {
                store.addMember(member)
            } else {
                store.updateMember(member)
            }
            print("[AddMembersView] saveAdultMember completed locally for unauthenticated flow")
            return true
        }

        guard backendHouseholdContext.activeHouseholdId != nil else {
            let message = "No active household selected. Please create or join a family first."
            addPersonSaveErrorMessage = message
            backendHouseholdPeopleContext.lastError = message
            print("[AddMembersView] saveAdultMember failed: \(message)")
            return false
        }

        let backendRole = backendHouseholdPeopleContext.mapAdultMemberToBackendRole(member)
        let isDriver = member.roles.contains(.driver)
        let didSave: Bool
        if let existing = backendHouseholdPeopleContext.person(for: member.id) {
            let updated = BackendHouseholdPerson(
                id: existing.id,
                householdId: existing.householdId,
                name: member.fullName,
                relationship: member.relationship,
                role: backendRole,
                phone: member.phone,
                isDriver: isDriver,
                createdAt: existing.createdAt,
                updatedAt: existing.updatedAt
            )
            didSave = await backendHouseholdPeopleContext.updatePerson(updated)
        } else {
            didSave = await backendHouseholdPeopleContext.createPerson(
                name: member.fullName,
                relationship: member.relationship,
                role: backendRole,
                phone: member.phone,
                isDriver: isDriver
            )
        }

        if didSave {
            await backendHouseholdPeopleContext.refreshForActiveHousehold()
            addPersonSaveErrorMessage = nil
            print("[AddMembersView] saveAdultMember succeeded and refreshed people list")
            return true
        }

        let backendError = backendHouseholdPeopleContext.lastError?.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = (backendError?.isEmpty == false) ? backendError! : "Unable to save adult member. Please try again."
        addPersonSaveErrorMessage = message
        print("[AddMembersView] saveAdultMember failed: \(message)")
        return false
    }

    private func badgeView(title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(TribeTheme.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(TribeTheme.primary.opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct JoinFamilyView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TribeStore
    @State private var inviteCode = ""

    var body: some View {
        ZStack {
            TribeTheme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                TribeCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Join a family")
                            .font(.system(size: 30, weight: .bold))
                        Text("Enter the family code shared with you.")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)

                        TextField("Family code (H-XXXXXXXX)", text: $inviteCode)
                            .textInputAutocapitalization(.characters)
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

                Button("Continue") {
                    let trimmed = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    let currentName = store.tribe?.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.createTribe(
                        name: (currentName?.isEmpty == false ? currentName! : "Joined Family"),
                        tribeCode: trimmed
                    )
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(TribeTheme.primary)
                .clipShape(Capsule())
                .disabled(inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .navigationTitle("Join Family")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AddMembersView(store: TribeStore(demoFlow: true)) { }
    }
}
