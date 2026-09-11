import SwiftUI

struct JoinHouseholdView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext
    @EnvironmentObject private var realtimeService: SupabaseRealtimeService

    let onJoined: (() async -> Void)?

    @State private var joinCode = ""
    @State private var isJoining = false
    @State private var showErrorAlert = false
    @State private var showJoinedMessage = false
    @State private var errorMessage = ""

    init(onJoined: (() async -> Void)? = nil) {
        self.onJoined = onJoined
    }

    var body: some View {
        Form {
            Section("Join Family") {
                TextField("Family Code (H-XXXXXXXX)", text: $joinCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Text("Use the code shared by your family (example: H-DED572F3).")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(isJoining ? "Joining..." : "Join Family") {
                    Task { await joinFamily() }
                }
                .disabled(isJoining || joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if showJoinedMessage {
                Section {
                    Text("You joined the family")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Join Family")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Unable to Join", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func joinFamily() async {
        let normalized = joinCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return }
        guard parseHouseholdJoinCode(normalized) != nil else {
            errorMessage = "Enter a valid family code."
            showErrorAlert = true
            return
        }
        isJoining = true
        defer { isJoining = false }

        await backendHouseholdContext.joinHousehold(inviteCode: normalized)
        guard backendHouseholdContext.householdAlertError == nil else {
            errorMessage = backendHouseholdContext.householdAlertError ?? "We couldn't join this family. Please try again."
            showErrorAlert = true
            return
        }

        await backendChildrenContext.refreshForActiveHousehold()
        if let householdId = backendHouseholdContext.activeHouseholdId {
            await realtimeService.subscribeToHousehold(householdId: householdId)
        }
        if let onJoined {
            await onJoined()
        }
        showJoinedMessage = true
        try? await Task.sleep(nanoseconds: 900_000_000)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        JoinHouseholdView()
    }
}
