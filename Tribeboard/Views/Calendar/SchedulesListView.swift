import SwiftUI

struct UIScheduleTemplate: Identifiable, Hashable {
    let id: UUID
    var title: String
    var timeString: String
    var recurrenceLabel: String
    var driverName: String
    var passengers: [String]
    var stopsSummary: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        title: String,
        timeString: String,
        recurrenceLabel: String,
        driverName: String,
        passengers: [String],
        stopsSummary: String,
        isEnabled: Bool
    ) {
        self.id = id
        self.title = title
        self.timeString = timeString
        self.recurrenceLabel = recurrenceLabel
        self.driverName = driverName
        self.passengers = passengers
        self.stopsSummary = stopsSummary
        self.isEnabled = isEnabled
    }
}

enum UIOccurrenceStatus: String, Hashable {
    case upcoming
    case created
}

struct UIOccurrence: Identifiable, Hashable {
    let id: UUID
    var date: Date
    var timeString: String
    var status: UIOccurrenceStatus

    init(
        id: UUID = UUID(),
        date: Date,
        timeString: String,
        status: UIOccurrenceStatus
    ) {
        self.id = id
        self.date = date
        self.timeString = timeString
        self.status = status
    }
}

struct SchedulesListView: View {
    @State private var schedules: [UIScheduleTemplate] = Self.seedSchedules
    @State private var isShowingEditor = false
    @State private var isShowingEditorPlaceholder = false

    // Keep this UI-only gate so there is a fallback path.
    private let supportsScheduleEditor = true

    var body: some View {
        NavigationStack {
            ZStack {
                CalendarUITheme.offWhite.ignoresSafeArea()

                if schedules.isEmpty {
                    emptyState
                        .padding(16)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach($schedules) { $schedule in
                                scheduleCard(schedule: $schedule)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Schedules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("+ New") {
                        if supportsScheduleEditor {
                            isShowingEditor = true
                        } else {
                            isShowingEditorPlaceholder = true
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingEditor) {
                ScheduleEditorView(mode: .create) { saved in
                    schedules.append(UIScheduleTemplate(savedSchedule: saved))
                }
            }
            .sheet(isPresented: $isShowingEditorPlaceholder) {
                SchedulePlaceholderSheet(
                    title: "Schedule Editor",
                    message: "ScheduleEditorView is not available in this target yet."
                )
            }
        }
    }

    private func scheduleCard(schedule: Binding<UIScheduleTemplate>) -> some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 12) {
                NavigationLink {
                    ScheduleDetailView(schedule: schedule) {
                        schedules.removeAll { $0.id == schedule.wrappedValue.id }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(schedule.wrappedValue.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(CalendarUITheme.textPrimary)

                        Text("\(schedule.wrappedValue.timeString) • \(schedule.wrappedValue.recurrenceLabel)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(CalendarUITheme.textSecondary)

                        Text("Driver: \(schedule.wrappedValue.driverName)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(CalendarUITheme.textSecondary)

                        Text("Passengers: \(schedule.wrappedValue.passengers.joined(separator: ", "))")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(CalendarUITheme.textSecondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                Toggle("Enabled", isOn: schedule.isEnabled)
                    .font(.system(size: 15, weight: .semibold))
                    .tint(CalendarUITheme.indigo)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(CalendarUITheme.indigo)

            Text("No schedules yet")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(CalendarUITheme.textPrimary)

            Text("Create your first schedule to start generating upcoming runs.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CalendarUITheme.textSecondary)
                .multilineTextAlignment(.center)

            Button("Create Schedule") {
                if supportsScheduleEditor {
                    isShowingEditor = true
                } else {
                    isShowingEditorPlaceholder = true
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(CalendarUITheme.indigo)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private static let seedSchedules: [UIScheduleTemplate] = [
        UIScheduleTemplate(
            title: "School Dropoff",
            timeString: "06:45 AM",
            recurrenceLabel: "Weekdays",
            driverName: "Tafadzwa",
            passengers: ["TJ", "Tawana"],
            stopsSummary: "Home -> School",
            isEnabled: true
        ),
        UIScheduleTemplate(
            title: "School Pickup",
            timeString: "02:30 PM",
            recurrenceLabel: "Weekdays",
            driverName: "Tafadzwa",
            passengers: ["TJ", "Tawana"],
            stopsSummary: "School -> Home",
            isEnabled: true
        )
    ]
}

extension UIScheduleTemplate {
    init(savedSchedule: CalendarMockModel.UISchedule) {
        self.init(
            id: savedSchedule.id,
            title: savedSchedule.title,
            timeString: savedSchedule.timeString,
            recurrenceLabel: savedSchedule.recurrenceLabel,
            driverName: savedSchedule.driverName,
            passengers: savedSchedule.passengerNames,
            stopsSummary: savedSchedule.stops.map(\.label).joined(separator: " -> "),
            isEnabled: savedSchedule.isEnabled
        )
    }

    var asCalendarSchedule: CalendarMockModel.UISchedule {
        let stopLabels = stopsSummary
            .components(separatedBy: "->")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let normalizedStops = stopLabels.enumerated().map { index, label in
            CalendarMockModel.UIStop(
                type: index == 0 ? "Pickup" : "Dropoff",
                label: label,
                address: ""
            )
        }

        return CalendarMockModel.UISchedule(
            id: id,
            title: title,
            timeString: timeString,
            recurrenceLabel: recurrenceLabel,
            driverName: driverName,
            passengerNames: passengers,
            isEnabled: isEnabled,
            stops: normalizedStops.isEmpty
                ? [
                    .init(type: "Pickup", label: "Home", address: ""),
                    .init(type: "Dropoff", label: "School", address: "")
                ]
                : normalizedStops
        )
    }
}

#Preview {
    SchedulesListView()
}
