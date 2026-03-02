import SwiftUI

struct SchedulePlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let message: String

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(CalendarUITheme.textPrimary)

                Text(message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CalendarUITheme.textSecondary)

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(CalendarUITheme.indigo)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(20)
            .navigationTitle("Coming Soon")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ScheduleDeleteConfirmationModifier: ViewModifier {
    @Binding var isPresented: Bool
    let scheduleTitle: String
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Delete schedule?",
            isPresented: $isPresented,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \"\(scheduleTitle)\" from the UI list. This action cannot be undone.")
        }
    }
}

private struct ScheduleDiscardChangesModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onDiscard: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Discard changes?",
            isPresented: $isPresented,
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) {
                onDiscard()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your unsaved changes will be lost.")
        }
    }
}

extension View {
    func deleteScheduleConfirmation(
        isPresented: Binding<Bool>,
        scheduleTitle: String,
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(
            ScheduleDeleteConfirmationModifier(
                isPresented: isPresented,
                scheduleTitle: scheduleTitle,
                onDelete: onDelete
            )
        )
    }

    func discardScheduleChangesConfirmation(
        isPresented: Binding<Bool>,
        onDiscard: @escaping () -> Void
    ) -> some View {
        modifier(
            ScheduleDiscardChangesModifier(
                isPresented: isPresented,
                onDiscard: onDiscard
            )
        )
    }
}
