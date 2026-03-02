import SwiftUI

struct CalendarHomeView: View {
    @Binding var monthDate: Date
    @Binding var selectedDate: Date
    let occurrencesForMonth: [UIScheduleOccurrence]
    let occurrencesForSelectedDate: [UIScheduleOccurrence]
    let onOpenDayList: (Date) -> Void
    let onOpenCreateSchedule: () -> Void
    let onCreateRunNow: (UIScheduleOccurrence) -> Void
    let onViewSchedule: (UIScheduleOccurrence) -> Void

    private let calendar = Calendar.current
    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: monthDate)
    }

    var body: some View {
        ZStack {
            UICalendarDesignSystem.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: UICalendarDesignSystem.Spacing.medium) {
                    header
                    monthGridCard
                    selectedDaySection
                }
                .padding(UICalendarDesignSystem.Spacing.medium)
            }
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(UICalendarDesignSystem.Colors.textPrimary)
            }

            Spacer()

            Text(monthTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(UICalendarDesignSystem.Colors.textPrimary)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(UICalendarDesignSystem.Colors.textPrimary)
                }

                Button(action: onOpenCreateSchedule) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(UICalendarDesignSystem.Colors.primary)
                        .clipShape(Circle())
                }
                .accessibilityLabel("New Schedule")
            }
        }
    }

    private var monthGridCard: some View {
        UICalendarCard {
            VStack(spacing: UICalendarDesignSystem.Spacing.small) {
                HStack {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(UICalendarDesignSystem.Colors.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }

                let grid = makeMonthGrid(for: monthDate)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                    ForEach(grid.indices, id: \.self) { index in
                        let day = grid[index]
                        UIDayCell(
                            dayNumber: day.dayNumber,
                            isToday: day.date.map { calendar.isDateInToday($0) } ?? false,
                            isSelected: day.date.map { calendar.isDate($0, inSameDayAs: selectedDate) } ?? false,
                            hasOccurrences: day.date.map { dateHasOccurrences($0) } ?? false
                        ) {
                            guard let date = day.date else { return }
                            selectedDate = date
                        }
                    }
                }
            }
        }
    }

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Selected Day")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(UICalendarDesignSystem.Colors.textPrimary)
                Spacer()
                Button("See All") {
                    onOpenDayList(selectedDate)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(UICalendarDesignSystem.Colors.primary)
            }

            let visible = Array(occurrencesForSelectedDate.prefix(3))
            if visible.isEmpty {
                UICalendarCard {
                    VStack(spacing: 10) {
                        Image(systemName: "calendar")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(UICalendarDesignSystem.Colors.primary)
                        Text("No scheduled occurrences")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(UICalendarDesignSystem.Colors.textPrimary)
                        Text("Tap + to create your first schedule.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(UICalendarDesignSystem.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            } else {
                ForEach(visible) { occurrence in
                    UIOccurrenceCard(
                        occurrence: occurrence,
                        onCreateRunNow: { onCreateRunNow(occurrence) },
                        onViewSchedule: { onViewSchedule(occurrence) }
                    )
                }
            }
        }
    }

    private func shiftMonth(by value: Int) {
        guard let shifted = calendar.date(byAdding: .month, value: value, to: monthDate) else { return }
        monthDate = shifted
        if !calendar.isDate(selectedDate, equalTo: shifted, toGranularity: .month) {
            selectedDate = calendar.startOfDay(for: shifted)
        }
    }

    private func dateHasOccurrences(_ date: Date) -> Bool {
        occurrencesForMonth.contains { calendar.isDate($0.dateTime, inSameDayAs: date) }
    }

    private func makeMonthGrid(for month: Date) -> [MonthGridDay] {
        guard
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
            let dayRange = calendar.range(of: .day, in: .month, for: monthStart)
        else {
            return []
        }

        let weekday = calendar.component(.weekday, from: monthStart) // Sun=1
        let mondayBasedOffset = (weekday + 5) % 7

        var result: [MonthGridDay] = Array(repeating: MonthGridDay(date: nil, dayNumber: nil), count: mondayBasedOffset)
        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                result.append(MonthGridDay(date: date, dayNumber: day))
            }
        }
        while result.count % 7 != 0 { result.append(MonthGridDay(date: nil, dayNumber: nil)) }
        return result
    }
}

private struct MonthGridDay {
    let date: Date?
    let dayNumber: Int?
}

#Preview {
    let month = Date()
    let selected = Date()
    let monthOccurrences = UICalendarMockData.occurrencesForMonth(containing: month)
    let dayOccurrences = UICalendarMockData.occurrencesForDay(selected)
    return NavigationStack {
        CalendarHomeView(
            monthDate: .constant(month),
            selectedDate: .constant(selected),
            occurrencesForMonth: monthOccurrences,
            occurrencesForSelectedDate: dayOccurrences,
            onOpenDayList: { _ in },
            onOpenCreateSchedule: {},
            onCreateRunNow: { _ in },
            onViewSchedule: { _ in }
        )
    }
}
