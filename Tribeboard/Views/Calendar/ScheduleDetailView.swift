import SwiftUI

struct ScheduleDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext

    @Binding var schedule: UIScheduleTemplate
    let onDelete: () -> Void

    @State private var upcomingOccurrences: [UIOccurrence]
    @State private var isShowingEditor = false
    @State private var isShowingEditorPlaceholder = false
    @State private var isShowingDeleteConfirmation = false

    // Keep this UI-only gate so there is a fallback path.
    private let supportsScheduleEditor = true

    init(schedule: Binding<UIScheduleTemplate>, onDelete: @escaping () -> Void) {
        self._schedule = schedule
        self.onDelete = onDelete
        _upcomingOccurrences = State(initialValue: Self.mockOccurrences(for: schedule.wrappedValue))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                titleCard
                stopsCard
                upcomingCard
                actionsCard
            }
            .padding(16)
        }
        .background(CalendarUITheme.offWhite.ignoresSafeArea())
        .navigationTitle("Schedule Detail")
        .navigationBarTitleDisplayMode(.inline)
        .deleteScheduleConfirmation(
            isPresented: $isShowingDeleteConfirmation,
            scheduleTitle: schedule.title
        ) {
            onDelete()
            dismiss()
        }
        .sheet(isPresented: $isShowingEditor) {
            NavigationStack {
                ScheduleEditorView(mode: .edit(schedule.asCalendarSchedule)) { saved in
                    schedule = UIScheduleTemplate(savedSchedule: saved)
                    upcomingOccurrences = Self.mockOccurrences(for: schedule)
                }
            }
        }
        .sheet(isPresented: $isShowingEditorPlaceholder) {
            SchedulePlaceholderSheet(
                title: "Schedule Editor",
                message: "ScheduleEditorView is not available in this target yet."
            )
        }
    }

    private var titleCard: some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(schedule.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(CalendarUITheme.textPrimary)

                Text("\(schedule.timeString) • \(schedule.recurrenceLabel)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CalendarUITheme.textSecondary)

                Text("Driver: \(schedule.driverName)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CalendarUITheme.textSecondary)

                Text("Passengers: \(schedule.passengers.joined(separator: ", "))")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(CalendarUITheme.textSecondary)
                    .lineLimit(2)

                CalendarBadge(
                    text: schedule.isEnabled ? "Enabled" : "Disabled",
                    color: schedule.isEnabled ? CalendarUITheme.success : CalendarUITheme.warning
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var stopsCard: some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Stops")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CalendarUITheme.textPrimary)

                ForEach(parsedStops.indices, id: \.self) { index in
                    let stop = parsedStops[index]
                    HStack(spacing: 10) {
                        Circle()
                            .fill(index == 0 ? CalendarUITheme.indigo : CalendarUITheme.warning)
                            .frame(width: 8, height: 8)
                        Text(index == 0 ? "Pickup" : "Stop \(index + 1)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CalendarUITheme.textSecondary)
                        Text(stop)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(CalendarUITheme.textPrimary)
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var upcomingCard: some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Upcoming Occurrences")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CalendarUITheme.textPrimary)

                ForEach(upcomingOccurrences.indices, id: \.self) { index in
                    let occurrence = upcomingOccurrences[index]

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(Self.formattedDate(occurrence.date))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(CalendarUITheme.textPrimary)
                            Spacer()
                            CalendarBadge(
                                text: occurrence.status == .created ? "Created" : "Upcoming",
                                color: occurrence.status == .created ? CalendarUITheme.success : CalendarUITheme.indigo
                            )
                        }

                        Text(occurrence.timeString)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(CalendarUITheme.textSecondary)

                        Button {
                            upcomingOccurrences[index].status = .created
                        } label: {
                            Text(occurrence.status == .created ? "Run Created" : "Create Run Now")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(
                                    occurrence.status == .created
                                        ? CalendarUITheme.success
                                        : CalendarUITheme.indigo
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(occurrence.status == .created)
                        .opacity(occurrence.status == .created ? 0.85 : 1.0)
                    }
                    .padding(12)
                    .background(Color.gray.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actionsCard: some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Actions")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CalendarUITheme.textPrimary)

                Button("Edit Schedule") {
                    guard backendHouseholdContext.canEditSchedules else { return }
                    if supportsScheduleEditor {
                        isShowingEditor = true
                    } else {
                        isShowingEditorPlaceholder = true
                    }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(CalendarUITheme.indigo)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Toggle("Enabled", isOn: $schedule.isEnabled)
                    .font(.system(size: 15, weight: .semibold))
                    .tint(CalendarUITheme.indigo)
                    .disabled(!backendHouseholdContext.canEditSchedules)

                Button(role: .destructive) {
                    guard backendHouseholdContext.canEditSchedules else { return }
                    isShowingDeleteConfirmation = true
                } label: {
                    Text("Delete Schedule")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!backendHouseholdContext.canEditSchedules)
                if !backendHouseholdContext.canEditSchedules {
                    Text("Only organisers can manage schedules.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var parsedStops: [String] {
        let parsed = schedule.stopsSummary
            .components(separatedBy: "->")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if parsed.isEmpty {
            return ["Home", "School"]
        }
        return parsed
    }

    private static func mockOccurrences(for schedule: UIScheduleTemplate) -> [UIOccurrence] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return UIOccurrence(
                date: date,
                timeString: schedule.timeString,
                status: .upcoming
            )
        }
    }

    private static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        ScheduleDetailView(
            schedule: .constant(
                UIScheduleTemplate(
                    title: "School Dropoff",
                    timeString: "06:45 AM",
                    recurrenceLabel: "Weekdays",
                    driverName: "Tafadzwa",
                    passengers: ["TJ", "Tawana"],
                    stopsSummary: "Home -> School",
                    isEnabled: true
                )
            )
        ) {
            // UI-only preview action.
        }
    }
}
