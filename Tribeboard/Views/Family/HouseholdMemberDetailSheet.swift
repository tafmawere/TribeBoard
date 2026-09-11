import SwiftUI

struct HouseholdMemberDetailSheet: View {
    let membership: BackendHouseholdMembership
    let householdName: String
    let canManageMembers: Bool
    var presentRemovalConfirmation: Bool = false

    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var authSession: AuthSessionContext
    @Environment(\.dismiss) private var dismiss

    @State private var accessRole: String = "observer"
    @State private var relationshipLabel: String = ""
    @State private var isSaving = false
    @State private var isRemoving = false
    @State private var errorMessage: String?
    @State private var showRemoveConfirmation = false
    @State private var showOrganiserRemovalConfirmation = false

    private var profile: BackendProfile? {
        backendHouseholdContext.activeHouseholdProfilesByUserId[membership.userId]
    }

    private var displayName: String {
        let resolved = AuthBackedMemberDisplayResolver.resolveName(
            profile: profile,
            relationshipLabel: membership.relationshipLabel
        )
        let email = profile?.email?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        if resolved == email {
            return membership.relationshipLabel?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                ?? "Member"
        }
        return resolved
    }

    private var email: String {
        profile?.email?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Not available"
    }

    private var removalEvaluation: HouseholdMemberRemovalPolicy.Evaluation {
        backendHouseholdContext.removalEligibility(for: membership)
    }

    private var memberAvatarIdentity: TribeAvatarIdentity {
        if let profile {
            return profile.avatarIdentity(fallbackDisplayName: displayName)
        }
        return TribeAvatarIdentity(displayName: displayName)
    }

