import SwiftUI

enum UICalendarEditorRecurrenceKind: String, CaseIterable, Identifiable {
    case oneOff = "One-off"
    case daily = "Daily"
    case weekly = "Weekly"
    var id: String { rawValue }
}

struct UICalendarScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let users: [UICalendarUser]
    let editingSchedule: UISchedule?
    let onSave: (UISchedule) -> Void

    @State private var title: String
    @State private var selectedTime: Date
    @State private var recurrenceKind: UICalendarEditorRecurrenceKind
    @State private var weeklyDays: Set<Int>
    @State private var selectedDriverID: UUID?
    @State private var selectedPassengerIDs: Set<UUID>
    @State private var stops: [UICalendarStop]
    @State private var isEnabled = true

    private let weekdayEntries: [(Int, String)] = [
        (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")
    ]

    init(users: [UICalendarUser], editingSchedule: UISchedule? = nil, onSave: @escaping (UISchedule) -> Void) {
        self.users = users
        self.editingSchedule = editingSchedule
        self.onSave = onSave

        let schedule = editingSchedule
        _title = State(initialValue: schedule?.title ?? "")
        _selectedTime = State(initialValue: Calendar.current.date(from: schedule?.timeOfDay ?? DateComponents(hour: 7, minute: 0)) ?? Date())
        _recurrenceKind = State(initialValue: .weekly)
        _weeklyDays = State(initialValue: Set([2, 3, 4, 5, 6]))
        _selectedDriverID = State(initialValue: schedule?.driver.id)
        _selectedPassengerIDs = State(initialValue: Set(schedule?.passengers.map(\.id) ?? []))
        _stops = State(initialValue: schedule?.stops ?? [
            UICalendarStop(type: .pickup, label: "Home"),
            UICalendarStop(type: .dropoff, label: "School")
        ])
        _isEnabled = State(initialValue: schedule?.isEnabled ?? true)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                UICalendarDesignSystem.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: UICalendarDesignSystem.Spacing.medium) {
                        basicCard
                        participantsCard
                        stopsCard
                        Toggle("Enabled", isOn: $isEnabled)
                            .tint(UICalendarDesignSystem.Colors.primary)
                            .padding()
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(UICalendarDesignSystem.Spacing.medium)
                }
            }
            .navigationTitle(editingSchedule == nil ? "New Schedule" : "Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    UICalendarPrimaryButton(title: "Save") { saveTapped() }
                        .opacity(canSave ? 1 : 0.55)
                        .disabled(!canSave)
                    UICalendarSecondaryButton(title: "Cancel") { dismiss() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var basicCard: some View {
        UICalendarCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Basic Info")
                    .font(.system(size: 17, weight: .bold))
                TextField("Title", text: $title)
                    .padding(12)
                    .background(Color.gray.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                HStack {
                    ForEach(weekdayEntries, id: \.0) { weekday, label in
                        UICalendarChip(text: label, isSelected: weeklyDays.contains(weekday), action: {
                            if weeklyDays.contains(weekday) { weeklyDays.remove(weekday) } else { weeklyDays.insert(weekday) }
                        })
                    }
                }
            }
        }
    }

    private var participantsCard: some View {
        UICalendarCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Participants")
                    .font(.system(size: 17, weight: .bold))
                Picker("Driver", selection: $selectedDriverID) {
                    Text("Select").tag(Optional<UUID>.none)
                    ForEach(users) { user in
                        Text(user.name).tag(Optional(user.id))
                    }
                }
                .pickerStyle(.menu)
                HStack {
                    ForEach(users) { user in
                        UICalendarChip(
                            text: user.name,
                            isSelected: selectedPassengerIDs.contains(user.id),
                            action: {
                                if selectedPassengerIDs.contains(user.id) { selectedPassengerIDs.remove(user.id) } else { selectedPassengerIDs.insert(user.id) }
                            }
                        )
                    }
                }
            }
        }
    }

    private var stopsCard: some View {
        UICalendarCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Stops")
                        .font(.system(size: 17, weight: .bold))
                    Spacer()
                    Button("Add stop") {
                        stops.append(UICalendarStop(type: .dropoff, label: "New Stop"))
                    }
                }
                ForEach(stops) { stop in
                    HStack {
                        UICalendarBadge(
                            text: stop.type.rawValue.uppercased(),
                            color: stop.type == .pickup ? UICalendarDesignSystem.Colors.primary : UICalendarDesignSystem.Colors.warning
                        )
                        Text(stop.label)
                        Spacer()
                    }
                }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !stops.isEmpty && selectedDriverID != nil
    }

    private func saveTapped() {
        guard let selectedDriverID, let driver = users.first(where: { $0.id == selectedDriverID }) else { return }
        let passengers = users.filter { selectedPassengerIDs.contains($0.id) }
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)

        let saved = UISchedule(
            id: editingSchedule?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            timeOfDay: DateComponents(hour: timeComponents.hour, minute: timeComponents.minute),
            recurrence: .weekly(days: Array(weeklyDays)),
            startDate: Date(),
            driver: driver,
            passengers: passengers,
            stops: stops,
            isEnabled: isEnabled
        )
        onSave(saved)
        dismiss()
    }
}

#Preview {
    UICalendarScheduleEditorView(users: UICalendarMockData.users) { _ in }
}
