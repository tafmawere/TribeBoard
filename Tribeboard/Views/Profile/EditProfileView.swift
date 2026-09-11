import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var backendProfileContext: BackendProfileContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var displayName = ""
    @State private var inlineError: String?
    @State private var isSaving = false
    @State private var lastPrefilledProfileId: UUID?
    @State private var showAvatarPicker = false

    private var resolvedDisplayName: String {
        backendProfileContext.currentUserProfile?.resolvedDisplayName(
            providerDisplayName: authSession.currentUserProviderDisplayName,
            fallbackEmail: authSession.currentUserEmail
        ).value ?? "User"
    }

    private var profileAvatarIdentity: TribeAvatarIdentity {
        if let profile = backendProfileContext.currentUserProfile {
            return profile.avatarIdentity(fallbackDisplayName: resolvedDisplayName)
        }
        return TribeAvatarIdentity(displayName: resolvedDisplayName)
    }

    var body: some View {
        Form {
            Section("Profile picture") {
                HStack(spacing: 14) {
                    TribeAvatarView(
                        identity: profileAvatarIdentity,
                        size: .large,
                        accessToken: authSession.currentAccessToken
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Button("Choose TribeBoard avatar") {
                            showAvatarPicker = true
                        }
                        Button("Upload photo") {
                            showAvatarPicker = true
                        }
                        Button("Remove photo / use default avatar", role: .destructive) {
                            showAvatarPicker = true
                        }
                        .font(.system(size: 13))
                    }
                }
                Text("Choose an illustrated avatar or upload your own photo.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Section("Name") {
                TextField("First Name", text: $firstName)
                    .textInputAutocapitalization(.words)
                TextField("Last Name", text: $lastName)
                    .textInputAutocapitalization(.words)
                TextField("Display Name", text: $displayName)
                    .textInputAutocapitalization(.words)
                Text("Display name is used across TribeBoard.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            if let inlineError, !inlineError.isEmpty {
                Section {
                    Text(inlineError)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task { await save() }
                }
                .disabled(isSaving)
            }
        }
        .sheet(isPresented: $showAvatarPicker) {
            if let profileId = backendProfileContext.currentUserProfile?.id,
               let token = authSession.currentAccessToken {
                NavigationStack {
                    AvatarPickerView(
                        subjectKind: .profile(profileId),
                        displayName: resolvedDisplayName,
                        memberType: .adult,
                        isDriver: backendHouseholdContext.isCurrentUserDriver,
                        canUploadPhoto: true,
                        initialIdentity: profileAvatarIdentity,
                        accessToken: token
                    )
                }
            }
        }
        .task {
            await backendProfileContext.refreshProfile(
                authEmail: authSession.currentUserEmail,
                providerDisplayName: authSession.currentUserProviderDisplayName
            )
            prefill()
        }
        .onChange(of: backendProfileContext.currentUserProfile?.id) { _, _ in
            prefill()
        }
    }

    private func prefill() {
        guard let profile = backendProfileContext.currentUserProfile else { return }
        guard lastPrefilledProfileId != profile.id || (firstName.isEmpty && lastName.isEmpty && displayName.isEmpty) else {
            return
        }
        let currentFirst = backendProfileContext.currentUserProfile?.first_name?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let currentLast = backendProfileContext.currentUserProfile?.last_name?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let currentDisplay = backendProfileContext.currentUserProfile?.display_name?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        firstName = currentFirst
        lastName = currentLast
        displayName = currentDisplay
        lastPrefilledProfileId = profile.id
    }

    private func save() async {
        inlineError = nil
        let trimmedDisplay = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDisplay.isEmpty || !trimmedFirst.isEmpty || !trimmedLast.isEmpty else {
            inlineError = "Please add a display name, first name, or last name."
            return
        }

        isSaving = true
        defer { isSaving = false }
        let didSave = await backendProfileContext.updateCurrentUserProfile(
            firstName: firstName,
            lastName: lastName,
            displayName: displayName,
            avatarURL: backendProfileContext.currentUserProfile?.avatar_url,
            authEmail: authSession.currentUserEmail,
            providerDisplayName: authSession.currentUserProviderDisplayName
        )
        guard didSave else {
            inlineError = backendProfileContext.lastError ?? "Unable to save profile right now."
            return
        }
        dismiss()
    }
}
