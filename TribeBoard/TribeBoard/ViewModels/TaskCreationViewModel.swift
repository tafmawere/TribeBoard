import SwiftUI
import Foundation

/// ViewModel for managing task creation state and validation
@MainActor
class TaskCreationViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Items to be included in the shopping task
    @Published var selectedItems: [GroceryItem] = []
    
    /// Selected family member for task assignment
    @Published var selectedFamilyMember: String = ""
    
    /// Selected task type
    @Published var selectedTaskType: TaskType = .shopRun
    
    /// Due date for the task
    @Published var dueDate = Date().addingTimeInterval(3600) // Default to 1 hour from now
    
    /// Optional notes for the task
    @Published var notes: String = ""
    
    /// Optional location for the task
    @Published var selectedLocation: TaskLocation?
    
    /// Loading state for task creation
    @Published var isCreating = false
    
    /// Error message for display
    @Published var errorMessage: String?
    
    /// Success message for operations
    @Published var successMessage: String?
    
    /// Available family members for assignment
    @Published var availableFamilyMembers: [String] = []
    
    /// Available locations for shopping
    @Published var availableLocations: [TaskLocation] = []
    
    /// Show location picker
    @Published var showLocationPicker = false
    
    /// Current user creating the task
    @Published var currentUser: String = "Current User"
    
    // MARK: - Computed Properties
    
    /// Whether the form is valid for submission
    var isFormValid: Bool {
        return !selectedItems.isEmpty &&
               !selectedFamilyMember.isEmpty &&
               !selectedFamilyMember.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Validation errors for display
    var validationErrors: [String] {
        var errors: [String] = []
        
        if selectedItems.isEmpty {
            errors.append("At least one item must be selected")
        }
        
        if selectedFamilyMember.isEmpty || selectedFamilyMember.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("A family member must be assigned")
        }
        
        if dueDate <= Date() {
            errors.append("Due date must be in the future")
        }
        
        return errors
    }
    
    /// Whether validation errors exist
    var hasValidationErrors: Bool {
        !validationErrors.isEmpty
    }
    
    /// Formatted due date for display
    var formattedDueDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(dueDate) {
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: dueDate))"
        } else if calendar.isDateInTomorrow(dueDate) {
            formatter.timeStyle = .short
            return "Tomorrow at \(formatter.string(from: dueDate))"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: dueDate)
        }
    }
    
    /// Summary of selected items for display
    var itemsSummary: String {
        if selectedItems.isEmpty {
            return "No items selected"
        } else if selectedItems.count <= 3 {
            return selectedItems.map { $0.ingredient.name }.joined(separator: ", ")
        } else {
            let firstThree = selectedItems.prefix(3).map { $0.ingredient.name }.joined(separator: ", ")
            return "\(firstThree) +\(selectedItems.count - 3) more"
        }
    }
    
    /// Total estimated cost of selected items
    var estimatedCost: Double {
        // Mock calculation based on item count and type
        let basePrice = 25.0 // Base price per item
        let urgentMultiplier = 1.3 // Urgent items cost more
        
        return selectedItems.reduce(0.0) { total, item in
            let itemPrice = basePrice * (item.isUrgent ? urgentMultiplier : 1.0)
            return total + itemPrice
        }
    }
    
    /// Formatted estimated cost
    var formattedEstimatedCost: String {
        return String(format: "R%.0f", estimatedCost)
    }
    
    /// Whether location is required for the selected task type
    var isLocationRequired: Bool {
        selectedTaskType == .schoolRunPlusShop
    }
    
    /// Whether location selection should be shown
    var shouldShowLocationSelection: Bool {
        selectedTaskType == .shopRun || selectedTaskType == .schoolRunPlusShop
    }
    
    // MARK: - Initialization
    
    init() {
        setupInitialState()
    }
    
    // MARK: - Public Methods
    
    /// Load available family members and locations
    func loadInitialData() {
        availableFamilyMembers = MealPlanDataProvider.mockFamilyMembers()
        availableLocations = mockShoppingLocations()
        
        // Set default family member if available
        if !availableFamilyMembers.isEmpty && selectedFamilyMember.isEmpty {
            selectedFamilyMember = availableFamilyMembers.first ?? ""
        }
    }
    
    /// Set items for the task (typically called from grocery list)
    func setItems(_ items: [GroceryItem]) {
        selectedItems = items
    }
    
    /// Add an item to the task
    func addItem(_ item: GroceryItem) {
        if !selectedItems.contains(where: { $0.id == item.id }) {
            selectedItems.append(item)
        }
    }
    
    /// Remove an item from the task
    func removeItem(_ item: GroceryItem) {
        selectedItems.removeAll { $0.id == item.id }
    }
    
    /// Select a family member for assignment
    func selectFamilyMember(_ member: String) {
        selectedFamilyMember = member
    }
    
    /// Select a task type
    func selectTaskType(_ type: TaskType) {
        selectedTaskType = type
        
        // Clear location if not applicable to new task type
        if !shouldShowLocationSelection {
            selectedLocation = nil
        }
    }
    
    /// Select a location for the task
    func selectLocation(_ location: TaskLocation?) {
        selectedLocation = location
        showLocationPicker = false
    }
    
    /// Show location picker sheet
    func showLocationSelection() {
        showLocationPicker = true
    }
    
    /// Update due date
    func updateDueDate(_ date: Date) {
        dueDate = date
    }
    
    /// Update notes
    func updateNotes(_ text: String) {
        notes = text
    }
    
    /// Create the shopping task
    func createTask() async -> Bool {
        // Validate form before creating
        guard isFormValid else {
            errorMessage = validationErrors.first ?? "Please check all required fields"
            return false
        }
        
        isCreating = true
        errorMessage = nil
        
        do {
            // Simulate task creation delay
            try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
            
            let newTask = ShoppingTask(
                items: selectedItems,
                assignedTo: selectedFamilyMember,
                taskType: selectedTaskType,
                dueDate: dueDate,
                notes: notes.isEmpty ? nil : notes,
                location: selectedLocation,
                status: .pending,
                createdBy: currentUser
            )
            
            // In a real app, this would save to the data store
            // For now, we'll just simulate success
            
            await MainActor.run {
                self.successMessage = "Task created and assigned to \(selectedFamilyMember)"
                
                // Auto-clear success message
                Task {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        self.successMessage = nil
                    }
                }
            }
            
            // Reset form after successful creation
            resetForm()
            
            return true
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to create task: \(error.localizedDescription)"
            }
            return false
        }
        
        isCreating = false
    }
    
    /// Validate individual fields
    func validateField(_ field: TaskFormField) -> String? {
        switch field {
        case .items:
            return selectedItems.isEmpty ? "At least one item must be selected" : nil
        case .assignee:
            return selectedFamilyMember.isEmpty ? "A family member must be assigned" : nil
        case .taskType:
            return nil // Task type always has a default value
        case .dueDate:
            return dueDate <= Date() ? "Due date must be in the future" : nil
        case .location:
            return isLocationRequired && selectedLocation == nil ? "Location is required for this task type" : nil
        case .notes:
            return nil // Notes are optional
        }
    }
    
    /// Check if a specific field has validation errors
    func hasFieldError(_ field: TaskFormField) -> Bool {
        validateField(field) != nil
    }
    
    /// Get validation error for a specific field
    func getFieldError(_ field: TaskFormField) -> String {
        validateField(field) ?? ""
    }
    
    /// Reset the form to initial state
    func resetForm() {
        selectedItems = []
        selectedFamilyMember = availableFamilyMembers.first ?? ""
        selectedTaskType = .shopRun
        dueDate = Date().addingTimeInterval(3600) // 1 hour from now
        notes = ""
        selectedLocation = nil
        errorMessage = nil
        successMessage = nil
    }
    
    /// Clear error message
    func clearErrorMessage() {
        errorMessage = nil
    }
    
    /// Clear success message
    func clearSuccessMessage() {
        successMessage = nil
    }
    
    /// Estimate task completion time based on items and type
    func estimateCompletionTime() -> String {
        let baseTime = selectedTaskType == .schoolRunPlusShop ? 45 : 30 // minutes
        let itemTime = selectedItems.count * 3 // 3 minutes per item
        let totalMinutes = baseTime + itemTime
        
        if totalMinutes < 60 {
            return "\(totalMinutes) minutes"
        } else {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours) hour\(hours == 1 ? "" : "s")"
        }
    }
    
    /// Get suggested due date based on task type and urgency
    func getSuggestedDueDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if any items are urgent
        let hasUrgentItems = selectedItems.contains { $0.isUrgent }
        
        if hasUrgentItems {
            // Urgent items should be done within 2-4 hours
            return calendar.date(byAdding: .hour, value: Int.random(in: 2...4), to: now) ?? now
        } else {
            // Regular items can be done within 1-2 days
            let hoursToAdd = selectedTaskType == .schoolRunPlusShop ? 24 : 6 // School runs can wait longer
            return calendar.date(byAdding: .hour, value: hoursToAdd, to: now) ?? now
        }
    }
    
    /// Apply suggested due date
    func applySuggestedDueDate() {
        dueDate = getSuggestedDueDate()
    }
    
    // MARK: - Private Methods
    
    private func setupInitialState() {
        loadInitialData()
        
        // Set default due date
        dueDate = Date().addingTimeInterval(3600) // 1 hour from now
        
        // Set current user (in real app, this would come from auth service)
        currentUser = "Current User"
    }
    
    /// Mock shopping locations for task assignment
    private func mockShoppingLocations() -> [TaskLocation] {
        return [
            TaskLocation(
                name: "Woolworths",
                address: "123 Main Street, Sandton",
                latitude: -26.1076,
                longitude: 28.0567,
                type: .supermarket
            ),
            TaskLocation(
                name: "Pick n Pay",
                address: "456 School Road, Randburg",
                latitude: -26.0927,
                longitude: 28.0094,
                type: .supermarket
            ),
            TaskLocation(
                name: "Checkers",
                address: "789 Shopping Centre, Fourways",
                latitude: -25.9927,
                longitude: 28.0094,
                type: .supermarket
            ),
            TaskLocation(
                name: "Spar",
                address: "321 Corner Street, Rosebank",
                latitude: -26.1448,
                longitude: 28.0436,
                type: .supermarket
            ),
            TaskLocation(
                name: "Clicks Pharmacy",
                address: "654 Health Plaza, Hyde Park",
                latitude: -26.1186,
                longitude: 28.0186,
                type: .pharmacy
            )
        ]
    }
}

// MARK: - Supporting Enums

/// Enum for task form fields (for validation)
enum TaskFormField: String, CaseIterable {
    case items = "Items"
    case assignee = "Assignee"
    case taskType = "Task Type"
    case dueDate = "Due Date"
    case location = "Location"
    case notes = "Notes"
    
    var displayName: String {
        return rawValue
    }
    
    var isRequired: Bool {
        switch self {
        case .items, .assignee, .taskType, .dueDate:
            return true
        case .location, .notes:
            return false
        }
    }
}

// MARK: - Task Creation Errors

/// Errors that can occur during task creation
enum TaskCreationError: LocalizedError {
    case invalidItems
    case invalidAssignee
    case invalidDueDate
    case locationRequired
    case creationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidItems:
            return "Please select at least one item for the shopping task"
        case .invalidAssignee:
            return "Please assign the task to a family member"
        case .invalidDueDate:
            return "Due date must be in the future"
        case .locationRequired:
            return "Location is required for this task type"
        case .creationFailed(let message):
            return "Failed to create task: \(message)"
        }
    }
}