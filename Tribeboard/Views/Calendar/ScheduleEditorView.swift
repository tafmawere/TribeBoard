//
//  ScheduleEditorView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import SwiftUI
import Combine

// MARK: - ScheduleEditorViewModel

/// View model for the schedule editor that manages schedule creation and editing
@MainActor
class ScheduleEditorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var title: String = ""
    @Published var time: Date = Date()
    @Published var recurrenceType: RecurrenceType = .weekly
    @Published var selectedWeekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    @Published var oneOffDate: Date = Date()
    @Published var startDate: Date = Date()
    @Published var endDate: Date?
    @Published var hasEndDate: Bool = false
    @Published var driverId: String = ""
    @Published var passengerIds: [String] = []
    @Published var stops: [ScheduleStop] = []
    @Published var isEnabled: Bool = true
    
    // MARK: - Dependencies
    
    private let scheduleStore: ScheduleStore
    private let existingSchedule: RunSchedule?
    
    // MARK: - Computed Properties
    
    /// True if editing an existing schedule, false if creating new
    var isEditMode: Bool {
        existingSchedule != nil
    }
    
    /// True if all required fields are valid
    var isValid: Bool {
        !title.isEmpty && !driverId.isEmpty && !stops.isEmpty
    }
    
    /// Available demo users for driver selection
    var availableDrivers: [DemoUser] {
        [
            DemoUser(id: "demo-tafadzwa", displayName: "Tafadzwa"),
            DemoUser(id: "demo-rue", displayName: "Rue")
        ]
    }
    
    /// Available demo users for passenger selection
    var availablePassengers: [DemoUser] {
        [
            DemoUser(id: "demo-tj", displayName: "TJ"),
            DemoUser(id: "demo-tawana", displayName: "Tawana")
        ]
    }
    
    // MARK: - Initialization
    
    init(scheduleStore: ScheduleStore, existingSchedule: RunSchedule? = nil) {
        self.scheduleStore = scheduleStore
        self.existingSchedule = existingSchedule
        
        // Set defaults for new schedule
        if existingSchedule == nil {
            // Default driver: Tafadzwa
            self.driverId = "demo-tafadzwa"
            
            // Default passengers: TJ and Tawana
            self.passengerIds = ["demo-tj", "demo-tawana"]
        } else if let schedule = existingSchedule {
            // Load existing schedule data
            loadSchedule(schedule)
        }
    }
    
    // MARK: - Public Methods
    
    /// Save the schedule to the store
    func save() async throws {
        // Build recurrence pattern based on type
        let recurrence: RecurrencePattern
        switch recurrenceType {
        case .oneOff:
            recurrence = .none(oneOffDate: oneOffDate)
        case .daily:
            recurrence = .daily
        case .weekly:
            recurrence = .weekly(weekdays: selectedWeekdays)
        }
        
        // Extract time of day from time picker
        let timeOfDay = TimeOfDay(from: time)
        
        // Create or update schedule
        let schedule = RunSchedule(
            id: existingSchedule?.id ?? UUID().uuidString,
            title: title,
            timeOfDay: timeOfDay,
            recurrence: recurrence,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            driverUserId: driverId,
            passengerUserIds: passengerIds,
            stops: stops,
            isEnabled: isEnabled
        )
        
        // Persist to store
        try await scheduleStore.upsert(schedule)
    }
    
    /// Add a new stop to the schedule
    func addStop() {
        let newStop = ScheduleStop(
            type: .pickup,
            label: "",
            location: LocationData(
                latitude: 37.7749,
                longitude: -122.4194,
                address: ""
            )
        )
        stops.append(newStop)
    }
    
    /// Remove a stop at the given index
    func removeStop(at index: Int) {
        guard index >= 0 && index < stops.count else { return }
        stops.remove(at: index)
    }
    
    /// Update a stop at the given index
    func updateStop(at index: Int, stop: ScheduleStop) {
        guard index >= 0 && index < stops.count else { return }
        stops[index] = stop
    }
    
    // MARK: - Private Methods
    
    /// Load data from an existing schedule
    private func loadSchedule(_ schedule: RunSchedule) {
        title = schedule.title
        
        // Convert time of day to Date for picker
        time = schedule.timeOfDay.combined(with: Date())
        
        // Load recurrence pattern
        switch schedule.recurrence {
        case .none(let oneOffDate):
            recurrenceType = .oneOff
            self.oneOffDate = oneOffDate
        case .daily:
            recurrenceType = .daily
        case .weekly(let weekdays):
            recurrenceType = .weekly
            selectedWeekdays = weekdays
        }
        
        startDate = schedule.startDate
        endDate = schedule.endDate
        hasEndDate = schedule.endDate != nil
        driverId = schedule.driverUserId
        passengerIds = schedule.passengerUserIds
        stops = schedule.stops
        isEnabled = schedule.isEnabled
    }
}

