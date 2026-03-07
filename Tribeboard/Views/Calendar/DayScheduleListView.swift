import SwiftUI

struct DayScheduleListView: View {
    @EnvironmentObject private var scheduleDataSource: ScheduleDataSource
    @EnvironmentObject private var runDataSource: RunDataSource
    let date: Date

    @State private var occurrences: [CalendarMockModel.UIScheduleOccurrence]
    @State private var editorMode: ScheduleEditorView.Mode = .create
    @State private var isShowingEditor = false
    @State private var actionMessage: String?

    init(date: Date, occurrences: [CalendarMockModel.UIScheduleOccurrence]) {
        self.date = date
        _occurrences = State(initialValue: occurrences.sorted { $0.date < $1.date })
    }

    var body: some View {
        ZStack {
            CalendarUITheme.offWhite.ignoresSafeArea()

            if occurrences.isEmpty {
                emptyState
                    .padding(16)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        if let actionMessage {
                            Text(actionMessage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(CalendarUITheme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        ForEach(occurrences.indices, id: \.self) { index in
                            let occurrence = occurrences[index]
                            let isPersistedCreated = isRunAlreadyCreated(for: occurrence)
                            CalendarOccurrenceCard(
                                title: occurrence.schedule.title,
                                time: occurrence.schedule.timeString,
                                driver: occurrence.schedule.driverName,
                                passengers: occurrence.schedule.passengerNames,
                                isCreated: occurrence.status == .alreadyCreated || isPersistedCreated,
                                subtitle: occurrence.subtitle,
                                onTap: {
                                    editorMode = .edit(occurrence.schedule)
                                    isShowingEditor = true
                                },
                                onCreateRunNow: {
                                    Task {
                                        await createRunNow(for: index)
                                    }
                                }
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle(formattedDate(date))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("New") {
                    editorMode = .create
                    isShowingEditor = true
                }
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            NavigationStack {
                ScheduleEditorView(mode: editorMode) { saved in
                    let newOccurrence = CalendarMockModel.UIScheduleOccurrence(
                        schedule: saved,
                        date: date,
                        status: .none,
                        subtitle: saved.recurrenceLabel
                    )
                    switch editorMode {
                    case .create:
                        occurrences.append(newOccurrence)
                    case let .edit(existing):
                        if let idx = occurrences.firstIndex(where: { $0.schedule.id == existing.id }) {
                            occurrences[idx].schedule = saved
                        } else {
                            occurrences.append(newOccurrence)
                        }
                    }
                    occurrences.sort { $0.date < $1.date }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(CalendarUITheme.indigo)
            Text("No schedules for this day")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(CalendarUITheme.textPrimary)
            UICalendarActionButton(title: "Create a Schedule") {
                editorMode = .create
                isShowingEditor = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM"
        return formatter.string(from: date)
    }

    private func createRunNow(for index: Int) async {
        guard occurrences.indices.contains(index) else { return }
        let occurrence = occurrences[index]
        guard let template = templateForOccurrence(occurrence) else {
            actionMessage = "Unable to find matching schedule template."
            return
        }

        let created = await runDataSource.createRun(template: template, date: date)
        if created {
            occurrences[index].status = .alreadyCreated
            actionMessage = "Created run for \(template.name)."
        } else {
            actionMessage = runDataSource.lastError ?? "Run already exists for \(template.name)."
        }
    }

    private func isRunAlreadyCreated(for occurrence: CalendarMockModel.UIScheduleOccurrence) -> Bool {
        guard let template = templateForOccurrence(occurrence) else { return false }
        let dayRuns = runDataSource.runsForDay(date)
        return dayRuns.contains { $0.templateId == template.id }
    }

    private func templateForOccurrence(_ occurrence: CalendarMockModel.UIScheduleOccurrence) -> SystemDomain.ScheduleTemplate? {
        if let exact = scheduleDataSource.templates.first(where: { $0.id == occurrence.schedule.id }) {
            return exact
        }
        let normalizedName = occurrence.schedule.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let (hour, minute) = parseHourMinute(from: occurrence.schedule.timeString) else {
            return nil
        }
        return scheduleDataSource.templates.first {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(normalizedName) == .orderedSame
            && $0.hour == hour
            && $0.minute == minute
        }
    }

    private func parseHourMinute(from value: String) -> (Int, Int)? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        guard let parsed = formatter.date(from: value) else { return nil }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: parsed)
        guard let hour = comps.hour, let minute = comps.minute else { return nil }
        return (hour, minute)
    }
}

private struct UICalendarActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(CalendarUITheme.indigo)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(minHeight: 44)
    }
}

#Preview {
    NavigationStack {
        DayScheduleListView(
            date: Date(),
            occurrences: []
        )
    }
}
