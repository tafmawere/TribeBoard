import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var flow: AppFlowState

    @State private var confirmationText = ""
    @State private var isDeleting = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var canDelete: Bool {
        confirmationText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "DELETE"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                warningCard
                retentionCard
                subscriptionCard
                confirmationCard
                policyLinkCard
                deleteButton
            }
            .padding(16)
        }
        .background(Color(red: 0.976, green: 0.980, blue: 0.984).ignoresSafeArea())
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isDeleting)
        .alert("Unable to Delete Account", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var warningCard: some View {
        SettingsSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("This action is permanent", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.red)

                Text("Deleting your account will remove:")
                    .font(.system(size: 14, weight: .semibold))

                VStack(alignment: .leading, spacing: 8) {
                    deletionItem("Your profile")
                    deletionItem("Your household membership")
                    deletionItem("Child profiles linked to your account")
                    deletionItem("Journey history")
                    deletionItem("Location logs")
                    deletionItem("Calendar entries")
                    deletionItem("Reminders")
                    deletionItem("Uploaded content")
                }
            }
        }
    }

    private var retentionCard: some View {
        SettingsSectionCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Records we may keep")
                    .font(.system(size: 14, weight: .semibold))
                Text("Some information may be retained where required for legal, billing, security, fraud-prevention, or child-safety obligations. See our Delete Account Policy for details.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var subscriptionCard: some View {
        SettingsSectionCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Subscriptions")
                    .font(.system(size: 14, weight: .semibold))
                Text("If you subscribed through Apple or Google, cancel your subscription separately in your Apple ID or Google Play account settings. Deleting your TribeBoard account does not automatically cancel billing.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var confirmationCard: some View {
        SettingsSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Type DELETE to confirm")
                    .font(.system(size: 14, weight: .semibold))
                TextField("DELETE", text: $confirmationText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .padding(12)
                    .background(Color.gray.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var policyLinkCard: some View {
        SettingsSectionCard {
            Button {
                guard let url = URL(string: ExternalLinks.deleteAccountPolicy) else { return }
                openURL(url)
            } label: {
                SettingsRow(
                    icon: "doc.text",
                    title: "Delete Account Policy",
                    subtitle: "Full details on what is removed and retained",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            Task { await performDeletion() }
        } label: {
            HStack {
                Spacer()
                if isDeleting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Delete My Account Permanently")
                        .font(.system(size: 16, weight: .bold))
                }
                Spacer()
            }
            .padding(.vertical, 14)
            .background(canDelete && !isDeleting ? Color.red : Color.red.opacity(0.35))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canDelete || isDeleting)
    }

    private func deletionItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.red)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
        }
    }

    private func performDeletion() async {
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await AccountDeletionService.deleteCurrentUserAccount(userId: authSession.currentUserId)
            await authSession.signOut()
            OnboardingPreferences.clear()
            flow.signOut()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        DeleteAccountView()
            .environmentObject(AuthSessionContext())
            .environmentObject(AppFlowState())
    }
}