// MARK: - RecurrenceType

/// Simplified recurrence type for UI picker
enum RecurrenceType: String, CaseIterable, Identifiable {
    case oneOff = "One-off"
    case daily = "Daily"
    case weekly = "Weekly"
    
    var id: String { rawValue }
}

// MARK: - DemoUser

/// Simple user model for picker display
struct DemoUser: Identifiable {
    let id: String
    let displayName: String
}

// MARK: - ScheduleEditorView

/// View for creating and editing schedules
struct ScheduleEditorView: View {
    
    // MARK: - State
    
    @StateObject private var viewModel: ScheduleEditorViewModel
    
    // MARK: - Environment
    
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Initialization
    
    init(viewModel: ScheduleEditorViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Info section
                basicInfoSection
                
                // Recurrence section
                recurrenceSection
                
                // Participants section
                participantsSection
                
                // Stops section
                stopsSection
            }
            .navigationTitle(viewModel.isEditMode ? "Edit Schedule" : "New Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            do {
                                try await viewModel.save()
                                dismiss()
                            } catch {
                                // Show error alert
                                appCoordinator.handleError(error, context: "Failed to save schedule")
                            }
                        }
                    }
                    .disabled(!viewModel.isValid)
                }
            }
        }
    }
    
    // MARK: - Basic Info Section
    
    private var basicInfoSection: some View {
        Section {
            TextField("Title", text: $viewModel.title)
                .font(.body)
            
            DatePicker(
                "Time",
                selection: $viewModel.time,
                displayedComponents: .hourAndMinute
            )
            .font(.body)
        } header: {
            Text("Basic Info")
        }
    }
    
    // MARK: - Recurrence Section
    
    private var recurrenceSection: some View {
        Section {
            Picker("Pattern", selection: $viewModel.recurrenceType) {
                ForEach(RecurrenceType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .font(.body)
            
            // One-off date picker
            if viewModel.recurrenceType == .oneOff {
                DatePicker(
                    "Date",
                    selection: $viewModel.oneOffDate,
                    displayedComponents: .date
                )
                .font(.body)
            }
            
            // Weekly weekday chips
            if viewModel.recurrenceType == .weekly {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.spacing12) {
                    Text("Days of Week")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    weekdayChipsView
                }
                .padding(.vertical, DesignSystem.Spacing.spacing8)
            }
            
            // Date range
            DatePicker(
                "Start Date",
                selection: $viewModel.startDate,
                displayedComponents: .date
            )
            .font(.body)
            
            Toggle("Has End Date", isOn: $viewModel.hasEndDate)
                .font(.body)
            
            if viewModel.hasEndDate {
                DatePicker(
                    "End Date",
                    selection: Binding(
                        get: { viewModel.endDate ?? Date() },
                        set: { viewModel.endDate = $0 }
                    ),
                    displayedComponents: .date
                )
                .font(.body)
            }
        } header: {
            Text("Recurrence")
        }
    }
    
    // MARK: - Weekday Chips View
    
    private var weekdayChipsView: some View {
        HStack(spacing: DesignSystem.Spacing.spacing8) {
            ForEach(Weekday.allCases, id: \.self) { weekday in
                WeekdayChip(
                    weekday: weekday,
                    isSelected: viewModel.selectedWeekdays.contains(weekday),
                    onTap: {
                        if viewModel.selectedWeekdays.contains(weekday) {
                            viewModel.selectedWeekdays.remove(weekday)
                        } else {
                            viewModel.selectedWeekdays.insert(weekday)
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Participants Section
    
    private var participantsSection: some View {
        Section {
            Picker("Driver", selection: $viewModel.driverId) {
                ForEach(viewModel.availableDrivers) { user in
                    Text(user.displayName).tag(user.id)
                }
            }
            .font(.body)
            
            // Passengers multi-selector
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.spacing8) {
                Text("Passengers")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                ForEach(viewModel.availablePassengers) { user in
                    Toggle(user.displayName, isOn: Binding(
                        get: { viewModel.passengerIds.contains(user.id) },
                        set: { isSelected in
                            if isSelected {
                                if !viewModel.passengerIds.contains(user.id) {
                                    viewModel.passengerIds.append(user.id)
                                }
                            } else {
                                viewModel.passengerIds.removeAll { $0 == user.id }
                            }
                        }
                    ))
                    .font(.body)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.spacing8)
        } header: {
            Text("Participants")
        }
    }
    
    // MARK: - Stops Section
    
    private var stopsSection: some View {
        Section {
            ForEach(Array(viewModel.stops.enumerated()), id: \.element.id) { index, stop in
                StopEditorRow(
                    stop: stop,
                    onUpdate: { updatedStop in
                        viewModel.updateStop(at: index, stop: updatedStop)
                    },
                    onDelete: {
                        viewModel.removeStop(at: index)
                    }
                )
            }
            
            Button(action: {
                viewModel.addStop()
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(DesignSystem.Colors.primaryBlue)
                    
                    Text("Add Stop")
                        .foregroundColor(DesignSystem.Colors.primaryBlue)
                }
                .font(.body)
            }
        } header: {
            Text("Stops")
        }
    }
}

// MARK: - Weekday Chip

/// Chip component for weekday selection
struct WeekdayChip: View {
    let weekday: Weekday
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(weekday.rawValue.prefix(3).uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : DesignSystem.Colors.textSecondary)
                .padding(.horizontal, DesignSystem.Spacing.spacing12)
                .padding(.vertical, DesignSystem.Spacing.spacing8)
                .background(isSelected ? DesignSystem.Colors.primaryBlue : DesignSystem.Colors.screenBackground)
                .cornerRadius(DesignSystem.CornerRadius.radiusSmall)
        }
    }
}

// MARK: - Stop Editor Row

/// Row component for editing a single stop
struct StopEditorRow: View {
    let stop: ScheduleStop
    let onUpdate: (ScheduleStop) -> Void
    let onDelete: () -> Void
    
    @State private var label: String
    @State private var address: String
    @State private var stopType: StopType
    
    init(stop: ScheduleStop, onUpdate: @escaping (ScheduleStop) -> Void, onDelete: @escaping () -> Void) {
        self.stop = stop
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        
        _label = State(initialValue: stop.label)
        _address = State(initialValue: stop.location.address ?? "")
        _stopType = State(initialValue: stop.type)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.spacing8) {
            HStack {
                Picker("Type", selection: $stopType) {
                    Text("Pickup").tag(StopType.pickup)
                    Text("Dropoff").tag(StopType.dropoff)
                    Text("Waypoint").tag(StopType.waypoint)
                }
                .font(.caption)
                .onChange(of: stopType) { _, newValue in
                    updateStop()
                }
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            TextField("Label (e.g., Home, School)", text: $label)
                .font(.body)
                .onChange(of: label) { _, _ in
                    updateStop()
                }
            
            TextField("Address", text: $address)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .onChange(of: address) { _, _ in
                    updateStop()
                }
        }
        .padding(.vertical, DesignSystem.Spacing.spacing8)
    }
    
    private func updateStop() {
        let updatedStop = ScheduleStop(
            id: stop.id,
            type: stopType,
            label: label,
            location: LocationData(
                latitude: stop.location.latitude,
                longitude: stop.location.longitude,
                address: address
            ),
            notes: stop.notes
        )
        onUpdate(updatedStop)
    }
}

// MARK: - Preview

#if DEBUG
struct ScheduleEditorView_Previews: PreviewProvider {
    static var previews: some View {
        let container = DependencyContainer()
        let viewModel = ScheduleEditorViewModel(
            scheduleStore: container.scheduleStore,
            existingSchedule: nil
        )
        
        return ScheduleEditorView(viewModel: viewModel)
            .environmentObject(AppCoordinator(dependencyContainer: container))
    }
}
#endif
