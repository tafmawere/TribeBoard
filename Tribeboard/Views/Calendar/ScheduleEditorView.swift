import SwiftUI

struct ScheduleEditorView: View {
    enum Mode {
        case create
        case edit(CalendarMockModel.UISchedule)
    }

    private struct EditableStop: Identifiable {
        let id: UUID
        var label: String
        var latitude: String
        var longitude: String
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var scheduleDataSource: ScheduleDataSource

    let mode: Mode
    let isOnboardingContext: Bool
    let onSave: (CalendarMockModel.UISchedule) -> Void

    @State private var title: String
    @State private var time: Date
    @State private var weekdays: Set<Int>
    @State private var stops: [EditableStop]
    @State private var isEnabled: Bool
    @State private var showDeleteAlert = false

    private let weekdayItems: [(Int, String)] = [(2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")]
    private let templateId: UUID

    init(
        mode: Mode,
        isOnboardingContext: Bool = false,
        onSave: @escaping (CalendarMockModel.UISchedule) -> Void
    ) {
        self.mode = mode
        self.isOnboardingContext = isOnboardingContext
        self.onSave = onSave

        let defaultTime = Calendar.current.date(from: DateComponents(hour: 6, minute: 45)) ?? Date()

        switch mode {
        case .create:
            self.templateId = UUID()
            _title = State(initialValue: "")
            _time = State(initialValue: defaultTime)
            _weekdays = State(initialValue: [2, 3, 4, 5, 6])
            _stops = State(initialValue: [
                EditableStop(id: UUID(), label: "Home", latitude: "-17.8249", longitude: "31.0530"),
                EditableStop(id: UUID(), label: "Friend", latitude: "-17.8150", longitude: "31.0602"),
                EditableStop(id: UUID(), label: "School", latitude: "-17.8015", longitude: "31.0476")
            ])
            _isEnabled = State(initialValue: true)
        case let .edit(schedule):
            self.templateId = schedule.id
            _title = State(initialValue: schedule.title)
            _time = State(initialValue: Self.timeFromString(schedule.timeString) ?? defaultTime)
            _weekdays = State(initialValue: Self.weekdaysFromRecurrence(schedule.recurrenceLabel))
            _stops = State(initialValue: schedule.stops.enumerated().map { _, stop in
                let split = stop.address.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                return EditableStop(
                    id: UUID(),
                    label: stop.label,
                    latitude: split.first ?? "",
                    longitude: split.count > 1 ? split[1] : ""
                )
            })
            _isEnabled = State(initialValue: schedule.isEnabled)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                detailsCard
                weekdaysCard
                stopsCard
                enabledCard
                if case .edit = mode {
                    deleteCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(CalendarUITheme.offWhite.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    performSave()
                }
                .disabled(scheduleDataSource.isWorking || !canSave)
            }
        }
        .alert("Delete Schedule?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    await scheduleDataSource.delete(id: templateId)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the schedule template.")
        }
        .alert(
            "Could Not Save Schedule",
            isPresented: Binding(
                get: { scheduleDataSource.lastError != nil },
                set: { isPresented in
                    if !isPresented {
                        scheduleDataSource.lastError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                scheduleDataSource.lastError = nil
            }
        } message: {
            Text(scheduleDataSource.lastError ?? "Unknown validation error.")
        }
    }

    private var bottomActionBar: some View {
        HStack(spacing: 10) {
            Button("Cancel") {
                dismiss()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(CalendarUITheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.black.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                performSave()
            } label: {
                HStack(spacing: 8) {
                    if scheduleDataSource.isWorking {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(scheduleDataSource.isWorking ? "Saving..." : "Save")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(CalendarUITheme.indigo)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(scheduleDataSource.isWorking || !canSave)
            .opacity(scheduleDataSource.isWorking || !canSave ? 0.7 : 1.0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private var detailsCard: some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Schedule Details")
                textField("Title", text: $title)
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .tint(CalendarUITheme.indigo)
                if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    validationText("Title is required.")
                }
            }
        }
    }

    private var weekdaysCard: some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Weekdays")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                    ForEach(weekdayItems, id: \.0) { day, label in
                        weekdayChip(day: day, label: label)
                    }
                }
                if weekdays.isEmpty {
                    validationText("Select at least one weekday.")
                }
            }
        }
    }

    private var stopsCard: some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionTitle("Stops")
                    Spacer()
                    Button("Add Stop") {
                        guard stops.count < 3 else { return }
                        stops.append(EditableStop(id: UUID(), label: "", latitude: "", longitude: ""))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CalendarUITheme.indigo)
                    .disabled(stops.count >= 3)
                }

