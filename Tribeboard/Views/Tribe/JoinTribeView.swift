import SwiftUI

struct JoinTribeView: View {
    @ObservedObject var store: TribeStore
    let onJoin: () -> Void

    @State private var inviteCode = ""
    @State private var inlineError: String?

    var body: some View {
        ZStack {
            TribeTheme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                TribeCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Join a family")
                            .font(.system(size: 30, weight: .bold))
                        Text("Enter the invite code shared with you.")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)

                        TextField("Invite code", text: $inviteCode)
                            .textInputAutocapitalization(.characters)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        inlineError == nil ? Color.black.opacity(0.08) : Color.red.opacity(0.45),
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
                    let trimmed = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    guard !trimmed.isEmpty else { return }
                    guard isValidInviteCode(trimmed) else {
                        inlineError = "Invalid invite code. Use format TRIBE-XXXX."
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
        .navigationTitle("Join Tribe")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: inviteCode) { _, _ in
            if inlineError != nil {
                inlineError = nil
            }
        }
    }

    private func isValidInviteCode(_ code: String) -> Bool {
        let parts = code.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0] == "TRIBE" else { return false }
        let suffix = String(parts[1])
        guard suffix.count == 4 else { return false }
        return suffix.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
    }
}

#Preview {
    NavigationStack {
        JoinTribeView(store: TribeStore()) { }
    }
}
