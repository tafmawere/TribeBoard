import SwiftUI

struct DayScheduleListView: View {
    let date: Date

    @State private var occurrences: [CalendarMockModel.UIScheduleOccurrence]
    @State private var editorMode: ScheduleEditorView.Mode = .create
    @State private var isShowingEditor = false

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
                        ForEach(occurrences.indices, id: \.self) { index in
                            let occurrence = occurrences[index]
                            CalendarOccurrenceCard(
                                title: occurrence.schedule.title,
                                time: occurrence.schedule.timeString,
                                driver: occurrence.schedule.driverName,
                                passengers: occurrence.schedule.passengerNames,
                                isCreated: occurrence.status == .alreadyCreated,
                                subtitle: occurrence.subtitle,
                                onTap: {
                                    editorMode = .edit(occurrence.schedule)
                                    isShowingEditor = true
                                },
                                onCreateRunNow: {
                                    occurrences[index].status = .alreadyCreated
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
