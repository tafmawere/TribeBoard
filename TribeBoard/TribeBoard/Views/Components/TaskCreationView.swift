import SwiftUI

/// View for creating shopping tasks with form interface and validation
struct TaskCreationView: View {
    @StateObject private var viewModel = TaskCreationViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    // Focus states for form navigation
    @FocusState private var focusedField: TaskFormField?
    
    // Animation states
    @State private var showSuccessAnimation = false
    @State private var isFormVisible = false
    
    // Initialization with optional pre-selected items
    let preSelectedItems: [GroceryItem]
    let onTaskCreated: ((ShoppingTask) -> Void)?
    
    init(preSelectedItems: [GroceryItem] = [], onTaskCreated: ((ShoppingTask) -> Void)? = nil) {
        self.preSelectedItems = preSelectedItems
        self.onTaskCreated = onTaskCreated
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header section
                    headerSection
                    
                    // Form content
                    formContent
                    
                    // Action buttons
                    actionButtons
                }
                .screenPadding()
                .opacity(isFormVisible ? 1 : 0)
                .animation(DesignSystem.Animation.smooth, value: isFormVisible)
            }
            .navigationTitle("Create Shopping Task")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(viewModel.isCreating)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isCreating)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isCreating {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
        }
        .onAppear {
            setupInitialState()
        }
        .alert("Task Created", isPresented: .constant(showSuccessAnimation)) {
            Button("OK") {
                showSuccessAnimation = false
                dismiss()
            }
        } message: {
            Text("Shopping task has been assigned to \(viewModel.selectedFamilyMember)")
        }
        .sheet(isPresented: $viewModel.showLocationPicker) {
            LocationPickerView(
                selectedLocation: $viewModel.selectedLocation,
                availableLocations: viewModel.availableLocations,
                onLocationSelected: { location in
                    viewModel.selectLocation(location)
                }
            )
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Task summary card
            taskSummaryCard
            
            // Estimated completion time
            estimatedTimeCard
        }
    }
    
    private var taskSummaryCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .font(.title2)
                    .foregroundColor(.brandPrimary)
                
                Text("Task Summary")
                    .titleMedium()
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(viewModel.selectedItems.count) item\(viewModel.selectedItems.count == 1 ? "" : "s")")
                    .captionLarge()
                    .foregroundColor(.secondary)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                            .fill(Color.brandPrimary.opacity(0.1))
                    )
            }
            
            if !viewModel.selectedItems.isEmpty {
                Text(viewModel.itemsSummary)
                    .bodySmall()
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            } else {
                Text("No items selected")
                    .bodySmall()
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            if viewModel.estimatedCost > 0 {
                HStack {
                    Text("Estimated cost:")
                        .captionLarge()
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(viewModel.formattedEstimatedCost)
                        .labelMedium()
                        .foregroundColor(.brandPrimary)
                }
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .mediumShadow()
        )
    }
    
    private var estimatedTimeCard: some View {
        HStack {
            Image(systemName: "clock")
                .font(.title3)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Estimated Time")
                    .labelMedium()
                    .foregroundColor(.primary)
                
                Text(viewModel.estimateCompletionTime())
                    .captionLarge()
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Use Suggested") {
                viewModel.applySuggestedDueDate()
                HapticManager.shared.lightImpact()
            }
            .buttonStyle(TertiaryButtonStyle())
            .disabled(viewModel.isCreating)
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
    }
    
    // MARK: - Form Content
    
    private var formContent: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Items section
            itemsSection
            
            // Assignment section
            assignmentSection
            
            // Task details section
            taskDetailsSection
            
            // Location section (if applicable)
            if viewModel.shouldShowLocationSelection {
                locationSection
            }
            
            // Notes section
            notesSection
        }
    }
    
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(
                title: "Items to Purchase",
                icon: "cart",
                isRequired: true,
                hasError: viewModel.hasFieldError(.items)
            )
            
            if viewModel.selectedItems.isEmpty {
                emptyItemsView
            } else {
                itemsList
            }
            
            if viewModel.hasFieldError(.items) {
                validationErrorView(message: viewModel.getFieldError(.items))
            }
        }
    }
    
    private var emptyItemsView: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "cart.badge.plus")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No items selected")
                .bodyMedium()
                .foregroundColor(.secondary)
            
            Text("Add items from your grocery list to create a shopping task")
                .captionLarge()
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .stroke(Color(.systemGray4), style: StrokeStyle(lineWidth: 1, dash: [5]))
                )
        )
    }
    
    private var itemsList: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(viewModel.selectedItems) { item in
                itemRow(item)
            }
        }
    }
    
    private func itemRow(_ item: GroceryItem) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Item emoji and info
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text(item.ingredient.emoji)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.ingredient.name)
                        .bodyMedium()
                        .foregroundColor(.primary)
                    
                    Text("\(item.ingredient.quantity) \(item.ingredient.unit)")
                        .captionLarge()
                        .foregroundColor(.secondary)
                    
                    if let linkedMeal = item.linkedMeal {
                        Text("For: \(linkedMeal)")
                            .captionSmall()
                            .foregroundColor(.brandPrimary)
                    }
                }
            }
            
            Spacer()
            
            // Urgent indicator
            if item.isUrgent {
                Text("URGENT")
                    .captionSmall()
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                            .fill(Color.red)
                    )
            }
            
            // Remove button
            Button(action: {
                viewModel.removeItem(item)
                HapticManager.shared.lightImpact()
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundColor(.red)
            }
            .disabled(viewModel.isCreating)
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
    }
    
    private var assignmentSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(
                title: "Assign To",
                icon: "person.circle",
                isRequired: true,
                hasError: viewModel.hasFieldError(.assignee)
            )
            
            familyMemberPicker
            
            if viewModel.hasFieldError(.assignee) {
                validationErrorView(message: viewModel.getFieldError(.assignee))
            }
        }
    }
    
    private var familyMemberPicker: some View {
        Menu {
            ForEach(viewModel.availableFamilyMembers, id: \.self) { member in
                Button(member) {
                    viewModel.selectFamilyMember(member)
                    HapticManager.shared.lightImpact()
                }
            }
        } label: {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.brandPrimary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Assigned to")
                        .captionLarge()
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.selectedFamilyMember.isEmpty ? "Select family member" : viewModel.selectedFamilyMember)
                        .bodyMedium()
                        .foregroundColor(viewModel.selectedFamilyMember.isEmpty ? .secondary : .primary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .cardPadding()
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                            .stroke(
                                viewModel.hasFieldError(.assignee) ? Color.red : Color(.systemGray4),
                                lineWidth: viewModel.hasFieldError(.assignee) ? 2 : 1
                            )
                    )
            )
        }
        .disabled(viewModel.isCreating)
    }
    
    private var taskDetailsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(
                title: "Task Details",
                icon: "gear",
                isRequired: true
            )
            
            taskTypePicker
            dueDatePicker
        }
    }
    
    private var taskTypePicker: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Task Type")
                .labelMedium()
                .foregroundColor(.primary)
            
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(TaskType.allCases, id: \.self) { taskType in
                    taskTypeButton(taskType)
                }
            }
        }
    }
    
    private func taskTypeButton(_ taskType: TaskType) -> some View {
        Button(action: {
            viewModel.selectTaskType(taskType)
            HapticManager.shared.lightImpact()
        }) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text(taskType.emoji)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(taskType.rawValue)
                        .labelMedium()
                        .foregroundColor(viewModel.selectedTaskType == taskType ? .white : .primary)
                    
                    Text(taskType.description)
                        .captionSmall()
                        .foregroundColor(viewModel.selectedTaskType == taskType ? .white.opacity(0.8) : .secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .fill(viewModel.selectedTaskType == taskType ? LinearGradient.brandGradient : LinearGradient(colors: [Color(.systemBackground)], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                            .stroke(
                                viewModel.selectedTaskType == taskType ? Color.clear : Color(.systemGray4),
                                lineWidth: 1
                            )
                    )
            )
        }
        .disabled(viewModel.isCreating)
    }
    
    private var dueDatePicker: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Due Date & Time")
                .labelMedium()
                .foregroundColor(.primary)
            
            DatePicker(
                "Due Date",
                selection: Binding(
                    get: { viewModel.dueDate },
                    set: { viewModel.updateDueDate($0) }
                ),
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .disabled(viewModel.isCreating)
            
            if viewModel.hasFieldError(.dueDate) {
                validationErrorView(message: viewModel.getFieldError(.dueDate))
            }
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(
                title: "Location",
                icon: "location",
                isRequired: viewModel.isLocationRequired,
                hasError: viewModel.hasFieldError(.location)
            )
            
            if let selectedLocation = viewModel.selectedLocation {
                selectedLocationView(selectedLocation)
            } else {
                selectLocationButton
            }
            
            // Map placeholder
            mapPlaceholderView
            
            if viewModel.hasFieldError(.location) {
                validationErrorView(message: viewModel.getFieldError(.location))
            }
        }
    }
    
    private func selectedLocationView(_ location: TaskLocation) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Text(location.type.emoji)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    .bodyMedium()
                    .foregroundColor(.primary)
                
                Text(location.address)
                    .captionLarge()
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button("Change") {
                viewModel.showLocationSelection()
            }
            .buttonStyle(TertiaryButtonStyle())
            .disabled(viewModel.isCreating)
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
    }
    
    private var selectLocationButton: some View {
        Button(action: {
            viewModel.showLocationSelection()
        }) {
            HStack {
                Image(systemName: "location.circle")
                    .font(.title2)
                    .foregroundColor(.brandPrimary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Select Location")
                        .bodyMedium()
                        .foregroundColor(.primary)
                    
                    Text(viewModel.isLocationRequired ? "Location is required for this task type" : "Optional location for shopping")
                        .captionLarge()
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .cardPadding()
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                            .stroke(
                                viewModel.hasFieldError(.location) ? Color.red : Color(.systemGray4),
                                style: StrokeStyle(lineWidth: viewModel.hasFieldError(.location) ? 2 : 1, dash: [5])
                            )
                    )
            )
        }
        .disabled(viewModel.isCreating)
    }
    
    private var mapPlaceholderView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Location Preview")
                .captionLarge()
                .foregroundColor(.secondary)
            
            // Use existing map placeholder component
            SchoolRunMapPlaceholder(
                currentStop: viewModel.selectedLocation.map { location in
                    RunStop(name: location.name, type: .custom, task: "Shopping", estimatedMinutes: 15)
                },
                showCurrentLocation: true,
                mapStyle: .thumbnail
            )
            .frame(height: 120)
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(
                title: "Notes",
                icon: "note.text",
                isRequired: false
            )
            
            TextField(
                "Add any special instructions or notes...",
                text: Binding(
                    get: { viewModel.notes },
                    set: { viewModel.updateNotes($0) }
                ),
                axis: .vertical
            )
            .textFieldStyle(ValidatedTextFieldStyle(
                isValid: true,
                isFocused: focusedField == .notes,
                hasError: false
            ))
            .lineLimit(3...6)
            .focused($focusedField, equals: .notes)
            .disabled(viewModel.isCreating)
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Create task button
            Button(action: {
                createTask()
            }) {
                HStack {
                    if viewModel.isCreating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                    }
                    
                    Text(viewModel.isCreating ? "Creating Task..." : "Create Task")
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!viewModel.isFormValid || viewModel.isCreating)
            .accessibilityLabel(viewModel.isCreating ? "Creating shopping task" : "Create shopping task")
            .accessibilityHint("Creates a new shopping task with the selected items and settings")
            
            // Reset form button
            Button("Reset Form") {
                viewModel.resetForm()
                HapticManager.shared.lightImpact()
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(viewModel.isCreating)
            .accessibilityLabel("Reset form")
            .accessibilityHint("Clears all form fields and resets to default values")
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String, icon: String, isRequired: Bool, hasError: Bool = false) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(hasError ? .red : .brandPrimary)
            
            Text(title)
                .titleSmall()
                .foregroundColor(.primary)
            
            if isRequired {
                Text("*")
                    .titleSmall()
                    .foregroundColor(.red)
            }
            
            Spacer()
        }
    }
    
    private func validationErrorView(message: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.red)
            
            Text(message)
                .captionLarge()
                .foregroundColor(.red)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
    }
    
    // MARK: - Actions
    
    private func setupInitialState() {
        if !preSelectedItems.isEmpty {
            viewModel.setItems(preSelectedItems)
        }
        
        // Animate form appearance
        withAnimation(DesignSystem.Animation.smooth.delay(0.1)) {
            isFormVisible = true
        }
    }
    
    private func createTask() {
        // Dismiss keyboard
        focusedField = nil
        
        Task {
            let success = await viewModel.createTask()
            
            if success {
                // Show success animation
                withAnimation(DesignSystem.Animation.bouncy) {
                    showSuccessAnimation = true
                }
                
                // Haptic feedback
                HapticManager.shared.successImpact()
                
                // Call completion handler if provided
                // Note: In a real implementation, we would pass the created task
                onTaskCreated?(ShoppingTask(
                    items: viewModel.selectedItems,
                    assignedTo: viewModel.selectedFamilyMember,
                    taskType: viewModel.selectedTaskType,
                    dueDate: viewModel.dueDate,
                    notes: viewModel.notes.isEmpty ? nil : viewModel.notes,
                    location: viewModel.selectedLocation,
                    status: .pending,
                    createdBy: viewModel.currentUser
                ))
            }
        }
    }
}