                ForEach(stops.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Stop \(index + 1)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(CalendarUITheme.textPrimary)
                            Spacer()
                            if stops.count > 2 {
                                Button {
                                    stops.remove(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        textField("Label", text: $stops[index].label)
                        HStack(spacing: 8) {
                            textField("Latitude", text: $stops[index].latitude)
                            textField("Longitude", text: $stops[index].longitude)
                        }
                    }
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if let stopsValidationMessage {
                    validationText(stopsValidationMessage)
                }
            }
        }
    }

    private var enabledCard: some View {
        CalendarCard {
            Toggle("Enabled", isOn: $isEnabled)
                .font(.system(size: 15, weight: .semibold))
                .tint(CalendarUITheme.indigo)
        }
    }

    private var deleteCard: some View {
        CalendarCard {
            Button(role: .destructive) {
                showDeleteAlert = true
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
        }
    }

    private var navTitle: String {
        switch mode {
        case .create:
            return "New Schedule"
        case .edit:
            return "Edit Schedule"
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !weekdays.isEmpty &&
        hasValidStops
    }

    private var hasValidStops: Bool {
        stopsValidationMessage == nil
    }

    private var stopsValidationMessage: String? {
        guard stops.count >= 2 else {
            return "Add at least 2 stops."
        }
        for stop in stops {
            if stop.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Each stop must have a label."
            }
            guard let lat = Double(stop.latitude), let lon = Double(stop.longitude) else {
                return "Each stop must have valid latitude and longitude values."
            }
            if !(-90.0...90.0).contains(lat) || !(-180.0...180.0).contains(lon) {
                return "Latitude must be -90...90 and longitude must be -180...180."
            }
        }
        return nil
    }

    private func saveTemplate() async -> Bool {
        let existing = scheduleDataSource.templates.first(where: { $0.id == templateId })
        let validStops = stops.enumerated().compactMap { index, stop -> SystemDomain.Stop? in
            guard
                !stop.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                let lat = Double(stop.latitude),
                let lon = Double(stop.longitude)
            else { return nil }
            let existingStops = existing?.stops.sorted { $0.order < $1.order } ?? []
            let existingStopId = index < existingStops.count ? existingStops[index].id : nil
            return SystemDomain.Stop(
                id: existingStopId ?? UUID(),
                name: stop.label.trimmingCharacters(in: .whitespacesAndNewlines),
                latitude: lat,
                longitude: lon,
                order: index
            )
        }

        var components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let template = SystemDomain.ScheduleTemplate(
            id: templateId,
            name: title.trimmingCharacters(in: .whitespacesAndNewlines),
            childId: existing?.childId ?? UUID(),
            driverId: existing?.driverId,
            weekdays: weekdays,
            hour: components.hour ?? 6,
            minute: components.minute ?? 45,
            stops: validStops,
            isActive: isEnabled,
            createdAt: existing?.createdAt ?? Date()
        )

        await scheduleDataSource.upsert(template)
        guard scheduleDataSource.lastError == nil else {
            return false
        }
        onSave(template.asCalendarSchedule)
        return true
    }

    private func performSave() {
        guard canSave else { return }
        Task {
            let saved = await saveTemplate()
            if saved {
                dismiss()
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(CalendarUITheme.textPrimary)
    }

    private func textField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CalendarUITheme.textSecondary)
            TextField(title, text: text)
                .foregroundStyle(.primary)
                .tint(CalendarUITheme.indigo)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func weekdayChip(day: Int, label: String) -> some View {
        let isSelected = weekdays.contains(day)
        return Button {
            if isSelected {
                weekdays.remove(day)
            } else {
                weekdays.insert(day)
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : CalendarUITheme.textPrimary)
                .frame(minWidth: 44)
                .frame(height: 36)
                .background(isSelected ? CalendarUITheme.indigo : Color(uiColor: .tertiarySystemBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func validationText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.red.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func timeFromString(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.date(from: value)
    }

    private static func weekdaysFromRecurrence(_ recurrenceLabel: String) -> Set<Int> {
        let lowered = recurrenceLabel.lowercased()
        if lowered.contains("weekday") || lowered.contains("school") {
            return [2, 3, 4, 5, 6]
        }
        return [2, 3, 4, 5, 6]
    }
}

extension SystemDomain.ScheduleTemplate {
    var asCalendarSchedule: CalendarMockModel.UISchedule {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return CalendarMockModel.UISchedule(
            id: id,
            title: name,
            timeString: formatter.string(from: date),
            recurrenceLabel: "Custom",
            driverName: driverId != nil ? "Assigned Driver" : "Unassigned",
            passengerNames: ["Passenger"],
            isEnabled: isActive,
            stops: stops.sorted { $0.order < $1.order }.map {
                CalendarMockModel.UIStop(
                    type: $0.order == 0 ? "Pickup" : "Dropoff",
                    label: $0.name,
                    address: "\($0.latitude), \($0.longitude)"
                )
            }
        )
    }
}

#Preview {
    NavigationStack {
        ScheduleEditorView(mode: .create) { _ in }
            .environmentObject(ScheduleDataSource())
    }
}
