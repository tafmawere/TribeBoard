import SwiftUI

/// View for displaying and managing shopping tasks with filtering and status updates
struct TaskListView: View {
    @StateObject private var viewModel = TaskListViewModel()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    // State for animations and interactions
    @State private var selectedTask: ShoppingTask?
    @State private var showTaskCreation = false
    @State private var showFilterSheet = false
    @State private var isListVisible = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.filteredTasks.isEmpty {
                    emptyStateView
                } else {
                    taskListContent
                }
            }
            .navigationTitle("Shopping Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    filterButton
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    addTaskButton
                }
            }
            .refreshable {
                await viewModel.loadTasks()
            }
            .sheet(isPresented: $showTaskCreation) {
                TaskCreationView { task in
                    viewModel.addTask(task)
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                TaskFilterSheet(
                    selectedFilters: $viewModel.activeFilters,
                    availableFamilyMembers: viewModel.availableFamilyMembers,
                    onFiltersChanged: { filters in
                        viewModel.applyFilters(filters)
                    }
                )
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailView(task: task) { updatedTask in
                    viewModel.updateTask(updatedTask)
                }
            }
        }
        .onAppear {
            setupInitialState()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearErrorMessage()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading tasks...")
                .bodyMedium()
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("No Shopping Tasks")
                    .headlineSmall()
                    .foregroundColor(.primary)
                
                Text(viewModel.hasActiveFilters ? "No tasks match your current filters" : "Create your first shopping task to get started")
                    .bodyMedium()
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: DesignSystem.Spacing.md) {
                if viewModel.hasActiveFilters {
                    Button("Clear Filters") {
                        viewModel.clearFilters()
                        HapticManager.shared.lightImpact()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                
                Button("Create Task") {
                    showTaskCreation = true
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .screenPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Task List Content
    
    private var taskListContent: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                // Filter summary (if filters are active)
                if viewModel.hasActiveFilters {
                    filterSummaryView
                }
                
                // Task statistics
                taskStatisticsView
                
                // Task list
                ForEach(viewModel.filteredTasks) { task in
                    taskCard(task)
                        .onTapGesture {
                            selectedTask = task
                        }
                }
            }
            .screenPadding()
            .opacity(isListVisible ? 1 : 0)
            .animation(DesignSystem.Animation.smooth, value: isListVisible)
        }
    }
    
    // MARK: - Filter Summary View
    
    private var filterSummaryView: some View {
        HStack {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.title3)
                .foregroundColor(.brandPrimary)
            
            Text("Filtered by: \(viewModel.activeFiltersDescription)")
                .bodySmall()
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Clear") {
                viewModel.clearFilters()
                HapticManager.shared.lightImpact()
            }
            .buttonStyle(TertiaryButtonStyle())
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color.brandPrimary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .stroke(Color.brandPrimary.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Task Statistics View
    
    private var taskStatisticsView: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            statisticCard(
                title: "Total",
                value: "\(viewModel.allTasks.count)",
                icon: "list.bullet.clipboard",
                color: .blue
            )
            
            statisticCard(
                title: "Pending",
                value: "\(viewModel.pendingTasksCount)",
                icon: "clock",
                color: .orange
            )
            
            statisticCard(
                title: "Overdue",
                value: "\(viewModel.overdueTasksCount)",
                icon: "exclamationmark.triangle",
                color: .red
            )
        }
    }
    
    private func statisticCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                
                Spacer()
                
                Text(value)
                    .titleMedium()
                    .foregroundColor(.primary)
                    .fontWeight(.semibold)
            }
            
            HStack {
                Text(title)
                    .captionLarge()
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
    }
    
    // MARK: - Task Card
    
    private func taskCard(_ task: ShoppingTask) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header with task type and status
            taskCardHeader(task)
            
            // Assignment and due date
            taskCardAssignment(task)
            
            // Items preview
            taskCardItems(task)
            
            // Location (if applicable)
            if let location = task.location {
                taskCardLocation(location)
            }
            
            // Action buttons
            taskCardActions(task)
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .overlay(
                    // Priority indicator border
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .stroke(priorityColor(for: task.priority), lineWidth: task.priority == .critical ? 3 : 2)
                        .opacity(task.priority == .low ? 0.3 : 0.6)
                )
                .mediumShadow()
        )
        .contextMenu {
            taskContextMenu(task)
        }
    }
    
    private func taskCardHeader(_ task: ShoppingTask) -> some View {
        HStack {
            // Task type icon and name
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text(task.taskType.emoji)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.taskType.rawValue)
                        .titleSmall()
                        .foregroundColor(.primary)
                    
                    if task.isOverdue {
                        Text("OVERDUE")
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
            }
            
            Spacer()
            
            // Status badge
            statusBadge(for: task.status)
        }
    }
    
    private func taskCardAssignment(_ task: ShoppingTask) -> some View {
        HStack {
            // Assigned to
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "person.circle.fill")
                    .font(.caption)
                    .foregroundColor(.brandPrimary)
                
                Text("Assigned to \(task.assignedTo)")
                    .captionLarge()
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Due date
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: task.isOverdue ? "exclamationmark.triangle.fill" : "clock")
                    .font(.caption)
                    .foregroundColor(task.isOverdue ? .red : .orange)
                
                Text(task.shortDueDate)
                    .captionLarge()
                    .foregroundColor(task.isOverdue ? .red : .secondary)
                    .fontWeight(task.isOverdue ? .semibold : .regular)
            }
        }
    }
    
    private func taskCardItems(_ task: ShoppingTask) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Image(systemName: "cart")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(task.itemCount) item\(task.itemCount == 1 ? "" : "s")")
                    .captionLarge()
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            Text(task.itemSummary)
                .bodySmall()
                .foregroundColor(.primary)
                .lineLimit(2)
        }
    }
    
    private func taskCardLocation(_ location: TaskLocation) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Text(location.type.emoji)
                .font(.caption)
            
            Text(location.name)
                .captionLarge()
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private func taskCardActions(_ task: ShoppingTask) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Status update buttons
            if task.status == .pending {
                Button("Start") {
                    viewModel.updateTaskStatus(task, to: .inProgress)
                    HapticManager.shared.lightImpact()
                }
                .buttonStyle(TertiaryButtonStyle())
            } else if task.status == .inProgress {
                Button("Complete") {
                    viewModel.updateTaskStatus(task, to: .completed)
                    HapticManager.shared.successImpact()
                }
                .buttonStyle(TertiaryButtonStyle())
            }
            
            Spacer()
            
            // View details button
            Button("Details") {
                selectedTask = task
            }
            .buttonStyle(TertiaryButtonStyle())
        }
    }
    
    // MARK: - Helper Views
    
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
    
    // MARK: - Context Menu
    
    private func taskContextMenu(_ task: ShoppingTask) -> some View {
        Group {
            Button(action: {
                selectedTask = task
            }) {
                Label("View Details", systemImage: "info.circle")
            }
            
            if task.status == .pending {
                Button(action: {
                    viewModel.updateTaskStatus(task, to: .inProgress)
                }) {
                    Label("Start Task", systemImage: "play.circle")
                }
            }
            
            if task.status == .inProgress {
                Button(action: {
                    viewModel.updateTaskStatus(task, to: .completed)
                }) {
                    Label("Mark Complete", systemImage: "checkmark.circle")
                }
            }
            
            Divider()
            
            Button(action: {
                viewModel.duplicateTask(task)
            }) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            
            Button(role: .destructive, action: {
                viewModel.deleteTask(task)
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Toolbar Buttons
    
    private var filterButton: some View {
        Button(action: {
            showFilterSheet = true
        }) {
            Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.title3)
                .foregroundColor(.brandPrimary)
        }
        .accessibilityLabel(viewModel.hasActiveFilters ? "Filter tasks (active)" : "Filter tasks")
        .accessibilityHint("Opens filter options to sort and filter shopping tasks")
    }
    
    private var addTaskButton: some View {
        Button(action: {
            showTaskCreation = true
        }) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundColor(.brandPrimary)
        }
        .accessibilityLabel("Add new task")
        .accessibilityHint("Creates a new shopping task")
    }
    
    // MARK: - Actions
    
    private func setupInitialState() {
        Task {
            await viewModel.loadTasks()
            
            // Animate list appearance
            withAnimation(DesignSystem.Animation.smooth.delay(0.2)) {
                isListVisible = true
            }
        }
    }
}

// MARK: - Task List ViewModel

@MainActor
class TaskListViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var allTasks: [ShoppingTask] = []
    @Published var filteredTasks: [ShoppingTask] = []
    @Published var activeFilters = TaskFilters()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var availableFamilyMembers: [String] = []
    
    // MARK: - Computed Properties
    
    var hasActiveFilters: Bool {
        !activeFilters.isEmpty
    }
    
    var activeFiltersDescription: String {
        var descriptions: [String] = []
        
        if let person = activeFilters.assignedTo {
            descriptions.append(person)
        }
        
        if let status = activeFilters.status {
            descriptions.append(status.rawValue)
        }
        
        if activeFilters.showOverdueOnly {
            descriptions.append("Overdue")
        }
        
        return descriptions.isEmpty ? "None" : descriptions.joined(separator: ", ")
    }
    
    var pendingTasksCount: Int {
        allTasks.filter { $0.status == .pending }.count
    }
    
    var overdueTasksCount: Int {
        allTasks.filter { $0.isOverdue }.count
    }
    
    // MARK: - Initialization
    
    init() {
        setupInitialState()
    }
    
    // MARK: - Public Methods
    
    func loadTasks() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Simulate network delay
            try await Task.sleep(nanoseconds: 500_000_000)
            
            let tasks = MealPlanDataProvider.mockShoppingTasks()
            
            await MainActor.run {
                self.allTasks = tasks
                self.applyCurrentFilters()
                self.availableFamilyMembers = Array(Set(tasks.map { $0.assignedTo })).sorted()
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load tasks: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    func applyFilters(_ filters: TaskFilters) {
        activeFilters = filters
        applyCurrentFilters()
    }
    
    func clearFilters() {
        activeFilters = TaskFilters()
        applyCurrentFilters()
    }
    
    func updateTaskStatus(_ task: ShoppingTask, to status: TaskStatus) {
        if let index = allTasks.firstIndex(where: { $0.id == task.id }) {
            var updatedTask = allTasks[index]
            updatedTask.status = status
            allTasks[index] = updatedTask
            applyCurrentFilters()
        }
    }
    
    func addTask(_ task: ShoppingTask) {
        allTasks.append(task)
        applyCurrentFilters()
    }
    
    func updateTask(_ task: ShoppingTask) {
        if let index = allTasks.firstIndex(where: { $0.id == task.id }) {
            allTasks[index] = task
            applyCurrentFilters()
        }
    }
    
    func duplicateTask(_ task: ShoppingTask) {
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
        
        allTasks.append(duplicatedTask)
        applyCurrentFilters()
    }
    
    func deleteTask(_ task: ShoppingTask) {
        allTasks.removeAll { $0.id == task.id }
        applyCurrentFilters()
    }
    
    func clearErrorMessage() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func setupInitialState() {
        // Load initial data
        Task {
            await loadTasks()
        }
    }
    
    private func applyCurrentFilters() {
        var filtered = allTasks
        
        // Filter by assigned person
        if let assignedTo = activeFilters.assignedTo {
            filtered = filtered.filter { $0.assignedTo == assignedTo }
        }
        
        // Filter by status
        if let status = activeFilters.status {
            filtered = filtered.filter { $0.status == status }
        }
        
        // Filter by overdue
        if activeFilters.showOverdueOnly {
            filtered = filtered.filter { $0.isOverdue }
        }
        
        // Sort by priority and due date
        filtered.sort { task1, task2 in
            // First sort by priority
            if task1.priority.sortOrder != task2.priority.sortOrder {
                return task1.priority.sortOrder < task2.priority.sortOrder
            }
            
            // Then by due date
            return task1.dueDate < task2.dueDate
        }
        
        filteredTasks = filtered
    }
}

// MARK: - Task Filters
// TaskFilters is defined in TasksViewModel.swift

// MARK: - Preview

#Preview("Task List View - With Tasks") {
    TaskListView()
        .previewEnvironment(.authenticated)
}

