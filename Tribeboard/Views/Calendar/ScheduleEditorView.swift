import SwiftUI

struct ScheduleEditorView: View {
    enum Mode {
        case create
        case edit(CalendarMockModel.UISchedule)
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let onSave: (CalendarMockModel.UISchedule) -> Void

    @State private var title: String
    @State private var time: Date
    @State private var recurrence: RecurrenceKind
    @State private var weeklyDays: Set<Int>
    @State private var oneOffDate: Date
    @State private var driverName: String
    @State private var selectedPassengers: Set<String>
    @State private var stops: [CalendarMockModel.UIStop]
    @State private var isEnabled: Bool

    private let weekdayItems: [(Int, String)] = [(2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")]
    private let drivers = ["Tafadzwa", "Rue"]
    private let passengerPool = ["TJ", "Tawana", "Rue"]

    init(mode: Mode, onSave: @escaping (CalendarMockModel.UISchedule) -> Void) {
        self.mode = mode
        self.onSave = onSave

        let now = Date()

        switch mode {
        case .create:
            _title = State(initialValue: "")
            _time = State(initialValue: Calendar.current.date(from: DateComponents(hour: 6, minute: 45)) ?? now)
            _recurrence = State(initialValue: .schoolWeek)
            _weeklyDays = State(initialValue: Set([2, 3, 4, 5, 6]))
            _oneOffDate = State(initialValue: now)
            _driverName = State(initialValue: "Tafadzwa")
            _selectedPassengers = State(initialValue: Set(["TJ", "Tawana"]))
            _stops = State(initialValue: [
                CalendarMockModel.UIStop(type: "Pickup", label: "Home", address: "123 Maple St"),
                CalendarMockModel.UIStop(type: "Dropoff", label: "School", address: "456 School Ave")
            ])
            _isEnabled = State(initialValue: true)
        case let .edit(schedule):
            _title = State(initialValue: schedule.title)
            _time = State(initialValue: Self.timeFromString(schedule.timeString) ?? now)
            _recurrence = State(initialValue: schedule.recurrenceLabel.lowercased().contains("one") ? .oneTime : .schoolWeek)
            _weeklyDays = State(initialValue: Set([2, 3, 4, 5, 6]))
            _oneOffDate = State(initialValue: now)
            _driverName = State(initialValue: schedule.driverName)
            _selectedPassengers = State(initialValue: Set(schedule.passengerNames))
            _stops = State(initialValue: schedule.stops)
            _isEnabled = State(initialValue: schedule.isEnabled)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    basicInfoCard
                    recurrenceCard
                    participantsCard
                    stopsCard
                    enabledCard
                    summaryPreviewCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .background(CalendarUITheme.offWhite.ignoresSafeArea())
            .navigationTitle("New Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: recurrence) { _, newValue in
                if newValue == .schoolWeek {
                    weeklyDays = Set([2, 3, 4, 5, 6])
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveSchedule()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var basicInfoCard: some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Basic Info")
                textField("Title", text: $title)

                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .tint(CalendarUITheme.indigo)
            }
        }
    }

    private var recurrenceCard: some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Run type")
                HStack(spacing: 8) {
                    recurrenceChip(kind: .oneTime)
                    recurrenceChip(kind: .schoolWeek)
                    recurrenceChip(kind: .custom)
                }

                if recurrence == .custom {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 42), spacing: 8)], spacing: 8) {
                        ForEach(weekdayItems, id: \.0) { item in
                            dayChip(dayCode: item.0, label: item.1)
                        }
                    }
                } else if recurrence == .oneTime {
                    DatePicker("Date", selection: $oneOffDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
            }
        }
    }

    private var participantsCard: some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Participants")
                Picker("Driver", selection: $driverName) {
                    ForEach(drivers, id: \.self) { driver in
                        Text(driver).tag(driver)
                    }
                }
                .pickerStyle(.menu)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Passengers")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CalendarUITheme.textSecondary)
                    HStack {
                        ForEach(passengerPool, id: \.self) { passenger in
                            CalendarChip(
                                text: passenger,
                                selected: selectedPassengers.contains(passenger),
                                action: {
                                    if selectedPassengers.contains(passenger) {
                                        selectedPassengers.remove(passenger)
                                    } else {
                                        selectedPassengers.insert(passenger)
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    private var stopsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            CalendarCard {
                HStack {
                    sectionTitle("Stops")
                    Spacer()
                    Button("Add Pickup") {
                        stops.append(CalendarMockModel.UIStop(type: "Pickup", label: "", address: ""))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CalendarUITheme.indigo)
                    Button("Add Dropoff") {
                        stops.append(CalendarMockModel.UIStop(type: "Dropoff", label: "", address: ""))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CalendarUITheme.warning)
                }
            }

            ForEach(stops.indices, id: \.self) { index in
                stopCard(index: index)
            }
        }
    }

    private var enabledCard: some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Activate this run", isOn: $isEnabled)
                    .font(.system(size: 15, weight: .semibold))
                    .tint(CalendarUITheme.indigo)
                Text("Turn off to pause without deleting.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(CalendarUITheme.textSecondary)
            }
        }
    }

    private var summaryPreviewCard: some View {
        CalendarCard {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Run Summary")
                Text("\(pickupLabel) \u{2192} \(dropoffLabel)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CalendarUITheme.textPrimary)
                Text("\(recurrenceSummary) \u{2022} \(Self.formatTime(time))")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(CalendarUITheme.textSecondary)
            }
        }
    }

    private var editingSchedule: CalendarMockModel.UISchedule? {
        if case let .edit(schedule) = mode {
            return schedule
        }
        return nil
    }

    private var recurrenceLabel: String {
        switch recurrence {
        case .oneTime: return "One-time"
        case .schoolWeek: return "Weekdays"
        case .custom: return "Custom"
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        pickupStops.contains(where: isStopDefined) &&
        dropoffStops.contains(where: isStopDefined) &&
        (recurrence == .oneTime || !weeklyDays.isEmpty)
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
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(red: 0.952, green: 0.957, blue: 0.965))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func saveSchedule() {
        let saved = CalendarMockModel.UISchedule(
            id: editingSchedule?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            timeString: Self.formatTime(time),
            recurrenceLabel: recurrenceLabel,
            driverName: driverName,
            passengerNames: selectedPassengers.sorted(),
            isEnabled: isEnabled,
            stops: stops
        )
        onSave(saved)
        dismiss()
    }

    private var pickupStops: [CalendarMockModel.UIStop] {
        stops.filter { $0.type == "Pickup" }
    }

    private var dropoffStops: [CalendarMockModel.UIStop] {
        stops.filter { $0.type == "Dropoff" }
    }

    private var pickupLabel: String {
        pickupStops.first(where: isStopDefined)?.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? pickupStops.first(where: isStopDefined)!.label
            : "Home"
    }

    private var dropoffLabel: String {
        dropoffStops.first(where: isStopDefined)?.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? dropoffStops.first(where: isStopDefined)!.label
            : "School"
    }

    private var recurrenceSummary: String {
        switch recurrence {
        case .oneTime:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: oneOffDate)
        case .schoolWeek:
            return "Mon\u{2013}Fri"
        case .custom:
            let selected = weekdayItems.filter { weeklyDays.contains($0.0) }.map(\.1)
            return selected.isEmpty ? "No days" : selected.joined(separator: ", ")
        }
    }

    private func isStopDefined(_ stop: CalendarMockModel.UIStop) -> Bool {
        !stop.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !stop.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func recurrenceChip(kind: RecurrenceKind) -> some View {
        Button {
            recurrence = kind
        } label: {
            Text(kind.rawValue)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(recurrence == kind ? .white : CalendarUITheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(recurrence == kind ? CalendarUITheme.indigo : Color.black.opacity(0.06))
                .clipShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func dayChip(dayCode: Int, label: String) -> some View {
        let isSelected = weeklyDays.contains(dayCode)
        return Button {
            if isSelected {
                weeklyDays.remove(dayCode)
            } else {
                weeklyDays.insert(dayCode)
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : CalendarUITheme.textPrimary)
                .frame(minWidth: 42)
                .padding(.vertical, 8)
                .background(isSelected ? CalendarUITheme.indigo : Color.black.opacity(0.06))
                .clipShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func stopCard(index: Int) -> some View {
        let isPickup = stops[index].type == "Pickup"
        let accent = isPickup ? CalendarUITheme.indigo : CalendarUITheme.warning

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: isPickup ? "location.fill" : "mappin.and.ellipse")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                    Text(isPickup ? "Pickup" : "Dropoff")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CalendarUITheme.textPrimary)
                }
                Spacer()
                Button {
                    stops.remove(at: index)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            textField("Label", text: $stops[index].label)

            VStack(alignment: .leading, spacing: 6) {
                Text("Address")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CalendarUITheme.textSecondary)
                HStack(spacing: 8) {
                    Image(systemName: "mappin")
                        .foregroundStyle(CalendarUITheme.textSecondary)
                    TextField("Search address", text: $stops[index].address)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(red: 0.952, green: 0.957, blue: 0.965))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(14)
        .background(accent.opacity(0.08))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.25), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: date)
    }

    private static func timeFromString(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.date(from: value)
    }
}

private enum RecurrenceKind: String, CaseIterable, Identifiable {
    case oneTime = "One-time"
    case schoolWeek = "School week"
    case custom = "Custom"
    var id: String { rawValue }
}

#Preview {
    ScheduleEditorView(mode: .create) { _ in }
}
