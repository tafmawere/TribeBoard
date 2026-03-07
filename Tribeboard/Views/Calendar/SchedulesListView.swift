import SwiftUI

// Legacy UI schedule models kept for compatibility with existing detail screens.
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

    init(id: UUID = UUID(), date: Date, timeString: String, status: UIOccurrenceStatus) {
        self.id = id
        self.date = date
        self.timeString = timeString
        self.status = status
    }
}

struct SchedulesListView: View {
    @EnvironmentObject private var scheduleDataSource: ScheduleDataSource
    @EnvironmentObject private var runDataSource: RunDataSource

    @State private var isShowingEditor = false
    @State private var editingTemplate: SystemDomain.ScheduleTemplate?
    @State private var generationMessage: String?

    var body: some View {
        ZStack {
            CalendarUITheme.offWhite.ignoresSafeArea()

            if scheduleDataSource.templates.isEmpty && !scheduleDataSource.isLoading {
                emptyState
                    .padding(16)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        if let generationMessage {
                            generationBanner(text: generationMessage)
                        }
                        ForEach(scheduleDataSource.templates) { template in
                            scheduleCard(template)
                        }
                    }
                    .padding(16)
                }
                .refreshable {
                    await scheduleDataSource.refresh()
                }
            }
        }
        .navigationTitle("Schedules")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
#if DEBUG
                Button("Clear Runs") {
                    Task {
                        try? await SystemBootstrap.clearAllRuns()
                        await runDataSource.refresh()
                        generationMessage = "Cleared all runs"
                    }
                }
#endif
                Button("Generate Runs") {
                    Task {
                        let newRuns = await scheduleDataSource.generateRuns(daysAhead: 14)
                        await runDataSource.refresh()
                        generationMessage = newRuns == 0
                            ? "No new runs (already up to date)"
                            : "Generated \(newRuns) new runs"
                    }
                }
                .disabled(scheduleDataSource.isWorking)

                Button("New Schedule") {
                    editingTemplate = nil
                    isShowingEditor = true
                }
            }
        }
        .task {
            await scheduleDataSource.refresh()
#if DEBUG
            await scheduleDataSource.seedDemoIfNeeded()
#endif
        }
        .sheet(isPresented: $isShowingEditor, onDismiss: {
            Task { await scheduleDataSource.refresh() }
        }) {
            NavigationStack {
                ScheduleEditorView(mode: editorMode) { _ in
                    // Real persistence happens in ScheduleDataSource.
                }
            }
        }
    }

    private var editorMode: ScheduleEditorView.Mode {
        guard let editingTemplate else { return .create }
        return .edit(editingTemplate.asCalendarSchedule)
    }

    private func scheduleCard(_ template: SystemDomain.ScheduleTemplate) -> some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    editingTemplate = template
                    isShowingEditor = true
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(template.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(CalendarUITheme.textPrimary)

                        Text("\(timeText(template)) • \(weekdaysLabel(template.weekdays))")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(CalendarUITheme.textSecondary)

                        Text("\(template.stops.count) stops")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(CalendarUITheme.textSecondary)

                        AppBadge(
                            text: template.isActive ? "ENABLED" : "DISABLED",
                            style: template.isActive ? .success : .neutral
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                Toggle("Enabled", isOn: Binding(
                    get: { template.isActive },
                    set: { newValue in
                        Task { await scheduleDataSource.toggleEnabled(id: template.id, enabled: newValue) }
                    }
                ))
                .font(.system(size: 15, weight: .semibold))
                .tint(CalendarUITheme.indigo)
            }
        }
    }

    private func generationBanner(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(CalendarUITheme.indigo)
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CalendarUITheme.textPrimary)
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(CalendarUITheme.indigo)

            Text("No schedules yet")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(CalendarUITheme.textPrimary)

            Text("Create a schedule to generate recurring runs.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CalendarUITheme.textSecondary)
                .multilineTextAlignment(.center)

            Button("Create Schedule") {
                editingTemplate = nil
                isShowingEditor = true
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(CalendarUITheme.indigo)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

#if DEBUG
            if AppConfig.isDemoFlowEnabled {
                Button("Seed Demo Schedules") {
                    Task { await scheduleDataSource.seedDemoIfNeeded() }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CalendarUITheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
#endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func weekdaysLabel(_ weekdays: Set<Int>) -> String {
        let ordered = [2, 3, 4, 5, 6, 7, 1]
        let labels: [Int: String] = [1: "Sun", 2: "Mon", 3: "Tue", 4: "Wed", 5: "Thu", 6: "Fri", 7: "Sat"]
        let names = ordered.compactMap { day in
            weekdays.contains(day) ? labels[day] : nil
        }
        if names == ["Mon", "Tue", "Wed", "Thu", "Fri"] { return "Weekdays" }
        return names.joined(separator: ", ")
    }

    private func timeText(_ template: SystemDomain.ScheduleTemplate) -> String {
        var components = DateComponents()
        components.hour = template.hour
        components.minute = template.minute
        let date = Calendar.current.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
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
            stops: normalizedStops
        )
    }
}

#Preview {
    NavigationStack {
        SchedulesListView()
            .environmentObject(ScheduleDataSource())
            .environmentObject(RunDataSource())
    }
}