#Preview("Task List View - Empty") {
    TaskListView()
        .onAppear {
            // Simulate empty state by clearing tasks
        }
        .previewEnvironment(.authenticated)
}

#Preview("Task List View - Loading") {
    TaskListView()
        .previewEnvironmentLoading()
}

#Preview("Task List View - Filtered") {
    TaskListView()
        .onAppear {
            // Simulate filtered state
        }
        .previewEnvironment(.authenticated)
}

#Preview("Task List View - Overdue Tasks") {
    TaskListView()
        .onAppear {
            // Simulate overdue tasks
        }
        .previewEnvironment(.authenticated)
}

#Preview("Task List View - Dark Mode") {
    TaskListView()
        .previewEnvironment(.authenticated)
        .preferredColorScheme(.dark)
}

#Preview("Task List View - Large Text") {
    TaskListView()
        .previewEnvironment(.authenticated)
        .environment(\.sizeCategory, .extraExtraExtraLarge)
}

#Preview("Task List View - iPad") {
    TaskListView()
        .previewEnvironment(.authenticated)
        .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
}

#Preview("Task List View - High Contrast") {
    TaskListView()
        .previewEnvironment(.authenticated)
}

#Preview("Task List View - Parent Admin") {
    TaskListView()
        .previewEnvironment(role: .parentAdmin)
}

#Preview("Task List View - Kid") {
    TaskListView()
        .previewEnvironment(role: .kid)
}