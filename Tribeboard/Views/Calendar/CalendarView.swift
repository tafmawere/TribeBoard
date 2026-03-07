import SwiftUI
import Foundation

enum CalendarMockModel {
    struct UIStop: Identifiable, Hashable {
        let id: UUID
        var type: String
        var label: String
        var address: String

        init(id: UUID = UUID(), type: String, label: String, address: String) {
            self.id = id
            self.type = type
            self.label = label
            self.address = address
        }
    }

    struct UISchedule: Identifiable, Hashable {
        let id: UUID
        var title: String
        var timeString: String
        var recurrenceLabel: String
        var driverName: String
        var passengerNames: [String]
        var isEnabled: Bool
        var stops: [UIStop]

        init(
            id: UUID = UUID(),
            title: String,
            timeString: String,
            recurrenceLabel: String,
            driverName: String,
            passengerNames: [String],
            isEnabled: Bool,
            stops: [UIStop]
        ) {
            self.id = id
            self.title = title
            self.timeString = timeString
            self.recurrenceLabel = recurrenceLabel
            self.driverName = driverName
            self.passengerNames = passengerNames
            self.isEnabled = isEnabled
            self.stops = stops
        }
    }

    enum OccurrenceStatus: Hashable {
        case none
        case alreadyCreated
    }

    struct UIScheduleOccurrence: Identifiable, Hashable {
        let id: UUID
        var schedule: UISchedule
        var date: Date
        var status: OccurrenceStatus
        var subtitle: String

        init(
            id: UUID = UUID(),
            schedule: UISchedule,
            date: Date,
            status: OccurrenceStatus,
            subtitle: String
        ) {
            self.id = id
            self.schedule = schedule
            self.date = date
            self.status = status
            self.subtitle = subtitle
        }
    }
}

struct CalendarView: View {
    @EnvironmentObject private var scheduleDataSource: ScheduleDataSource
    @EnvironmentObject private var runDataSource: RunDataSource
    var suggestedRunsProvider: (() -> [RunSuggestion])? = nil
    @State private var monthDate = Date()
    @State private var selectedDate = Date()
    @State private var goToDaySchedule = false
    @State private var dayScheduleDate = Date()

    @State private var schedules: [CalendarMockModel.UISchedule] = CalendarView.seedSchedules()
    @State private var createdOccurrenceIDs: Set<UUID> = []

    @State private var editorMode: ScheduleEditorView.Mode = .create
    @State private var isShowingEditor = false
    @State private var dayActionMessage: String?

    private let calendar = Calendar.current
    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        ZStack {
            CalendarUITheme.offWhite.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    monthHeader
                    monthGridCard
                    selectedDaySchedulesSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goToDaySchedule) {
            DayScheduleListView(
                date: dayScheduleDate,
                occurrences: occurrencesForDay(dayScheduleDate)
            )
        }
        .sheet(isPresented: $isShowingEditor) {
            NavigationStack {
                ScheduleEditorView(mode: editorMode) { savedSchedule in
                    if let index = schedules.firstIndex(where: { $0.id == savedSchedule.id }) {
                        schedules[index] = savedSchedule
                    } else {
                        schedules.append(savedSchedule)
                    }
                }
            }
        }
        .onAppear {
            Task { await scheduleDataSource.refresh() }
        }
        .onChange(of: isShowingEditor) { _, isPresented in
            if !isPresented {
                Task { await scheduleDataSource.refresh() }
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CalendarUITheme.textPrimary)
                    .frame(minWidth: 44, minHeight: 44)
            }

            Spacer()

            Text(formattedMonth(monthDate))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(CalendarUITheme.textPrimary)

