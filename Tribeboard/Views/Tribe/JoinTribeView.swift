import SwiftUI

struct JoinTribeView: View {
    @ObservedObject var store: TribeStore
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    let onJoin: () -> Void

    @State private var joinCode = ""
    @State private var inlineError: String?
    @State private var isJoining = false

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

                        TextField("Family code (H-XXXXXXXX)", text: $joinCode)
                            .textInputAutocapitalization(.characters)
                            .foregroundStyle(.primary)
                            .tint(TribeTheme.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        inlineError == nil ? Color(uiColor: .separator).opacity(0.35) : Color.red.opacity(0.6),
                                        lineWidth: 1
                                    )
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        if let inlineError {
                            Text(inlineError)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.red.opacity(0.9))
                        }
                    }
                }

                Button("Continue") {
                    Task {
                        await joinFamily()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(TribeTheme.primary)
                .clipShape(Capsule())
                .disabled(joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isJoining)
                .opacity((joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isJoining) ? 0.6 : 1)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .navigationTitle("Join Tribe")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: joinCode) { _, _ in
            if inlineError != nil {
                inlineError = nil
            }
        }
    }

    private func joinFamily() async {
        let trimmed = joinCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return }
        guard parseHouseholdJoinCode(trimmed) != nil else {
            inlineError = "Enter a valid family code."
            return
        }
        isJoining = true
        defer { isJoining = false }
        await backendHouseholdContext.joinHousehold(inviteCode: trimmed)
        guard backendHouseholdContext.householdAlertError == nil else {
            inlineError = backendHouseholdContext.householdAlertError ?? "We couldn't join this family. Please try again."
            return
        }
        let currentName = (store.tribe?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        store.createTribe(
            name: currentName.isEmpty ? "Joined Family" : currentName,
            tribeCode: trimmed
        )
        inlineError = nil
        onJoin()
    }
}

#Preview {
    NavigationStack {
        JoinTribeView(store: TribeStore()) { }
    }
}
