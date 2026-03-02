import SwiftUI

struct UICalendarDayScheduleListView: View {
    let date: Date
    let occurrences: [UIScheduleOccurrence]
    let onCreateRunNow: (UIScheduleOccurrence) -> Void
    let onViewSchedule: (UIScheduleOccurrence) -> Void

    var body: some View {
        ZStack {
            UICalendarDesignSystem.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: UICalendarDesignSystem.Spacing.medium) {
                    Text(titleText)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(UICalendarDesignSystem.Colors.textPrimary)

                    if occurrences.isEmpty {
                        UICalendarCard {
                            VStack(spacing: 10) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundStyle(UICalendarDesignSystem.Colors.warning)
                                Text("No occurrences for this date")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(UICalendarDesignSystem.Colors.textPrimary)
                                Text("Try another day or create a schedule.")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(UICalendarDesignSystem.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                    } else {
                        ForEach(occurrences.sorted { $0.dateTime < $1.dateTime }) { occurrence in
                            UIOccurrenceCard(
                                occurrence: occurrence,
                                onCreateRunNow: { onCreateRunNow(occurrence) },
                                onViewSchedule: { onViewSchedule(occurrence) }
                            )
                        }
                    }
                }
                .padding(UICalendarDesignSystem.Spacing.medium)
            }
        }
        .navigationTitle("Day Schedule")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var titleText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        UICalendarDayScheduleListView(
            date: Date(),
            occurrences: UICalendarMockData.occurrencesForDay(Date()),
            onCreateRunNow: { _ in },
            onViewSchedule: { _ in }
        )
    }
}
