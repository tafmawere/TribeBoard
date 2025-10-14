import SwiftUI
import Foundation
import Combine
import os.log

/// ViewModel for planning and creating new school runs
@MainActor
class RunPlannerViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Title of the run being planned
    @Published var title: String = ""
    
    /// Selected date for the run
    @Published var selectedDate: Date = Date()
    
    /// List of stops in the run
    @Published var stops: [RunStop] = []
    
    /// Loading state for save operations
    @Published var isLoading: Bool = false
    
    /// Error message for display
    @Published var errorMessage: String?
    
    /// Form validation state
    @Published var isValid: Bool = false
    
    /// Individual field validation states
    @Published var titleError: String?
    @Published var dateError: String?
    @Published var stopsError: String?
    
    /// Real-time validation states
    @Published var titleValidationState: TitleValidationState = .empty
    @Published var stopValidationStates: [UUID: StopNameValidationState] = [:]
    
    /// Validation warnings
    @Published var validationWarnings: [String] = []
    
    /// Whether to show validation warnings
    @Published var showValidationWarnings: Bool = false
    
    // MARK: - Private Properties
    
    /// Manager for school run data operations
    private let manager: SchoolRunManager
    
    /// Error handler for comprehensive error management
    private let errorHandler: SchoolRunErrorHandler
    
    /// Haptic feedback manager
    private let hapticManager: HapticManager
    
    /// Minimum date allowed for scheduling (today)
    private let minimumDate = Calendar.current.startOfDay(for: Date())
    
    /// Maximum date allowed for scheduling (1 year from now)
    private let maximumDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    
    // MARK: - Computed Properties
    
    /// Check if the form has any data entered
    var hasUnsavedChanges: Bool {
        !title.isEmpty || !stops.isEmpty
    }
    
    /// Estimated duration for the run based on stops
    var estimatedDuration: TimeInterval {
        guard stops.count > 1 else { return 0 }
        
        let sortedStops = stops.sorted { $0.time < $1.time }
        guard let firstStop = sortedStops.first,
              let lastStop = sortedStops.last else { return 0 }
        
        return lastStop.time.timeIntervalSince(firstStop.time)
    }
    
    /// Formatted estimated duration string
    var estimatedDurationText: String {
        let duration = estimatedDuration
        guard duration > 0 else { return "No duration" }
        
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Check if date is valid for scheduling
    var isDateValid: Bool {
        selectedDate >= minimumDate && selectedDate <= maximumDate
    }
    
    /// Next available time for a new stop (15 minutes after the last stop)
    var nextAvailableTime: Date {
        guard let lastStop = stops.max(by: { $0.time < $1.time }) else {
            // If no stops, start 15 minutes from the selected date
            return Calendar.current.date(byAdding: .minute, value: 15, to: selectedDate) ?? selectedDate
        }
        
        return Calendar.current.date(byAdding: .minute, value: 15, to: lastStop.time) ?? lastStop.time
    }
    
    // MARK: - Initialization
    
    init(manager: SchoolRunManager? = nil, errorHandler: SchoolRunErrorHandler? = nil, hapticManager: HapticManager? = nil) {
        if let manager = manager {
            self.manager = manager
        } else {
            self.manager = SchoolRunManager()
        }
        
        if let errorHandler = errorHandler {
            self.errorHandler = errorHandler
        } else {
            self.errorHandler = SchoolRunErrorHandler()
        }
        
        if let hapticManager = hapticManager {
            self.hapticManager = hapticManager
        } else {
            self.hapticManager = HapticManager.shared
        }
        
        setupValidation()
    }
    
    // MARK: - Stop Management
    
    /// Add a new stop to the run
    func addStop() {
        let newStop = RunStop(
            name: "",
            time: nextAvailableTime,
            note: "",
            type: .pickup,
            task: "",
            estimatedMinutes: 5
        )
        
        stops.append(newStop)
        validateForm()
        
        // Haptic feedback for form interaction (respects accessibility settings)
        SchoolRunHapticFeedback.formInteraction()
    }
    
    /// Add a stop with specific details
    func addStop(name: String, time: Date, type: RunStop.StopType, note: String = "") {
        let newStop = RunStop(
            name: name,
            time: time,
            note: note,
            type: type,
            task: note,
            estimatedMinutes: 10
        )
        
        stops.append(newStop)
        sortStopsByTime()
        validateForm()
    }
    
    /// Remove a stop at the specified index
    func removeStop(at index: Int) {
        guard index >= 0 && index < stops.count else { return }
        stops.remove(at: index)
        validateForm()
        
        // Haptic feedback for destructive action (respects accessibility settings)
        SchoolRunHapticFeedback.destructiveAction()
    }
    
    /// Remove a stop by ID
    func removeStop(id: UUID) {
        stops.removeAll { $0.id == id }
        validateForm()
        
        // Haptic feedback for destructive action (respects accessibility settings)
        SchoolRunHapticFeedback.destructiveAction()
    }
    
    /// Update a stop at the specified index
    func updateStop(at index: Int, name: String? = nil, time: Date? = nil, type: RunStop.StopType? = nil, note: String? = nil) {
        guard index >= 0 && index < stops.count else { return }
        
        if let name = name {
            stops[index].name = name
        }
        if let time = time {
            stops[index].time = time
        }
        if let type = type {
            stops[index].type = type
        }
        if let note = note {
            stops[index].note = note
        }
        
        sortStopsByTime()
        validateForm()
    }
    
    /// Update a stop by ID
    func updateStop(id: UUID, name: String? = nil, time: Date? = nil, type: RunStop.StopType? = nil, note: String? = nil) {
        guard let index = stops.firstIndex(where: { $0.id == id }) else { return }
        updateStop(at: index, name: name, time: time, type: type, note: note)
    }
    
    /// Reorder stops by moving from one index to another
    func reorderStops(from source: IndexSet, to destination: Int) {
        stops.move(fromOffsets: source, toOffset: destination)
        validateForm()
    }
    
    /// Sort stops by time automatically
    func sortStopsByTime() {
        stops.sort { $0.time < $1.time }
    }
    
    /// Clear all stops
    func clearAllStops() {
        stops.removeAll()
        validateForm()
    }
    
    // MARK: - Form Validation
    
    /// Validate the entire form using comprehensive validation
    func validateForm() {
        // Use comprehensive validation
        let validationResult = SchoolRunValidation.validateRun(
            title: title,
            date: selectedDate,
            stops: stops
        )
        
        // Clear previous errors
        titleError = nil
        dateError = nil
        stopsError = nil
        validationWarnings = []
        
        // Process validation errors
        for error in validationResult.errors {
            switch error.category {
            case .validation:
                if case .invalidRunTitle(let message) = error {
                    titleError = message
                } else if case .invalidRunDate(let message) = error {
                    dateError = message
                } else {
                    // Stop-related validation errors
                    if stopsError == nil {
                        stopsError = error.userFriendlyMessage
                    }
                }
            default:
                // Handle other error categories
                if errorMessage == nil {
                    errorMessage = error.userFriendlyMessage
                }
            }
        }
        
        // Set validation warnings
        validationWarnings = validationResult.warnings
        showValidationWarnings = !validationWarnings.isEmpty
        
        // Update real-time validation states
        titleValidationState = SchoolRunValidation.validateTitleRealTime(title)
        updateStopValidationStates()
        
        // Overall form is valid if no errors
        isValid = validationResult.isValid
        
        // Handle errors through error handler if any critical errors
        if validationResult.hasCriticalErrors {
            let criticalErrors = validationResult.errors.filter { $0.severity == .critical }
            errorHandler.handleErrors(criticalErrors, context: "Form Validation")
        }
    }
    
    /// Validate title in real-time
    func validateTitleRealTime() {
        titleValidationState = SchoolRunValidation.validateTitleRealTime(title)
        
        // Clear title error if now valid
        if titleValidationState.isValid {
            titleError = nil
        }
    }
    
    /// Update stop validation states
    private func updateStopValidationStates() {
        for stop in stops {
            stopValidationStates[stop.id] = SchoolRunValidation.validateStopNameRealTime(stop.name)
        }
    }
    
    /// Validate individual stop in real-time
    func validateStopRealTime(_ stopId: UUID) {
        guard let stop = stops.first(where: { $0.id == stopId }) else { return }
        stopValidationStates[stopId] = SchoolRunValidation.validateStopNameRealTime(stop.name)
    }
    
    /// Get validation errors for a specific stop
    func getStopValidationErrors(for stopId: UUID) -> [String] {
        guard let stop = stops.first(where: { $0.id == stopId }) else { return [] }
        
        var errors: [String] = []
        
        let trimmedName = stop.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errors.append("Stop name is required")
        } else if trimmedName.count > 30 {
            errors.append("Stop name must be less than 30 characters")
        }
        
        // Check if time is reasonable (not too far in the past or future from selected date)
        let timeDifference = abs(stop.time.timeIntervalSince(selectedDate))
        if timeDifference > 86400 { // 24 hours
            errors.append("Stop time should be within 24 hours of the run date")
        }
        
        return errors
    }
    
    // MARK: - Save Operations
    
    /// Save the run to the manager with comprehensive error handling
    func saveRun() async -> SchoolRun? {
        // Final validation before saving
        validateForm()
        
        guard isValid else {
            let validationError = SchoolRunError.invalidUserInput("Please fix validation errors before saving")
            errorHandler.handleError(validationError, context: "Save Run")
            errorMessage = "Please fix validation errors before saving"
            return nil
        }
        
        isLoading = true
        errorMessage = nil
        errorHandler.clearError()
        
        do {
            let run = createSchoolRun()
            
            // Additional pre-save validation
            let finalValidation = SchoolRunValidation.validateRun(
                title: run.title,
                date: run.date,
                stops: run.route
            )
            
            if !finalValidation.isValid {
                let validationErrors = finalValidation.errors
                errorHandler.handleErrors(validationErrors, context: "Pre-save Validation")
                throw validationErrors.first ?? SchoolRunError.invalidRunData("Validation failed")
            }
            
            // Attempt to save
            try await manager.createRunAsync(run)
            
            // Success haptic feedback for save operation (respects accessibility settings)
            SchoolRunHapticFeedback.saveSuccessful()
            
            // Success - show success feedback
            ToastManager.shared.success("Run '\(run.title)' created successfully!")
            
            // Clear form after successful save
            clearForm()
            
            isLoading = false
            return run
            
        } catch let error as SchoolRunError {
            errorHandler.handleError(error, context: "Save Run")
            errorMessage = error.userFriendlyMessage
            
            // Error haptic feedback for save failure (respects accessibility settings)
            SchoolRunHapticFeedback.errorOccurred()
            
            isLoading = false
            return nil
        } catch {
            let wrappedError = SchoolRunError.unexpectedError(error.localizedDescription)
            errorHandler.handleError(wrappedError, context: "Save Run")
            errorMessage = "Failed to save run: \(error.localizedDescription)"
            
            // Error haptic feedback for save failure (respects accessibility settings)
            SchoolRunHapticFeedback.errorOccurred()
            
            isLoading = false
            return nil
        }
    }
    
    /// Create a SchoolRun from the current form data
    private func createSchoolRun() -> SchoolRun {
        let sortedStops = stops.sorted { $0.time < $1.time }
        
        return SchoolRun(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            date: selectedDate,
            route: sortedStops,
            status: .scheduled,
            estimatedDuration: estimatedDuration
        )
    }
    
    /// Validate and save the run (convenience method)
    func validateAndSave() async -> SchoolRun? {
        validateForm()
        
        guard isValid else {
            return nil
        }
        
        return await saveRun()
    }
    
    // MARK: - Form Management
    
    /// Clear the entire form
    func clearForm() {
        title = ""
        selectedDate = Date()
        stops.removeAll()
        clearErrors()
        validateForm()
    }
    
    /// Clear all error messages and validation states
    func clearErrors() {
        errorMessage = nil
        titleError = nil
        dateError = nil
        stopsError = nil
        validationWarnings = []
        showValidationWarnings = false
        titleValidationState = .empty
        stopValidationStates.removeAll()
        errorHandler.clearError()
    }
    
    /// Reset form to initial state
    func resetForm() {
        clearForm()
    }
    
    /// Load a run for editing (if needed for future edit functionality)
    func loadRun(_ run: SchoolRun) {
        title = run.title
        selectedDate = run.date
        stops = run.route
        validateForm()
    }
    
    // MARK: - Convenience Methods
    
    /// Get stops of a specific type
    func getStops(ofType type: RunStop.StopType) -> [RunStop] {
        return stops.filter { $0.type == type }
    }
    
    /// Get pickup stops
    var pickupStops: [RunStop] {
        getStops(ofType: .pickup)
    }
    
    /// Get dropoff stops
    var dropoffStops: [RunStop] {
        getStops(ofType: .dropoff)
    }
    
    /// Check if the run has both pickup and dropoff stops
    var hasMixedStopTypes: Bool {
        let hasPickup = stops.contains { $0.type == .pickup }
        let hasDropoff = stops.contains { $0.type == .dropoff }
        return hasPickup && hasDropoff
    }
    
    /// Get a summary of the planned run
    var runSummary: String {
        let stopCount = stops.count
        let pickupCount = pickupStops.count
        let dropoffCount = dropoffStops.count
        
        var summary = "\(stopCount) stop\(stopCount == 1 ? "" : "s")"
        
        if hasMixedStopTypes {
            summary += " (\(pickupCount) pickup, \(dropoffCount) dropoff)"
        } else if pickupCount > 0 {
            summary += " (all pickups)"
        } else if dropoffCount > 0 {
            summary += " (all dropoffs)"
        }
        
        if estimatedDuration > 0 {
            summary += " • \(estimatedDurationText)"
        }
        
        return summary
    }
    
    // MARK: - Private Setup
    
    /// Setup form validation observers with real-time feedback
    private func setupValidation() {
        // Real-time title validation
        $title
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.validateTitleRealTime()
                self?.validateForm()
            }
            .store(in: &cancellables)
        
        // Date validation
        $selectedDate
            .sink { [weak self] _ in
                self?.validateForm()
            }
            .store(in: &cancellables)
        
        // Stops validation
        $stops
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.validateForm()
            }
            .store(in: &cancellables)
    }
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Extensions

extension RunPlannerViewModel {
    /// Convenience initializer for testing
    convenience init(title: String = "", date: Date = Date(), stops: [RunStop] = [], manager: SchoolRunManager? = nil, errorHandler: SchoolRunErrorHandler? = nil) {
        self.init(manager: manager, errorHandler: errorHandler)
        self.title = title
        self.selectedDate = date
        self.stops = stops
        validateForm()
    }
}