            Spacer()

            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CalendarUITheme.textPrimary)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
    }

    private var monthGridCard: some View {
        CalendarCard {
            VStack(spacing: 10) {
                HStack {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CalendarUITheme.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                let grid = monthGrid(for: monthDate)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                    ForEach(grid.indices, id: \.self) { index in
                        let item = grid[index]
                        CalendarDayCell(
                            dayNumber: item.dayNumber,
                            isToday: item.date.map(calendar.isDateInToday) ?? false,
                            isSelected: item.date.map { calendar.isDate($0, inSameDayAs: selectedDate) } ?? false,
                            hasOccurrences: item.date.map { !occurrencesForDay($0).isEmpty } ?? false
                        ) {
                            guard let date = item.date else { return }
                            selectedDate = date
                            dayScheduleDate = date
                            goToDaySchedule = true
                        }
                    }
                }
            }
        }
    }

    private var selectedDaySchedulesSection: some View {
        let dayRuns = runDataSource.runsForDay(selectedDate, calendar: calendar)
        let daySuggestions = suggestedRunsForSelectedDate()
        let completedCount = dayRuns.filter { $0.status == .completed || $0.status == .cancelled }.count
        let scheduledCount = dayRuns.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Runs for \(formattedDayHeader(selectedDate))")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(CalendarUITheme.textPrimary)
                Spacer()
            }

            Text("\(scheduledCount) Scheduled • \(completedCount) Completed")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(CalendarUITheme.textSecondary)

            if let dayActionMessage {
                CalendarCard {
                    Text(dayActionMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CalendarUITheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            schedulesForSelectedDaySection

            if !daySuggestions.isEmpty {
                Text("Suggested")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CalendarUITheme.textPrimary)
                    .padding(.top, 2)

                LazyVStack(spacing: 10) {
                    ForEach(daySuggestions) { suggestion in
                        CalendarCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(suggestion.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(CalendarUITheme.textPrimary)
                                    Spacer()
                                    Text("Suggested")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(CalendarUITheme.indigo)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(CalendarUITheme.indigo.opacity(0.12))
                                        .clipShape(Capsule())
                                }

                                Text("\(suggestion.originName) → \(suggestion.destinationName)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(CalendarUITheme.textSecondary)

                                HStack {
                                    Text(timeString(suggestion.proposedStart))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(CalendarUITheme.indigo)
                                    Spacer()
                                    Text(suggestion.driverName ?? "No driver set")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(CalendarUITheme.textSecondary)
                                }
                            }
                        }
                    }
                }
            }

            if dayRuns.isEmpty {
                CalendarCard {
                    VStack(spacing: 10) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(CalendarUITheme.indigo)
                        Text("No runs scheduled for this day.")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(CalendarUITheme.textPrimary)
                        Button {
                            editorMode = .create
                            isShowingEditor = true
                        } label: {
                            Text("Create Run")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(CalendarUITheme.indigo)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(dayRuns) { run in
                        let uiRun = RunUIAdapter.mapToUIRun(run)
                        CalendarCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(uiRun.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(CalendarUITheme.textPrimary)
                                    Spacer()
                                    AppBadge(
                                        text: uiRun.status.rawValue.uppercased(),
                                        style: uiRun.status == .active ? .live : (uiRun.status == .completed ? .success : .info)
                                    )
                                }
                                Text(uiRun.scheduledTime)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(CalendarUITheme.textSecondary)
                                Text("\(uiRun.stops.count) stops")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(CalendarUITheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                Button {
                    Task {
                        let newRuns = await scheduleDataSource.generateRuns(daysAhead: 14)
                        await runDataSource.refresh()
                        dayActionMessage = newRuns == 0
                            ? "No new runs (already up to date)"
                            : "Generated \(newRuns) new runs"
                    }
                } label: {
                    Text("Create Runs for This Day")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(CalendarUITheme.indigo)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(Color.white)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(CalendarUITheme.indigo.opacity(0.45), lineWidth: 1.2)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
    }

    private var schedulesForSelectedDaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Schedules for this day")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CalendarUITheme.textPrimary)

            if schedulesForSelectedDay.isEmpty {
                Text("No active schedules match this date.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(CalendarUITheme.textSecondary)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(schedulesForSelectedDay) { template in
                        CalendarCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(template.name)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(CalendarUITheme.textPrimary)
                                Text("\(templateTimeText(template)) • \(weekdaysLabel(template.weekdays))")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(CalendarUITheme.textSecondary)
                                Text("\(template.stops.count) stops")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(CalendarUITheme.textSecondary)
                                Button {
                                    Task {
                                        let created = await runDataSource.createRun(template: template, date: selectedDate)
                                        dayActionMessage = created
                                            ? "Created run for \(template.name)"
                                            : "Run already exists for \(template.name)"
                                    }
                                } label: {
                                    Text("Create Run Now")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(CalendarUITheme.indigo)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private var selectedWeekdayInt: Int {
        calendar.component(.weekday, from: selectedDate)
    }

    private var schedulesForSelectedDay: [SystemDomain.ScheduleTemplate] {
        scheduleDataSource.templates
            .filter { $0.isActive && $0.weekdays.contains(selectedWeekdayInt) }
            .sorted { lhs, rhs in
                if lhs.hour == rhs.hour { return lhs.minute < rhs.minute }
                return lhs.hour < rhs.hour
            }
    }

    private func weekdaysLabel(_ weekdays: Set<Int>) -> String {
        let ordered = [2, 3, 4, 5, 6, 7, 1]
        let labels: [Int: String] = [1: "Sun", 2: "Mon", 3: "Tue", 4: "Wed", 5: "Thu", 6: "Fri", 7: "Sat"]
        let names = ordered.compactMap { day in weekdays.contains(day) ? labels[day] : nil }
        if names == ["Mon", "Tue", "Wed", "Thu", "Fri"] { return "Weekdays" }
        return names.joined(separator: ", ")
    }

    private func templateTimeText(_ template: SystemDomain.ScheduleTemplate) -> String {
        var components = DateComponents()
        components.hour = template.hour
        components.minute = template.minute
        let date = calendar.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func templateTimeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func suggestedRunsForSelectedDate() -> [RunSuggestion] {
        guard let provider = suggestedRunsProvider else { return [] }
        let suggestions = provider()
        return suggestions.filter { Calendar.current.isDate($0.proposedStart, inSameDayAs: selectedDate) }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func occurrencesForDay(_ date: Date) -> [CalendarMockModel.UIScheduleOccurrence] {
        occurrencesForMonth(containing: monthDate).filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func occurrencesForMonth(containing date: Date) -> [CalendarMockModel.UIScheduleOccurrence] {
        guard
            let interval = calendar.dateInterval(of: .month, for: date),
            let range = calendar.range(of: .day, in: .month, for: date)
        else {
            return []
        }

        var generated: [CalendarMockModel.UIScheduleOccurrence] = []
        for day in range {
            guard let dayDate = calendar.date(byAdding: .day, value: day - 1, to: interval.start) else { continue }
            let weekday = calendar.component(.weekday, from: dayDate)
            let isWeekday = (2...6).contains(weekday)

            for schedule in schedules where schedule.isEnabled {
                guard shouldOccur(schedule: schedule, isWeekday: isWeekday) else { continue }

                var timeParts = schedule.timeString.replacingOccurrences(of: " ", with: "").uppercased()
                let isPM = timeParts.hasSuffix("PM")
                timeParts = timeParts.replacingOccurrences(of: "AM", with: "").replacingOccurrences(of: "PM", with: "")
                let components = timeParts.split(separator: ":")
                let parsedHour = Int(components.first ?? "") ?? 7
                let parsedMinute = Int(components.dropFirst().first ?? "") ?? 0
                var hour24 = parsedHour % 12
                if isPM { hour24 += 12 }

                var dc = calendar.dateComponents([.year, .month, .day], from: dayDate)
                dc.hour = hour24
                dc.minute = parsedMinute
                let occurrenceDate = calendar.date(from: dc) ?? dayDate

                var occurrence = CalendarMockModel.UIScheduleOccurrence(
                    id: deterministicOccurrenceID(scheduleID: schedule.id, date: dayDate),
                    schedule: schedule,
                    date: occurrenceDate,
                    status: .none,
                    subtitle: schedule.recurrenceLabel
                )
                if createdOccurrenceIDs.contains(occurrence.id) {
                    occurrence.status = .alreadyCreated
                }
                generated.append(occurrence)
            }
        }
        return generated.sorted { $0.date < $1.date }
    }

    private func shouldOccur(schedule: CalendarMockModel.UISchedule, isWeekday: Bool) -> Bool {
        if schedule.recurrenceLabel.lowercased().contains("weekday") {
            return isWeekday
        }
        return true
    }

    private func deterministicOccurrenceID(scheduleID: UUID, date: Date) -> UUID {
        let dayKey = Int(calendar.startOfDay(for: date).timeIntervalSince1970)
        let seed = scheduleID.uuidString + "-\(dayKey)"
        let hash = abs(seed.hashValue)
        let hex = String(format: "%032llx", UInt64(hash))
        let uuidString = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20).prefix(12))"
        return UUID(uuidString: uuidString) ?? UUID()
    }

    private func shiftMonth(_ value: Int) {
        guard let shifted = calendar.date(byAdding: .month, value: value, to: monthDate) else { return }
        monthDate = shifted
        if !calendar.isDate(selectedDate, equalTo: shifted, toGranularity: .month) {
            selectedDate = calendar.startOfDay(for: shifted)
        }
    }

    private func formattedMonth(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    private func formattedDayHeader(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMM"
        return f.string(from: date)
    }

    private func monthGrid(for month: Date) -> [CalendarGridDay] {
        guard
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
            let dayRange = calendar.range(of: .day, in: .month, for: monthStart)
        else {
            return []
        }

        let weekday = calendar.component(.weekday, from: monthStart) // Sun=1
        let mondayBasedOffset = (weekday + 5) % 7

        var result: [CalendarGridDay] = Array(repeating: CalendarGridDay(date: nil, dayNumber: nil), count: mondayBasedOffset)
        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                result.append(CalendarGridDay(date: date, dayNumber: day))
            }
        }
        while result.count % 7 != 0 {
            result.append(CalendarGridDay(date: nil, dayNumber: nil))
        }
        return result
    }

    private static func seedSchedules() -> [CalendarMockModel.UISchedule] {
        [
            CalendarMockModel.UISchedule(
                title: "School Dropoff",
                timeString: "06:45 AM",
                recurrenceLabel: "Weekdays",
                driverName: "Tafadzwa",
                passengerNames: ["TJ", "Tawana"],
                isEnabled: true,
                stops: [
                    .init(type: "Pickup", label: "Home", address: "123 Maple St"),
                    .init(type: "Dropoff", label: "School", address: "456 School Ave")
                ]
            ),
            CalendarMockModel.UISchedule(
                title: "School Pickup",
                timeString: "02:30 PM",
                recurrenceLabel: "Weekdays",
                driverName: "Tafadzwa",
                passengerNames: ["TJ", "Tawana"],
                isEnabled: true,
                stops: [
                    .init(type: "Pickup", label: "School", address: "456 School Ave"),
                    .init(type: "Dropoff", label: "Home", address: "123 Maple St")
                ]
            )
        ]
    }
}

private struct CalendarGridDay {
    let date: Date?
    let dayNumber: Int?
}

struct CalendarPreviewRootView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Manual Preview Entry")
                    .font(.system(size: 22, weight: .bold))
                NavigationLink("Open Calendar") {
                    CalendarView()
                }
                .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CalendarUITheme.offWhite)
            .navigationTitle("Preview")
        }
    }
}

#Preview {
    CalendarPreviewRootView()
}
