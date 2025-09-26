import SwiftUI

/// Detailed view for a shopping task with editing capabilities
struct TaskDetailView: View {
    let task: ShoppingTask
    let onTaskUpdated: (ShoppingTask) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var editedTask: ShoppingTask
    @State private var isEditing = false
    @State private var showDeleteConfirmation = false
    
    init(task: ShoppingTask, onTaskUpdated: @escaping (ShoppingTask) -> Void) {
        self.task = task
        self.onTaskUpdated = onTaskUpdated
        self._editedTask = State(initialValue: task)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Task header
                    taskHeaderSection
                    
                    // Task details
                    taskDetailsSection
                    
                    // Items section
                    itemsSection
                    
                    // Location section
                    if let location = task.location {
                        locationSection(location)
                    }
                    
                    // Notes section
                    if let notes = task.notes, !notes.isEmpty {
                        notesSection(notes)
                    }
                    
                    // Action buttons
                    actionButtonsSection
                }
                .screenPadding()
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            saveChanges()
                        } else {
                            isEditing = true
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("Delete Task", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteTask()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this shopping task? This action cannot be undone.")
        }
    }
    
    // MARK: - Task Header Section
    
    private var taskHeaderSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text(task.taskType.emoji)
                    .font(.largeTitle)
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(task.taskType.rawValue)
                        .headlineSmall()
                        .foregroundColor(.primary)
                    
                    Text("Created by \(task.createdBy)")
                        .captionLarge()
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                statusBadge(for: task.status)
            }
            
            // Priority indicator
            if task.priority != .low {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(priorityColor(for: task.priority))
                    
                    Text("\(task.priority.rawValue) Priority")
                        .captionLarge()
                        .foregroundColor(priorityColor(for: task.priority))
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(LinearGradient.brandGradientSubtle)
                .overlay(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .stroke(priorityColor(for: task.priority).opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    // MARK: - Task Details Section
    
    private var taskDetailsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader("Task Details", icon: "info.circle")
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                detailRow(
                    icon: "person.circle.fill",
                    title: "Assigned To",
                    value: task.assignedTo,
                    color: .brandPrimary
                )
                
                detailRow(
                    icon: task.isOverdue ? "exclamationmark.triangle.fill" : "clock",
                    title: "Due Date",
                    value: task.formattedDueDate,
                    color: task.isOverdue ? .red : .orange
                )
                
                detailRow(
                    icon: "calendar",
                    title: "Created",
                    value: formatDate(task.createdAt),
                    color: .secondary
                )
                
                if task.isOverdue {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                        
                        Text("This task is overdue")
                            .captionLarge()
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                        
                        Spacer()
                    }
                    .padding(DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                            .fill(Color.red.opacity(0.1))
                    )
                }
            }
        }
    }
    
    // MARK: - Items Section
    
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader("Shopping Items (\(task.itemCount))", icon: "cart")
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(task.items) { item in
                    itemDetailRow(item)
                }
            }
        }
    }
    
    private func itemDetailRow(_ item: GroceryItem) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
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
                
                if let notes = item.notes {
                    Text(notes)
                        .captionSmall()
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            Spacer()
            
            if item.isUrgent {
                Text("URGENT")
                    .captionSmall()
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                            .fill(Color.red)
                    )
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
    }
    
    // MARK: - Location Section
    
    private func locationSection(_ location: TaskLocation) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader("Location", icon: "location")
            
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
                
                Button("Directions") {
                    // In a real app, this would open Maps
                    HapticManager.shared.lightImpact()
                }
                .buttonStyle(TertiaryButtonStyle())
            }
            .cardPadding()
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .fill(Color(.systemBackground))
                    .lightShadow()
            )
            
            // Map placeholder
            SchoolRunMapPlaceholder(
                currentStop: RunStop(name: location.name, type: .custom, task: "Shopping", estimatedMinutes: 15),
                showCurrentLocation: true,
                mapStyle: .thumbnail
            )
            .frame(height: 120)
        }
    }
    
    // MARK: - Notes Section
    
    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader("Notes", icon: "note.text")
            
            Text(notes)
                .bodyMedium()
                .foregroundColor(.primary)
                .padding(DesignSystem.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .fill(Color(.systemGray6))
                )
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Status update buttons
            if task.status == .pending {
                Button("Start Task") {
                    updateTaskStatus(.inProgress)
                }
                .buttonStyle(PrimaryButtonStyle())
            } else if task.status == .inProgress {
                Button("Mark Complete") {
                    updateTaskStatus(.completed)
                }
                .buttonStyle(PrimaryButtonStyle())
            } else if task.status == .completed {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    Text("Task Completed")
                        .titleMedium()
                        .foregroundColor(.green)
                    
                    Spacer()
                }
                .cardPadding()
                .background(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .fill(Color.green.opacity(0.1))
                )
            }
            
            // Secondary actions
            HStack(spacing: DesignSystem.Spacing.md) {
                Button("Duplicate") {
                    duplicateTask()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Delete") {
                    showDeleteConfirmation = true
                }
                .buttonStyle(DestructiveButtonStyle())
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.brandPrimary)
            
            Text(title)
                .titleSmall()
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    private func detailRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 16)
            
            Text(title)
                .captionLarge()
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .captionLarge()
                .foregroundColor(.primary)
                .fontWeight(.medium)
        }
    }
    
    private func statusBadge(for status: TaskStatus) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Text(status.emoji)
                .font(.caption)
            
            Text(status.rawValue)
                .captionSmall()
                .fontWeight(.semibold)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                .fill(statusColor(for: status).opacity(0.2))
        )
        .foregroundColor(statusColor(for: status))
    }
    
    private func statusColor(for status: TaskStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .inProgress: return .blue
        case .completed: return .green
        case .cancelled: return .gray
        }
    }
    
    private func priorityColor(for priority: TaskPriority) -> Color {
        switch priority {
        case .low: return .gray
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Actions
    
    private func updateTaskStatus(_ status: TaskStatus) {
        var updatedTask = task
        updatedTask.status = status
        onTaskUpdated(updatedTask)
        
        // Provide haptic feedback
        switch status {
        case .completed:
            HapticManager.shared.successImpact()
        default:
            HapticManager.shared.lightImpact()
        }
        
        dismiss()
    }
    
    private func duplicateTask() {
        let duplicatedTask = ShoppingTask(
            items: task.items,
            assignedTo: task.assignedTo,
            taskType: task.taskType,
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: task.dueDate) ?? task.dueDate,
            notes: task.notes,
            location: task.location,
            status: .pending,
            createdBy: task.createdBy
        )
        
        onTaskUpdated(duplicatedTask)
        HapticManager.shared.lightImpact()
        dismiss()
    }
    
    private func deleteTask() {
        // In a real app, this would delete the task
        HapticManager.shared.warning()
        dismiss()
    }
    
    private func saveChanges() {
        onTaskUpdated(editedTask)
        isEditing = false
        HapticManager.shared.lightImpact()
    }
}

#Preview("Task Detail View") {
    TaskDetailView(
        task: MealPlanDataProvider.mockShoppingTasks().first!,
        onTaskUpdated: { _ in }
    )
}

#Preview("Task Detail View - Overdue") {
    let overdueTasks = MealPlanDataProvider.mockShoppingTasks()
    TaskDetailView(
        task: overdueTasks.first { $0.isOverdue } ?? overdueTasks.first!,
        onTaskUpdated: { _ in }
    )
}