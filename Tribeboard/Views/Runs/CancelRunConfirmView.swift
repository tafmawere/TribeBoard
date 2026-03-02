import SwiftUI

struct CancelRunConfirmView: View {
    @Environment(\.dismiss) private var dismiss

    let onConfirm: (String) -> Void

    @State private var reason = "Late"
    @State private var otherReason = ""

    private let reasons = ["Late", "Not needed", "Driver unavailable", "Other"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(RunStitchTheme.warning)

                Text("Cancel Run?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(RunStitchTheme.textPrimary)

                Text("This will notify all members that this run is no longer happening.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(RunStitchTheme.textSecondary)
                    .multilineTextAlignment(.center)

                StitchCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Reason (optional)")
                            .font(.system(size: 15, weight: .semibold))
                        Picker("Reason", selection: $reason) {
                            ForEach(reasons, id: \.self) { item in
                                Text(item).tag(item)
                            }
                        }
                        .pickerStyle(.menu)

                        if reason == "Other" {
                            TextField("Enter reason", text: $otherReason)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }

                SecondaryButton(title: "Keep Run") {
                    dismiss()
                }
                DestructiveButton(title: "Cancel Run") {
                    let selected = reason == "Other" ? otherReason.trimmingCharacters(in: .whitespacesAndNewlines) : reason
                    onConfirm(selected)
                    dismiss()
                }
            }
            .padding(20)
            .background(RunStitchTheme.background.ignoresSafeArea())
            .navigationTitle("Cancel Run")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    CancelRunConfirmView { _ in }
}
