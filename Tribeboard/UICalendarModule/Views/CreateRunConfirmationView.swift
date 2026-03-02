import SwiftUI

struct CreateRunConfirmationView: View {
    let occurrence: UIScheduleOccurrence
    let onGoToRun: () -> Void

    var body: some View {
        ZStack {
            UICalendarDesignSystem.Colors.background.ignoresSafeArea()

            VStack(spacing: UICalendarDesignSystem.Spacing.large) {
                Spacer()

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(UICalendarDesignSystem.Colors.success)

                Text("Run Created")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(UICalendarDesignSystem.Colors.textPrimary)

                UICalendarCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(occurrence.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(UICalendarDesignSystem.Colors.textPrimary)

                        Text(dateTimeText(occurrence.dateTime))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(UICalendarDesignSystem.Colors.textSecondary)

                        Text("Driver: \(occurrence.driver.name)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(UICalendarDesignSystem.Colors.textSecondary)

                        Text("Stops: \(occurrence.stops.count)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(UICalendarDesignSystem.Colors.textSecondary)
                    }
                }

                UICalendarPrimaryButton(title: "Go to Run") {
                    onGoToRun()
                }

                Spacer()
            }
            .padding(UICalendarDesignSystem.Spacing.large)
        }
        .navigationTitle("Run Ready")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dateTimeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d • h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        CreateRunConfirmationView(
            occurrence: UICalendarMockData.occurrencesForDay(Date()).first ?? UIScheduleOccurrence(
                scheduleId: UUID(),
                dateTime: Date(),
                title: "School Pickup",
                driver: UICalendarMockData.rue,
                passengers: [UICalendarMockData.tj],
                stops: [UICalendarStop(type: .pickup, label: "School")],
                hasMaterializedRun: false
            ),
            onGoToRun: {}
        )
    }
}
