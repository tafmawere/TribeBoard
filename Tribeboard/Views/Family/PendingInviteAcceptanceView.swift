import SwiftUI

/// Shown after authentication when a deep link or manual code was captured before sign-in.
struct PendingInviteAcceptanceView: View {
    let preview: HouseholdInvitePreview
    var localizedError: String?
    let onAccept: () async -> Void
    let onDecline: () async -> Void

    @State private var isBusy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("You’ve been invited to join \(preview.householdName).")
                .font(.system(size: 22, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                labeledRow(title: "Invited by", value: preview.inviterDisplayName)
                labeledRow(title: "Access level", value: preview.normalizedAccessRole.rawValue.capitalized)
                if let relationship = preview.relationship?.trimmingCharacters(in: .whitespacesAndNewlines), !relationship.isEmpty {
                    labeledRow(title: "Relationship", value: relationship)
                }
            }
            .font(.system(size: 15))

            if let localizedError, !localizedError.isEmpty {
                Text(localizedError)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button(role: .cancel) {
                    Task { await runDecline() }
                } label: {
                    Text("Decline")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)

                Button {
                    Task { await runAccept() }
                } label: {
                    if isBusy {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Accept Invite")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func labeledRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(title):")
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.medium)
        }
    }

    @MainActor
    private func runAccept() async {
        isBusy = true
        defer { isBusy = false }
        await onAccept()
    }

    @MainActor
    private func runDecline() async {
        isBusy = true
        defer { isBusy = false }
        await onDecline()
    }
}
