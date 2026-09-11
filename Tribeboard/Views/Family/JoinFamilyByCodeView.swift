import SwiftUI

struct JoinFamilyByCodeView: View {
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @Environment(\.dismiss) private var dismiss

    @State private var inviteCode: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var previewHousehold: BackendHousehold?
    @State private var isJoining = false
    @State private var joinPreviewResult: InviteCodeJoinResult?

    var body: some View {
        Form {
            Section {
                TextField("Enter invite code", text: inviteCodeBinding)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Join a Family")
            }

            if let previewHousehold {
                Section("Confirm") {
                    Text(previewHousehold.name)
                        .font(.system(size: 16, weight: .semibold))
                    Text("Join this family?")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(confirmationHint)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button(isJoining ? "Joining..." : "Join") {
                            Task { await confirmJoin() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isJoining)

                        Button("Cancel", role: .cancel) {
                            self.previewHousehold = nil
                        }
                        .buttonStyle(.bordered)
                        .disabled(isJoining)
                    }
                }
            }

            Section {
                Button {
                    Task { await lookupFamily() }
                } label: {
                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Checking...")
                        }
                    } else {
                        Text("Join Family")
                    }
                }
                .disabled(normalizedInviteCode.isEmpty || isLoading || isJoining)
            }
        }
        .navigationTitle("Join a Family")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var inviteCodeBinding: Binding<String> {
        Binding(
            get: { inviteCode },
            set: { newValue in
                inviteCode = newValue.uppercased()
                errorMessage = nil
            }
        )
    }

    private var normalizedInviteCode: String {
        inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    @MainActor
    private func lookupFamily() async {
        guard !normalizedInviteCode.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let preview = try await backendHouseholdContext.previewJoinResult(inviteCode: normalizedInviteCode)
            previewHousehold = preview.household
            joinPreviewResult = preview
            errorMessage = nil
        } catch {
            previewHousehold = nil
            joinPreviewResult = nil
            errorMessage = joinLookupErrorMessage(for: error)
        }
    }

    @MainActor
    private func confirmJoin() async {
        guard !normalizedInviteCode.isEmpty else { return }
        isJoining = true
        defer { isJoining = false }
        await backendHouseholdContext.joinHousehold(inviteCode: normalizedInviteCode)
        if backendHouseholdContext.householdAlertError == nil {
            dismiss()
        } else {
            errorMessage = backendHouseholdContext.householdAlertError ?? "We couldn't join this family. Please try again."
        }
    }

    private var confirmationHint: String {
        if case .matchedInvite = joinPreviewResult {
            return "You will join this family immediately."
        }
        return "Your request will be sent for approval."
    }

    private func joinLookupErrorMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return description
        }
        return "Unable to verify this code right now. Please try again."
    }
}