    var body: some View {
        NavigationStack {
            Form {
                profileHeaderSection
                memberInfoSection
                if canManageMembers, membership.isPendingApproval {
                    pendingApprovalSection
                }
                if canManageMembers, membership.isActive {
                    accessManagementSection
                }
                if canManageMembers, membership.isActive {
                    removalSection
                }
            }
            .navigationTitle("Member details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if canManageMembers, membership.isActive {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isSaving ? "Saving..." : "Save") {
                            Task { await saveChanges() }
                        }
                        .disabled(isSaving || isRemoving)
                    }
                }
            }
            .onAppear {
                accessRole = membership.accessRole.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                relationshipLabel = membership.relationshipLabel ?? ""
                if presentRemovalConfirmation, removalEvaluation.canRemove {
                    if removalEvaluation.requiresOrganiserRemovalWarning {
                        showOrganiserRemovalConfirmation = true
                    } else {
                        showRemoveConfirmation = true
                    }
                }
            }
            .alert("Unable to update member", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .alert("Remove member?", isPresented: $showRemoveConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Remove member", role: .destructive) {
                    if removalEvaluation.requiresOrganiserRemovalWarning {
                        showOrganiserRemovalConfirmation = true
                    } else {
                        Task { await confirmRemoveMember() }
                    }
                }
            } message: {
                Text(standardRemovalMessage)
            }
            .alert("Remove organiser?", isPresented: $showOrganiserRemovalConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Remove organiser", role: .destructive) {
                    Task { await confirmRemoveMember() }
                }
            } message: {
                Text(organiserRemovalMessage)
            }
        }
    }

    private var profileHeaderSection: some View {
        Section {
            HStack(spacing: 16) {
                TribeAvatarView(
                    identity: memberAvatarIdentity,
                    size: .hero,
                    accessToken: authSession.currentAccessToken
                )
                VStack(alignment: .leading, spacing: 6) {
                    Text(displayName)
                        .font(.system(size: 22, weight: .bold))
                    Text(householdGroupLabel)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var memberInfoSection: some View {
        Section("Details") {
            detailRow(title: "Email", value: email)
            detailRow(title: "Relationship", value: formattedRelationship)
            detailRow(title: "Access role", value: formattedAccessRole)
            detailRow(title: "Joined", value: formattedJoinedDate)
            detailRow(title: "Household group", value: householdGroupLabel)
            detailRow(title: "Status", value: formattedStatus)
        }
    }

    private var pendingApprovalSection: some View {
        Section {
            Button("Approve membership") {
                Task { await approveMembership() }
            }
            .disabled(isSaving || isRemoving)
        }
    }

    private var accessManagementSection: some View {
        Section("Access") {
            Picker("Access role", selection: $accessRole) {
                Text("Organiser").tag("organiser")
                Text("Driver").tag("driver")
                Text("Observer").tag("observer")
            }
            TextField("Relationship", text: $relationshipLabel)
        }
    }

    @ViewBuilder
    private var removalSection: some View {
        Section {
            if let blockedReason = removalEvaluation.blockedReason {
                Text(blockedReason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Button("Remove from family", role: .destructive) {
                    showRemoveConfirmation = true
                }
                .disabled(isRemoving)
            }
        } header: {
            Text("Danger zone")
        } footer: {
            if removalEvaluation.canRemove {
                Text("They will lose access to schedules, children, runs, and shared family information for this household. Their account and profile are not deleted.")
            }
        }
    }

    private var standardRemovalMessage: String {
        """
        Are you sure you want to remove \(displayName) from \(householdName)?
        They will lose access to schedules, children, runs and shared family information for this household.
        """
    }

    private var organiserRemovalMessage: String {
        """
        \(displayName) is an organiser for \(householdName).

        Removing them will revoke their ability to manage members, invites, and household settings. This cannot be undone without inviting them again.

        Are you sure you want to remove this organiser?
        """
    }

    private var formattedRelationship: String {
        membership.relationshipLabel?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Not set"
    }

    private var formattedAccessRole: String {
        switch membership.normalizedAccessRole {
        case .organiser: return "Organiser"
        case .driver: return "Driver"
        case .observer: return "Observer"
        case .none: return membership.accessRole.capitalized
        }
    }

    private var householdGroupLabel: String {
        switch membership.normalizedAccessRole {
        case .organiser: return "Organisers"
        case .driver: return "Drivers"
        case .observer: return "Observers"
        case .none: return "Members"
        }
    }

    private var formattedStatus: String {
        switch membership.normalizedStatus {
        case .pending: return "Pending approval"
        case .active, .none: return "Active"
        case .revoked, .removed: return "Removed"
        case .cancelled: return "Cancelled"
        case .inactive: return "Inactive"
        case .declined: return "Declined"
        case .rejected: return "Rejected"
        }
    }

    private var formattedJoinedDate: String {
        guard let createdAt = membership.createdAt,
              let date = BackendTimestampParser.parse(createdAt) else {
            return "Unknown"
        }
        return Self.joinedDateFormatter.string(from: date)
    }

    private static let joinedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
    }

    private func approveMembership() async {
        guard canManageMembers else {
            errorMessage = "Only organisers can manage members."
            return
        }
        isSaving = true
        defer { isSaving = false }
        let ok = await backendHouseholdContext.approveMembership(membership.id)
        if ok {
            dismiss()
        } else {
            errorMessage = backendHouseholdContext.lastError ?? "Approval failed."
        }
    }

    private func saveChanges() async {
        guard canManageMembers else {
            errorMessage = "Only organisers can manage members."
            return
        }
        isSaving = true
        defer { isSaving = false }
        let ok = await backendHouseholdContext.updateMembershipAccess(
            membershipId: membership.id,
            accessRole: accessRole,
            relationshipLabel: relationshipLabel.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        if ok {
            dismiss()
        } else {
            errorMessage = backendHouseholdContext.lastError ?? "Save failed."
        }
    }

    private func confirmRemoveMember() async {
        guard canManageMembers else {
            errorMessage = "Only organisers can manage members."
            return
        }
        isRemoving = true
        defer { isRemoving = false }
        let ok = await backendHouseholdContext.removeMember(membershipId: membership.id)
        if ok {
            dismiss()
        } else {
            errorMessage = backendHouseholdContext.lastError ?? "Remove failed."
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