// MARK: - Location Picker View

private struct LocationPickerView: View {
    @Binding var selectedLocation: TaskLocation?
    let availableLocations: [TaskLocation]
    let onLocationSelected: (TaskLocation?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button("No Location") {
                        onLocationSelected(nil)
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                
                Section("Available Locations") {
                    ForEach(availableLocations) { location in
                        Button(action: {
                            onLocationSelected(location)
                            dismiss()
                        }) {
                            HStack {
                                Text(location.type.emoji)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(location.name)
                                        .bodyMedium()
                                        .foregroundColor(.primary)
                                    
                                    Text(location.address)
                                        .captionLarge()
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedLocation?.id == location.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.brandPrimary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Task Creation View - Empty") {
    TaskCreationView()
        .previewEnvironment(.authenticated)
}

#Preview("Task Creation View - With Items") {
    TaskCreationView(
        preSelectedItems: MealPlanDataProvider.mockGroceryItems().prefix(3).map { $0 }
    )
    .previewEnvironment(.authenticated)
}

#Preview("Task Creation View - Many Items") {
    TaskCreationView(
        preSelectedItems: MealPlanDataProvider.mockGroceryItems().prefix(8).map { $0 }
    )
    .previewEnvironment(.authenticated)
}

#Preview("Task Creation View - Urgent Items") {
    let urgentItems = MealPlanDataProvider.mockGroceryItems().prefix(3).map { item in
        GroceryItem(
            ingredient: item.ingredient,
            linkedMeal: item.linkedMeal,
            addedBy: item.addedBy,
            addedDate: item.addedDate,
            isUrgent: true,
            notes: item.notes
        )
    }
    
    TaskCreationView(preSelectedItems: urgentItems)
        .previewEnvironment(.authenticated)
}

#Preview("Task Creation View - Loading") {
    TaskCreationView(
        preSelectedItems: MealPlanDataProvider.mockGroceryItems().prefix(2).map { $0 }
    )
    .previewEnvironmentLoading()
}

#Preview("Task Creation View - Dark Mode") {
    TaskCreationView(
        preSelectedItems: MealPlanDataProvider.mockGroceryItems().prefix(2).map { $0 }
    )
    .previewEnvironment(.authenticated)
    .preferredColorScheme(.dark)
}

#Preview("Task Creation View - Large Text") {
    TaskCreationView(
        preSelectedItems: MealPlanDataProvider.mockGroceryItems().prefix(3).map { $0 }
    )
    .previewEnvironment(.authenticated)
    .environment(\.sizeCategory, .extraExtraExtraLarge)
}

#Preview("Task Creation View - iPad") {
    TaskCreationView(
        preSelectedItems: MealPlanDataProvider.mockGroceryItems().prefix(4).map { $0 }
    )
    .previewEnvironment(.authenticated)
    .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
}

#Preview("Task Creation View - High Contrast") {
    TaskCreationView(
        preSelectedItems: MealPlanDataProvider.mockGroceryItems().prefix(2).map { $0 }
    )
    .previewEnvironment(.authenticated)
}

#Preview("Location Picker View") {
    LocationPickerView(
        selectedLocation: .constant(nil),
        availableLocations: [
            TaskLocation(name: "Woolworths Menlyn", address: "Shop 123, Menlyn Park Shopping Centre", latitude: -25.7845, longitude: 28.2314, type: .supermarket),
            TaskLocation(name: "Pick n Pay Hatfield", address: "Corner of Burnett & Duncan Streets", latitude: -25.7479, longitude: 28.2293, type: .supermarket),
            TaskLocation(name: "Checkers Lynnwood", address: "Lynnwood Bridge Shopping Centre", latitude: -25.7679, longitude: 28.2767, type: .supermarket)
        ],
        onLocationSelected: { _ in }
    )
    .previewEnvironment(.authenticated)
}